begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(32);

-- Synthetic fixtures only, fully rolled back.
select has_table('public','exam_reference_drill_scoring_keys',
  'Private independently reviewed step rubric table exists');
select has_table('public','exam_reference_drill_grades',
  'Durable derived score table exists');
select ok((select relrowsecurity from pg_class
  where oid='public.exam_reference_drill_scoring_keys'::regclass),
  'Private scoring keys have RLS');
select ok(not has_table_privilege('authenticated',
  'public.exam_reference_drill_scoring_keys','SELECT'),
  'Learners cannot read private keys');
select ok(not has_table_privilege('anon',
  'public.exam_reference_drill_scoring_keys','SELECT'),
  'Anonymous API cannot read private keys');
select ok(not has_table_privilege('authenticated',
  'public.exam_reference_drill_grades','INSERT'),
  'Learners cannot claim their own verified score');
select ok(not has_table_privilege('authenticated',
  'public.exam_reference_drill_grades','UPDATE'),
  'Learners cannot rewrite verified score');
select ok(not has_function_privilege('anon',
  'public.score_exam_reference_drill_step(uuid,text)','EXECUTE'),
  'Anonymous API cannot request scoring');
select ok(has_function_privilege('authenticated',
  'public.score_exam_reference_drill_step(uuid,text)','EXECUTE'),
  'Authenticated learner can call guarded scoring function');
select ok(public.exam_reference_drill_tokens_valid(
  '{"resource_choice":["example_book"],"section_location":["1.1"],"interpretation":["yes"],"application":["b"]}'::jsonb),
  'Exactly four normalized reviewed steps can be approved');
select ok(not public.exam_reference_drill_tokens_valid(
  '{"resource_choice":["example_book"]}'::jsonb),
  'Incomplete R1-only rubric cannot silently score R2-R4');
select ok(not public.exam_reference_drill_tokens_valid(
  '{"resource_choice":["example_book","example_book"],"section_location":["1.1"],"interpretation":["yes"],"application":["b"]}'::jsonb),
  'Duplicate tokens in an answer set are rejected');

insert into auth.users (id,email) values
 ('b3000000-0000-4000-8000-000000000001','exm03-a@example.invalid'),
 ('b3000000-0000-4000-8000-000000000002','exm03-b@example.invalid'),
 ('b3000000-0000-4000-8000-000000000003',null)
on conflict(id) do nothing;

insert into public.learning_targets
  (id,target_type,title,slug,status,is_public,is_official)
values ('b3000000-0000-4000-8000-000000000011','licensure_exam',
  'EXM02B Scoring Synthetic','exm02b-scoring-private-fixture',
  'published',true,false);
insert into public.target_versions
 (id,target_id,version_code,status,metadata)
values ('b3000000-0000-4000-8000-000000000012',
 'b3000000-0000-4000-8000-000000000011','fictional-v1','published',
 '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"project_management","display_name":"Fake PM","curriculum_root_node_id":"b3000000-0000-4000-8000-000000000013"}]}}'::jsonb);
insert into public.curriculum_nodes
 (id,target_version_id,node_type,title,sort_order)
values ('b3000000-0000-4000-8000-000000000013',
 'b3000000-0000-4000-8000-000000000012','domain','Fake chapter',1);
insert into public.content_source_releases
 (id,publisher,title,version,source_url)
values
 ('b3000000-0000-4000-8000-000000000014','Fictional','Fake list',
  'fictional-2027','https://example.gov/scoring-fixture-list.pdf'),
 ('b3000000-0000-4000-8000-000000000015','Fictional','Fake book',
  '2027-book','https://example.org/scoring-fixture-book.pdf');

