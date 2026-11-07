-- ============================================================================
-- pgTAP Tests: Strict Learning Events Architecture Rules & Projections
-- Test file: supabase/tests/learning_events_strict_rules_test.sql
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(29);

-- 1. Setup synthetic test users in auth.users and public.users
insert into auth.users (id, email) values
  ('ee111111-0000-4000-8000-000000000001', 'strict_tester1@example.invalid'),
  ('ee111111-0000-4000-8000-000000000002', 'strict_tester2@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email, display_name) values
  ('ee111111-0000-4000-8000-000000000001', 'strict_tester1@example.invalid', 'strict_tester1'),
  ('ee111111-0000-4000-8000-000000000002', 'strict_tester2@example.invalid', 'strict_tester2')
on conflict (id) do nothing;

-- Setup test review item for tester 1
insert into public.review_items (
  id, user_id, content_id, content_type, lesson_id, title,
  stability, difficulty, fsrs_state, total_reviews, correct_reviews
) values (
  'fa111111-0000-4000-8000-000000000001',
  'ee111111-0000-4000-8000-000000000001',
  'strict-card-1', 'term', 'lesson-strict', 'Strict Term 1',
  2.5, 4.5, 1, 0, 0
) on conflict do nothing;

-- 1. TEST: Anonymous caller cannot execute record_events
set local role anon;
select throws_ok(
  $$ select record_events(array['{"event_type":"review","item_id":"strict-card-1"}'::jsonb]) $$,
  '42501',
  null,
  'Anon role cannot execute record_events'
);

-- Switch to authenticated User 1
set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', 'ee111111-0000-4000-8000-000000000001', true);
end $$;

-- 2. TEST: Missing idempotency_key returns rejected_missing_idempotency_key
create temp table missing_key_res as
select record_events(array[
  jsonb_build_object(
    'event_type', 'memory_card_review',
    'item_id', 'strict-card-1',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 1
  )
]) as res;

select is(
  (select res->'results'->0->>'status' from missing_key_res),
  'rejected_missing_idempotency_key',
  'Event missing idempotency_key returns rejected_missing_idempotency_key status'
);

-- 3. TEST: Event with envelope id but missing idempotency_key returns rejected_missing_idempotency_key (no fallback to id)
create temp table missing_key_with_id_res as
select record_events(array[
  jsonb_build_object(
    'id', 'fa444444-0000-4000-8000-000000000001',
    'event_type', 'memory_card_review',
    'item_id', 'strict-card-1',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 1
  )
]) as res;

select is(
  (select res->'results'->0->>'status' from missing_key_with_id_res),
  'rejected_missing_idempotency_key',
  'Event with envelope id but missing idempotency_key returns rejected_missing_idempotency_key status'
);

-- 4. TEST: Valid modern event is accepted
create temp table valid_event_res as
select record_events(array[
  jsonb_build_object(
    'idempotency_key', 'ik-001-test',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 1,
    'event_type', 'memory_card_review',
    'item_type', 'term',
    'item_id', 'strict-card-1',
    'rating', 3,
    'score', 1.0,
    'client_latency_ms', 1250,
    'presented_option_ids', jsonb_build_array('opt-a', 'opt-b'),
    'scheduler_state_after', jsonb_build_object(
      'stability', 3.8,
      'difficulty', 4.2,
      'state', 2,
      'due', (now() + interval '3 days')::text
    )
  )
]) as res;

select is(
  (select res->'results'->0->>'status' from valid_event_res),
  'accepted',
  'Valid modern event returns accepted status'
);

-- 5. TEST: Table public.learning_events stores canonical payload_sha256 and effective_occurred_at
select is(
  (select count(*)::int from public.learning_events
   where user_id = 'ee111111-0000-4000-8000-000000000001'
     and idempotency_key = 'ik-001-test'
     and payload_sha256 is not null
     and effective_occurred_at is not null
     and client_seq = 1),
  1,
  'public.learning_events stores non-null payload_sha256 and effective_occurred_at'
);

-- 6. TEST: review_items projection is updated
select is(
  (select total_reviews::int from public.review_items where id = 'fa111111-0000-4000-8000-000000000001'),
  1,
  'review_items total_reviews is incremented to 1'
);

-- 7. TEST: Duplicate replay of identical payload returns duplicate_noop
create temp table replay_event_res as
select record_events(array[
  jsonb_build_object(
    'idempotency_key', 'ik-001-test',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 1,
    'event_type', 'memory_card_review',
    'item_type', 'term',
    'item_id', 'strict-card-1',
    'rating', 3,
    'score', 1.0,
    'client_latency_ms', 1250,
    'presented_option_ids', jsonb_build_array('opt-a', 'opt-b')
  )
]) as res;

select is(
  (select res->'results'->0->>'status' from replay_event_res),
  'duplicate_noop',
  'Replaying identical payload returns duplicate_noop status'
);

-- 7. TEST: Duplicate replay returns the original event_id
select is(
  (select res->'results'->0->>'event_id' from replay_event_res),
  (select id::text from public.learning_events where idempotency_key = 'ik-001-test'),
  'duplicate_noop returns existing persisted event_id'
);

-- 8. TEST: Replay does not double-increment review_items
select is(
  (select total_reviews::int from public.review_items where id = 'fa111111-0000-4000-8000-000000000001'),
  1,
  'review_items total_reviews remains 1 after replay'
);

-- 9. TEST: Reusing same idempotency_key with modified payload returns idempotency_payload_mismatch
create temp table mismatch_event_res as
select record_events(array[
  jsonb_build_object(
    'idempotency_key', 'ik-001-test',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 1,
    'event_type', 'memory_card_review',
    'item_type', 'term',
    'item_id', 'strict-card-1',
    'rating', 1, -- Changed rating from 3 to 1
    'score', 0.0,
    'client_latency_ms', 9999
  )
]) as res;

select is(
  (select res->'results'->0->>'status' from mismatch_event_res),
  'idempotency_payload_mismatch',
  'Reusing idempotency_key with modified payload flags idempotency_payload_mismatch'
);

-- 10. TEST: Intra-batch deduplication: two identical events in same batch
create temp table intra_batch_res as
select record_events(array[
  jsonb_build_object(
    'idempotency_key', 'ik-002-dup',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 2,
    'event_type', 'memory_card_review',
    'item_type', 'term',
    'item_id', 'strict-card-1',
    'rating', 4,
    'score', 1.0
  ),
  jsonb_build_object(
    'idempotency_key', 'ik-002-dup',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 2,
    'event_type', 'memory_card_review',
    'item_type', 'term',
    'item_id', 'strict-card-1',
    'rating', 4,
    'score', 1.0
  )
]) as res;

select is(
  (select res->'results'->0->>'status' from intra_batch_res),
  'accepted',
  'First item in identical intra-batch group is accepted'
);

-- 11. TEST: Second item in identical intra-batch group is duplicate_noop
select is(
  (select res->'results'->1->>'status' from intra_batch_res),
  'duplicate_noop',
  'Second item in identical intra-batch group is marked duplicate_noop'
);

-- 12. TEST: Results preserve input array order
select is(
  (select count(*)::int from jsonb_array_elements((select res->'results' from intra_batch_res))),
  2,
  'Results array preserves exact input batch length'
);

-- 13. TEST: Intra-batch conflict: same idempotency_key with different payloads is quarantined
create temp table intra_conflict_res as
select record_events(array[
  jsonb_build_object(
    'idempotency_key', 'ik-003-conflict',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 3,
    'rating', 2
  ),
  jsonb_build_object(
    'idempotency_key', 'ik-003-conflict',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 3,
    'rating', 4 -- Conflicting payload
  )
]) as res;

select is(
  (select res->'results'->0->>'status' from intra_conflict_res),
  'idempotency_payload_mismatch',
  'Conflicting intra-batch item 0 is quarantined with idempotency_payload_mismatch'
);

-- 14. TEST: Conflicting intra-batch item 1 is also quarantined
select is(
  (select res->'results'->1->>'status' from intra_conflict_res),
  'idempotency_payload_mismatch',
  'Conflicting intra-batch item 1 is quarantined with idempotency_payload_mismatch'
);

-- 15. TEST: Sequence conflict within same session is rejected
create temp table seq_conflict_res as
select record_events(array[
  jsonb_build_object(
    'idempotency_key', 'ik-004-new-key-colliding-seq',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 1, -- Sequence 1 is already taken by ik-001-test
    'event_type', 'memory_card_review',
    'item_id', 'strict-card-1'
  )
]) as res;

select is(
  (select res->'results'->0->>'status' from seq_conflict_res),
  'sequence_conflict',
  'New key colliding with existing session sequence returns sequence_conflict'
);

-- 16. TEST: Subtransaction isolation: valid sibling item succeeds when another item fails
create temp table sibling_res as
select record_events(array[
  jsonb_build_object(
    'idempotency_key', 'ik-005-bad-seq',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 1, -- Sequence conflict with seq 1
    'event_type', 'memory_card_review',
    'item_id', 'strict-card-1'
  ),
  jsonb_build_object(
    'idempotency_key', 'ik-006-good-sibling',
    'session_id', 'fa222222-0000-4000-8000-000000000001',
    'client_seq', 10, -- Clean sequence 10
    'event_type', 'memory_card_review',
    'item_id', 'strict-card-1',
    'rating', 3
  )
]) as res;

select is(
  (select res->'results'->0->>'status' from sibling_res),
  'sequence_conflict',
  'First item failed with sequence_conflict'
);

select is(
  (select res->'results'->1->>'status' from sibling_res),
  'accepted',
  'Second item in batch succeeded with accepted despite sibling failure'
);

-- 17. TEST: Direct client INSERT into user_concept_state is rejected by RLS (42501)
select throws_ok(
  $$ insert into public.user_concept_state (
       user_id, concept_id, evidence_count, weighted_correct, weighted_total
     ) values (
       'ee111111-0000-4000-8000-000000000001',
       'fa333333-0000-4000-8000-000000000001',
       1, 1.0, 1.0
     ) $$,
  '42501',
  null,
  'Direct client INSERT into user_concept_state is denied by RLS'
);

-- 18. TEST: Direct client UPDATE into user_concept_state is denied by RLS (42501)
select throws_ok(
  $$ update public.user_concept_state
     set evidence_count = 100
     where user_id = 'ee111111-0000-4000-8000-000000000001' $$,
  '42501',
  null,
  'Direct client UPDATE into user_concept_state is denied by RLS'
);

-- 19. TEST: Authenticated client SELECT on own user_concept_state is allowed
select lives_ok(
  $$ select * from public.user_concept_state where user_id = 'ee111111-0000-4000-8000-000000000001' $$,
  'Authenticated user can SELECT own user_concept_state'
);

-- 20. TEST: Cross-user SELECT on user_concept_state returns 0 rows
do $$ begin
  perform set_config('request.jwt.claim.sub', 'ee111111-0000-4000-8000-000000000002', true);
end $$;

select is(
  (select count(*)::int from public.user_concept_state where user_id = 'ee111111-0000-4000-8000-000000000001'),
  0,
  'User 2 cannot see User 1 user_concept_state'
);

-- 23-29. LEGACY BACKFILL VERIFICATION SUITE
-- Reset role to postgres for schema simulation
set local role postgres;
set local search_path = public, extensions;

-- Setup synthetic legacy learning events table matching pre-Phase-4 schema
create temp table test_legacy_backfill_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  session_id text,
  occurred_at timestamptz not null,
  event_type text not null,
  item_type text not null,
  item_id text not null,
  rating smallint,
  score real,
  response jsonb,
  confidence smallint,
  client_latency_ms integer
);

