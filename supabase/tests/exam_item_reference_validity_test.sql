begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(30);

select has_table('public','assessment_item_reference_validity',
  'Private answer-location review records exist');
select ok((select relrowsecurity from pg_class
    where oid='public.assessment_item_reference_validity'::regclass),
  'Private bindings enforce RLS');
select ok(not has_table_privilege('anon','public.assessment_item_reference_validity','SELECT'),
  'Guest cannot read answer locations');
select ok(not has_table_privilege('authenticated','public.assessment_item_reference_validity','SELECT'),
  'Learner cannot read answer keys or private reviewer evidence');
select ok(not has_table_privilege('authenticated','public.assessment_item_reference_validity','INSERT'),
  'Learner cannot approve answer locations');
select ok(not has_function_privilege('anon',
    'public.exam_reference_items_requiring_review(uuid,uuid)','EXECUTE'),
  'Unauthenticated clients cannot use the editorial review queue');
select ok(not has_function_privilege('authenticated',
    'public.exam_reference_items_requiring_review(uuid,uuid)','EXECUTE'),
  'Authenticated learners cannot use the editorial review queue');

select ok(public.exam_item_answer_locations_valid(
    '[{"section":"2.1","source_page":"11"}]'::jsonb),
  'Exact section and source page are accepted');
select ok(not public.exam_item_answer_locations_valid(
    '[{"section":"2.1"}]'::jsonb),
  'Missing answer page cannot be approved');
select ok(not public.exam_item_answer_locations_valid('[]'::jsonb),
  'Cannot publish a reference-location answer without a location');

-- Synthetic reference/test items only; transaction rolls everything back.
insert into public.learning_targets
  (id,target_type,title,slug,status,is_public,is_official)
values (
  '11111111-1111-4111-8111-111111111111','licensure_exam',
  'EXM-02A Synthetic Reference Pilot','exm02a-synthetic-pilot','published',true,false
);
insert into public.target_versions
  (id,target_id,version_code,status,metadata)
values (
  '22222222-2222-4222-8222-222222222222',
  '11111111-1111-4111-8111-111111111111',
  'synthetic-v1','published',
  '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"project_management","display_name":"Synthetic PM","curriculum_root_node_id":"33333333-3333-4333-8333-333333333333"}]}}'::jsonb
);
insert into public.curriculum_nodes
  (id,target_version_id,node_type,title,sort_order)
values (
  '33333333-3333-4333-8333-333333333333',
  '22222222-2222-4222-8222-222222222222','domain','Synthetic PM',1
);
insert into public.content_source_releases
  (id,publisher,title,version,source_url)
values
  ('44444444-4444-4444-8444-444444444444',
   'Synthetic authority','Synthetic reference list','2027-list',
   'https://example.gov/synthetic-list.pdf'),
  ('55555555-5555-4555-8555-555555555555',
   'Synthetic publisher','Synthetic Handbook','synthetic-2027',
   'https://example.org/synthetic-book-2027'),
  ('66666666-6666-4666-8666-666666666666',
   'Synthetic publisher','Synthetic Handbook','synthetic-2028',
   'https://example.org/synthetic-book-2028');

insert into public.exam_reference_manifest_revisions (
  id,target_version_id,exam_part_key,revision,effective_from,effective_until,
  source_release_id,official_source_url,source_checked_at,
  author_ref,reviewer_ref,reviewed_at,review_status,publication_status,
  reference_entries
) values
  ('77777777-7777-4777-8777-777777777777',
   '22222222-2222-4222-8222-222222222222',
   'project_management',1,'2027-01-01','2027-12-31',
   '44444444-4444-4444-8444-444444444444',
   'https://example.gov/synthetic-list.pdf',now()-interval '2 days',
   'human-author','independent-expert',now()-interval '1 day',
   'approved','published',
   '[{"key":"handbook","edition":"synthetic-2027","source_page":"2"}]'::jsonb),
  ('88888888-8888-4888-8888-888888888888',
   '22222222-2222-4222-8222-222222222222',
   'project_management',2,'2028-01-01','2028-12-31',
   '44444444-4444-4444-8444-444444444444',
   'https://example.gov/synthetic-list.pdf',now()-interval '2 days',
   'human-author','independent-expert',now()-interval '1 day',
   'approved','published',
   '[{"key":"handbook","edition":"synthetic-2028","source_page":"2"}]'::jsonb);

