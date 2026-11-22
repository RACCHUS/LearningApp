-- pgTAP: prompt-pack signals 3-5 (migration 20261122050000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(20);

-- Accounts: 1 admin, 2 moderator, 3..8 learners (3..7 opted in with
-- scope 2, 8 opted in before the wording existed: scope 1).
insert into auth.users (id, email, raw_app_meta_data, is_anonymous)
select ('cf000000-0000-4000-8000-00000000000' || i)::uuid, 'pps' || i || '@example.invalid',
       '{"product_analytics_eligible":"true"}', false
from generate_series(1, 8) i
on conflict (id) do nothing;
insert into public.users (id) select ('cf000000-0000-4000-8000-00000000000' || i)::uuid
from generate_series(1, 8) i on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values
  ('cf000000-0000-4000-8000-000000000001', 'admin'),
  ('cf000000-0000-4000-8000-000000000002', 'moderator')
on conflict (user_id) do nothing;
insert into analytics.product_consents (user_id, consented)
select ('cf000000-0000-4000-8000-00000000000' || i)::uuid, true from generate_series(3, 8) i;
insert into analytics.prompt_quality_consents (user_id, consented, scope)
select ('cf000000-0000-4000-8000-00000000000' || i)::uuid, true, case when i = 8 then 1 else 2 end
from generate_series(3, 8) i;

-- A published curriculum topic with one published lesson.
insert into public.learning_targets (id, target_type, title, slug) values
  ('cf000000-0000-4000-8000-000000000010', 'curriculum_standard', 'Signals Book', 'test-signals-book');
insert into public.target_versions (id, target_id, version_code, status) values
  ('cf000000-0000-4000-8000-000000000011', 'cf000000-0000-4000-8000-000000000010', 'S1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, title, code, sort_order) values
  ('cf000000-0000-4000-8000-000000000021', 'cf000000-0000-4000-8000-000000000011', 'objective', 'Percent', '6.1', 1);
insert into public.lessons (id, title, visibility, tags) values
  ('cf000000-0000-4000-8000-000000000101', 'Published percent', 'public', array['percent']);
insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order) values
  ('cf000000-0000-4000-8000-000000000021', 'cf000000-0000-4000-8000-000000000101', 1);

-- Each learner made an AI lesson with pack la-gen-1.1, attached it to the
-- topic, used it two days ago, then answered the published lesson today.
insert into public.lessons (id, title, visibility, user_id, tags)
select ('cf000000-0000-4000-8000-00000000020' || i)::uuid, 'My AI lesson', 'private',
       ('cf000000-0000-4000-8000-00000000000' || i)::uuid,
       array['ai-generated','unreviewed','prompt-pack-la-gen-1.1']
from generate_series(3, 8) i;
insert into public.user_curriculum_resources (user_id, curriculum_node_id, lesson_id)
select ('cf000000-0000-4000-8000-00000000000' || i)::uuid, 'cf000000-0000-4000-8000-000000000021',
       ('cf000000-0000-4000-8000-00000000020' || i)::uuid
from generate_series(3, 8) i;
insert into public.user_progress (user_id, lesson_id, date, questions_answered, correct_count)
select ('cf000000-0000-4000-8000-00000000000' || i)::uuid,
       ('cf000000-0000-4000-8000-00000000020' || i)::uuid, current_date - 2, 3, 2
from generate_series(3, 8) i;
insert into public.user_progress (user_id, lesson_id, date, questions_answered, correct_count)
select ('cf000000-0000-4000-8000-00000000000' || i)::uuid,
       'cf000000-0000-4000-8000-000000000101', current_date, 4, 3
from generate_series(3, 8) i;

-- Consent scope.
select is((select scope from analytics.prompt_quality_consents
           where user_id = 'cf000000-0000-4000-8000-000000000008'), 1::smallint,
  'earlier opt-ins keep scope 1');
update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'analytics.prompt_quality';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000008', true);
select is(public.get_prompt_quality_status()->>'scope', '1', 'status reports the older scope');
select lives_ok($$ select public.set_prompt_quality_consent(false) $$, 'withdrawing works');
select is(public.get_prompt_quality_status()->>'scope', '0', 'no scope once withdrawn');
reset role;

-- Signal 3: review evidence.
select ok(not has_table_privilege('authenticated', 'private.content_review_evidence', 'select'),
  'learners cannot read review evidence');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000003', true);
select throws_ok($$ select public.record_content_review_evidence(
  'cf000000-0000-4000-8000-000000000203', 'accuracy', 'ok', 'volunteer') $$,
  '42501', null, 'learners cannot record review evidence');
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000002', true);
select lives_ok($$ select public.record_content_review_evidence(
  'cf000000-0000-4000-8000-000000000203', 'accuracy', 'concern', 'volunteer', 'Step 2 is wrong') $$,
  'a moderator records a volunteer accuracy concern');
select throws_ok($$ select public.record_content_review_evidence(
  'cf000000-0000-4000-8000-000000000203', 'rights', 'ok', 'owner') $$,
  '42501', null, 'only the owner records owner review');
select throws_ok($$ select public.record_content_review_evidence(
  'cf000000-0000-4000-8000-000000000203', 'vibes', 'ok', 'volunteer') $$,
  '22023', null, 'unknown aspects are rejected');
select is(jsonb_array_length(public.get_content_review_evidence('cf000000-0000-4000-8000-000000000203')), 1,
  'moderators can read a lesson''s evidence');

-- Signal 5: golden runs.
select throws_ok($$ select public.record_prompt_golden_run('la-gen-1.1', 'gemini', 10, 9) $$,
  '42501', null, 'moderators cannot record golden runs');
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000001', true);
select lives_ok($$ select public.record_prompt_golden_run('la-gen-1.1', 'gemini', 10, 9, null, 'Free tier') $$,
  'the admin records a golden run');
select throws_ok($$ select public.record_prompt_golden_run('la-gen-1.1', 'gemini', 10, 11) $$,
  '22023', null, 'passed cannot exceed total');
select throws_ok($$ select public.record_prompt_golden_run('la-gen-1.1', 'my bot', 10, 5) $$,
  '22023', null, 'free-text AI labels are rejected');

-- The report.
create temp table r as select public.get_prompt_pack_signals(90) as v;
select is((select v->'golden_runs'->0->>'pass_rate' from r), '0.900', 'golden pass rate');
select is((select v->'review_evidence'->0->>'concern' from r), '1', 'review concerns per pack');
-- Five scope-2 accounts (3..7); 8 withdrew and is not counted.
select is((select v->'downstream'->0->>'accounts' from r), '5', 'downstream counts scope-2 accounts only');
select is((select v->'downstream'->0->>'later_check_accuracy' from r), '0.750',
  'accuracy on later checks of the same topic');
reset role;

-- Under five accounts is suppressed.
update analytics.prompt_quality_consents set scope = 1
  where user_id = 'cf000000-0000-4000-8000-000000000007';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000001', true);
select is(public.get_prompt_pack_signals(90)->'downstream'->0->>'status', 'small_cohort_suppressed',
  'four accounts are suppressed');
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000002', true);
select throws_ok($$ select public.get_prompt_pack_signals(90) $$, '42501', null,
  'the report is admin-only');
reset role;

select * from finish();
rollback;