-- Insert 3 legacy events for session 1 in distinct chronological order
insert into test_legacy_backfill_events (
  id, user_id, session_id, occurred_at, event_type, item_type, item_id, rating, score, response, confidence, client_latency_ms
) values
  ('ba111111-0000-4000-8000-000000000001', 'ee111111-0000-4000-8000-000000000001', 'sess-legacy-1', now() - interval '3 hours', 'review', 'term', 'c1', 3, 1.0, '"ans1"'::jsonb, 4, 1200),
  ('ba111111-0000-4000-8000-000000000002', 'ee111111-0000-4000-8000-000000000001', 'sess-legacy-1', now() - interval '2 hours', 'review', 'term', 'c2', 4, 1.0, '"ans2"'::jsonb, 5, 800),
  ('ba111111-0000-4000-8000-000000000003', 'ee111111-0000-4000-8000-000000000001', 'sess-legacy-1', now() - interval '1 hour', 'review', 'term', 'c3', 2, 0.5, '"ans3"'::jsonb, 3, 2100);

-- Insert 2 legacy events for session 2
insert into test_legacy_backfill_events (
  id, user_id, session_id, occurred_at, event_type, item_type, item_id, rating, score, response, confidence, client_latency_ms
) values
  ('ba222222-0000-4000-8000-000000000001', 'ee111111-0000-4000-8000-000000000001', 'sess-legacy-2', now() - interval '30 minutes', 'review', 'term', 'c4', 3, 1.0, '"ans4"'::jsonb, 4, 1500),
  ('ba222222-0000-4000-8000-000000000002', 'ee111111-0000-4000-8000-000000000001', 'sess-legacy-2', now() - interval '15 minutes', 'review', 'term', 'c5', 1, 0.0, '"ans5"'::jsonb, 2, 3000);

