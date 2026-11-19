-- Parametric practice pilot (20261119020000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(33);

insert into auth.users (id, email, is_anonymous) values
  ('c0750000-0000-4000-8000-00000000000a', 'pp-learner@example.invalid', false),
  ('c0750000-0000-4000-8000-00000000000b', 'pp-other@example.invalid', false)
on conflict (id) do nothing;

-- Key isolation: no client role can read families, instances or helpers.
select ok(not has_table_privilege('authenticated', 'private.parametric_instances', 'SELECT'),
  'learners cannot read stored answers');
select ok(not has_table_privilege('authenticated', 'private.parametric_families', 'SELECT'),
  'learners cannot read family definitions');
select ok(not has_function_privilege('authenticated',
  'private.parametric_compute(text,jsonb,integer)', 'EXECUTE'),
  'learners cannot call the evaluator');
select ok(not has_function_privilege('anon', 'public.parametric_next_item(text)', 'EXECUTE'),
  'anonymous users cannot get items');
select is((select enabled and release_ready from private.site_feature_controls
            where feature_key = 'content.parametric_practice'), true,
  'gate activated by the owner-approved 20261119030000');
-- Keep the OFF-path coverage: switch it off inside this rolled-back test.
update private.site_feature_controls set enabled = false, release_ready = false
 where feature_key = 'content.parametric_practice';
select is(
  (select array_agg(c.column_name::text order by c.ordinal_position)
     from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = 'parametric_next_item'),
  null, 'sanity: next_item is a function, not a table');
select is(
  (select string_agg(p.parameter_name::text, ',' order by p.ordinal_position)
     from information_schema.parameters p
     join information_schema.routines r on r.specific_name = p.specific_name
    where r.routine_schema = 'public' and r.routine_name = 'parametric_next_item'
      and p.parameter_mode = 'OUT'),
  'instance_id,prompt,accepts_percent_sign',
  'the item DTO has no answer field');

-- Evaluator and parser.
select is(private.parametric_compute('percent_change', '{"original":80,"new":60}', null), -25::numeric,
  'percent change 80 -> 60 is -25');
select is(private.parametric_compute('fraction_to_decimal', '{"numerator":7,"denominator":8}', null), 0.875::numeric,
  '7/8 is 0.875');
select is(private.parametric_compute('percent_change', '{"original":30,"new":40}', 1), 33.3::numeric,
  'rounding half away from zero');
select is(private.parametric_compute('percent_change', '{"original":0,"new":5}', null), null,
  'zero base is invalid');
select is(private.parametric_compute('eval', '{}', null), null, 'unknown templates are refused');
select is(private.parametric_parse(' −25 % ', true), -25::numeric, 'unicode minus and % accepted');
select is(private.parametric_parse('25%', false), null, '% refused when not allowed');
select is(private.parametric_parse('1,250.5', false), 1250.5::numeric, 'proper grouping accepted');
select is(private.parametric_parse('12,50', false), null, 'bad grouping refused');
select is(private.parametric_parse('1e3', false), null, 'exponents refused');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0750000-0000-4000-8000-00000000000a', true);
select is((select count(*)::int from public.parametric_families_for('percent-change')), 0,
  'no families while OFF');
select throws_ok($$ select * from public.parametric_next_item('pc-whole-percent') $$,
  '42501', 'feature_disabled', 'items refused while OFF');
reset role;

update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'content.parametric_practice';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0750000-0000-4000-8000-00000000000a', true);
select is((select count(*)::int from public.parametric_families_for('percent-change')), 1,
  'the percent-change family is offered');
create temp table item on commit drop as
  select * from public.parametric_next_item('pc-whole-percent');
select ok((select prompt from item) ~ '^A price changed from \$[0-9]+ to \$[0-9]+\.',
  'the prompt is filled in');
select is((select instance_id from public.parametric_next_item('pc-whole-percent')),
  (select instance_id from item), 'an unanswered item is returned again');
reset role;

-- Scoring agrees with an independent recomputation of the stored variables.
create temp table truth on commit drop as
  select i.id,
         ((i.variables->>'new')::numeric - (i.variables->>'original')::numeric)
           / (i.variables->>'original')::numeric * 100 as expected,
         i.answer
    from private.parametric_instances i where i.id = (select instance_id from item);
select ok((select expected = answer and expected = trunc(expected) from truth),
  'stored answer matches the template and is a whole number');
grant select on truth to authenticated;
grant select on item to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0750000-0000-4000-8000-00000000000b', true);
select throws_ok(format($$ select * from public.parametric_submit(%L, '1') $$,
  (select instance_id from item)),
  'P0002', 'item_not_found', 'another learner cannot answer or read it');
select set_config('request.jwt.claim.sub', 'c0750000-0000-4000-8000-00000000000a', true);
select is((select readable from public.parametric_submit((select instance_id from item), 'twelve')),
  false, 'unreadable input is not an attempt');
select is((select answer from public.parametric_submit((select instance_id from item), 'twelve')),
  null, 'unreadable input reveals nothing');
select is((select correct from public.parametric_submit(
  (select instance_id from item), ((select expected from truth) + 1)::text)),
  false, 'a wrong first answer is marked wrong');
select is((select first_attempt from public.parametric_submit(
  (select instance_id from item), trim_scale((select expected from truth))::text || '%')),
  false, 'later answers are not first attempts');
select isnt((select instance_id from public.parametric_next_item('pc-whole-percent')),
  (select instance_id from item), 'after answering, a new item is made');
reset role;

select is((select first_correct from private.parametric_instances
            where id = (select instance_id from item)), false,
  'the first answer stays recorded');

-- Exposure and constraints across 20 answered fraction items.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0750000-0000-4000-8000-00000000000a', true);
do $$
declare r record;
begin
  for n in 1..20 loop
    select * into r from public.parametric_next_item('fd-terminating');
    perform public.parametric_submit(r.instance_id, '0');
  end loop;
end $$;
reset role;
select is((select count(distinct variables)::int from private.parametric_instances
            where family_id = 'fd-terminating'), 20,
  'no variant repeats within the last 20 items');
select ok((select bool_and((variables->>'numerator')::int < (variables->>'denominator')::int)
             from private.parametric_instances where family_id = 'fd-terminating'),
  'every fraction is proper (numerator < denominator)');
select ok((select bool_and(answer = private.parametric_compute('fraction_to_decimal', variables, null)
                           and scale(trim_scale(answer)) <= 6)
             from private.parametric_instances where family_id = 'fd-terminating'),
  'every stored answer is the exact terminating decimal');

select * from finish();
rollback;