insert into public.exam_reference_manifest_revisions(
 id,target_version_id,exam_part_key,revision,effective_from,effective_until,
 source_release_id,official_source_url,source_checked_at,author_ref,
 reviewer_ref,reviewed_at,review_status,publication_status,reference_entries
) values (
 'b3000000-0000-4000-8000-000000000016',
 'b3000000-0000-4000-8000-000000000012','project_management',1,
 '2027-01-01','2027-12-31',
 'b3000000-0000-4000-8000-000000000014',
 'https://example.gov/scoring-fixture-list.pdf',now()-interval '2 days',
 'fictional-author','fictional-reviewer',now()-interval '1 day',
 'approved','published',
 '[{"key":"example_book","edition":"2027-book","source_page":"2"}]'::jsonb
);
insert into public.assessment_items(
 id,origin_target_version_id,interaction_type,prompt,response_spec,scoring_spec
) values (
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000012',
 'single_choice','Fictional independent review item',
 '{"options":["A","B"]}'::jsonb,'{"correct_index":0}'::jsonb
);
insert into public.assessment_item_reference_validity(
 id,assessment_item_id,manifest_revision_id,
 item_content_revision,item_content_sha256,answer_location_revision,
 reference_edition_key,reference_edition,source_release_id,
 expected_locations,author_ref,ai_drafted,reviewer_ref,
 reviewer_qualification_evidence,reviewer_edition_access_evidence,
 rights_review_status,review_status,reviewed_at,review_minutes,
 publication_status
) values (
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000016',
 1,public.exam_reference_item_fingerprint('b3000000-0000-4000-8000-000000000017'),1,
 'example_book','2027-book','b3000000-0000-4000-8000-000000000015',
 '[{"section":"1.1","source_page":"11"}]'::jsonb,
 'fixture-author',true,'independent-qualified-human',
 'fictional qualified reviewer','fictional 2027 book in hand',
 'approved','approved',now(),12,'published'
);

-- An editorial rubric is a second independently approved entity.
insert into public.exam_reference_drill_scoring_keys (
 id,approved_binding_id,scoring_version,step_tokens,author_ref,
 ai_drafted,publication_status
) values (
 'b3000000-0000-4000-8000-000000000019',
 'b3000000-0000-4000-8000-000000000018',1,
 '{"resource_choice":["example_book"],"section_location":["1.1"],"interpretation":["yes"],"application":["b"]}'::jsonb,
 'fixture-author',true,'draft'
);
select throws_ok($q$
 update public.exam_reference_drill_scoring_keys
 set publication_status='published'
 where id='b3000000-0000-4000-8000-000000000019'
$q$, 'P0001',null,
 'Cannot publish scoring answer keys without independent reviewer signoff');
select lives_ok($q$
 update public.exam_reference_drill_scoring_keys set
  reviewer_ref='independent-score-reviewer',
  reviewer_qualification_evidence='fictional subject reviewer',
  reviewer_edition_access_evidence='fictional 2027 book in hand',
  rights_review_status='approved',review_status='approved',
  reviewed_at=now(),review_minutes=9,
  publication_status='published'
 where id='b3000000-0000-4000-8000-000000000019'
$q$, 'Independently approved scoring rubric can be published');
select throws_ok($q$
 update public.exam_reference_drill_scoring_keys
 set step_tokens='{"resource_choice":["wrong"],"section_location":["1.1"],"interpretation":["yes"],"application":["b"]}'::jsonb
 where id='b3000000-0000-4000-8000-000000000019'
$q$, 'P0001',null,'Published scoring answer keys cannot be changed');

set local role authenticated;
do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
   'b3000000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"is_anonymous":false}',true);
end $jwt$;

select throws_ok($q$
 select * from public.exam_reference_drill_scoring_keys
$q$, '42501',null,'Learner SELECT of answer keys is permission denied');
select throws_ok($q$
 insert into public.exam_reference_drill_grades(
  event_id,owner_auth_uid,approved_binding_id,scoring_key_id,
  drill_step,is_correct,scoring_version
 ) values (
 'b3000000-0000-4000-8000-000000000051',
 'b3000000-0000-4000-8000-000000000001',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000019',
 'resource_choice',true,1
 )
$q$, '42501',null,'Learner cannot forge a true score directly');

insert into public.exam_reference_drill_events(
 id,client_attempt_id,assessment_item_id,approved_binding_id,
 manifest_revision_id,exam_part_key,administration_date,
 item_content_revision,answer_location_revision,drill_step,responded,
 app_elapsed_ms,started_at,completed_at
) values
 ('b3000000-0000-4000-8000-000000000051',
 'b3000000-0000-4000-8000-000000000041',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,
 'resource_choice',true,2000,now()-interval '3 seconds',now()),
 ('b3000000-0000-4000-8000-000000000052',
 'b3000000-0000-4000-8000-000000000041',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,
 'section_location',true,2000,now()-interval '3 seconds',now()),
 ('b3000000-0000-4000-8000-000000000053',
 'b3000000-0000-4000-8000-000000000041',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,
 'interpretation',true,2000,now()-interval '3 seconds',now()),
 ('b3000000-0000-4000-8000-000000000054',
 'b3000000-0000-4000-8000-000000000041',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,
 'application',true,2000,now()-interval '3 seconds',now()),
 ('b3000000-0000-4000-8000-000000000055',
 'b3000000-0000-4000-8000-000000000042',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,
 'section_location',false,0,now()-interval '3 seconds',now());

