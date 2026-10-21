begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(29);

select has_table('public','exam_reference_drill_events','Durable private event table exists');
select ok((select relrowsecurity from pg_class
 where oid='public.exam_reference_drill_events'::regclass),'Events use row-level security');
select ok(has_table_privilege('authenticated','public.exam_reference_drill_events','SELECT'),'Permanent account can SELECT subject to RLS');
select ok(has_table_privilege('authenticated','public.exam_reference_drill_events','INSERT'),'Permanent account can INSERT subject to RLS');
select ok(has_table_privilege('authenticated','public.exam_reference_drill_events','DELETE'),'Owner deletion supported');
select ok(not has_table_privilege('authenticated','public.exam_reference_drill_events','UPDATE'),'No client update capability');
select ok(not has_table_privilege('anon','public.exam_reference_drill_events','SELECT'),'Public anon API has no SELECT');
select ok(not has_table_privilege('anon','public.exam_reference_drill_events','INSERT'),'Public anon API has no INSERT');

-- All fixtures are fictional, transaction-local, and rolled back.
insert into auth.users(id,email) values
 ('b2000000-0000-4000-8000-000000000001','exm02b-a@example.invalid'),
 ('b2000000-0000-4000-8000-000000000002','exm02b-b@example.invalid'),
 ('b2000000-0000-4000-8000-000000000003',null)
on conflict(id) do nothing;

insert into public.learning_targets
  (id,target_type,title,slug,status,is_public,is_official)
values ('b2000000-0000-4000-8000-000000000011','licensure_exam',
  'EXM02B Fictional Target','exm02b-private-attempt-fixture','published',true,false);
insert into public.target_versions
  (id,target_id,version_code,status,metadata)
values ('b2000000-0000-4000-8000-000000000012',
 'b2000000-0000-4000-8000-000000000011','fictional-v1','published',
 '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"project_management","display_name":"Fake PM","curriculum_root_node_id":"b2000000-0000-4000-8000-000000000013"}]}}'::jsonb);
insert into public.curriculum_nodes(id,target_version_id,node_type,title,sort_order)
values ('b2000000-0000-4000-8000-000000000013',
 'b2000000-0000-4000-8000-000000000012','domain','Fake part',1);
insert into public.content_source_releases(id,publisher,title,version,source_url)
values
 ('b2000000-0000-4000-8000-000000000014','Fictional',
  'Fictional exam list','fictional-2027','https://example.gov/exm02b-list.pdf'),
 ('b2000000-0000-4000-8000-000000000015','Fictional',
  'Fictional reference','2027-book','https://example.org/exm02b-book.pdf');

insert into public.exam_reference_manifest_revisions(
 id,target_version_id,exam_part_key,revision,effective_from,effective_until,
 source_release_id,official_source_url,source_checked_at,author_ref,
 reviewer_ref,reviewed_at,review_status,publication_status,reference_entries
) values (
 'b2000000-0000-4000-8000-000000000016',
 'b2000000-0000-4000-8000-000000000012','project_management',1,
 '2027-01-01','2027-12-31','b2000000-0000-4000-8000-000000000014',
 'https://example.gov/exm02b-list.pdf',now()-interval '2 days',
 'fictional-author','fictional-reviewer',now()-interval '1 day',
 'approved','published',
 '[{"key":"example_book","edition":"2027-book","source_page":"2"}]'::jsonb
);
insert into public.assessment_items(
 id,origin_target_version_id,interaction_type,prompt,response_spec,scoring_spec
) values (
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000012',
 'single_choice','Fictional practice only?',
 '{"options":["A","B"]}'::jsonb,
 '{"correct_index":0}'::jsonb
);
insert into public.assessment_item_reference_validity (
 id,assessment_item_id,manifest_revision_id,
 item_content_revision,item_content_sha256,answer_location_revision,
 reference_edition_key,reference_edition,source_release_id,
 expected_locations,author_ref,ai_drafted,reviewer_ref,
 reviewer_qualification_evidence,reviewer_edition_access_evidence,
 rights_review_status,review_status,reviewed_at,review_minutes,publication_status
) values (
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000016',
 1,public.exam_reference_item_fingerprint('b2000000-0000-4000-8000-000000000017'),1,
 'example_book','2027-book','b2000000-0000-4000-8000-000000000015',
 '[{"section":"1.1","source_page":"11"}]'::jsonb,
 'fictional-author',true,'another-qualified-human',
 'fictional qualified reviewer','fictional 2027 exact edition',
 'approved','approved',now(),12,'published'
);
select is((select count(*)::integer from public.assessment_item_reference_validity
 where id='b2000000-0000-4000-8000-000000000018'),1,
 'Test-only approved binding is ready for owner isolation checks');

