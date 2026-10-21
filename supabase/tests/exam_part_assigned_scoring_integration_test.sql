begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(22);

insert into auth.users (id,email) values
 ('d3180000-0000-4000-8000-000000000001','exm03-graded-a@example.invalid')
on conflict(id) do nothing;
insert into public.learning_targets
 (id,target_type,title,slug,status,is_public,is_official)
values ('d3160000-0000-4000-8000-000000000000','licensure_exam',
 'EXM03 Fictional Score Fixture','exm03-fictional-score-fixture',
 'published',true,false);
insert into public.target_versions
 (id,target_id,version_code,status,metadata)
values ('d3160000-0000-4000-8000-000000000001',
 'd3160000-0000-4000-8000-000000000000','fictional-v1','published',
 '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"part_a",
 "display_name":"Fictional Part A",
 "curriculum_root_node_id":"d3170000-0000-4000-8000-000000000000"}]}}'::jsonb);
insert into public.curriculum_nodes(id,target_version_id,node_type,title,sort_order)
values ('d3170000-0000-4000-8000-000000000000',
 'd3160000-0000-4000-8000-000000000001','domain','Fake Part',1);
insert into public.content_source_releases(id,publisher,title,version,source_url)
values
 ('d3140000-0000-4000-8000-000000000001','Synthetic',
  'Mock reference list','test-2026','https://example.gov/fictional-list'),
 ('d3150000-0000-4000-8000-000000000001','Synthetic',
  'Mock handbook','test-2026','https://example.org/fictional-book');
insert into public.exam_reference_manifest_revisions (
 id,target_version_id,exam_part_key,revision,effective_from,effective_until,
 source_release_id,official_source_url,source_checked_at,
 author_ref,reviewer_ref,reviewed_at,review_status,
 publication_status,reference_entries
) values (
 'd3190000-0000-4000-8000-000000000001',
 'd3160000-0000-4000-8000-000000000001','part_a',1,
 current_date-interval '5 days',current_date+interval '30 days',
 'd3140000-0000-4000-8000-000000000001',
 'https://example.gov/fictional-list',now()-interval '2 days',
 'synthetic-author','independent-synthetic-reviewer',now()-interval '1 day',
 'approved','published',
 '[{"key":"handbook","edition":"test-2026","source_page":"2"}]'::jsonb
);

do $fixture$
declare
 n integer;
 cid uuid;
 iid uuid;