-- Insert 1 legacy event with NULL session_id
insert into test_legacy_backfill_events (
  id, user_id, session_id, occurred_at, event_type, item_type, item_id, rating, score, response, confidence, client_latency_ms
) values
  ('ba333333-0000-4000-8000-000000000001', 'ee111111-0000-4000-8000-000000000001', null, now() - interval '5 minutes', 'review', 'term', 'c6', 3, 1.0, '"ans6"'::jsonb, 3, 1100);

-- Execute Step 1 Additive schema (without defaults on existing rows)
alter table test_legacy_backfill_events
  add column idempotency_key text,
  add column payload_sha256 text,
  add column client_seq integer,
  add column attempt_id uuid,
  add column client_occurred_at timestamptz,
  add column effective_occurred_at timestamptz,
  add column client_latency_ms_new integer,
  add column event_schema_version text not null default '1.0.0',
  add column received_at timestamptz,
  add column presented_option_ids text[];

-- TEST 23: Verify additive columns are initially NULL for existing rows
select is(
  (select count(*)::int from test_legacy_backfill_events where client_seq is null and idempotency_key is null and payload_sha256 is null),
  6,
  'Preexisting legacy rows have NULL client_seq, idempotency_key, and payload_sha256 prior to backfill'
);

-- Execute Step 2 Backfill logic exactly as in migration
update test_legacy_backfill_events
set client_occurred_at = coalesce(occurred_at, now())
where client_occurred_at is null;

