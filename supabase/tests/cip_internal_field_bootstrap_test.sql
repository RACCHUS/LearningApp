-- CIP 2020 internal field bootstrap: idempotency, parentage, repeated titles,
-- edition isolation, fail-closed validation and client denial.
-- Fixtures use CIP series 98, which CIP 2020 does not define.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(30);

select has_function('public', 'bootstrap_cip_internal_fields', array['text'],
  'Bootstrap function exists');
select has_function('public', 'taxonomy_internal_coverage', array['text'],
  'Internal coverage report exists');
select ok(not has_function_privilege('anon', 'public.bootstrap_cip_internal_fields(text)', 'EXECUTE'),
  'Anonymous clients cannot bootstrap fields');
select ok(not has_function_privilege('authenticated', 'public.bootstrap_cip_internal_fields(text)', 'EXECUTE'),
  'Learners cannot bootstrap fields');
select ok(has_function_privilege('service_role', 'public.bootstrap_cip_internal_fields(text)', 'EXECUTE'),
  'Service role can bootstrap fields');
select ok(has_function_privilege('anon', 'public.taxonomy_internal_coverage(text)', 'EXECUTE'),
  'Coverage of public taxonomy data is readable');
select throws_ok($$select public.bootstrap_cip_internal_fields('2030')$$, '22023', null,
  'Later CIP editions are never bootstrapped into duplicate fields');

-- Fixture: a curated broad field already mapped to series 98, plus an unrelated
-- native field whose name equals the repeated CIP title.
insert into public.external_classification_nodes
  (id, source_release_id, system, version, code, source_parent_code, level_code, level_depth, title, definition)
values
  ('98000000-0000-0000-0000-000000000098', 'a1000000-0000-0000-0000-000000000001',
   'cip', '2020', '98', null, 'series', 1, 'FIXTURE STUDIES.', 'Fixture series.'),
  ('98000000-0000-0000-0000-000000009801', 'a1000000-0000-0000-0000-000000000001',
   'cip', '2020', '98.01', '98', 'group', 2, 'Fixture Studies, General.', 'Fixture group.'),
  ('98000000-0000-0000-0000-000000009802', 'a1000000-0000-0000-0000-000000000001',
   'cip', '2020', '98.02', '98', 'group', 2, 'Applied Fixtures.', 'Second fixture group.'),
  ('98000000-0000-0000-0000-000098010100', 'a1000000-0000-0000-0000-000000000001',
   'cip', '2020', '98.0101', '98.01', 'program', 3, 'Fixture Studies, General.', 'Fixture program.');
update public.external_classification_nodes c
set parent_id = p.id
from public.external_classification_nodes p
where c.system = 'cip' and c.version = '2020' and c.code like '98.%'
  and p.system = 'cip' and p.version = '2020' and p.code = c.source_parent_code;

insert into public.fields (id, name, slug, field_kind, sort_order)
values
  ('98f00000-0000-0000-0000-000000000098', 'Fixture Studies', 'fixture-studies-curated', 'broad_field', 98),
  ('98f00000-0000-0000-0000-0000000000aa', 'Fixture Studies, General', 'fixture-studies-general', 'native_field', 0);
insert into public.field_external_classifications (field_id, classification_node_id, mapping_type)
values ('98f00000-0000-0000-0000-000000000098', '98000000-0000-0000-0000-000000000098', 'exact_match');

select lives_ok($$select public.bootstrap_cip_internal_fields('2020')$$,
  'Bootstrap succeeds on a valid hierarchy');

create temp table fixture_fields as
select n.code, f.id, f.parent_id, f.field_kind, f.name, f.slug
from public.external_classification_nodes n
join public.field_external_classifications fec
  on fec.classification_node_id = n.id and fec.mapping_type = 'exact_match'
join public.fields f on f.id = fec.field_id
where n.system = 'cip' and n.version = '2020' and n.code in ('98', '98.01', '98.02', '98.0101');

select is((select count(*)::integer from fixture_fields), 4,
  'Every fixture node has exactly one internal field');
select is((select id from fixture_fields where code = '98'), '98f00000-0000-0000-0000-000000000098'::uuid,
  'Existing curated broad field ID is reused, not regenerated');
select is((select field_kind from fixture_fields where code = '98.01'), 'subfield',
  'CIP groups become subfields');
select is((select field_kind from fixture_fields where code = '98.0101'), 'program_classification',
  'CIP programs become program classifications');
select is((select parent_id from fixture_fields where code = '98.01'), '98f00000-0000-0000-0000-000000000098'::uuid,
  'Subfields are parented by their series broad field');