insert into public.assessment_items
  (id,origin_target_version_id,interaction_type,prompt,
   response_spec,scoring_spec)
values
  ('99999999-9999-4999-8999-999999999999',
   '22222222-2222-4222-8222-222222222222','single_choice',
   'Synthetic: which section supports the example?',
   '{"options":["2.1","3.4"]}'::jsonb,'{"correct_index":0}'::jsonb);

select lives_ok($q$
  insert into public.assessment_item_reference_validity (
    id,assessment_item_id,manifest_revision_id,
    item_content_revision,item_content_sha256,answer_location_revision,
    reference_edition_key,reference_edition,source_release_id,
    expected_locations,author_ref,ai_drafted
  ) values (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '99999999-9999-4999-8999-999999999999',
    '77777777-7777-4777-8777-777777777777',
    1,public.exam_reference_item_fingerprint('99999999-9999-4999-8999-999999999999'),1,'handbook','synthetic-2027',
    '55555555-5555-4555-8555-555555555555',
    '[{"chapter":"2","section":"2.1","source_page":"11"}]'::jsonb,
    'human-author',true
  )
$q$, 'AI-assisted draft may have a human author of record and no reviewer yet');

select is(
  (select item_content_sha256 = public.exam_reference_item_fingerprint(assessment_item_id)
   from public.assessment_item_reference_validity
   where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  true, 'Draft binds to a computed snapshot of real item prompt and scoring');

select throws_ok($q$
  insert into public.assessment_item_reference_validity (
    assessment_item_id,manifest_revision_id,
    item_content_revision,item_content_sha256,answer_location_revision,
    reference_edition_key,reference_edition,source_release_id,
    expected_locations,author_ref,ai_drafted,
    reviewer_ref,reviewer_qualification_evidence,reviewer_edition_access_evidence,
    review_status,rights_review_status,reviewed_at,review_minutes,
    publication_status
  ) values (
    '99999999-9999-4999-8999-999999999999',
    '77777777-7777-4777-8777-777777777777',
    1,repeat('b',64),2,'handbook','synthetic-2027',
    '55555555-5555-4555-8555-555555555555',
    '[{"section":"2.1","source_page":"11"}]'::jsonb,
    'human-author',false,
    'another-human','Synthetic qualifications reviewed',
    'Synthetic exact edition held',
    'approved','approved',now(),5,'published'
  )
$q$, 'P0001', null,
  'Fake content hashes cannot be published even with independent review');

select throws_ok($q$
  update public.assessment_item_reference_validity
    set publication_status='published'
    where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
$q$, 'P0001', null,
  'Draft cannot publish without independent review and rights approval');

select throws_ok($q$
  update public.assessment_item_reference_validity
    set reviewer_ref='human-author'
    where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
$q$, '23514', null, 'Self-review is explicitly forbidden');

select lives_ok($q$
  update public.assessment_item_reference_validity
    set reviewer_ref='qualified-independent-human',
        reviewer_qualification_evidence='Synthetic credentials checked',
        reviewer_edition_access_evidence='Synthetic edition access confirmed',
        review_status='approved',rights_review_status='approved',
        reviewed_at=now(),review_minutes=8,
        publication_status='published'
    where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
$q$, 'Recorded independent review can approve the exact 2027 edition');

select throws_ok($q$
  update public.assessment_item_reference_validity
    set reference_edition='changed-without-review'
    where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
$q$, 'P0001', null, 'Published answer location cannot silently change');

select throws_ok($q$
  update public.assessment_items
    set prompt='Changed after independent reviewer signed off'
    where id='99999999-9999-4999-8999-999999999999'
$q$, 'P0001', null, 'Published answer-item text cannot change without new identity');

select is(
 (select count(*)::integer from public.exam_reference_items_requiring_review(
   '77777777-7777-4777-8777-777777777777',
   '88888888-8888-4888-8888-888888888888')),
  1,'A new manifest requires re-review even when a reference title stays the same');

select lives_ok($q$
  insert into public.assessment_item_reference_validity (
    assessment_item_id,manifest_revision_id,
    item_content_revision,item_content_sha256,answer_location_revision,
    reference_edition_key,reference_edition,source_release_id,
    expected_locations,author_ref,ai_drafted
  ) values (
    '99999999-9999-4999-8999-999999999999',
    '88888888-8888-4888-8888-888888888888',
    1,public.exam_reference_item_fingerprint('99999999-9999-4999-8999-999999999999'),1,'handbook','synthetic-2028',
    '66666666-6666-4666-8666-666666666666',
    '[{"section":"2.1","source_page":"19"}]'::jsonb,
    'human-author',true
  )
$q$, 'New edition creates a separate draft binding without copying approval');

select is(
 (select count(*)::integer from public.exam_reference_items_requiring_review(
   '77777777-7777-4777-8777-777777777777',
   '88888888-8888-4888-8888-888888888888')),
  1,'Merely creating a new draft never clears its mandatory re-review queue');

select throws_ok($q$
  update public.assessment_item_reference_validity
    set reviewer_ref='other-human',
        reviewer_qualification_evidence='Synthetic credentials verified',
        reviewer_edition_access_evidence='Synthetic edition access verified',
        review_status='approved',rights_review_status='approved',
        reviewed_at=now(),review_minutes=9,
        publication_status='published',
        reference_edition='not-the-manifest-edition'
    where manifest_revision_id='88888888-8888-4888-8888-888888888888'
$q$, 'P0001', null, 'A new edition must exactly match its manifest');

select lives_ok($q$
  update public.assessment_item_reference_validity
    set reviewer_ref='other-human',
        reviewer_qualification_evidence='Synthetic credentials verified',
        reviewer_edition_access_evidence='Synthetic edition access verified',
        review_status='approved',rights_review_status='approved',
        reviewed_at=now(),review_minutes=9,
        publication_status='published'
    where manifest_revision_id='88888888-8888-4888-8888-888888888888'
$q$, 'Independently reviewed 2028 binding can publish after re-review');

select is(
 (select count(*)::integer from public.exam_reference_items_requiring_review(
   '77777777-7777-4777-8777-777777777777',
   '88888888-8888-4888-8888-888888888888')),
  0,'A new approved edition-specific binding clears the re-review queue');

select is(
 (select count(*)::integer from public.assessment_item_reference_validity
  where assessment_item_id='99999999-9999-4999-8999-999999999999'
    and publication_status='published'),
  2,'New edition approval preserves previously reviewed historical answer locations');

select throws_ok($q$
  update public.assessment_item_reference_validity
     set ai_drafted=false
   where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
$q$, 'P0001', null, 'AI provenance cannot be erased from published binding');

select lives_ok($q$
  update public.assessment_item_reference_validity
     set publication_status='retired'
   where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
$q$, 'Historical binding may be retired without editing its answer location');

select is(
 (select count(*)::integer from public.assessment_item_reference_validity
  where assessment_item_id='99999999-9999-4999-8999-999999999999'),
  2,'Retired historical answer binding remains recorded for audit');

select throws_ok($q$
  update public.assessment_item_reference_validity
     set publication_status='published'
   where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
$q$, 'P0001', null, 'Retired answer bindings cannot be resurrected');

select is(
 (select count(*)::integer from public.exam_reference_items_requiring_review(
   '77777777-7777-4777-8777-777777777777',
   '88888888-8888-4888-8888-888888888888')),
  0,'Retirement of prior binding does not invalidate separately approved new version');

select * from finish();
rollback;
