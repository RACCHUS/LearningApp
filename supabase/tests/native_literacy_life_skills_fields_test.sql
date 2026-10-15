begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

select is(
  (select title from public.catalog_clusters where slug = 'cluster_life_milestones'),
  'Life Milestones & Survival Literacy',
  'Life milestones cluster is available in the database'
);
select ok(
  (select is_active from public.catalog_clusters where slug = 'cluster_life_milestones'),
  'Life milestones cluster is active'
);
select is(
  (select sort_order from public.catalog_clusters where slug = 'cluster_life_milestones'),
  13,
  'Life milestones cluster follows the existing twelve clusters'
);
select ok(
  (select count(*) >= 13 from public.catalog_clusters where is_active),
  'All existing clusters remain and the new cluster is added'
);

select is(
  (select count(*)::integer from public.fields
   where slug in ('foundational-literacy', 'civic-and-community-literacy', 'practical-life-skills')
     and parent_id is null and field_kind = 'native_field' and is_active),
  3,
  'Three active native-field roots are present'
);
select is(
  (select count(*)::integer from public.fields
   where slug in (
     'phonics-and-word-decoding',
     'supported-reading-and-comprehension',
     'oral-language-and-listening',
     'adult-basic-education-reading',
     'civics-and-naturalization-preparation',
     'driver-safety-and-license-preparation',
     'cash-and-atm-practice',
     'health-literacy-and-first-aid',
     'food-safety',
     'workplace-safety'
   )
     and field_kind = 'native_field' and is_active),
  10,
  'Ten active native-field subfields are present'
);
select is(
  (select count(*)::integer from public.fields
   where metadata->>'taxonomy_origin' = 'learningapp_authored'
     and field_kind = 'native_field' and is_active),
  13,
  'All thirteen fields are identified as LearningApp-authored'
);
select is(
  (select count(*)::integer from public.fields
   where slug in ('foundational-literacy', 'civic-and-community-literacy', 'practical-life-skills')
     and parent_id is null),
  3,
  'Native roots remain separate from external classification parents'
);
select is(
  (select count(*)::integer from public.fields child
   join public.fields parent on parent.id = child.parent_id
   where parent.slug = 'foundational-literacy' and child.is_active),
  4,
  'Foundational literacy has four child fields'
);
select is(
  (select count(*)::integer from public.fields child
   join public.fields parent on parent.id = child.parent_id
   where parent.slug = 'civic-and-community-literacy' and child.is_active),
  2,
  'Civic and community literacy has two child fields'
);
select is(
  (select count(*)::integer from public.fields child
   join public.fields parent on parent.id = child.parent_id
   where parent.slug = 'practical-life-skills' and child.is_active),
  4,
  'Practical life skills has four child fields'
);
select is(
  (select count(*)::integer from public.catalog_cluster_fields ccf
   join public.catalog_clusters cc on cc.id = ccf.cluster_id
   join public.fields f on f.id = ccf.field_id
   where cc.slug = 'cluster_life_milestones'
     and f.slug in ('foundational-literacy', 'civic-and-community-literacy', 'practical-life-skills')),
  3,
  'All three native roots are discoverable through the catalog cluster'
);
select is(
  (select count(*)::integer from public.fields
   where metadata->>'taxonomy_origin' = 'learningapp_authored'
     and description is not null and btrim(description) <> ''),
  13,
  'Every native field has a non-empty description'
);

select is(
  (select count(*)::integer from public.concept_fields cf
   join public.knowledge_concepts c on c.id = cf.concept_id
   where c.id in (
     'b1000000-0000-0000-0000-000000000001',
     'b1000000-0000-0000-0000-000000000002',
     'b1000000-0000-0000-0000-000000000003',
     'b1000000-0000-0000-0000-000000000004',
     'b1000000-0000-0000-0000-000000000005',
     'b1000000-0000-0000-0000-000000000006'
   )),
  6,
  'Existing sample concepts have explicit concept-field links'
);
select ok(
  not exists (
    select 1
    from public.concept_fields cf
    join public.knowledge_concepts c on c.id = cf.concept_id
    where c.id in (
      'b1000000-0000-0000-0000-000000000001',
      'b1000000-0000-0000-0000-000000000002',
      'b1000000-0000-0000-0000-000000000003',
      'b1000000-0000-0000-0000-000000000004',
      'b1000000-0000-0000-0000-000000000005',
      'b1000000-0000-0000-0000-000000000006'
    )
      and cf.field_id <> c.field_id
  ),
  'Concept-field links preserve each concept existing field placement'
);

select * from finish();
rollback;
