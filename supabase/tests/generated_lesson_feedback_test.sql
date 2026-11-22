-- pgTAP: feedback chips on AI-generated lessons (migration 20261121060000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(13);

insert into auth.users (id, email) values
  ('ca000000-0000-4000-8000-000000000001', 'chips-owner@example.invalid'),
  ('ca000000-0000-4000-8000-000000000002', 'chips-other@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values
  ('ca000000-0000-4000-8000-000000000001'), ('ca000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;
insert into public.lessons (id, title, visibility, user_id, tags) values
  ('ca000000-0000-4000-8000-000000000101', 'My generated lesson', 'private',
   'ca000000-0000-4000-8000-000000000001', array['ai-generated','unreviewed','prompt-pack-la-gen-1-1']),
  ('ca000000-0000-4000-8000-000000000102', 'Hand-written lesson', 'private',
   'ca000000-0000-4000-8000-000000000001', array['algebra']),
  ('ca000000-0000-4000-8000-000000000103', 'Old generated lesson', 'private',
   'ca000000-0000-4000-8000-000000000001', array['ai-generated']);

select ok(exists (select 1 from private.site_feature_change_audit
                  where feature_key = 'content.feedback_chips' and next_enabled
                    and reason like '%Owner-approved%'),
  'turning it on was an audited owner decision');
-- The gates below are tested from OFF, whatever production holds.
update private.site_feature_controls set enabled = false, release_ready = false
  where feature_key = 'content.feedback_chips';
select ok(not has_table_privilege('authenticated', 'private.generated_lesson_feedback', 'select'),
  'learners cannot read the feedback table');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000001', true);
select throws_ok($$ select public.set_generated_lesson_feedback('ca000000-0000-4000-8000-000000000101', 'confusing') $$,
  '42501', null, 'refused while the switch is off');
reset role;
update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'content.feedback_chips';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000001', true);

select is(public.set_generated_lesson_feedback('ca000000-0000-4000-8000-000000000101', 'confusing')->>'chip',
  'confusing', 'the owner rates their generated lesson');
select is(public.get_my_generated_lesson_feedback('ca000000-0000-4000-8000-000000000101'), 'confusing',
  'and can read their own choice');
select lives_ok($$ select public.set_generated_lesson_feedback('ca000000-0000-4000-8000-000000000101', 'too_hard') $$,
  'the choice can be changed');
select throws_ok($$ select public.set_generated_lesson_feedback('ca000000-0000-4000-8000-000000000101', 'meh') $$,
  '22023', null, 'only the five chips are accepted');
select throws_ok($$ select public.set_generated_lesson_feedback('ca000000-0000-4000-8000-000000000102', 'wrong') $$,
  '22023', null, 'hand-written lessons are not rated');
select lives_ok($$ select public.set_generated_lesson_feedback('ca000000-0000-4000-8000-000000000103', 'wrong') $$,
  'a generated lesson without a pack tag is accepted');

select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000002', true);
select throws_ok($$ select public.set_generated_lesson_feedback('ca000000-0000-4000-8000-000000000101', 'wrong') $$,
  '42501', null, 'someone else cannot rate a private lesson');
select throws_ok($$ select public.get_generated_lesson_feedback_overview(90) $$,
  '42501', null, 'the owner report is admin-only');
reset role;

select is((select array_agg(pack_version || ':' || chip order by pack_version)
           from private.generated_lesson_feedback
           where user_id = 'ca000000-0000-4000-8000-000000000001'),
  array['la-gen-1-1:too_hard', 'unknown:wrong'], 'the pack version comes from the lesson tag');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'ca000000-0000-4000-8000-000000000001', true);
select public.set_generated_lesson_feedback('ca000000-0000-4000-8000-000000000101', null);
reset role;
select is((select count(*)::int from private.generated_lesson_feedback
           where lesson_id = 'ca000000-0000-4000-8000-000000000101'), 0, 'clearing removes the row');

select * from finish();
rollback;