select is((select is_correct from public.score_exam_reference_drill_step(
 'b3000000-0000-4000-8000-000000000051','EXAMPLE_BOOK')),true,
 'R1 exact approved book scores true using server-owned keys');
select is((select is_correct from public.score_exam_reference_drill_step(
 'b3000000-0000-4000-8000-000000000052',' 1.1 ')),true,
 'R2 approved location scores true with safe token normalization');
select is((select is_correct from public.score_exam_reference_drill_step(
 'b3000000-0000-4000-8000-000000000053','no')),false,
 'R3 wrong interpretation scores false without answer disclosure');
select is((select is_correct from public.score_exam_reference_drill_step(
 'b3000000-0000-4000-8000-000000000054','b')),true,
 'R4 correct application scores true');
select is((select is_correct from public.score_exam_reference_drill_step(
 'b3000000-0000-4000-8000-000000000053','yes')),false,
 'A different retry answer cannot change an already graded event');
select is((select count(*)::integer from public.exam_reference_drill_grades),4,
 'Four graded events are idempotent, no duplicate-score row');
select is((select count(*)::integer from public.exam_reference_drill_events
 where verification_state='unverified'),5,
 'Untrusted observations remain labeled unverified after scoring');
select throws_ok($q$
 select * from public.score_exam_reference_drill_step(
  'b3000000-0000-4000-8000-000000000055','1.1')
$q$,'42501',null,'A skipped response cannot be scored after the fact');

-- Cross-account and anonymous impersonation must be rejected inside the
-- SECURITY DEFINER function, not merely by Flutter UX.
do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
   'b3000000-0000-4000-8000-000000000002',true);
end $jwt$;
select throws_ok($q$
 select * from public.score_exam_reference_drill_step(
 'b3000000-0000-4000-8000-000000000051','example_book')
$q$, '42501',null,
 'Account B cannot read or rescore account A event');
select is((select count(*)::integer from public.exam_reference_drill_grades),0,
 'Account B has no access to account A graded results');

do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
 'b3000000-0000-4000-8000-000000000003',true);
 perform set_config('request.jwt.claims','{"is_anonymous":true}',true);
end $jwt$;
select throws_ok($q$
 select * from public.score_exam_reference_drill_step(
 'b3000000-0000-4000-8000-000000000051','example_book')
$q$, '42501',null,
 'Authenticated Supabase anonymous guest cannot score events');

-- Return to permanent owner, exercise the rolling bound and cascade privacy.
do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
 'b3000000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"is_anonymous":false}',true);
end $jwt$;

do $limit$
declare i integer; new_event uuid;
begin
 for i in 1..16 loop
   insert into public.exam_reference_drill_events(
     client_attempt_id,assessment_item_id,approved_binding_id,
     manifest_revision_id,exam_part_key,administration_date,
     item_content_revision,answer_location_revision,drill_step,responded,
     app_elapsed_ms,started_at,completed_at
   ) values (
     gen_random_uuid(),'b3000000-0000-4000-8000-000000000017',
     'b3000000-0000-4000-8000-000000000018',
     'b3000000-0000-4000-8000-000000000016',
     'project_management','2027-08-01',1,1,'resource_choice',true,
     1000,now()-interval '2 seconds',now()
   ) returning id into new_event;
   perform * from public.score_exam_reference_drill_step(new_event,'example_book');
 end loop;
end
$limit$;
select is((select count(*)::integer from public.exam_reference_drill_grades),20,
 'Per-binding rolling review-cap fixture has twenty graded events');

insert into public.exam_reference_drill_events(
 id,client_attempt_id,assessment_item_id,approved_binding_id,
 manifest_revision_id,exam_part_key,administration_date,
 item_content_revision,answer_location_revision,drill_step,responded,
 app_elapsed_ms,started_at,completed_at
) values (
 'b3000000-0000-4000-8000-000000000056',
 'b3000000-0000-4000-8000-000000000043',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-08-01',1,1,
 'resource_choice',true,1000,now()-interval '2 seconds',now()
);
select throws_ok($q$
 select * from public.score_exam_reference_drill_step(
  'b3000000-0000-4000-8000-000000000056','example_book')
$q$, '42501',null,'Repeated score-oracle requests are capped');
select is((select count(*)::integer from public.exam_reference_drill_grades),20,
 'Rejected twenty-first score cannot write partial grade');

delete from public.exam_reference_drill_events
  where client_attempt_id='b3000000-0000-4000-8000-000000000041';
select is((select count(*)::integer from public.exam_reference_drill_grades),16,
 'Owner deletion of attempt also deletes its four private derived grades');
reset role;

select * from finish();
rollback;
