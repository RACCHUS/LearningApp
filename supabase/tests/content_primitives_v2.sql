begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(16);

-- 1. Table existence
select has_table('public', 'lesson_blocks', 'lesson_blocks table exists');
select has_table('public', 'assessment_stimuli', 'assessment_stimuli table exists');
select has_table('public', 'assessment_items', 'assessment_items table exists');
select has_table('public', 'assessment_item_concepts', 'assessment_item_concepts table exists');
select has_table('public', 'target_version_concept_mappings', 'target_version_concept_mappings table exists');

-- 2. TargetVersion status includes review_ready
select has_column('public', 'target_versions', 'status', 'target_versions has status column');

set local role service_role;

-- 3. Verify inserting review_ready version
insert into public.target_versions (
  id, target_id, version_code, title, status
) values (
  '88888888-0000-0000-0000-000000000001',
  (select id from public.learning_targets limit 1),
  'v-test-review-ready',
  'Review Ready Target Version Test',
  'review_ready'
);

select is(
  (select status from public.target_versions where id = '88888888-0000-0000-0000-000000000001'),
  'review_ready',
  'target_versions accepts review_ready status'
);

-- 4. Verify lesson_blocks insertion
insert into public.lessons (
  id, title, visibility
) values (
  '88888888-0000-0000-0000-000000000000',
  'Test Lesson for Primitives',
  'public'
);

insert into public.lesson_blocks (
  id, lesson_id, sort_order, block_type, content
) values (
  '88888888-0000-0000-0000-000000000002',
  '88888888-0000-0000-0000-000000000000',
  1,
  'markdown',
  '{"markdown": "# Test Instructional Section"}'::jsonb
);

select is(
  (select count(*)::integer from public.lesson_blocks where id = '88888888-0000-0000-0000-000000000002'),
  1,
  'service_role can insert lesson_blocks'
);

-- 5. Verify assessment_stimuli insertion
insert into public.assessment_stimuli (
  id, stimulus_type, title, body
) values (
  '88888888-0000-0000-0000-000000000003',
  'clinical_case',
  'Patient Case: 58-year-old female',
  'Patient presents with acute chest pain...'
);

select is(
  (select count(*)::integer from public.assessment_stimuli where id = '88888888-0000-0000-0000-000000000003'),
  1,
  'service_role can insert assessment_stimuli'
);

-- 6. Verify assessment_items insertion with stimulus
insert into public.assessment_items (
  id, stimulus_id, interaction_type, prompt, response_spec, scoring_spec
) values (
  '88888888-0000-0000-0000-000000000004',
  '88888888-0000-0000-0000-000000000003',
  'multi_select',
  'Which two medications are immediately indicated? (Select two)',
  '{"options": ["Aspirin", "Metformin", "Nitroglycerin", "Warfarin"]}'::jsonb,
  '{"correctIndices": [0, 2], "scoring": "all_or_nothing"}'::jsonb
);

select is(
  (select count(*)::integer from public.assessment_items where id = '88888888-0000-0000-0000-000000000004'),
  1,
  'service_role can insert multi_select assessment_items with stimulus'
);

-- 7. Insert test concept & verify canonical concept resolver function
insert into public.knowledge_concepts (
  id, name, slug, aliases, description, status
) values (
  '88888888-0000-0000-0000-000000000005',
  'Canonical Hash Table',
  'canonical-hash-table',
  array['hash-map', 'hash_tables', 'hash-tables'],
  'Core associative key-value lookup data structure.',
  'active'
);

-- 8. Verify assessment_item_concepts
insert into public.assessment_item_concepts (
  assessment_item_id, concept_id, role
) values (
  '88888888-0000-0000-0000-000000000004',
  '88888888-0000-0000-0000-000000000005',
  'primary'
);

select is(
  (select count(*)::integer from public.assessment_item_concepts where assessment_item_id = '88888888-0000-0000-0000-000000000004'),
  1,
  'service_role can link assessment_item_concepts'
);

-- Match by exact slug
select is(
  (select match_type from public.resolve_canonical_concept('canonical-hash-table')),
  'exact_slug',
  'resolve_canonical_concept matches exact slug'
);

-- Match by slug alias
select is(
  (select match_type from public.resolve_canonical_concept('hash-tables')),
  'slug_alias',
  'resolve_canonical_concept matches slug alias'
);

-- Match by exact name
select is(
  (select match_type from public.resolve_canonical_concept('unknown-slug', 'Canonical Hash Table')),
  'exact_name',
  'resolve_canonical_concept matches exact name'
);

-- Match by name alias
select is(
  (select match_type from public.resolve_canonical_concept('unknown-slug', 'hash-map')),
  'name_alias',
  'resolve_canonical_concept matches name alias'
);

-- 9. Anonymous read verification
set local role anon;

select is(
  (select count(*)::integer from public.assessment_stimuli where id = '88888888-0000-0000-0000-000000000003'),
  1,
  'anonymous users can read public assessment_stimuli'
);

rollback;
