-- ============================================================================
-- LearningApp-authored literacy and practical-life field taxonomy.
--
-- These native fields organize the app's existing literacy, life-milestone,
-- and life-survival screens. They are not external academic classifications,
-- official standards, credentials, or statements of legal/medical requirements.
-- The six shipped sample programming concepts are linked to their existing
-- field through concept_fields; no new concept placements are inferred.
-- ============================================================================

insert into public.catalog_clusters (
  id, slug, title, description, emoji, accent_color, sort_order, is_active
)
values (
  gen_random_uuid(),
  'cluster_life_milestones',
  'Life Milestones & Survival Literacy',
  'Foundational literacy, civic milestones, and practical life-skills practice.',
  '🏛️',
  '#4338CA',
  13,
  true
)
on conflict (slug) do update
set is_active = true,
    sort_order = excluded.sort_order
where catalog_clusters.title = excluded.title;

do $$
begin
  if exists (
    select 1 from public.catalog_clusters
    where slug = 'cluster_life_milestones'
      and title <> 'Life Milestones & Survival Literacy'
  ) then
    raise exception 'Catalog cluster slug cluster_life_milestones is already used by a different cluster'
      using errcode = 'P0001';
  end if;
end
$$;

insert into public.fields (
  name, slug, description, field_kind, parent_id, sort_order, is_active, aliases, metadata
)
values
  (
    'Foundational Literacy',
    'foundational-literacy',
    'Learning areas for beginning reading, oral language, and adult basic-education reading practice.',
    'native_field',
    null,
    1,
    true,
    array['early literacy', 'basic reading'],
    jsonb_build_object('taxonomy_origin', 'learningapp_authored', 'source_surface', 'foundational_literacy_screen')
  ),
  (
    'Civic and Community Literacy',
    'civic-and-community-literacy',
    'Learning areas for civic knowledge and practical community navigation.',
    'native_field',
    null,
    2,
    true,
    array['civic learning', 'community navigation'],
    jsonb_build_object('taxonomy_origin', 'learningapp_authored', 'source_surface', 'life_milestones_screen')
  ),
  (
    'Practical Life Skills',
    'practical-life-skills',
    'Learning areas represented by LearningApp practical life-skills practice screens.',
    'native_field',
    null,
    3,
    true,
    array['survival literacy', 'everyday skills'],
    jsonb_build_object('taxonomy_origin', 'learningapp_authored', 'source_surface', 'life_domains_screen')
  )
on conflict (slug) do nothing;

insert into public.fields (
  name, slug, description, field_kind, parent_id, sort_order, is_active, aliases, metadata
)
select
  child.name,
  child.slug,
  child.description,
  'native_field',
  parent.id,
  child.sort_order,
  true,
  child.aliases,
  jsonb_build_object(
    'taxonomy_origin', 'learningapp_authored',
    'source_surface', child.source_surface
  )
from (
  values
    (
      'Phonics and Word Decoding',
      'phonics-and-word-decoding',
      'Beginning reading practice with letter-sound relationships and word decoding.',
      'foundational-literacy',
      1,
      array['phonics', 'decoding'],
      'foundational_literacy_screen'
    ),
    (
      'Supported Reading and Comprehension',
      'supported-reading-and-comprehension',
      'Supported reading practice using decodable stories and comprehension activities.',
      'foundational-literacy',
      2,
      array['reading fluency', 'reading comprehension', 'decodable stories'],
      'foundational_literacy_screen'
    ),
    (
      'Oral Language and Listening',
      'oral-language-and-listening',
      'Oral-first language and listening practice used alongside foundational literacy.',
      'foundational-literacy',
      3,
      array['oral language', 'listening'],
      'oral_diagnostic_widget'
    ),
    (
      'Adult Basic-Education Reading',
      'adult-basic-education-reading',
      'Reading practice bridging foundational literacy toward adult basic education.',
      'foundational-literacy',
      4,
      array['GED reading bridge', 'adult reading'],
      'ged_bridge_widget'
    ),
    (
      'Civics and Naturalization Preparation',
      'civics-and-naturalization-preparation',
      'Civic knowledge and oral interview practice represented by the citizenship milestone screen.',
      'civic-and-community-literacy',
      1,
      array['US civics', 'citizenship preparation'],
      'uscis_civics_simulator_widget'
    ),
    (
      'Driver Safety and License Preparation',
      'driver-safety-and-license-preparation',
      'Road-safety and driver-exam practice represented by the Florida driver milestone screen.',
      'civic-and-community-literacy',
      2,
      array['driver education', 'road safety'],
      'dmv_exam_simulator_widget'
    ),
    (
      'Cash and ATM Practice',
      'cash-and-atm-practice',
      'Practice recognizing US cash and using an ATM interface.',
      'practical-life-skills',
      1,
      array['cash literacy', 'ATM practice'],
      'currency_atm_widget'
    ),
    (
      'Health Literacy and First Aid',
      'health-literacy-and-first-aid',
      'Practice reading prescription labels and learning introductory first-aid actions.',
      'practical-life-skills',
      2,
      array['prescription labels', 'first aid'],
      'rx_and_first_aid_widget'
    ),
    (
      'Food Safety',
      'food-safety',
      'Food-handling and food-safety practice represented by the LearningApp food-safety screen.',
      'practical-life-skills',
      3,
      array['food handling'],
      'food_safety_widget'
    ),
    (
      'Workplace Safety',
      'workplace-safety',
      'Workplace-safety practice represented by the LearningApp workplace-safety screen.',
      'practical-life-skills',
      4,
      array['occupational safety'],
      'workplace_safety_widget'
    )
) as child(name, slug, description, parent_slug, sort_order, aliases, source_surface)
join public.fields parent on parent.slug = child.parent_slug
where parent.field_kind = 'native_field'
  and parent.metadata->>'taxonomy_origin' = 'learningapp_authored'
