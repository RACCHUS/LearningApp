begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(35);

select has_function('public','exm03_account_practice_inventory',
 array[]::text[],'Combined owner inventory exists');
select has_function('public','exm03_account_practice_export',
 array[]::text[],'Combined bounded archive exists');
select has_function('public','exm03_account_part_export_page',
 array['integer','timestamp with time zone','uuid'],
 'Owner-only assignment keyset exporter exists');
select ok(not has_function_privilege('anon',
 'public.exm03_account_part_export_page(integer,timestamptz,uuid)','EXECUTE'),
 'Anonymous role cannot invoke assignment history page');
select ok(has_function_privilege('authenticated',
 'public.exm03_account_part_export_page(integer,timestamptz,uuid)','EXECUTE'),
 'Permanent signed-in users have guarded RPC entrypoint');
select has_function('public','exm03_erase_account_practice',
 array['integer','integer','integer','text','text'],
 'Verified all-practice erasure exists');
select ok(not has_function_privilege('anon',
 'public.exm03_account_practice_export()','EXECUTE'),
 'Unsigned callers cannot export combined history');
select ok(not has_function_privilege('anon',
 'public.exm03_erase_account_practice(integer,integer,integer,text,text)',
 'EXECUTE'),'Unsigned callers cannot erase');
select ok(not has_function_privilege('authenticated',
 'public.exm03_portability_owner()','EXECUTE'),
 'Internal Auth session assertion is not a public RPC');
select ok(not has_table_privilege('authenticated',
 'public.exam_part_practice_assignments','SELECT'),
 'Combined export does not expose assignment-table reads');
select ok(not has_table_privilege('authenticated',
 'public.exam_reference_drill_scoring_keys','SELECT'),
 'Combined export does not expose reference answer keys');

insert into auth.users(id,email) values
 ('e4010000-0000-4000-8000-000000000001','exm-port-a@example.invalid'),
 ('e4010000-0000-4000-8000-000000000002','exm-port-b@example.invalid');
insert into auth.sessions(id,user_id) values
 ('e4020000-0000-4000-8000-000000000001',
  'e4010000-0000-4000-8000-000000000001'),
 ('e4020000-0000-4000-8000-000000000002',
  'e4010000-0000-4000-8000-000000000002');
insert into public.learning_targets
 (id,target_type,title,slug,status,is_public,is_official)
values ('e4030000-0000-4000-8000-000000000001','licensure_exam',
 'EXM03 Portability Fixture','exm03-portability-fixture',
 'published',true,false);
insert into public.target_versions
 (id,target_id,version_code,status,metadata)
values ('e4040000-0000-4000-8000-000000000001',
 'e4030000-0000-4000-8000-000000000001','fictional-1','published',
 '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"part_a",
 "display_name":"Part A","curriculum_root_node_id":
 "e4050000-0000-4000-8000-000000000001"}]}}'::jsonb);
insert into public.curriculum_nodes
 (id,target_version_id,node_type,title,sort_order)
values ('e4050000-0000-4000-8000-000000000001',
 'e4040000-0000-4000-8000-000000000001','domain','Part root',1);
insert into public.content_source_releases
 (id,publisher,title,version,source_url)
values ('e4060000-0000-4000-8000-000000000001',
 'Fictional','Synthetic list','test','https://example.org/list');
insert into public.exam_reference_manifest_revisions(
 id,target_version_id,exam_part_key,revision,effective_from,effective_until,
 source_release_id,official_source_url,source_checked_at,author_ref,
 reviewer_ref,reviewed_at,review_status,publication_status,reference_entries
) values ('e4070000-0000-4000-8000-000000000001',
 'e4040000-0000-4000-8000-000000000001','part_a',1,
 current_date-interval '1 day',current_date+interval '1 day',
 'e4060000-0000-4000-8000-000000000001',
 'https://example.org/list',now()-interval '1 day',
 'author-synthetic','reviewer-synthetic',now()-interval '1 hour',
 'approved','published','[{"key":"book","edition":"test","source_page":"1"}]'::jsonb);