select is((select parent_id from fixture_fields where code = '98.0101'),
  (select id from fixture_fields where code = '98.01'),
  'Program fields are parented by their group subfield');
select isnt((select id from fixture_fields where code = '98.01'), (select id from fixture_fields where code = '98.0101'),
  'Repeated group/program titles produce distinct fields');
select is((select name from fixture_fields where code = '98.0101'), 'Fixture Studies, General',
  'Field names drop the CIP trailing period');
select is((select slug from fixture_fields where code = '98.0101'), 'fixture-studies-general-cip-98-0101',
  'Generated slugs are code-qualified');
select is((select count(*)::integer from public.field_external_classifications
           where field_id = '98f00000-0000-0000-0000-0000000000aa'), 0,
  'Same-named native field is never merged on title');

-- Idempotent rerun keeps every ID.
select is((public.bootstrap_cip_internal_fields('2020')->>'created_total')::integer, 0,
  'Rerun creates nothing');
select is((select count(*)::integer from fixture_fields ff
           join public.field_external_classifications fec on fec.field_id = ff.id
           join public.external_classification_nodes n on n.id = fec.classification_node_id
           where n.code = ff.code and n.system = 'cip' and n.version = '2020'), 4,
  'Rerun preserves every internal field ID');

-- Source-edition isolation: a CIP 2030 node is not bootstrapped by the 2020 run.
insert into public.external_classification_nodes
  (id, source_release_id, system, version, code, level_code, level_depth, title)
values ('98000000-0000-0000-0000-203098010100', 'a1000000-0000-0000-0000-000000000001',
        'cip', '2030', '98.0101', 'program', 3, 'Fixture Studies, General.');
select lives_ok($$select public.bootstrap_cip_internal_fields('2020')$$,
  'CIP 2020 run ignores other editions');
select is((select count(*)::integer from public.field_external_classifications
           where classification_node_id = '98000000-0000-0000-0000-203098010100'), 0,
  'CIP 2030 node gets no automatically duplicated field');

-- Coverage separates internal mapping from import counts.
select is((public.taxonomy_internal_coverage('2020')#>>'{levels,group,unmapped}')::integer, 0,
  'Coverage reports no unmapped groups after bootstrap');
select is((public.taxonomy_internal_coverage('2020')#>>'{levels,program,unmapped}')::integer, 0,
  'Coverage reports no unmapped programs after bootstrap');

-- Fail closed: a new program whose external parent is missing.
insert into public.external_classification_nodes
  (id, source_release_id, system, version, code, source_parent_code, level_code, level_depth, title)
values ('98000000-0000-0000-0000-000098990100', 'a1000000-0000-0000-0000-000000000001',
        'cip', '2020', '98.9901', '98.99', 'program', 3, 'Broken Fixture.');
select throws_ok($$select public.bootstrap_cip_internal_fields('2020')$$, 'P0001', null,
  'Broken external parents fail closed');
select is((select count(*)::integer from public.fields where slug like 'broken-fixture-cip-%'), 0,
  'No orphan field is created for a broken parent');
select is((public.taxonomy_internal_coverage('2020')#>>'{levels,program,unmapped}')::integer, 1,
  'Coverage reports the unmapped broken program');
select is((public.taxonomy_internal_coverage('2020')->>'complete')::boolean, false,
  'Coverage is not complete while a node is unmapped');
delete from public.external_classification_nodes where id = '98000000-0000-0000-0000-000098990100';

-- Fail closed: ambiguous exact mapping.
insert into public.field_external_classifications (field_id, classification_node_id, mapping_type)
values ('98f00000-0000-0000-0000-0000000000aa', '98000000-0000-0000-0000-000000009801', 'exact_match');
select throws_ok($$select public.bootstrap_cip_internal_fields('2020')$$, 'P0001', null,
  'Ambiguous exact mappings fail closed');
delete from public.field_external_classifications
where field_id = '98f00000-0000-0000-0000-0000000000aa';

-- Fail closed: never merge into an existing unmapped field by slug.
insert into public.external_classification_nodes
  (id, source_release_id, system, version, code, source_parent_code, parent_id, level_code, level_depth, title)
values ('98000000-0000-0000-0000-000098020100', 'a1000000-0000-0000-0000-000000000001',
        'cip', '2020', '98.0201', '98.02', '98000000-0000-0000-0000-000000009802',
        'program', 3, 'Applied Fixtures.');
insert into public.fields (name, slug, field_kind)
values ('Squatter', 'applied-fixtures-cip-98-0201', 'native_field');
select throws_ok($$select public.bootstrap_cip_internal_fields('2020')$$, 'P0001', null,
  'Slug collisions are refused rather than merged');

select * from finish();
rollback;