on conflict (slug) do nothing;

do $$
declare
  v_cluster_id uuid;
  v_field_id uuid;
  v_expected record;
begin
  -- Never adopt a same-slug field owned by another taxonomy source.
  if exists (
    select 1 from public.fields f
    where f.slug in (
      'foundational-literacy',
      'civic-and-community-literacy',
      'practical-life-skills',
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
      and (
        f.field_kind <> 'native_field'
        or f.metadata->>'taxonomy_origin' is distinct from 'learningapp_authored'
      )
  ) then
    raise exception 'A native learning field slug is already owned by another taxonomy source'
      using errcode = 'P0001';
  end if;

  -- All native children must retain their declared parent, not just their name.
  for v_expected in
    select * from (values
      ('phonics-and-word-decoding', 'foundational-literacy'),
      ('supported-reading-and-comprehension', 'foundational-literacy'),
      ('oral-language-and-listening', 'foundational-literacy'),
      ('adult-basic-education-reading', 'foundational-literacy'),
      ('civics-and-naturalization-preparation', 'civic-and-community-literacy'),
      ('driver-safety-and-license-preparation', 'civic-and-community-literacy'),
      ('cash-and-atm-practice', 'practical-life-skills'),
      ('health-literacy-and-first-aid', 'practical-life-skills'),
      ('food-safety', 'practical-life-skills'),
      ('workplace-safety', 'practical-life-skills')
    ) expected(child_slug, parent_slug)
  loop
    if not exists (
      select 1
      from public.fields child
      join public.fields parent on parent.slug = v_expected.parent_slug
      where child.slug = v_expected.child_slug
        and child.parent_id = parent.id
        and child.is_active
    ) then
      raise exception 'Native learning field % is missing or has an invalid parent',
        v_expected.child_slug using errcode = 'P0001';
    end if;
  end loop;

  select id into strict v_cluster_id
  from public.catalog_clusters
  where slug = 'cluster_life_milestones';

  for v_expected in
    select * from (values
      ('foundational-literacy', 1),
      ('civic-and-community-literacy', 2),
      ('practical-life-skills', 3)
    ) expected(field_slug, sort_order)
  loop
    select id into strict v_field_id
    from public.fields
    where slug = v_expected.field_slug and is_active;

    insert into public.catalog_cluster_fields (cluster_id, field_id, sort_order)
    values (v_cluster_id, v_field_id, v_expected.sort_order)
      on conflict (cluster_id, field_id) do update
        set sort_order = excluded.sort_order;
    end loop;
end
$$;

-- Preserve the existing single-field placement while exposing the same links
-- through the canonical many-to-many concept_fields relation.
insert into public.concept_fields (concept_id, field_id, relationship)
select c.id, c.field_id, 'core_concept'
from public.knowledge_concepts c
where c.status = 'active'
  and c.field_id is not null
  and c.id in (
    'b1000000-0000-0000-0000-000000000001',
    'b1000000-0000-0000-0000-000000000002',
    'b1000000-0000-0000-0000-000000000003',
    'b1000000-0000-0000-0000-000000000004',
    'b1000000-0000-0000-0000-000000000005',
    'b1000000-0000-0000-0000-000000000006'
  )
on conflict (concept_id, field_id) do nothing;
