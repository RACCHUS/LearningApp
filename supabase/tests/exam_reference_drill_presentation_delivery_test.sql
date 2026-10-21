begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(21);

select has_table('public','exam_reference_drill_presentations',
  'Original approved practice presentations are stored privately');
select ok(not has_table_privilege('authenticated',
  'public.exam_reference_drill_presentations','SELECT'),
  'Learners cannot read unpublished presentations');
select ok(not has_function_privilege('anon',
  'public.get_exam_reference_drill_practice(uuid,text,date)','EXECUTE'),
  'Unregistered/anonymous API cannot call practice projection');
select ok(has_function_privilege('authenticated',
  'public.get_exam_reference_drill_practice(uuid,text,date)','EXECUTE'),
  'Signed-in learner may call the server-reviewed practice projection');
select ok(public.exam_reference_drill_steps_valid(
  '{"resource_choice":{"prompt":"Which fictional handbook is most relevant for this example?","choices":[{"value":"another_book","label":"Other Fictional Book"},{"value":"example_book","label":"Example Fictional Book"}]},"section_location":{"prompt":"Which fictional section contains the rule needed for this practice?","choices":[{"value":"1.2","label":"Section 1.2"},{"value":"1.1","label":"Section 1.1"}]},"interpretation":{"prompt":"Does the fictional rule apply to the described case?","choices":[{"value":"no","label":"No"},{"value":"yes","label":"Yes"}]},"application":{"prompt":"Choose the best fictional answer to finish the case.","choices":[{"value":"a","label":"Answer A"},{"value":"b","label":"Answer B"}]}}'::jsonb
), 'Four original prompts and answer options validate');
select ok(not public.exam_reference_drill_steps_valid(
  '{"resource_choice":{"prompt":"too short","choices":[]}}'::jsonb
), 'Incomplete or invalid prompt content cannot be published');

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


insert into public.exam_reference_drill_presentations(
 id,scoring_key_id,presentation_revision,steps,author_ref,ai_drafted
) values (
 'b3000000-0000-4000-8000-000000000071',
 'b3000000-0000-4000-8000-000000000019',1,
 '{"resource_choice":{"prompt":"Which fictional handbook is most relevant for this example?","choices":[{"value":"another_book","label":"Other Fictional Book"},{"value":"example_book","label":"Example Fictional Book"}]},"section_location":{"prompt":"Which fictional section contains the rule needed for this practice?","choices":[{"value":"1.2","label":"Section 1.2"},{"value":"1.1","label":"Section 1.1"}]},"interpretation":{"prompt":"Does the fictional rule apply to the described case?","choices":[{"value":"no","label":"No"},{"value":"yes","label":"Yes"}]},"application":{"prompt":"Choose the best fictional answer to finish the case.","choices":[{"value":"a","label":"Answer A"},{"value":"b","label":"Answer B"}]}}'::jsonb,
 'original-human-author',true
);
select throws_ok($q$
 update public.exam_reference_drill_presentations
 set publication_status='published'
 where id='b3000000-0000-4000-8000-000000000071'
$q$, 'P0001',null,'Unreviewed original questions cannot be published');
select lives_ok($q$
 update public.exam_reference_drill_presentations
 set reviewer_ref='independent-prompt-reviewer',
 reviewer_qualification_evidence='fictional code-book reviewer',
 reviewer_edition_access_evidence='fictional book edition in hand',
 rights_review_status='approved',review_status='approved',
 reviewed_at=now(),review_minutes=12,publication_status='published'
 where id='b3000000-0000-4000-8000-000000000071'
$q$, 'Independently reviewed original prompt set may publish');
select throws_ok($q$
 update public.exam_reference_drill_presentations
 set steps='{}'::jsonb
 where id='b3000000-0000-4000-8000-000000000071'
$q$, 'P0001',null,'Published original prompts cannot be rewritten');

set local role authenticated;
do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
 'b3000000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"is_anonymous":false}',true);
end $jwt$;

select throws_ok($q$
 select * from public.exam_reference_drill_presentations
$q$, '42501',null,'Learner cannot bypass projection to read review records');

select ok(
 public.get_exam_reference_drill_practice(
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-06-01') is not null,
 'Permanent account gets reviewed practice for an applicable exam date');
select is(
 public.get_exam_reference_drill_practice(
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2026-12-31'), null::jsonb,
 '2026 exam cannot access edition-specific 2027 practice');
select is(
 public.get_exam_reference_drill_practice(
 'b3000000-0000-4000-8000-000000000016',
 'wrong_part','2027-06-01'), null::jsonb,
 'A different part cannot inherit a reviewed practice prompt');
select ok(
 (public.get_exam_reference_drill_practice(
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-06-01') -> 'steps'
 -> 'resource_choice' -> 'choices') @>
 '[{"value":"example_book"}]'::jsonb,
 'The delivery contains safe reviewed prompts and answer options');
select ok(
 not (public.get_exam_reference_drill_practice(
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-06-01') ? 'step_tokens'),
 'Private rubric tokens are not delivered as a top-level field');
select ok(
 not (public.get_exam_reference_drill_practice(
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-06-01') ? 'scoring_spec'),
 'Internal assessment scoring_spec never crosses the delivery boundary');
select ok(
 not (public.get_exam_reference_drill_practice(
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-06-01') ? 'reviewer_ref'),
 'Editorial reviewer evidence is absent from learner projection');

do $jwt$ begin
 perform set_config('request.jwt.claim.sub',
 'b3000000-0000-4000-8000-000000000003',true);
 perform set_config('request.jwt.claims','{"is_anonymous":true}',true);
end $jwt$;
select throws_ok($q$
 select public.get_exam_reference_drill_practice(
 'b3000000-0000-4000-8000-000000000016',
 'project_management','2027-06-01')
$q$,'42501',null,'Supabase anonymous auth guests cannot receive private drills');

reset role;
select * from finish();
rollback;