insert into public.assessment_items(
 id,origin_target_version_id,interaction_type,prompt,response_spec,scoring_spec
)
select ('e4080000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'e4040000-0000-4000-8000-000000000001','single_choice',
 'Synthetic reviewed prompt '||n,
 '{"options":["A","B"]}'::jsonb,'{"correct_index":0}'::jsonb
from generate_series(1,6) n;

insert into public.exam_part_practice_assignments(
 id,owner_id,target_id,target_version_id,exam_part_key,
 curriculum_root_node_id,manifest_revision_id,practice_kind,
 assigned_items,expires_at
)
select ('e4090000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('e4010000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'e4030000-0000-4000-8000-000000000001',
 'e4040000-0000-4000-8000-000000000001',
 'part_a','e4050000-0000-4000-8000-000000000001',
 'e4070000-0000-4000-8000-000000000001',
 'diagnostic',
 (select jsonb_agg(jsonb_build_object(
   'id',i.id,'sha256',public.exam_reference_item_fingerprint(i.id))
   order by i.id) from public.assessment_items i
   where i.origin_target_version_id=
    'e4040000-0000-4000-8000-000000000001'),
 now()+interval '1 hour'
from generate_series(1,2) n;

insert into public.exam_part_practice_attempts(
 owner_id,target_id,target_version_id,exam_part_key,
 curriculum_root_node_id,practice_kind,question_count,
 fully_correct_count,partial_count,practice_score,
 question_edition_fingerprint,assignment_id,response_sha256
) values (
 'e4010000-0000-4000-8000-000000000001',
 'e4030000-0000-4000-8000-000000000001',
 'e4040000-0000-4000-8000-000000000001','part_a',
 'e4050000-0000-4000-8000-000000000001',
 'diagnostic',6,4,0,0.666667,
 repeat('b',64),
 'e4090000-0000-4000-8000-000000000001',repeat('a',64)
);

-- Cross-store fixture: one approved R1-R4 event and a derived grade.
-- Editorial scoring keys are test-only rows in this rollback transaction.
insert into public.content_source_releases(
 id,publisher,title,version,source_url
) values ('e4060000-0000-4000-8000-000000000002',
 'Fictional','Test handbook','test','https://example.org/handbook');
insert into public.assessment_item_reference_validity(
 id,assessment_item_id,manifest_revision_id,item_content_revision,
 item_content_sha256,answer_location_revision,reference_edition_key,
 reference_edition,source_release_id,expected_locations,author_ref,
 ai_drafted,reviewer_ref,reviewer_qualification_evidence,
 reviewer_edition_access_evidence,rights_review_status,review_status,
 reviewed_at,review_minutes,publication_status
) values (
 'e4100000-0000-4000-8000-000000000001',
 'e4080000-0000-4000-8000-000000000001',
 'e4070000-0000-4000-8000-000000000001',1,
 public.exam_reference_item_fingerprint(
  'e4080000-0000-4000-8000-000000000001'),1,
 'book','test','e4060000-0000-4000-8000-000000000002',
 '[{"section":"1.1","source_page":"11"}]'::jsonb,
 'fictional-author',true,'independent-fictional-reviewer',
 'Qualified fictional reviewer','Fictional edition in hand',
 'approved','approved',now(),8,'published');
insert into public.exam_reference_drill_scoring_keys(
 id,approved_binding_id,scoring_version,step_tokens,author_ref,
 ai_drafted,publication_status
) values (
 'e4110000-0000-4000-8000-000000000001',
 'e4100000-0000-4000-8000-000000000001',
 1,'{"resource_choice":["book"],"section_location":["1.1"],
 "interpretation":["yes"],"application":["a"]}'::jsonb,
 'fictional-author',true,'draft');
insert into public.exam_reference_drill_events(
 id,owner_auth_uid,client_attempt_id,assessment_item_id,
 approved_binding_id,manifest_revision_id,exam_part_key,
 administration_date,item_content_revision,answer_location_revision,
 drill_step,responded,app_elapsed_ms,started_at,completed_at
) values (
 'e4120000-0000-4000-8000-000000000001',
 'e4010000-0000-4000-8000-000000000001',
 'e4130000-0000-4000-8000-000000000001',
 'e4080000-0000-4000-8000-000000000001',
 'e4100000-0000-4000-8000-000000000001',
 'e4070000-0000-4000-8000-000000000001',
 'part_a',current_date,1,1,'resource_choice',true,500,
 now()-interval '2 seconds',now());
insert into public.exam_reference_drill_grades(
 event_id,owner_auth_uid,approved_binding_id,scoring_key_id,drill_step,
 is_correct,scoring_version
) values (
 'e4120000-0000-4000-8000-000000000001',
 'e4010000-0000-4000-8000-000000000001',
 'e4100000-0000-4000-8000-000000000001',
 'e4110000-0000-4000-8000-000000000001',
 'resource_choice',true,1);

select throws_ok($q$select public.exm03_account_practice_export()$q$,
 '42501',null,'No JWT denies privileged practice export');
select throws_ok($q$select public.exm03_account_practice_inventory()$q$,
 '42501',null,'No JWT denies inventory');

set local role authenticated;
do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
 'e4010000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims',
 '{"sub":"e4010000-0000-4000-8000-000000000001","role":"authenticated",
 "is_anonymous":false,"session_id":"e4020000-0000-4000-8000-000000000001"}',true);
end $jwt$;

select is((public.exm03_account_practice_inventory()->
 'reference_events')::text,'1',
 'Combined preview contains saved R1-R4 practice evidence');
select is((public.exm03_account_practice_inventory()->
 'reference_grades')::text,'1',
 'Combined preview includes the dependent R1-R4 grade');
select is((public.exm03_account_practice_export()->
 'reference_practice'->>'record_count')::int,1,
 'Combined export includes exact R1-R4 record count');
select is((public.exm03_account_practice_inventory()->
 'bound_per_store')::text,'50000',
 'Owner inventory advertises bounded 50k per store');
