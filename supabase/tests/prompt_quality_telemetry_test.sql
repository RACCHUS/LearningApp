-- pgTAP: opt-in prompt-quality telemetry (migration 20261121010000).
-- Every gate must hold to record; withdrawal erases; codes only.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(27);

insert into auth.users (id, email, raw_app_meta_data, is_anonymous) values
  ('c8000000-0000-4000-8000-000000000001', 'pq-yes@example.invalid', '{"product_analytics_eligible":"true"}', false),
  ('c8000000-0000-4000-8000-000000000002', 'pq-base-off@example.invalid', '{"product_analytics_eligible":"true"}', false),
  ('c8000000-0000-4000-8000-000000000003', 'pq-ineligible@example.invalid', '{}', false)
on conflict (id) do nothing;
insert into analytics.product_consents (user_id, consented) values
  ('c8000000-0000-4000-8000-000000000001', true),
  ('c8000000-0000-4000-8000-000000000002', false);
-- (An ineligible account cannot hold base consent at all; an existing
-- trigger refuses it, so account 3 has no consent row.)

create function pg_temp.ev(p_id text, p_outcome text default 'clean') returns jsonb language sql as $$
  select jsonb_build_object('event_id', p_id, 'pack_version', 'la-gen-1.1', 'ai_label', 'gemini',
    'tier', 'compact', 'mode', 'json', 'outcome', p_outcome, 'error_code', 'none',
    'requested', 3, 'accepted', 3, 'sentinel', true)
$$;
grant execute on function pg_temp.ev(text, text) to authenticated;

select ok(exists (select 1 from private.site_feature_controls
                  where feature_key = 'analytics.prompt_quality' and not enabled and not release_ready),
  'the switch is seeded OFF and not release ready');
select ok(not has_function_privilege('anon', 'public.record_prompt_quality_events(jsonb[])', 'execute'),
  'guests cannot record');
select ok(not has_table_privilege('authenticated', 'analytics.prompt_quality_events', 'select'),
  'learners cannot read the event table');

-- Switch OFF: nothing works, the status says so.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c8000000-0000-4000-8000-000000000001', true);
select is(public.get_prompt_quality_status()->>'enabled', 'false', 'status reports the switch off');
select throws_ok($$ select public.set_prompt_quality_consent(true) $$, '42501', null,
  'opting in is refused while the switch is off');
select throws_ok($$ select public.record_prompt_quality_events(array[pg_temp.ev('c8000000-0000-4000-8000-000000000101')]) $$,
  '42501', null, 'recording is refused while the switch is off');
reset role;

update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'analytics.prompt_quality';

set local role authenticated;
select is(public.get_prompt_quality_status()->>'available', 'true', 'eligible, consented account may opt in');
select is(public.get_prompt_quality_status()->>'consented', 'false', 'but has not yet');
select throws_ok($$ select public.record_prompt_quality_events(array[pg_temp.ev('c8000000-0000-4000-8000-000000000102')]) $$,
  '42501', null, 'no recording before the extra opt-in');
select lives_ok($$ select public.set_prompt_quality_consent(true) $$, 'the learner opts in');
select is((public.record_prompt_quality_events(array[
  pg_temp.ev('c8000000-0000-4000-8000-000000000103'),
  pg_temp.ev('c8000000-0000-4000-8000-000000000104', 'partial')]))->>'processed_count', '2',
  'codes and counts are recorded after opting in');
select throws_ok($$ select public.record_prompt_quality_events(array[
  pg_temp.ev('c8000000-0000-4000-8000-000000000105') || '{"reply_text":"secret"}'::jsonb]) $$,
  '22023', null, 'any extra field (such as reply text) is rejected');
select throws_ok($$ select public.record_prompt_quality_events(array[
  jsonb_set(pg_temp.ev('c8000000-0000-4000-8000-000000000106'), '{ai_label}', '"my private bot"')]) $$,
  '22023', null, 'free-text labels are rejected');
select throws_ok($$ select public.record_prompt_quality_events(array[
  jsonb_set(pg_temp.ev('c8000000-0000-4000-8000-000000000107'), '{requested}', '"3"')]) $$,
  '22023', null, 'counts must be numbers');

-- Accounts that fail a base gate.
select set_config('request.jwt.claim.sub', 'c8000000-0000-4000-8000-000000000002', true);
select is(public.get_prompt_quality_status()->>'available', 'false', 'no base consent: not available');
select throws_ok($$ select public.set_prompt_quality_consent(true) $$, '42501', null,
  'no base consent: cannot opt in');
select set_config('request.jwt.claim.sub', 'c8000000-0000-4000-8000-000000000003', true);
select throws_ok($$ select public.set_prompt_quality_consent(true) $$, '42501', null,
  'not eligible: cannot opt in');
select lives_ok($$ select public.set_prompt_quality_consent(false) $$, 'withdrawing always works');
reset role;

select is((select count(*)::int from analytics.prompt_quality_events
           where user_id = 'c8000000-0000-4000-8000-000000000001'), 2, 'two events stored');

-- Privacy review fixes (migration 20261121040000).
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c8000000-0000-4000-8000-000000000001', true);
select is(jsonb_array_length(public.export_my_prompt_quality_events()->'events'), 2,
  'a learner can export their own rows');
select ok(public.export_my_prompt_quality_events()::text !~ 'c8000000-0000-4000-8000-000000000001',
  'the export carries codes and counts, not the account id');
select is((public.get_prompt_quality_status()->>'stored_events')::int, 2, 'status reports stored rows');
select set_config('request.jwt.claim.sub', 'c8000000-0000-4000-8000-000000000003', true);
select is(jsonb_array_length(public.export_my_prompt_quality_events()->'events'), 0,
  'other accounts see none of them');
reset role;
update private.site_feature_controls set enabled = false where feature_key = 'analytics.prompt_quality';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c8000000-0000-4000-8000-000000000001', true);
select is(public.get_prompt_quality_status()->>'consented', 'true',
  'with the switch off, the opt-in is still reported so it can be withdrawn');
reset role;
update private.site_feature_controls set enabled = true where feature_key = 'analytics.prompt_quality';

-- Withdrawing the base analytics consent erases prompt-quality data too.
update analytics.product_consents set consented = false
  where user_id = 'c8000000-0000-4000-8000-000000000001';
select is((select count(*)::int from analytics.prompt_quality_events
           where user_id = 'c8000000-0000-4000-8000-000000000001'), 0,
  'base withdrawal deletes prompt-quality events');
select is((select consented from analytics.prompt_quality_consents
           where user_id = 'c8000000-0000-4000-8000-000000000001'), false,
  'and turns the extra opt-in off');

-- The owner report is admin-only.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c8000000-0000-4000-8000-000000000001', true);
select throws_ok($$ select public.get_prompt_quality_overview(30) $$, '42501', null,
  'learners cannot read the owner report');
reset role;

select * from finish();
rollback;
