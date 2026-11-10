-- ANA-008: clients cannot bypass public.record_events() by writing
-- authoritative learning evidence directly. Run on a disposable local DB
-- built from the full append-only migration chain, never on production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(20);

-- Permissions must be denied at the GRANT boundary, regardless of RLS.
select ok(not has_table_privilege('authenticated','public.learning_events','INSERT'),
  'Authenticated users cannot INSERT raw learning evidence');
select ok(not has_table_privilege('authenticated','public.learning_events','UPDATE'),
  'Authenticated users cannot UPDATE raw learning evidence');
select ok(not has_table_privilege('authenticated','public.learning_events','DELETE'),
  'Authenticated users cannot DELETE raw learning evidence');
select ok(not has_table_privilege('anon','public.learning_events','INSERT'),
  'Unauthenticated clients cannot INSERT raw learning evidence');
select ok(has_table_privilege('authenticated','public.learning_events','SELECT'),
  'Owner-scoped learning evidence SELECT remains available');
select ok(has_function_privilege('authenticated','public.record_events(jsonb[])','EXECUTE'),
  'Authenticated callers retain EXECUTE on the approved record_events RPC');
select ok((select prosecdef from pg_proc where oid='public.record_events(jsonb[])'::regprocedure),
  'record_events runs with its existing SECURITY DEFINER identity');
select ok(not exists (
  select 1 from pg_policies
   where schemaname='public' and tablename='learning_events'
     and cmd in ('INSERT','ALL')
), 'No direct client INSERT RLS policy is retained');
select ok(has_table_privilege('service_role','public.learning_events','INSERT'),
  'Trusted service role can still insert authoritative evidence');

-- All test identities and review content are synthetic and transaction-local.
insert into auth.users (id, email) values
  ('a8000000-0000-4000-8000-000000000001','ana008learner1@example.invalid'),
  ('a8000000-0000-4000-8000-000000000002','ana008learner2@example.invalid')
on conflict (id) do nothing;
insert into public.users (id, email, display_name) values
  ('a8000000-0000-4000-8000-000000000001','ana008learner1@example.invalid','ANA-008 learner 1'),
  ('a8000000-0000-4000-8000-000000000002','ana008learner2@example.invalid','ANA-008 learner 2')
on conflict (id) do nothing;
insert into public.review_items (
  id, user_id, content_id, content_type, lesson_id, title,
  stability, difficulty, fsrs_state, total_reviews, correct_reviews
) values (
  'a8000000-0000-4000-8000-000000000003',
  'a8000000-0000-4000-8000-000000000001',
  'ana008-card', 'term', 'ana008-lesson', 'ANA-008 test item',
  2.5, 4.5, 1, 0, 0
) on conflict do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub','a8000000-0000-4000-8000-000000000001',true);

select throws_ok(
  $$ insert into public.learning_events (user_id,event_type,item_type,item_id)
     values ('a8000000-0000-4000-8000-000000000001','memory_card_review','term','forged-evidence') $$,
  '42501', null, 'Even an own-user forged evidence INSERT is denied');

select throws_ok(
  $$ update public.learning_events set score=1 where user_id='a8000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'Authenticated UPDATE on evidence is denied');

select throws_ok(
  $$ delete from public.learning_events where user_id='a8000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'Authenticated DELETE on evidence is denied');

-- Only the server-validated RPC can accept the same learner's real event.
create temp table ana008_first as
select public.record_events(array[
  jsonb_build_object(
    'idempotency_key','ana008-one',
    'session_id','a8000000-0000-4000-8000-000000000004',
    'client_seq',1,
    'event_type','memory_card_review',
    'item_type','term',
    'item_id','ana008-card',
    'rating',3,
    'score',1.0,
    'client_latency_ms',1250,
    'presented_option_ids',jsonb_build_array('opt-a','opt-b'),
    'scheduler_state_after',jsonb_build_object(
      'stability',3.8,'difficulty',4.2,'state',2,
      'due',(now() + interval '3 days')::text
    )
  )
]) as response;

select is((select response->'results'->0->>'status' from ana008_first),
  'accepted', 'Valid record_events call still accepts learning evidence');

select is(
  (select count(*)::int from public.learning_events
    where idempotency_key='ana008-one'
      and user_id='a8000000-0000-4000-8000-000000000001'),
  1, 'RPC persists exactly one authoritative event');

select is(
  (select total_reviews::int from public.review_items
    where id='a8000000-0000-4000-8000-000000000003'),
  1, 'RPC still updates the authoritative review projection');

create temp table ana008_replay as
select public.record_events(array[
  jsonb_build_object(
    'idempotency_key','ana008-one',
    'session_id','a8000000-0000-4000-8000-000000000004',
    'client_seq',1,
    'event_type','memory_card_review',
    'item_type','term',
    'item_id','ana008-card',
    'rating',3,
    'score',1.0,
    'client_latency_ms',1250,
    'presented_option_ids',jsonb_build_array('opt-a','opt-b'),
    'scheduler_state_after',jsonb_build_object(
      'stability',3.8,'difficulty',4.2,'state',2,
      'due',(now() + interval '3 days')::text
    )
  )
]) as response;

select is((select response->'results'->0->>'status' from ana008_replay),
  'duplicate_noop', 'Idempotent replay remains a no-op');
select is(
  (select total_reviews::int from public.review_items
    where id='a8000000-0000-4000-8000-000000000003'),
  1, 'Replay does not double count review projections');

select lives_ok(
  $$ select * from public.learning_events
      where user_id='a8000000-0000-4000-8000-000000000001' $$,
  'Owner can still SELECT their learning evidence');

select set_config('request.jwt.claim.sub','a8000000-0000-4000-8000-000000000002',true);
select is(
  (select count(*)::int from public.learning_events
    where user_id='a8000000-0000-4000-8000-000000000001'),
  0, 'RLS still prevents another learner from reading this evidence');

set local role anon;
select throws_ok(
  $$ select public.record_events(array['{"event_type":"memory_card_review"}'::jsonb]) $$,
  '42501', null, 'Unauthenticated clients cannot execute record_events');

select * from finish();
rollback;
