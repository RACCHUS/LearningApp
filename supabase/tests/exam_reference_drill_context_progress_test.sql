begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(34);

select has_function('public','exam_reference_drill_part_attempt_history',
  array['uuid','text','integer','timestamp with time zone','uuid'],
  'Owner/part/edition drill attempt-history RPC exists');
select ok(not has_function_privilege('anon',
  'public.exam_reference_drill_part_attempt_history(uuid,text,integer,timestamptz,uuid)','EXECUTE'),
  'Anonymous SQL role cannot inspect private part history');
select ok(has_function_privilege('authenticated',
  'public.exam_reference_drill_part_attempt_history(uuid,text,integer,timestamptz,uuid)','EXECUTE'),
  'Signed-in owner role may inspect private part history');
select is((select prosecdef from pg_proc where oid=
  'public.exam_reference_drill_part_attempt_history(uuid,text,integer,timestamptz,uuid)'::regprocedure),
  false,'Part history is security invoker and cannot bypass owner RLS');
select has_function('public','exam_reference_drill_context_progress',
  array['uuid'],'Exact-version Current Context RPC exists');
select ok(not has_function_privilege('anon',
  'public.exam_reference_drill_context_progress(uuid)','EXECUTE'),
  'Unauthenticated callers cannot inspect reference practice');
select ok(has_function_privilege('authenticated',
  'public.exam_reference_drill_context_progress(uuid)','EXECUTE'),
  'Owner-authenticated caller can obtain context summary');
select is((select prosecdef from pg_proc where oid=
  'public.exam_reference_drill_context_progress(uuid)'::regprocedure),
  false,'Summary executes as caller and cannot bypass RLS');
select ok(not has_table_privilege('authenticated',
  'public.exam_reference_drill_scoring_keys','SELECT'),
  'The private editorial scoring key remains inaccessible');

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

insert into public.exam_reference_drill_events (
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
 'project_management','2027-07-01',1,1,
 'resource_choice',true,1000,now()-interval '2 seconds',now()),
 ('b3000000-0000-4000-8000-000000000052',
 'b3000000-0000-4000-8000-000000000041',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-07-01',1,1,
 'section_location',true,1000,now()-interval '2 seconds',now()),
 ('b3000000-0000-4000-8000-000000000053',
 'b3000000-0000-4000-8000-000000000041',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-07-01',1,1,
 'interpretation',false,1000,now()-interval '2 seconds',now());
select is((select is_correct from public.score_exam_reference_drill_step(
 'b3000000-0000-4000-8000-000000000051','example_book')),
 true,'Owner receives the server-derived correctness receipt');
select is((select count(*)::integer from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000012')),3,
 'Three distinct R1/R2/R3 skill rows returned for exact target version');
select is((select sum(recorded_steps)::integer
 from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000012')),3,
 'All three edition observations included in Current Context');
select is((select sum(graded_correct)::integer
 from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000012')),1,
 'Only server-graded correct choice counts toward verified response evidence');
select is((select sum(graded_incorrect)::integer
 from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000012')),0,
 'No guessed score for other steps');
select is((select sum(awaiting_grade)::integer
 from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000012')),1,
 'Unscored response remains clearly distinguished');
select is((select sum(skipped_steps)::integer
 from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000012')),1,
 'Skipped step remains ungraded and distinct');
select is((select count(*)::integer from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000098')),0,
 'Different target version cannot inherit practice evidence');
select is((select count(*)::integer from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000012')
 where manifest_revision_id='b3000000-0000-4000-8000-000000000016'
 and manifest_revision=1 and exam_part_key='project_management'
 and target_version_id='b3000000-0000-4000-8000-000000000012'),3,
 'Every group carries the exact published version, manifest and exam part');

-- EXM-03 real saved attempt grouping, no client guess of official score.
select is((select count(*)::integer
  from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000012','project_management')),1,
  'Existing three step events form one saved, incomplete private drill');
select is((select recorded_steps
  from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000012','project_management')),3,
  'History counts exactly the three existing immutable step observations');
select is((select completed_four_steps
  from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000012','project_management')),false,
  'Three steps cannot be mislabeled a finished R1-R4 practice drill');
select is((select count(*)::integer
  from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000012','another_part')),0,
  'Part history never inherits a different exam-part key');
select is((select count(*)::integer
  from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000098','project_management')),0,
  'Part history never inherits a different target version');
select throws_ok($q$
  select * from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000012','project_management',51)
$q$,'22023',null,'Private part-history RPC enforces safe page bounds');
select throws_ok($q$
  select * from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000012','project_management',20,
    now(),null)
$q$,'22023',null,'History rejects incomplete paired cursor');

insert into public.exam_reference_drill_events (
 id,client_attempt_id,assessment_item_id,approved_binding_id,
 manifest_revision_id,exam_part_key,administration_date,
 item_content_revision,answer_location_revision,drill_step,responded,
 app_elapsed_ms,started_at,completed_at
) values (
 'b3000000-0000-4000-8000-000000000054',
 'b3000000-0000-4000-8000-000000000041',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-07-01',1,1,
 'application',true,1000,now()-interval '2 seconds',now()
);
select is((select completed_four_steps
  from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000012','project_management')),true,
  'Only four accepted unique R1-R4 steps count as completed practice');
select is((select graded_correct
  from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000012','project_management')),1,
  'A completed four-step drill does not fabricate ungraded correctness');

do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
 'b3000000-0000-4000-8000-000000000002',true);
end $jwt$;
select is((select count(*)::integer from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000012')),0,
 'Account B sees zero of account A activity or grades');
select is((select count(*)::integer
  from public.exam_reference_drill_part_attempt_history(
    'b3000000-0000-4000-8000-000000000012','project_management')),0,
  'Account B cannot read owner A attempt history');

do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
 'b3000000-0000-4000-8000-000000000003',true);
 perform set_config('request.jwt.claims','{"is_anonymous":true}',true);
end $jwt$;
select throws_ok($q$
 select * from public.exam_reference_drill_context_progress(
 'b3000000-0000-4000-8000-000000000012')
$q$,'42501',null,
 'Supabase Auth anonymous guest cannot read Current Context evidence');
select throws_ok($q$
 select * from public.exam_reference_drill_part_attempt_history(
 'b3000000-0000-4000-8000-000000000012','project_management')
$q$,'42501',null,
 'Anonymous Auth guests cannot read durable part-attempt history');
reset role;

select * from finish();
rollback;
