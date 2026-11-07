-- ============================================================================
-- pgTAP Tests: Strict Learning Events Architecture Rules & Projections
-- Test file: supabase/tests/learning_events_strict_rules_test.sql
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(21);

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

-- 3. TEST: Valid modern event is accepted
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

-- 4. TEST: Table public.learning_events stores canonical payload_sha256 and effective_occurred_at
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

-- 5. TEST: review_items projection is updated
select is(
  (select total_reviews::int from public.review_items where id = 'fa111111-0000-4000-8000-000000000001'),
  1,
  'review_items total_reviews is incremented to 1'
);

-- 6. TEST: Duplicate replay of identical payload returns duplicate_noop
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

select * from finish();
rollback;

