begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(19);

select has_table('public','exam_reference_drill_attempts',
  'Durable attempts use a separate owner-scoped evidence table');
select ok((select relrowsecurity from pg_class
    where oid='public.exam_reference_drill_attempts'::regclass),
  'Attempts enforce RLS');
select ok(not has_table_privilege('anon','public.exam_reference_drill_attempts','SELECT'),
  'Guests cannot read private attempt history');
select ok(has_table_privilege('authenticated','public.exam_reference_drill_attempts','SELECT'),
  'Signed-in learners can read their own history');
select ok(has_table_privilege('authenticated','public.exam_reference_drill_attempts','DELETE'),
  'Owners can request deletion directly');
select ok(not has_table_privilege('authenticated','public.exam_reference_drill_attempts','INSERT'),
  'Browser clients cannot forge server-verified scores');
select ok(not has_table_privilege('authenticated','public.exam_reference_drill_attempts','UPDATE'),
  'Browser clients cannot edit scoring history');

-- Entirely synthetic, transaction-rolled-back source, learner and book.
insert into auth.users(id,email) values
 ('a1000000-0000-4000-8000-000000000001','exm-02b-a@example.org'),
 ('b2000000-0000-4000-8000-000000000002','exm-02b-b@example.org');

insert into public.learning_targets
  (id,target_type,title,slug,status,is_public,is_official)
values (
 'c3000000-0000-4000-8000-000000000003','licensure_exam',
 'Synthetic EXM-02B Goal','exm02b-disposable-synthetic','published',true,false
);
insert into public.target_versions
  (id,target_id,version_code,status,metadata)
values (
 'c4000000-0000-4000-8000-000000000004',
 'c3000000-0000-4000-8000-000000000003','synthetic-2027',
 'published',
 '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"project_management","display_name":"Synthetic PM","curriculum_root_node_id":"c5000000-0000-4000-8000-000000000005"}]}}'::jsonb
);
insert into public.curriculum_nodes
  (id,target_version_id,node_type,title,sort_order)
values (
 'c5000000-0000-4000-8000-000000000005',
 'c4000000-0000-4000-8000-000000000004','domain','Fictional Root',1
);
insert into public.content_source_releases
  (id,publisher,title,version,source_url)
values
 ('c6000000-0000-4000-8000-000000000006',
   'Example regulator','Fictional exam reference list','fictional-list-v1',
   'https://example.gov/fake-exam-list.pdf'),
 ('c7000000-0000-4000-8000-000000000007',
   'Example publisher','Fictional Handbook','synthetic-2027',
   'https://example.org/fake-handbook');

insert into public.exam_reference_manifest_revisions (
  id,target_version_id,exam_part_key,revision,effective_from,effective_until,
  source_release_id,official_source_url,source_checked_at,
  author_ref,reviewer_ref,reviewed_at,review_status,publication_status,
  reference_entries
) values (
 'c8000000-0000-4000-8000-000000000008',
 'c4000000-0000-4000-8000-000000000004','project_management',
 1,'2027-01-01','2027-12-31',
 'c6000000-0000-4000-8000-000000000006',
 'https://example.gov/fake-exam-list.pdf',
 now()-interval '2 days','example-human-author','example-human-reviewer',
 now()-interval '1 day','approved','published',
 '[{"key":"fictional_handbook","edition":"synthetic-2027","source_page":"1"}]'::jsonb
);
insert into public.assessment_items
  (id,origin_target_version_id,interaction_type,prompt,
   response_spec,scoring_spec)
values (
 'c9000000-0000-4000-8000-000000000009',
 'c4000000-0000-4000-8000-000000000004',
 'single_choice','Synthetic training example for 2027',
 '{"options":["A","B"]}'::jsonb,'{"correct_index":0}'::jsonb
);
insert into public.assessment_item_reference_validity (
  id,assessment_item_id,manifest_revision_id,
  item_content_revision,item_content_sha256,answer_location_revision,
  reference_edition_key,reference_edition,source_release_id,
  expected_locations,author_ref,ai_drafted,
  reviewer_ref,reviewer_qualification_evidence,
  reviewer_edition_access_evidence,
  rights_review_status,review_status,publication_status,reviewed_at,review_minutes
) values (
 'ca000000-0000-4000-8000-00000000000a',
 'c9000000-0000-4000-8000-000000000009',
 'c8000000-0000-4000-8000-000000000008',
 1,public.exam_reference_item_fingerprint(
   'c9000000-0000-4000-8000-000000000009'),1,
 'fictional_handbook','synthetic-2027',
 'c7000000-0000-4000-8000-000000000007',
 '[{"section":"2.1","source_page":"10"}]'::jsonb,
 'example-human-author',false,'example-independent-reviewer',
 'Synthetic review qualification only',
 'Fictional exact edition evidence',
 'approved','approved','published',now(),4
);

