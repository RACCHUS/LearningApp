-- TEL-01B / TEL-04A: pgTAP verification for public.context_fast_preferences and
-- public.update_context_fast_preferences compare-and-set concurrency, exact
-- 64-bit advisory lock acquisition, idempotency, authorization, direct-DELETE
-- denial, and strict separation from learning_contexts.scope_config.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(28);

INSERT INTO auth.users (id, email)
VALUES
  ('c1100000-0000-4000-8000-000000000001', 'tel01b-owner@example.invalid'),
  ('c1100000-0000-4000-8000-000000000002', 'tel01b-other@example.invalid')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.learning_contexts (
  id,
  user_id,
  label,
  root_type,
  root_id,
  scope_config
)
VALUES
  (
    'c2200000-0000-4000-8000-000000000001',
    'c1100000-0000-4000-8000-000000000001',
    'CLEP Introductory Psychology',
    'target',
    '00000000-0000-4000-8000-000000000101',
    '{"preserve_me": true}'::jsonb
  ),
  (
    'c2200000-0000-4000-8000-000000000002',
    'c1100000-0000-4000-8000-000000000002',
    'Other Learner Target',
    'target',
    '00000000-0000-4000-8000-000000000101',
    '{}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

-- 1. Privilege and grant invariants (including direct DELETE revocation)
SELECT ok(
  has_table_privilege('authenticated', 'public.context_fast_preferences', 'SELECT'),
  'Authenticated learners can SELECT own context_fast_preferences'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.context_fast_preferences', 'INSERT'),
  'Authenticated learners cannot bypass CAS via direct INSERT'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.context_fast_preferences', 'UPDATE'),
  'Authenticated learners cannot bypass CAS via direct UPDATE'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.context_fast_preferences', 'DELETE'),
  'Authenticated learners cannot reset revision history via direct DELETE'
);
SELECT ok(
  has_function_privilege(
    'authenticated',
    'public.update_context_fast_preferences(uuid, integer, text, text, integer, timestamptz, text[])',
    'EXECUTE'
  ),
  'Authenticated learners can execute update_context_fast_preferences RPC'
);
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'public.update_context_fast_preferences(uuid, integer, text, text, integer, timestamptz, text[])',
    'EXECUTE'
  ),
  'Anonymous role cannot execute update_context_fast_preferences RPC'
);

-- 2. Unauthenticated rejection
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$ SELECT public.update_context_fast_preferences(
       'c2200000-0000-4000-8000-000000000001'::uuid,
       0,
       'mut-anon',
       'fast'
     ) $$,
  '42501',
  NULL,
  'Unauthenticated call to update_context_fast_preferences is rejected'
);

-- 3. Authenticated owner context & cross-user rejection
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  'c1100000-0000-4000-8000-000000000001',
  true
);

SELECT throws_ok(
  $$ INSERT INTO public.context_fast_preferences (
       context_id, user_id, strategy, revision
     ) VALUES (
       'c2200000-0000-4000-8000-000000000001'::uuid,
       'c1100000-0000-4000-8000-000000000001'::uuid,
       'fast',
       99
     ) $$,
  '42501',
  NULL,
  'Direct client INSERT into context_fast_preferences is denied'
);

SELECT throws_ok(
  $$ SELECT public.update_context_fast_preferences(
       'c2200000-0000-4000-8000-000000000002'::uuid,
       0,
       'mut-cross-user',
       'fast'
     ) $$,
  '42501',
  NULL,
  'Cannot update Fast preferences on another learner context'
);

-- 4. First write with non-zero expected_revision fails as conflict without inserting
CREATE TEMP TABLE tel01b_nonzero_first_write AS
  SELECT public.update_context_fast_preferences(
    'c2200000-0000-4000-8000-000000000001'::uuid,
    2,
    'mut-bad-first-rev',
    'fast'
  ) AS payload;

SELECT is(
  (SELECT (payload->>'conflict')::boolean FROM tel01b_nonzero_first_write),
  true,
  'First write with expected_revision > 0 when no server row exists returns conflict=true'
);
SELECT is(
  (SELECT (payload->>'actual_revision')::integer FROM tel01b_nonzero_first_write),
  0,
  'First write conflict reports actual_revision = 0'
);
SELECT is(
  (SELECT count(*)::integer FROM public.context_fast_preferences
    WHERE context_id = 'c2200000-0000-4000-8000-000000000001'::uuid),
  0,
  'Rejected first write does not insert a row'
);

-- 5. Valid initial CAS write (rev 0 -> rev 1) from Device A
CREATE TEMP TABLE tel01b_device_a_write AS
  SELECT public.update_context_fast_preferences(
    'c2200000-0000-4000-8000-000000000001'::uuid,
    0,
    'mut-device-a-1',
    'fast',
    45,
    NULL,
    ARRAY['lesson-b', 'lesson-a', 'lesson-a']
  ) AS payload;