select is((public.exm03_account_practice_inventory()->
 'part_attempts')::text,'1',
 'Preview counts the owner scored assignment');
select is((public.exm03_account_practice_inventory()->
 'part_assignments')::text,'1',
 'Preview includes pending and scored assignment inventory');
select is(jsonb_array_length(public.exm03_account_practice_export()->
 'part_practice'),1,'Complete owner practice archive includes exact assignment');
select ok(public.exm03_account_practice_export()::text not like '%response_sha256%'
 and public.exm03_account_practice_export()::text not like '%assigned_items%'
 and public.exm03_account_practice_export()::text not like '%correct_index%'
 and public.exm03_account_practice_export()::text not like '%issued_session_id%',
 'Combined archive excludes hidden assignment/answer/session fields');
select is((public.exm03_account_practice_export()->
 'part_practice'->0->'attempt'->>'fully_correct_count')::int,4,
 'Combined export provides bounded educational score summary');

select is((public.exm03_account_part_export_page(250,null,null)->
 'row_count')::text,'1',
 'Part page returns exact owner assignment count');
select ok(public.exm03_account_part_export_page(250,null,null)::text
 not like '%issued_session_id%' and
 public.exm03_account_part_export_page(250,null,null)::text
 not like '%assigned_items%' and
 public.exm03_account_part_export_page(250,null,null)::text
 not like '%response_sha256%',
 'Part page redacts session, private items and answer fingerprints');
select is((public.exm03_account_part_export_page(
 250,'2099-01-01T00:00:00Z'::timestamptz,
 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)->
 'row_count')::text,'1','Stable keyset cursor can page before later instant');
select throws_ok($q$
 select public.exm03_account_part_export_page(251,null,null)
$q$,'22023',null,'Oversized assignment page fails closed');
select throws_ok($q$
 select public.exm03_account_part_export_page(
 250,now()::timestamptz,null)
$q$,'22023',null,'Incomplete page cursor fails closed');

select throws_ok($q$
 select public.exm03_erase_account_practice(1,1,1,repeat('0',32),'WRONG')
$q$,'22023',null,'Wrong erasure phrase cannot mutate history');
select throws_ok($q$
 select public.exm03_erase_account_practice(1,1,1,repeat('0',32),
 'DELETE ALL EXAM PRACTICE')
$q$,'40001',null,'Stale fingerprint cannot erase rows');
select is((public.exm03_account_practice_inventory()->
 'part_attempts')::text,'1','Failed confirmation did not erase scored history');

-- A revoked Auth session with the same JWT subject cannot export.
do $revoked$ begin
 perform set_config('request.jwt.claims',
 '{"sub":"e4010000-0000-4000-8000-000000000001","role":"authenticated",
 "is_anonymous":false,"session_id":"e4020000-0000-4000-8000-000000000099"}',true);
end $revoked$;
select throws_ok($q$select public.exm03_account_practice_export()$q$,
 '42501',null,'Expired/revoked session cannot export');
select throws_ok($q$select public.exm03_account_part_export_page(250,null,null)$q$,
 '42501',null,'Revoked JWT session cannot page private assignment history');
do $real$ begin
 perform set_config('request.jwt.claims',
 '{"sub":"e4010000-0000-4000-8000-000000000001","role":"authenticated",
 "is_anonymous":false,"session_id":"e4020000-0000-4000-8000-000000000001"}',true);
end $real$;

select is((select (public.exm03_erase_account_practice(
 1,1,1,public.exm03_account_practice_inventory()->>
 'snapshot_fingerprint','DELETE ALL EXAM PRACTICE')
 ->>'deleted_part_assignments')::int),1,
 'Confirmed owner delete removes issued assignment and dependent score');
select is((public.exm03_account_practice_inventory()->
 'reference_events')::text,'0',
 'Confirmed deletion also removes reference event evidence');
select is((public.exm03_account_practice_inventory()->
 'part_attempts')::text,'0',
 'Dependent scored attempts are irrecoverable after deletion');

do $other$ begin
 perform set_config('request.jwt.claim.sub',
 'e4010000-0000-4000-8000-000000000002',true);
 perform set_config('request.jwt.claims',
 '{"sub":"e4010000-0000-4000-8000-000000000002","role":"authenticated",
 "is_anonymous":false,"session_id":"e4020000-0000-4000-8000-000000000002"}',true);
end $other$;
select is((public.exm03_account_practice_inventory()->
 'part_assignments')::text,'1',
 'Deleting one learner does not delete a different owner');
do $guest$ begin
 perform set_config('request.jwt.claims',
 '{"sub":"e4010000-0000-4000-8000-000000000002","role":"authenticated",
 "is_anonymous":true,"session_id":"e4020000-0000-4000-8000-000000000002"}',true);
end $guest$;
select throws_ok($q$select public.exm03_account_practice_inventory()$q$,
 '42501',null,'Anonymous Auth guests cannot preview saved history');
select * from finish();
rollback;
