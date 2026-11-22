-- pgTAP: champion/challenger for curriculum content (migration 20261122060000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(17);

insert into auth.users (id, email) values
  ('d1000000-0000-4000-8000-000000000001', 'cc-admin@example.invalid'),
  ('d1000000-0000-4000-8000-000000000002', 'cc-learner@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('d1000000-0000-4000-8000-000000000001'), ('d1000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values ('d1000000-0000-4000-8000-000000000001', 'admin')
on conflict (user_id) do nothing;

-- An official target with a published champion and two review-ready challengers.
insert into public.learning_targets (id, target_type, title, slug, is_official) values
  ('d1000000-0000-4000-8000-000000000010', 'curriculum_standard', 'Official Book', 'test-cc-official', true);
insert into public.target_versions (id, target_id, version_code, status) values
  ('d1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000010', 'R1', 'draft'),
  ('d1000000-0000-4000-8000-000000000012', 'd1000000-0000-4000-8000-000000000010', 'R2', 'draft'),
  ('d1000000-0000-4000-8000-000000000013', 'd1000000-0000-4000-8000-000000000010', 'R3', 'draft');
update public.target_versions set status = 'review_ready' where target_id = 'd1000000-0000-4000-8000-000000000010';
update public.target_versions set status = 'published' where id = 'd1000000-0000-4000-8000-000000000011';

-- A learner-owned goal: unchanged behaviour.
insert into public.learning_targets (id, target_type, title, slug, created_by) values
  ('d1000000-0000-4000-8000-000000000020', 'career', 'My goal', 'test-cc-mine', 'd1000000-0000-4000-8000-000000000002');
insert into public.target_versions (id, target_id, version_code, status) values
  ('d1000000-0000-4000-8000-000000000021', 'd1000000-0000-4000-8000-000000000020', 'M1', 'draft'),
  ('d1000000-0000-4000-8000-000000000022', 'd1000000-0000-4000-8000-000000000020', 'M2', 'draft');
update public.target_versions set status = 'review_ready' where target_id = 'd1000000-0000-4000-8000-000000000020';
update public.target_versions set status = 'published' where id = 'd1000000-0000-4000-8000-000000000021';

select ok(not has_table_privilege('authenticated', 'private.content_version_decisions', 'select'),
  'learners cannot read decisions');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-000000000002', true);
select throws_ok($$ select public.record_content_version_decision(
  'd1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000012', 'replace', 'fixes_defect', 'Broken math') $$,
  '42501', null, 'learners cannot record decisions');
select lives_ok($$ select public.publish_target_version('d1000000-0000-4000-8000-000000000022', true) $$,
  'a learner-owned goal still publishes and retires without a decision');

select set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-000000000001', true);
select throws_ok($$ select public.record_content_version_decision(
  'd1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000012', 'replace', 'none') $$,
  '22023', null, 'replacing needs a basis');
select throws_ok($$ select public.record_content_version_decision(
  'd1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000012', 'replace', 'fixes_defect', '  ') $$,
  '22023', null, 'a defect basis must name the defect');
select throws_ok($$ select public.record_content_version_decision(
  'd1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000012', 'replace', 'rubric_margin', null,
  '{"champion":{"clarity":3,"accuracy":4,"accessibility":3},"challenger":{"clarity":4,"accuracy":4,"accessibility":3}}') $$,
  '22023', null, 'a one-point margin is not enough');
select throws_ok($$ select public.record_content_version_decision(
  'd1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000012', 'replace', 'rubric_margin', null,
  '{"champion":{"clarity":2,"accuracy":5,"accessibility":2},"challenger":{"clarity":5,"accuracy":4,"accessibility":5}}') $$,
  '22023', null, 'a challenger less accurate than the champion cannot replace it');
select throws_ok($$ select public.record_content_version_decision(
  'd1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000012', 'replace', 'rubric_margin', null,
  '{"champion":{"clarity":3},"challenger":{"clarity":5}}') $$,
  '22023', null, 'an incomplete rubric is rejected');
select throws_ok($$ select public.record_content_version_decision(
  'd1000000-0000-4000-8000-000000000012', 'd1000000-0000-4000-8000-000000000011', 'replace', 'fixes_defect', 'Broken math') $$,
  '22023', null, 'the champion must be the published version');
reset role;

-- No decision: the official champion cannot be retired.
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '', true);
select throws_ok($$ select public.publish_target_version('d1000000-0000-4000-8000-000000000012', true) $$,
  '22023', null, 'retiring an official champion without a decision is refused');
-- An alternate decision does not unlock it either.
select lives_ok($$ select public.record_content_version_decision(
  'd1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000013', 'alternate', 'none',
  null, null, 'Kept as an alternate wording') $$, 'a challenger can be kept as an alternate');
select throws_ok($$ select public.publish_target_version('d1000000-0000-4000-8000-000000000013', true) $$,
  '22023', null, 'an alternate does not replace the champion');
select is((select status from public.target_versions where id = 'd1000000-0000-4000-8000-000000000013'),
  'review_ready', 'the alternate stays unpublished');

-- A documented defect unlocks the replacement.
select is((public.record_content_version_decision(
  'd1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000012', 'replace', 'fixes_defect',
  'IMPORT_REVISION 3: inline math broke paragraphs'))->>'decision', 'replace',
  'the service role records a defect-fix decision');
select is((public.publish_target_version('d1000000-0000-4000-8000-000000000012', true))->>'retired_previous_count', '1',
  'with the decision, publishing retires the champion');
select set_config('request.jwt.claim.role', 'authenticated', true);
select is((select status from public.target_versions where id = 'd1000000-0000-4000-8000-000000000011'),
  'retired', 'the old version remains, retired');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-000000000001', true);
select is((select count(*)::int from jsonb_array_elements(public.get_content_version_decisions(50)) d
           where d->>'target_slug' = 'test-cc-official'), 2, 'the admin sees both decisions');
reset role;

select * from finish();
rollback;