set local role authenticated;
do $jwt$ begin
  perform set_config('request.jwt.claim.sub','b2000000-0000-4000-8000-000000000001',true);
  perform set_config('request.jwt.claims','{"is_anonymous":false}',true);
end $jwt$;

select lives_ok($q$
 insert into public.exam_reference_drill_events (
 client_attempt_id,assessment_item_id,approved_binding_id,manifest_revision_id,
 exam_part_key,administration_date,item_content_revision,answer_location_revision,
 drill_step,responded,app_elapsed_ms,self_reported_book_ms,started_at,completed_at
 ) values (
 'b2000000-0000-4000-8000-000000000041',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,'resource_choice',true,900,1200,
 now()-interval '2 seconds',now()
 )
$q$, 'Permanent owner can record a version-pinned ungraded R1 event');

select is((select count(*)::integer from public.exam_reference_drill_events),1,
 'Permanent owner can read own event');
select is((select count(*)::integer from public.exam_reference_drill_events
 where verification_state='unverified'),1,
 'Events cannot falsely assert a verified score');
select is((select count(*)::integer from public.exam_reference_drill_events
 where owner_auth_uid='b2000000-0000-4000-8000-000000000001'),1,
 'Auth user ID is assigned, not public.users ID');

select throws_ok($q$
 insert into public.exam_reference_drill_events (
 client_attempt_id,assessment_item_id,approved_binding_id,manifest_revision_id,
 exam_part_key,administration_date,item_content_revision,answer_location_revision,
 drill_step,responded,app_elapsed_ms,started_at,completed_at
 ) values (
 'b2000000-0000-4000-8000-000000000041',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,'resource_choice',true,900,
 now()-interval '2 seconds',now()
 )
$q$,'23505',null,'R1 retry is idempotent and does not create duplicate rows');

select throws_ok($q$
 insert into public.exam_reference_drill_events (
 client_attempt_id,assessment_item_id,approved_binding_id,manifest_revision_id,
 exam_part_key,administration_date,item_content_revision,answer_location_revision,
 drill_step,responded,app_elapsed_ms,started_at,completed_at
 ) values (
 'b2000000-0000-4000-8000-000000000042',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000016',
 'project_management','2026-12-31',1,1,'section_location',true,2000,
 now()-interval '2 seconds',now()
 )
$q$,'P0001',null,'2027 approval cannot be used for a 2026 exam date');

select throws_ok($q$
 insert into public.exam_reference_drill_events (
 client_attempt_id,assessment_item_id,approved_binding_id,manifest_revision_id,
 exam_part_key,administration_date,item_content_revision,answer_location_revision,
 drill_step,responded,app_elapsed_ms,started_at,completed_at
 ) values (
 'b2000000-0000-4000-8000-000000000041',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000016',
 'project_management','2027-08-02',1,1,'section_location',true,2000,
 now()-interval '2 seconds',now()
 )
$q$,'P0001',null,'One attempt cannot silently switch examination dates');

select throws_ok($q$
 insert into public.exam_reference_drill_events (
 client_attempt_id,assessment_item_id,approved_binding_id,manifest_revision_id,
 exam_part_key,administration_date,item_content_revision,answer_location_revision,
 drill_step,responded,app_elapsed_ms,started_at,completed_at
 ) values (
 'b2000000-0000-4000-8000-000000000043',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,2,'interpretation',true,2000,
 now()-interval '2 seconds',now()
 )
$q$,'P0001',null,'Incorrect answer-revision number is rejected');