begin
 for n in 1..3 loop
   cid := ('d3130000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid;
   insert into public.knowledge_concepts(id,name,slug)
     values(cid,'Synthetic concept '||n,'exm03-private-score-'||n);
   insert into public.curriculum_node_concepts(
     curriculum_node_id,concept_id,relevance)
     values('d3170000-0000-4000-8000-000000000000',cid,'core');
 end loop;
 for n in 1..6 loop
   iid := ('d3110000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid;
   cid := ('d3130000-0000-4000-8000-' ||
        lpad((((n-1)%3)+1)::text,12,'0'))::uuid;
   insert into public.assessment_items(
     id,origin_target_version_id,interaction_type,
     prompt,response_spec,scoring_spec)
   values(iid,'d3160000-0000-4000-8000-000000000001',
     'single_choice','Fictional independently reviewed prompt '||n,
     '{"options":["A","B"]}'::jsonb,'{"correct_index":0}'::jsonb);
   insert into public.assessment_item_concepts
     (assessment_item_id,concept_id,role)
     values(iid,cid,'primary');
   insert into public.assessment_item_reference_validity (
     id,assessment_item_id,manifest_revision_id,
     item_content_revision,item_content_sha256,answer_location_revision,
     reference_edition_key,reference_edition,source_release_id,
     expected_locations,author_ref,ai_drafted,
     reviewer_ref,reviewer_qualification_evidence,
     reviewer_edition_access_evidence,rights_review_status,review_status,
     reviewed_at,review_minutes,publication_status
   ) values (
     ('d3120000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
     iid,'d3190000-0000-4000-8000-000000000001',
     1,public.exam_reference_item_fingerprint(iid),1,
     'handbook','test-2026','d3150000-0000-4000-8000-000000000001',
     '[{"section":"1.1","source_page":"11"}]'::jsonb,
     'synthetic-author',true,'independent-synthetic-reviewer',
     'Synthetic reviewer qualifications', 'Synthetic edition access proof',
     'approved','approved',now(),8,'published'
   );
 end loop;
end
$fixture$;

-- Real Supabase auth session ownership is required in addition to JWT.
-- These synthetic sessions and their issued assignments roll back with pgTAP.
insert into auth.sessions (id,user_id) values
 ('d3210000-0000-4000-8000-000000000001',
  'd3180000-0000-4000-8000-000000000001');

select ok(not has_function_privilege('anon',
  'public.exm03_issue_assigned_practice(uuid,text)','EXECUTE'),
  'Unsigned clients cannot request part assignments');
select ok(has_function_privilege('authenticated',
  'public.exm03_issue_assigned_practice(uuid,text)','EXECUTE'),
  'Only authenticated learners can request scoped educational practice');

set local role authenticated;
do $issuer_jwt$
begin
 perform set_config('request.jwt.claim.sub',
 'd3180000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims',
 '{"sub":"d3180000-0000-4000-8000-000000000001","role":"authenticated",
 "is_anonymous":false,
 "session_id":"d3210000-0000-4000-8000-000000000001"}',true);
end
$issuer_jwt$;

select throws_ok($q$
 select public.exm03_issue_assigned_practice(
  'd3160000-0000-4000-8000-000000000001','part_b')
$q$,'42501',null,'Issuer rejects unconfigured Part B without fallback');

create temp table exm03_issued as
select public.exm03_issue_assigned_practice(
 'd3160000-0000-4000-8000-000000000001','part_a') result;
select is((select (result->>'question_count')::int from exm03_issued),6,
 'Server selects exactly six reviewed canonical Part A questions');
select ok((select not (result::text like '%correct_index%')
 and not (result::text like '%scoring_spec%')
 and not (result::text like '%sha256%')
 from exm03_issued),
 'Issuer never exposes scores, correct answers or item hashes');
-- The learner must NOT read the private assignment table to verify issuance.
select ok((select (result->>'assignment_id') is not null from exm03_issued),
 'Authenticated issuer returns only the opaque new assignment identifier');
select is((select (public.exm03_issue_assigned_practice(
 'd3160000-0000-4000-8000-000000000001','part_a')
 ->>'question_count')::int),6,
 'Second bounded assignment is permitted for same learner');
select throws_ok($q$
 select public.exm03_issue_assigned_practice(
 'd3160000-0000-4000-8000-000000000001','part_a')
$q$,'42501',null,
 'Third pending assignment is denied by concurrent issuance bound');

-- A changed/invalid session cannot borrow an existing owner's Auth identity.
do $revoked$
begin
 perform set_config('request.jwt.claims',
 '{"sub":"d3180000-0000-4000-8000-000000000001","role":"authenticated",
 "is_anonymous":false,
 "session_id":"d3210000-0000-4000-8000-000000000099"}',true);
end
$revoked$;
select throws_ok($q$
 select public.exm03_issue_assigned_practice(
 'd3160000-0000-4000-8000-000000000001','part_a')
$q$,'42501',null,'Revoked or nonexistent session cannot issue attempts');
reset role;

insert into public.exam_part_practice_assignments (
 id,owner_id,target_id,target_version_id,exam_part_key,
 curriculum_root_node_id,manifest_revision_id,practice_kind,
 assigned_items,expires_at)
select
 'd3200000-0000-4000-8000-000000000001'::uuid,
 'd3180000-0000-4000-8000-000000000001'::uuid,
 'd3160000-0000-4000-8000-000000000000'::uuid,
 'd3160000-0000-4000-8000-000000000001'::uuid,'part_a',
 'd3170000-0000-4000-8000-000000000000'::uuid,
 'd3190000-0000-4000-8000-000000000001'::uuid,'diagnostic',
 jsonb_agg(jsonb_build_object('id',i.id,'sha256',
   public.exam_reference_item_fingerprint(i.id)) order by i.id),
 now()+interval '1 hour'
from public.assessment_items i
where i.origin_target_version_id =
  'd3160000-0000-4000-8000-000000000001'::uuid;

select is((select count(*)::integer from public.exam_part_practice_assignments
  where exam_part_key='part_a'),3,
 'Two pending and one scored test assignment were issued');
select throws_ok($q$
 select public.exm03_record_assigned_practice(
 'd3200000-0000-4000-8000-000000000001','{}'::jsonb)
$q$,'22023',null,'Incomplete answers cannot be recorded');
select is((select count(*)::integer from public.exam_part_practice_attempts),0,
 'Rejected submission cannot leave a partial result');

create temp table exm03_payload as
select jsonb_object_agg(i.id::text,to_jsonb(
  case when right(i.id::text,1) in ('1','2','3') then 0 else 1 end))
 as answers from public.assessment_items i
where i.origin_target_version_id =
 'd3160000-0000-4000-8000-000000000001'::uuid;
create temp table exm03_grade as
select public.exm03_record_assigned_practice(
 'd3200000-0000-4000-8000-000000000001',answers) as result
from exm03_payload;

select is((select (result->>'fully_correct_count')::integer
 from exm03_grade),3,'Scorer uses canonical answer index for six items');
select is((select (result->>'practice_score')::numeric
 from exm03_grade),0.5::numeric,'Practice score is derived from server grades');
select is((select count(*)::integer from public.exam_part_practice_attempts),1,
 'One durable score is recorded for exactly one assignment');
select ok((select (public.exm03_record_assigned_practice(
 'd3200000-0000-4000-8000-000000000001',answers)
 ->>'already_recorded')::boolean from exm03_payload),
 'Same answer batch is idempotently recovered');
select is((select count(*)::integer from public.exam_part_practice_attempts),1,
 'Identical retry does not create another attempt');
select throws_ok($q$
 select public.exm03_record_assigned_practice(
 'd3200000-0000-4000-8000-000000000001',
 jsonb_object_agg(i.id::text,to_jsonb(0)))
 from public.assessment_items i
 where i.origin_target_version_id =
  'd3160000-0000-4000-8000-000000000001'::uuid
$q$,'23505',null,'Conflicting response replay is rejected');

set local role authenticated;
do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
  'd3180000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"is_anonymous":false}',true);
end $jwt$;
select is(public.exm03_erase_part_attempts(
 'd3160000-0000-4000-8000-000000000001','part_a'),3,
 'Owner erasure deletes two pending and one scored assignment atomically');
reset role;
select is((select count(*)::integer from public.exam_part_practice_attempts),0,
 'Erasure eliminates graded attempts');
select is((select count(*)::integer from public.exam_part_practice_assignments),0,
 'Erasure eliminates replayable question assignment');
select throws_ok($q$
 select public.exm03_record_assigned_practice(
 'd3200000-0000-4000-8000-000000000001','{}'::jsonb)
$q$,'42501',null,'Erased assignment cannot recreate a score');

select * from finish();
rollback;