update test_legacy_backfill_events
set effective_occurred_at = client_occurred_at
where effective_occurred_at is null;

update test_legacy_backfill_events
set received_at = client_occurred_at
where received_at is null;

update test_legacy_backfill_events
set session_id = '00000000-0000-0000-0000-000000000000'
where session_id is null;

with numbered as (
  select id, row_number() over (
    partition by user_id, session_id
    order by effective_occurred_at asc, id asc
  )::integer as seq
  from test_legacy_backfill_events
  where client_seq is null
)
update test_legacy_backfill_events le
set client_seq = numbered.seq
from numbered
where le.id = numbered.id;

update test_legacy_backfill_events
set idempotency_key = 'legacy_' || id::text
where idempotency_key is null or idempotency_key like 'raw_%';

update test_legacy_backfill_events
set payload_sha256 = encode(digest(convert_to(
  jsonb_build_object(
    'session_id', session_id,
    'client_seq', client_seq,
    'attempt_id', attempt_id,
    'event_type', event_type,
    'content_id', item_id,
    'item_id', item_id,
    'presented_option_ids', '[]'::jsonb,
    'learner_response', response,
    'fsrs_rating', rating,
    'assistance_provided', '[]'::jsonb,
    'learner_confidence', confidence,
    'client_latency_ms', coalesce(client_latency_ms, 0),
    'client_occurred_at_utc_iso', to_char(client_occurred_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
  )::text, 'UTF8'
), 'sha256'), 'hex')
where payload_sha256 is null or payload_sha256 = 'raw_uncomputed_digest';

-- TEST 24: Verify client_seq is strictly 1, 2, 3 in temporal order for sess-legacy-1
select is(
  (select array_agg(client_seq order by effective_occurred_at asc) from test_legacy_backfill_events where session_id = 'sess-legacy-1'),
  array[1, 2, 3],
  'Legacy backfill assigns deterministic sequential 1, 2, 3 client_seq per session in temporal order'
);

-- TEST 25: Verify client_seq is strictly 1, 2 in temporal order for sess-legacy-2
select is(
  (select array_agg(client_seq order by effective_occurred_at asc) from test_legacy_backfill_events where session_id = 'sess-legacy-2'),
  array[1, 2],
  'Legacy backfill assigns deterministic sequential 1, 2 client_seq for second session'
);

-- TEST 26: Verify NULL session_id was normalized and sequenced as 1
select is(
  (select client_seq from test_legacy_backfill_events where session_id = '00000000-0000-0000-0000-000000000000'),
  1,
  'Legacy event with NULL session_id normalized to zero UUID and assigned client_seq = 1'
);

-- TEST 27: Verify all rows have idempotency_key = legacy_<id>
select is(
  (select count(*)::int from test_legacy_backfill_events where idempotency_key = 'legacy_' || id::text),
  6,
  'All legacy rows have deterministic idempotency_key matching legacy_<id>'
);

-- TEST 28: Verify all rows have 64-char hex SHA-256 digests and none retain placeholder
select is(
  (select count(*)::int from test_legacy_backfill_events where length(payload_sha256) = 64 and payload_sha256 ~ '^[0-9a-f]{64}$' and payload_sha256 <> 'raw_uncomputed_digest'),
  6,
  'All legacy rows have valid 64-character SHA-256 payload digests computed from canonical fields'
);

-- TEST 29: Verify Step 3 NOT NULL constraints and unique index apply cleanly to backfilled table
select lives_ok(
  $$ alter table test_legacy_backfill_events
       alter column client_seq set not null,
       alter column idempotency_key set not null,
       alter column payload_sha256 set not null;
     alter table test_legacy_backfill_events
       add constraint test_legacy_user_session_seq_key unique (user_id, session_id, client_seq);
  $$,
  'Step 3 NOT NULL and composite UNIQUE constraints apply cleanly without violation on backfilled data'
);

select * from finish();
rollback;