select lives_ok($q$
 insert into public.exam_reference_drill_events (
 client_attempt_id,assessment_item_id,approved_binding_id,manifest_revision_id,
 exam_part_key,administration_date,item_content_revision,answer_location_revision,
 drill_step,responded,app_elapsed_ms,started_at,completed_at,recorded_at
 ) values (
 'b2000000-0000-4000-8000-000000000041',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,'section_location',true,2000,
 now()-interval '2 seconds',now(),'2001-01-01T00:00:00Z'
 )
$q$, 'R2 event can be saved for same attempt without duplicating R1');
select ok((select min(recorded_at)>now()-interval '2 minutes'
 from public.exam_reference_drill_events),'Client cannot backdate server receipt timestamp');

-- Other permanent user B has separate history even if attempt UUID collides.
do $jwt$ begin
  perform set_config('request.jwt.claim.sub','b2000000-0000-4000-8000-000000000002',true);
end $jwt$;
select is((select count(*)::integer from public.exam_reference_drill_events),0,
 'Account B cannot read account A events');

select throws_ok($q$
 insert into public.exam_reference_drill_events (
 owner_auth_uid,client_attempt_id,assessment_item_id,approved_binding_id,
 manifest_revision_id,exam_part_key,administration_date,
 item_content_revision,answer_location_revision,drill_step,responded,
 app_elapsed_ms,started_at,completed_at
 ) values (
 'b2000000-0000-4000-8000-000000000001',
 'b2000000-0000-4000-8000-000000000045',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',
 1,1,'resource_choice',true,500,
 now()-interval '2 seconds',now()
 )
$q$,'42501',null,
 'Account B cannot insert an event claiming account A ownership');


with removed as (
 delete from public.exam_reference_drill_events
 where client_attempt_id='b2000000-0000-4000-8000-000000000041'
 returning id
) select is((select count(*)::integer from removed),0,
 'Account B cannot delete A events');
select lives_ok($q$
 insert into public.exam_reference_drill_events (
 client_attempt_id,assessment_item_id,approved_binding_id,manifest_revision_id,
 exam_part_key,administration_date,item_content_revision,answer_location_revision,
 drill_step,responded,app_elapsed_ms,started_at,completed_at
 ) values (
 'b2000000-0000-4000-8000-000000000041',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,'resource_choice',false,1000,
 now()-interval '2 seconds',now()
 )
$q$,'Different owners may reuse the same client attempt UUID');
select is((select count(*)::integer from public.exam_reference_drill_events),1,
 'Owner B sees only own record, not A records');

-- Authenticated DB role is shared by anonymous Supabase Auth guests.
do $jwt$ begin
  perform set_config('request.jwt.claim.sub','b2000000-0000-4000-8000-000000000003',true);
  perform set_config('request.jwt.claims','{"is_anonymous":true}',true);
end $jwt$;
select is((select count(*)::integer from public.exam_reference_drill_events),0,
 'Anonymous guest has no durable event history');
select throws_ok($q$
 insert into public.exam_reference_drill_events (
 client_attempt_id,assessment_item_id,approved_binding_id,manifest_revision_id,
 exam_part_key,administration_date,item_content_revision,answer_location_revision,
 drill_step,responded,app_elapsed_ms,started_at,completed_at
 ) values (
 'b2000000-0000-4000-8000-000000000044',
 'b2000000-0000-4000-8000-000000000017',
 'b2000000-0000-4000-8000-000000000018',
 'b2000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,'resource_choice',true,900,
 now()-interval '2 seconds',now()
 )
$q$,'42501',null,'Anonymous Supabase Auth user cannot insert durable events');

-- The original owner can delete self-owned records for privacy, not edit.
do $jwt$ begin
  perform set_config('request.jwt.claim.sub','b2000000-0000-4000-8000-000000000001',true);
  perform set_config('request.jwt.claims','{"is_anonymous":false}',true);
end $jwt$;
with removed as (
 delete from public.exam_reference_drill_events
 where client_attempt_id='b2000000-0000-4000-8000-000000000041'
 returning id
) select is((select count(*)::integer from removed),2,
 'Owner A can explicitly delete both of their own step events');
select is((select count(*)::integer from public.exam_reference_drill_events),0,
 'Owner A does not see account B after deleting their own history');

reset role;
select is((select count(*)::integer from public.exam_reference_drill_events),1,
 'User-directed deletion never deletes another owner history');
select * from finish();
rollback;
