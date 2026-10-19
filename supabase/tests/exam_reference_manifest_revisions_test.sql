begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(25);

select has_index('public','exam_reference_manifest_revisions','exam_manifest_lookup_idx',
  'Manifest date lookup is indexed');

select has_table('public','exam_reference_manifest_revisions',
  'EXM-01 manifests are independent of target versions');
select col_is_pk('public','exam_reference_manifest_revisions','id',
  'Manifest revision has immutable UUID identity');
select ok((select relrowsecurity from pg_class
  where oid='public.exam_reference_manifest_revisions'::regclass),
  'New public table has RLS enabled');
select ok(has_table_privilege('anon','public.exam_reference_manifest_revisions','SELECT'),
  'Guest reads explicitly granted');
select ok(not has_table_privilege('anon','public.exam_reference_manifest_revisions','INSERT'),
  'Guest cannot author source rules');
select ok(not has_table_privilege('authenticated','public.exam_reference_manifest_revisions','INSERT'),
  'Learner cannot publish source rules');
select ok(not has_table_privilege('authenticated','public.exam_reference_manifest_revisions','UPDATE'),
  'Learner cannot edit official rules');
select ok(not has_table_privilege('authenticated','public.exam_reference_manifest_revisions','DELETE'),
  'Learner cannot delete history');

select ok(public.exam_reference_manifest_payload_valid(
  '[{"key":"book_one","edition":"2027","source_page":"2"}]'::jsonb,
  '[{"name":"tabs","state":"unknown","value":null}]'::jsonb),
  'Allowed verified citation plus unknown room rule shape');
select ok(not public.exam_reference_manifest_payload_valid(
  '[{"key":"book_one","edition":"2027"}]'::jsonb,'[]'::jsonb),
  'Book edition must have a primary source page');
select ok(not public.exam_reference_manifest_payload_valid(
  '[{"key":"book_one","edition":"2027","source_page":"2"}]'::jsonb,
  '[{"name":"tabs","state":"verified","value":true}]'::jsonb),
  'Verified room rule must have its own page citation');

-- Disposable fictional source/target fixtures. No real regulator list is seeded.
insert into public.learning_targets
  (id,target_type,title,slug,status,is_public,is_official)
values
  ('01111111-1111-4111-8111-111111111111','licensure_exam',
  'Synthetic EXM-01 practice target','exm01-disposable-synthetic','published',true,false);

insert into public.target_versions
  (id,target_id,version_code,status,metadata)
values
  ('02222222-2222-4222-8222-222222222222',
   '01111111-1111-4111-8111-111111111111','synthetic-v1','published',
   '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"project_management","display_name":"Synthetic Project Management","curriculum_root_node_id":"03333333-3333-4333-8333-333333333333"}]}}'::jsonb);

insert into public.curriculum_nodes
  (id,target_version_id,node_type,title,sort_order)
values
  ('03333333-3333-4333-8333-333333333333',
   '02222222-2222-4222-8222-222222222222',
   'domain','Synthetic part',1);

insert into public.content_source_releases
  (id,publisher,title,version,source_url)
values
  ('04444444-4444-4444-8444-444444444444',
   'Fixture Test Authority','Synthetic release only','synthetic-2027',
   'https://example.org/fictional-2027-reference-list.pdf');

select lives_ok($q$
  insert into public.exam_reference_manifest_revisions
    (id,target_version_id,exam_part_key,revision,effective_from,
     effective_until,source_release_id,official_source_url,source_checked_at,
     author_ref,reference_entries,room_rules)
  values
    ('05555555-5555-4555-8555-555555555555',
     '02222222-2222-4222-8222-222222222222',
     'project_management',1,'2027-01-01','2027-12-31',
     '04444444-4444-4444-8444-444444444444',
     'https://example.org/fictional-2027-reference-list.pdf',now()-interval '1 day',
     'fixture-author',
     '[{"key":"book_one","edition":"synthetic-2027","source_page":"1"}]'::jsonb,
     '[{"name":"tabs","state":"unknown","value":null}]'::jsonb)
$q$, 'Draft reference revisions can be authored privately');

select throws_ok($q$
  update public.exam_reference_manifest_revisions
     set publication_status='published'
   where id='05555555-5555-4555-8555-555555555555'
$q$, '23514', null,
  'Unreviewed draft cannot publish despite usable dates');

select lives_ok($q$
  update public.exam_reference_manifest_revisions
     set reviewer_ref='qualified-independent-human',
         review_status='approved', reviewed_at=now(),
         publication_status='published'
   where id='05555555-5555-4555-8555-555555555555'
$q$, 'Reviewed, different-human, sourced revision can publish');

