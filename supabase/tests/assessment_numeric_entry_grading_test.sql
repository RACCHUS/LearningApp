-- pgTAP: server grading of numeric_entry items (migration 20261120020000).
-- Strict number parsing, tolerance, no key without a response, and the same
-- visibility rules as the other interaction types.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(14);

insert into public.lessons (id, title, visibility) values
  ('c4000000-0000-4000-8000-000000000101', 'Numeric Public Lesson', 'public');
insert into auth.users(id, email) values
  ('c4000000-0000-4000-8000-000000000001', 'numeric-owner@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('c4000000-0000-4000-8000-000000000001')
on conflict (id) do nothing;
insert into public.lessons (id, title, visibility, user_id) values
  ('c4000000-0000-4000-8000-000000000102', 'Numeric Private Lesson', 'private',
   'c4000000-0000-4000-8000-000000000001');

insert into public.assessment_items
  (id, lesson_id, interaction_type, prompt, response_spec, scoring_spec, explanation)
values
  ('c4000000-0000-4000-8000-000000000201', 'c4000000-0000-4000-8000-000000000101',
   'numeric_entry', 'What is 15% of 80?', '{}', '{"correct_value":12}', 'Book answer: 12'),
  ('c4000000-0000-4000-8000-000000000202', 'c4000000-0000-4000-8000-000000000101',
   'numeric_entry', 'Round pi to 2 places', '{}', '{"correct_value":3.14,"tolerance":0.005}', null),
  ('c4000000-0000-4000-8000-000000000203', 'c4000000-0000-4000-8000-000000000101',
   'numeric_entry', 'Large number', '{}', '{"correct_value":1200}', null),
  ('c4000000-0000-4000-8000-000000000204', 'c4000000-0000-4000-8000-000000000101',
   'numeric_entry', 'No key', '{}', '{}', null),
  ('c4000000-0000-4000-8000-000000000205', 'c4000000-0000-4000-8000-000000000102',
   'numeric_entry', 'Hidden', '{}', '{"correct_value":7}', null);

create temporary table g(label text, r jsonb) on commit drop;
grant all on g to anon;
set local role anon;
insert into g select 'int',     public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000201","response":12}]')->0;
insert into g select 'string',  public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000201","response":" 12.0 "}]')->0;
insert into g select 'wrong',   public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000201","response":"13"}]')->0;
insert into g select 'text',    public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000201","response":"twelve"}]')->0;
insert into g select 'tol_in',  public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000202","response":"3.141"}]')->0;
insert into g select 'tol_out', public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000202","response":"3.2"}]')->0;
insert into g select 'grouped', public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000203","response":"1,200"}]')->0;
insert into g select 'comma',   public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000203","response":"1,20"}]')->0;
insert into g select 'minus',   public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000201","response":"−12"}]')->0;
insert into g select 'nokey',   public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000204","response":1}]')->0;
insert into g select 'noresp',  public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000201","response":null}]')->0;
insert into g select 'private', public.grade_assessment_items('[{"item_id":"c4000000-0000-4000-8000-000000000205","response":7}]')->0;
reset role;

select is((select r->>'is_correct' from g where label = 'int'), 'true', 'a JSON number is graded');
select is((select r->>'is_correct' from g where label = 'string'), 'true', 'a numeric string with spaces is graded');
select is((select r->>'is_correct' from g where label = 'wrong'), 'false', 'a wrong number is incorrect');
select is((select r->>'is_correct' from g where label = 'text'), 'false', 'words are not numbers');
select ok((select r->>'error' is null from g where label = 'text'), 'and are graded, not errors');
select is((select r->>'is_correct' from g where label = 'tol_in'), 'true', 'inside the tolerance');
select is((select r->>'is_correct' from g where label = 'tol_out'), 'false', 'outside the tolerance');
select is((select r->>'is_correct' from g where label = 'grouped'), 'true', 'grouped thousands are accepted');
select is((select r->>'is_correct' from g where label = 'comma'), 'false', 'a decimal comma is not reinterpreted');
select is((select r->>'is_correct' from g where label = 'minus'), 'false', 'unicode minus is read as minus (-12 is not 12)');
select is((select r->>'is_correct' from g where label = 'nokey'), 'false', 'an item without a key is never correct');
select is((select r->>'error' from g where label = 'noresp'), 'response_required', 'no key without a response');
select ok((select r->'scoring_spec' is null from g where label = 'noresp'), 'and no scoring_spec is returned');
select is((select r->>'error' from g where label = 'private'), 'not_available', 'private lessons stay hidden');

select * from finish();
rollback;