select lives_ok($sql$
  insert into public.exam_reference_drill_attempts (
    id,owner_auth_user_id,client_attempt_key,step_ordinal,
    target_version_id,exam_part_key,intended_exam_date,
    manifest_revision_id,answer_binding_id,assessment_item_id,
    item_content_revision,answer_location_revision,drill_mode,skill_step,
    scoring_version,scored_correct,app_elapsed_ms,
    physical_book_self_reported_minutes,started_at,completed_at
  ) values (
    'cb000000-0000-4000-8000-00000000000b',
    'a1000000-0000-4000-8000-000000000001',
    'cc000000-0000-4000-8000-00000000000c',1,
    'c4000000-0000-4000-8000-000000000004',
    'project_management','2027-03-10',
    'c8000000-0000-4000-8000-000000000008',
    'ca000000-0000-4000-8000-00000000000a',
    'c9000000-0000-4000-8000-000000000009',
    1,1,'r1','choose_reference','synthetic-v1',true,25000,5,
    now()-interval '1 minute',now()
  )
$sql$, 'Trusted writer can record version-pinned practice evidence');

select is((select app_elapsed_ms from public.exam_reference_drill_attempts
    where id='cb000000-0000-4000-8000-00000000000b'),
  25000, 'App-observed time is stored independently of physical book time');
select is((select physical_book_self_reported_minutes
    from public.exam_reference_drill_attempts
    where id='cb000000-0000-4000-8000-00000000000b'),
  5, 'Physical book time is only self-reported evidence');

select throws_ok($sql$
  insert into public.exam_reference_drill_attempts (
    owner_auth_user_id,client_attempt_key,step_ordinal,target_version_id,
    exam_part_key,intended_exam_date,manifest_revision_id,answer_binding_id,
    assessment_item_id,item_content_revision,answer_location_revision,
    drill_mode,skill_step,scoring_version,scored_correct,app_elapsed_ms,
    started_at,completed_at
  )
  select owner_auth_user_id,client_attempt_key,step_ordinal,target_version_id,
    exam_part_key,intended_exam_date,manifest_revision_id,answer_binding_id,
    assessment_item_id,item_content_revision,answer_location_revision,
    drill_mode,skill_step,scoring_version,scored_correct,app_elapsed_ms,
    started_at,completed_at
  from public.exam_reference_drill_attempts
  where id='cb000000-0000-4000-8000-00000000000b'
$sql$, '23505', null, 'Retries cannot duplicate the same owner+session+step');

select throws_ok($sql$
  update public.exam_reference_drill_attempts
    set scored_correct=false
    where id='cb000000-0000-4000-8000-00000000000b'
$sql$, 'P0001', null, 'Verified attempt rows are immutable');

select throws_ok($sql$
  insert into public.exam_reference_drill_attempts (
    owner_auth_user_id,client_attempt_key,step_ordinal,target_version_id,
    exam_part_key,intended_exam_date,manifest_revision_id,answer_binding_id,
    assessment_item_id,item_content_revision,answer_location_revision,
    drill_mode,skill_step,scoring_version,scored_correct,app_elapsed_ms,
    started_at,completed_at
  )
  select owner_auth_user_id,
    'cd000000-0000-4000-8000-00000000000d'::uuid,
    1,target_version_id,
    exam_part_key,'2026-03-10'::date,manifest_revision_id,answer_binding_id,
    assessment_item_id,item_content_revision,answer_location_revision,
    drill_mode,skill_step,scoring_version,scored_correct,app_elapsed_ms,
    started_at,completed_at
  from public.exam_reference_drill_attempts
  where id='cb000000-0000-4000-8000-00000000000b'
$sql$, 'P0001', null, 'Wrong exam administration year cannot claim 2027 source');

select throws_ok($sql$
  insert into public.exam_reference_drill_attempts (
    owner_auth_user_id,client_attempt_key,step_ordinal,target_version_id,
    exam_part_key,intended_exam_date,manifest_revision_id,answer_binding_id,
    assessment_item_id,item_content_revision,answer_location_revision,
    drill_mode,skill_step,scoring_version,scored_correct,app_elapsed_ms,
    started_at,completed_at
  )
  select owner_auth_user_id,
    'ce000000-0000-4000-8000-00000000000e'::uuid,
    1,target_version_id,
    exam_part_key,intended_exam_date,manifest_revision_id,answer_binding_id,
    assessment_item_id,item_content_revision,answer_location_revision,
    'r1','interpret',scoring_version,scored_correct,app_elapsed_ms,
    started_at,completed_at
  from public.exam_reference_drill_attempts
  where id='cb000000-0000-4000-8000-00000000000b'
$sql$, '23514', null, 'R1 must only be used for reference selection');

set local role authenticated;
select set_config('request.jwt.claim.sub',
 'a1000000-0000-4000-8000-000000000001',true);
select is((select count(*)::integer from public.exam_reference_drill_attempts),
  1,'Owner A sees exactly their own attempt');

select set_config('request.jwt.claim.sub',
 'b2000000-0000-4000-8000-000000000002',true);
select is((select count(*)::integer from public.exam_reference_drill_attempts),
  0,'Owner B cannot see account A attempts');
select is((with deleted as (
  delete from public.exam_reference_drill_attempts
  returning id
) select count(*)::integer from deleted),
  0,'Owner B cannot delete account A history');

select set_config('request.jwt.claim.sub',
 'a1000000-0000-4000-8000-000000000001',true);
select is((with deleted as (
  delete from public.exam_reference_drill_attempts
  returning id
) select count(*)::integer from deleted),
  1,'Owner A can delete their private drill history');
reset role;

select is((select count(*)::integer from public.exam_reference_drill_attempts),
  0,'Deleted practice evidence is not retained after user-directed deletion');

select * from finish();
rollback;
