begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

-- 1. Table existence
select has_table('public', 'content_source_releases', 'content_source_releases table exists');
select has_table('public', 'content_source_mappings', 'content_source_mappings table exists');

-- 2. Column existence
select has_column('public', 'content_source_releases', 'publisher', 'content_source_releases has publisher');
select has_column('public', 'content_source_releases', 'version', 'content_source_releases has version');
select has_column('public', 'content_source_releases', 'sha256', 'content_source_releases has sha256');

select has_column('public', 'content_source_mappings', 'source_release_id', 'content_source_mappings has source_release_id');
select has_column('public', 'content_source_mappings', 'entity_type', 'content_source_mappings has entity_type');
select has_column('public', 'content_source_mappings', 'citation_location', 'content_source_mappings has citation_location');

-- 3. Insert and read as service_role
set local role service_role;

insert into public.content_source_releases (id, publisher, title, version, source_url, license, sha256)
values (
  '11111111-2222-3333-4444-555555555555',
  'CompTIA',
  'CompTIA Security+ Exam Objectives',
  'SY0-701',
  'https://www.comptia.org/certifications/security',
  'Educational Fair Use Reference',
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
);

select is(
  (select count(*)::integer from public.content_source_releases where id = '11111111-2222-3333-4444-555555555555'),
  1,
  'service_role can insert content_source_releases'
);

insert into public.learning_targets (id, slug, title, target_type, status, is_public)
values ('88888888-8888-8888-8888-888888888888', 'prov-test-target', 'Prov Test Target', 'certification', 'published', true)
on conflict do nothing;

insert into public.target_versions (id, target_id, version_code, status)
values ('77777777-7777-7777-7777-777777777777', '88888888-8888-8888-8888-888888888888', 'v1', 'published')
on conflict do nothing;

insert into public.curriculum_nodes (id, target_version_id, node_type, code, title, sort_order)
values ('99999999-9999-9999-9999-999999999999', '77777777-7777-7777-7777-777777777777', 'domain', 'D1', 'Domain 1', 1)
on conflict do nothing;

insert into public.content_source_mappings (
  source_release_id, entity_type, entity_id, relationship, citation_location
) values (
  '11111111-2222-3333-4444-555555555555',
  'curriculum_node',
  '99999999-9999-9999-9999-999999999999',
  'official_blueprint',
  'Domain 1.0 General Security Concepts'
);

select is(
  (select count(*)::integer from public.content_source_mappings where source_release_id = '11111111-2222-3333-4444-555555555555'),
  1,
  'service_role can insert content_source_mappings'
);

-- 4. Verify anonymous read access to provenance
set local role anon;

select is(
  (select count(*)::integer from public.content_source_releases where id = '11111111-2222-3333-4444-555555555555'),
  1,
  'anon can read content_source_releases'
);

select is(
  (select count(*)::integer from public.content_source_mappings where source_release_id = '11111111-2222-3333-4444-555555555555'),
  1,
  'anon can read content_source_mappings'
);

select * from finish();
rollback;