SELECT is(
  (SELECT (payload->>'conflict')::boolean FROM tel01b_device_a_write),
  false,
  'Valid rev 0 -> rev 1 CAS write succeeds without conflict'
);
SELECT is(
  (SELECT (payload->'preference'->>'revision')::integer FROM tel01b_device_a_write),
  1,
  'Server assigns revision = 1 on initial CAS write'
);
SELECT is(
  (SELECT payload->'preference'->>'strategy' FROM tel01b_device_a_write),
  'fast',
  'Server persists strategy = fast'
);
SELECT is(
  (SELECT payload->'preference'->'manual_skipped_activity_ids' FROM tel01b_device_a_write),
  '["lesson-a", "lesson-b"]'::jsonb,
  'Server normalizes and deduplicates manual_skipped_activity_ids'
);
SELECT is(
  (SELECT scope_config FROM public.learning_contexts
    WHERE id = 'c2200000-0000-4000-8000-000000000001'::uuid),
  '{"preserve_me": true}'::jsonb,
  'learning_contexts.scope_config remains completely untouched by Fast preference writes'
);

-- Verify direct DELETE by authenticated owner is denied on existing preference row
SELECT throws_ok(
  $$ DELETE FROM public.context_fast_preferences
      WHERE context_id = 'c2200000-0000-4000-8000-000000000001'::uuid $$,
  '42501',
  NULL,
  'Authenticated owner cannot directly DELETE context_fast_preferences row to reset revision'
);

-- 6. Verify transaction-scoped 64-bit advisory lock is held in pg_locks for target context
SELECT ok(
  EXISTS (
    SELECT 1
      FROM pg_locks
     WHERE locktype = 'advisory'
       AND pid = pg_backend_pid()
       AND granted = true
       AND objsubid = 1
       AND ((classid::bigint << 32) | (objid::bigint & 4294967295)) =
           pg_catalog.hashtextextended(
             'fast-pref:c2200000-0000-4000-8000-000000000001',
             0
           )
  ),
  'update_context_fast_preferences acquires exact 64-bit transaction-scoped advisory lock in pg_locks for target context'
);

-- 7. Idempotent replay with same mutation_id does not increment revision
CREATE TEMP TABLE tel01b_replay AS
  SELECT public.update_context_fast_preferences(
    'c2200000-0000-4000-8000-000000000001'::uuid,
    0,
    'mut-device-a-1',
    'fast',
    45,
    NULL,
    ARRAY['lesson-a', 'lesson-b']
  ) AS payload;

SELECT is(
  (SELECT payload->>'status' FROM tel01b_replay),
  'idempotent_replay',
  'Duplicate mutation_id returns idempotent_replay'
);
SELECT is(
  (SELECT (payload->'preference'->>'revision')::integer FROM tel01b_replay),
  1,
  'Idempotent replay preserves revision = 1 without incrementing'
);

-- 8. Concurrent / stale write from Device B with expected_revision = 0 fails as conflict
CREATE TEMP TABLE tel01b_device_b_conflict AS
  SELECT public.update_context_fast_preferences(
    'c2200000-0000-4000-8000-000000000001'::uuid,
    0,
    'mut-device-b-stale',
    'standard',
    15,
    NULL,
    ARRAY[]::text[]
  ) AS payload;

SELECT is(
  (SELECT (payload->>'conflict')::boolean FROM tel01b_device_b_conflict),
  true,
  'Concurrent/stale write with expected_revision = 0 against revision = 1 returns conflict=true'
);
SELECT is(
  (SELECT payload->'preference'->>'strategy' FROM tel01b_device_b_conflict),
  'fast',
  'Conflict payload returns authoritative strategy = fast'
);
SELECT is(
  (SELECT (payload->'preference'->>'optional_total_minutes')::integer FROM tel01b_device_b_conflict),
  45,
  'Conflict payload preserves authoritative optional_total_minutes = 45'
);

-- 9. Subsequent valid CAS update (rev 1 -> rev 2) succeeds
CREATE TEMP TABLE tel01b_device_b_retry AS
  SELECT public.update_context_fast_preferences(
    'c2200000-0000-4000-8000-000000000001'::uuid,
    1,
    'mut-device-b-retry-2',
    'standard',
    NULL,
    NULL,
    ARRAY['lesson-c']
  ) AS payload;

SELECT is(
  (SELECT (payload->>'conflict')::boolean FROM tel01b_device_b_retry),
  false,
  'Rebased CAS write at expected_revision = 1 succeeds'
);
SELECT is(
  (SELECT (payload->'preference'->>'revision')::integer FROM tel01b_device_b_retry),
  2,
  'Rebased CAS write advances revision to 2'
);

-- 10. Cross-user RLS visibility and ON DELETE CASCADE from parent learning_context
SELECT set_config(
  'request.jwt.claim.sub',
  'c1100000-0000-4000-8000-000000000002',
  true
);
SELECT is(
  (SELECT count(*)::integer FROM public.context_fast_preferences
    WHERE context_id = 'c2200000-0000-4000-8000-000000000001'::uuid),
  0,
  'Other learner cannot SELECT owner context_fast_preferences under RLS'
);

SELECT set_config(
  'request.jwt.claim.sub',
  'c1100000-0000-4000-8000-000000000001',
  true
);
DELETE FROM public.learning_contexts
 WHERE id = 'c2200000-0000-4000-8000-000000000001'::uuid;

SELECT is(
  (SELECT count(*)::integer FROM public.context_fast_preferences
    WHERE context_id = 'c2200000-0000-4000-8000-000000000001'::uuid),
  0,
  'Deleting parent learning_context cascades to context_fast_preferences even with direct DELETE revoked'
);

SELECT * FROM finish();
ROLLBACK;
