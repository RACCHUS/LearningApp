-- pgTAP: curriculum freshness (migration 20261122010000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(14);

insert into auth.users (id, email) values
  ('cb000000-0000-4000-8000-000000000001', 'fresh-learner@example.invalid')
on conflict (id) do nothing;
insert into public.learning_targets (id, target_type, title, slug) values
  ('cb000000-0000-4000-8000-000000000010', 'curriculum_standard', 'Fresh Book', 'test-fresh-book');
insert into public.target_versions (id, target_id, version_code, status) values
  ('cb000000-0000-4000-8000-000000000011', 'cb000000-0000-4000-8000-000000000010', 'F1', 'draft');

select is((public.set_target_version_freshness('cb000000-0000-4000-8000-000000000011', 'V2', null, 'abc1234'))->>'review_by',
  (current_date + interval '9 months')::date::text, 'V2 defaults to a 9-month review');
select throws_ok($$ select public.set_target_version_freshness('cb000000-0000-4000-8000-000000000011', 'V4') $$,
  '22023', null, 'V4 fast-moving content is refused');
select throws_ok($$ select public.set_target_version_freshness('cb000000-0000-4000-8000-000000000011', 'V3') $$,
  '22023', null, 'V3 needs an explicit review_by');
select throws_ok($$ select public.set_target_version_freshness('cb000000-0000-4000-8000-000000000011', 'V0', current_date - 1) $$,
  '22023', null, 'review_by must be in the future');
select ok(not has_function_privilege('authenticated', 'public.set_target_version_freshness(uuid,text,date,text)', 'execute'),
  'learners cannot set freshness');
select ok(not has_function_privilege('authenticated', 'public.raise_due_curriculum_refresh_items()', 'execute'),
  'learners cannot raise items');

update public.target_versions set status = 'review_ready' where id = 'cb000000-0000-4000-8000-000000000011';
update public.target_versions set status = 'published' where id = 'cb000000-0000-4000-8000-000000000011';
select throws_ok($$ select public.set_target_version_freshness('cb000000-0000-4000-8000-000000000011', 'V1') $$,
  '22023', null, 'published versions cannot be changed');

select is(public.raise_due_curriculum_refresh_items(), 0, 'nothing is due yet');
-- Time passes.
update private.target_version_freshness set review_by = current_date
  where target_version_id = 'cb000000-0000-4000-8000-000000000011';
select is(public.raise_due_curriculum_refresh_items(), 1, 'a passed review-by raises one item');
select is(public.raise_due_curriculum_refresh_items(), 0, 'only one open item per version and reason');

select is(public.report_curriculum_source_change('test-fresh-book', 'abc1234'), 0, 'an unchanged source raises nothing');
select is(public.report_curriculum_source_change('test-fresh-book', 'def5678'), 1, 'a changed source raises an item');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'cb000000-0000-4000-8000-000000000001', true);
select throws_ok($$ select public.get_curriculum_freshness() $$, '42501', null, 'the owner view is admin-only');
select throws_ok($$ select public.resolve_curriculum_refresh_item(gen_random_uuid(), 'resolved') $$,
  '42501', null, 'learners cannot resolve items');
reset role;

select * from finish();
rollback;
