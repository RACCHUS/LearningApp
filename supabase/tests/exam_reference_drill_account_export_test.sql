begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(24);

select has_function('public','exam_reference_drill_account_export',
  array['integer'],'All-edition owner-only practice export is an RPC');
select ok(not has_function_privilege('anon',
  'public.exam_reference_drill_account_export(integer)','EXECUTE'),
  'Public API cannot export protected learner practice');
select ok(has_function_privilege('authenticated',
  'public.exam_reference_drill_account_export(integer)','EXECUTE'),
  'Permanent account can invoke own practice export');
select is((select prosecdef from pg_proc where oid=
  'public.exam_reference_drill_account_export(integer)'::regprocedure),
  false,'Export is security invoker and must obey both underlying RLS rules');
select ok(not has_table_privilege('authenticated',
  'public.exam_reference_drill_scoring_keys','SELECT'),
  'Private rubric keys remain unreadable');

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
 'project_management','2027-07-01',1,1,'resource_choice',true,
 900,now()-interval '2 seconds',now()),
 ('b3000000-0000-4000-8000-000000000052',
 'b3000000-0000-4000-8000-000000000041',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-07-01',1,1,'section_location',false,
 1100,now()-interval '2 seconds',now()),
 ('b3000000-0000-4000-8000-000000000053',
 'b3000000-0000-4000-8000-000000000041',
 'b3000000-0000-4000-8000-000000000017',
 'b3000000-0000-4000-8000-000000000018',
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-07-01',1,1,'interpretation',true,
 1200,now()-interval '2 seconds',now());

select is((select is_correct from public.score_exam_reference_drill_step(
 'b3000000-0000-4000-8000-000000000051','example_book')),true,
 'Only server-private scoring derives the correct choice');
select is((public.exam_reference_drill_account_export()->>'record_count')::integer,
 3,'All owned R1–R4 records are exported together');
select is(jsonb_array_length(public.exam_reference_drill_account_export()->'steps'),
 3,'Export has three complete observations, not a silently clipped page');
select is(public.exam_reference_drill_account_export()->>'scope',
 'reference-practice-all-editions','Export is explicitly scoped, not whole account');
select is(public.exam_reference_drill_account_export()->>'snapshot_consistency',
 'single-sql-statement','Export states its consistent database read shape');
select ok(not (public.exam_reference_drill_account_export()->'steps'->0 ? 'step_tokens'),
 'Private approved tokens cannot appear inside the export');
select ok(not (public.exam_reference_drill_account_export()->'steps'->0 ? 'scoring_spec'),
 'No internal scoring rubric content crosses the export boundary');
select ok(not (public.exam_reference_drill_account_export()->'steps'->0 ? 'reviewer_ref'),
 'Editorial author/reviewer evidence is excluded from learner export');
select is((select count(*)::integer from jsonb_array_elements(
 public.exam_reference_drill_account_export()->'steps'
 ) as row(value) where row.value->>'verification_state'='unverified'),3,
 'Practice observations remain unverified even after a server grade');
select is((select count(*)::integer from jsonb_array_elements(
 public.exam_reference_drill_account_export()->'steps'
 ) as row(value) where row.value->>'is_correct'='true'),1,
 'Exactly one private server-checked response appears');
select is((select count(*)::integer from jsonb_array_elements(
 public.exam_reference_drill_account_export()->'steps'
 ) as row(value) where row.value->>'responded'='false'
 and row.value->'is_correct'='null'::jsonb),1,
 'Skipped activity is distinct from graded correctness');
select throws_ok($q$
 select public.exam_reference_drill_account_export(2)
$q$,'54000',null,'Over-limit export fails rather than truncating');
select throws_ok($q$
 select public.exam_reference_drill_account_export(0)
$q$,'22023',null,'Invalid export bound is rejected');

-- Retiring a formerly published manifest cannot erase the learner's history.
reset role;
update public.exam_reference_manifest_revisions
  set publication_status='retired'
  where id='b3000000-0000-4000-8000-000000000016';
set local role authenticated;
select is((public.exam_reference_drill_account_export()->>'record_count')::integer,
 3,'Retired reference lists remain in private historical EXM export');

do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
  'b3000000-0000-4000-8000-000000000002',true);
end $jwt$;
select is((public.exam_reference_drill_account_export()->>'record_count')::integer,
 0,'Account B cannot access account A events/grades after retirement');

do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
  'b3000000-0000-4000-8000-000000000003',true);
 perform set_config('request.jwt.claims','{"is_anonymous":true}',true);
end $jwt$;
select throws_ok($q$
 select public.exam_reference_drill_account_export()
$q$,'42501',null,'Supabase Auth anonymous guest cannot request account archive');
reset role;
select * from finish();
rollback;