select throws_ok($q$
  update public.exam_reference_manifest_revisions
     set reference_entries='[]'::jsonb
   where id='05555555-5555-4555-8555-555555555555'
$q$, 'P0001', null,
  'Published payload is immutable');

select throws_ok($q$
  insert into public.exam_reference_manifest_revisions
    (id,target_version_id,exam_part_key,revision,effective_from,
     effective_until,source_release_id,official_source_url,source_checked_at,
     author_ref,reviewer_ref,reviewed_at,review_status,publication_status,
     reference_entries)
  values
    ('06666666-6666-4666-8666-666666666666',
     '02222222-2222-4222-8222-222222222222',
     'project_management',2,'2027-07-01','2028-01-01',
     '04444444-4444-4444-8444-444444444444',
     'https://example.org/fictional-2027-reference-list.pdf',now()-interval '1 day',
     'fixture-author','qualified-independent-human',now(),'approved','published',
     '[{"key":"book_one","edition":"synthetic-2027","source_page":"1"}]'::jsonb)
$q$, '23P01', null,
  'Overlapping published effective ranges are rejected');

select lives_ok($q$
  insert into public.exam_reference_manifest_revisions
    (id,target_version_id,exam_part_key,revision,effective_from,
     effective_until,source_release_id,official_source_url,source_checked_at,
     author_ref,reviewer_ref,reviewed_at,review_status,publication_status,
     reference_entries)
  values
    ('07777777-7777-4777-8777-777777777777',
     '02222222-2222-4222-8222-222222222222',
     'project_management',2,'2028-01-01','2028-12-31',
     '04444444-4444-4444-8444-444444444444',
     'https://example.org/fictional-2027-reference-list.pdf',now()-interval '1 day',
     'fixture-author','qualified-independent-human',now(),'approved','published',
     '[{"key":"book_one","edition":"synthetic-2028","source_page":"1"}]'::jsonb)
$q$, 'Adjacent time windows can use same curriculum target ID');

select throws_ok($q$
  insert into public.exam_reference_manifest_revisions
    (target_version_id,exam_part_key,revision,effective_from,
     source_release_id,official_source_url,source_checked_at,
     author_ref,reviewer_ref,reviewed_at,review_status,publication_status,
     reference_entries)
  values
    ('02222222-2222-4222-8222-222222222222',
     'not_a_real_part',1,'2029-01-01',
     '04444444-4444-4444-8444-444444444444',
     'https://example.org/fictional-2027-reference-list.pdf',now()-interval '1 day',
     'fixture-author','qualified-independent-human',now(),'approved','published',
     '[{"key":"book_one","edition":"synthetic-2029","source_page":"1"}]'::jsonb)
$q$, 'P0001', null,
  'Cannot publish a manifest for an unrecognized exam part');

select throws_ok($q$
  insert into public.exam_reference_manifest_revisions
    (target_version_id,exam_part_key,revision,effective_from,
     source_release_id,official_source_url,source_checked_at,
     author_ref,reviewer_ref,reviewed_at,review_status,publication_status,
     reference_entries)
  values
    ('02222222-2222-4222-8222-222222222222',
     'project_management',3,'2029-01-01',
     '04444444-4444-4444-8444-444444444444',
     'https://example.org/fictional-2027-reference-list.pdf',now()-interval '1 day',
     'same-person','same-person',now(),'approved','published',
     '[{"key":"book_one","edition":"synthetic-2029","source_page":"1"}]'::jsonb)
$q$, '23514', null,
  'Author of record and approving reviewer must differ');

select lives_ok($q$
  update public.exam_reference_manifest_revisions
     set publication_status='retired'
   where id='05555555-5555-4555-8555-555555555555'
$q$, 'Old revisions can be retired with a status-only transition');

select throws_ok($q$
  update public.exam_reference_manifest_revisions
     set publication_status='published'
   where id='05555555-5555-4555-8555-555555555555'
$q$, 'P0001', null,
  'Retired revision can never be resurrected');

select is(
  (select count(*)::integer from public.exam_reference_manifest_revisions
   where target_version_id='02222222-2222-4222-8222-222222222222'),
  2, 'Both historical and successor revisions keep their stable target ID');

-- RLS: readers see reviewed published row, not retired or drafts.
set local role anon;
select is(
  (select count(*)::integer from public.exam_reference_manifest_revisions
   where target_version_id='02222222-2222-4222-8222-222222222222'),
  1, 'Guest can see only active approved published revisions');
reset role;

select is(
  (select count(*)::integer from public.exam_reference_manifest_revisions
   where publication_status='retired'),
  1, 'Retired record remains in immutable history for administrator audit');

select * from finish();
rollback;
