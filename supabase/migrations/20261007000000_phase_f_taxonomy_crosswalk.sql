-- ============================================================================
-- Phase F: Full Taxonomy & Crosswalk Expansion Migration
-- Migration: 20261007000000_phase_f_taxonomy_crosswalk.sql
-- Description:
--   1. Adds convenient application view v_target_occupation_mappings joining
--      learning_target_fields to v_field_occupation_mappings.
--   2. Adds RPC resolve_taxonomy_lineage for tracing external taxonomy transitions.
--   3. Adds RPC get_target_crosswalk_occupations for high-performance UI retrieval.
--   4. Seeds representative decennial lineage data (CIP 2010 -> 2020 & SOC 2010 -> 2018).
--   5. Seeds multidisciplinary field bindings in learning_target_fields.
--   6. Seeds lateral field relations in field_relations.
--   7. Configures RLS policies and grants for the new views and RPCs.
-- ============================================================================

-- 1. TARGET OCCUPATION MAPPINGS VIEW
-- Allows direct queries connecting a LearningTarget to related labor occupations
-- through its primary and supporting fields.
create or replace view public.v_target_occupation_mappings as
  select distinct
    ltf.target_id,
    lt.slug as target_slug,
    lt.title as target_title,
    ltf.field_id,
    f.name as field_name,
    f.slug as field_slug,
    ltf.role as field_role,
    ltf.display_order as field_display_order,
    fom.occupation_id,
    fom.classification_system,
    fom.classification_version,
    fom.classification_code,
    fom.occupation_code,
    fom.occupation_title,
    fom.mapping_kind,
    fom.source_release_id
  from public.learning_target_fields ltf
  join public.learning_targets lt on lt.id = ltf.target_id
  join public.fields f on f.id = ltf.field_id
  join public.v_field_occupation_mappings fom on fom.field_id = ltf.field_id;

-- 2. TAXONOMY LINEAGE RESOLUTION RPC
-- Traverses taxonomy_node_lineage to resolve how a historical code transitioned
create or replace function public.resolve_taxonomy_lineage(
  p_source_system text,
  p_from_version text,
  p_from_code text
)
returns table (
  id uuid,
  source_system text,
  from_version text,
  from_code text,
  to_version text,
  to_code text,
  transition_type text,
  notes text,
  created_at timestamptz
) as $$
begin
  return query
  select
    l.id,
    l.source_system,
    l.from_version,
    l.from_code,
    l.to_version,
    l.to_code,
    l.transition_type,
    l.notes,
    l.created_at
  from public.taxonomy_node_lineage l
  where l.source_system = p_source_system
    and l.from_version = p_from_version
    and (l.from_code = p_from_code or (p_from_code is null and l.from_code is null))
  order by l.created_at asc;
end;
$$ language plpgsql stable security definer;

-- 3. TARGET CROSSWALK OCCUPATIONS RPC
-- Fetches enriched occupation cards for a specific learning target
create or replace function public.get_target_crosswalk_occupations(
  p_target_id uuid
)
returns table (
  occupation_id uuid,
  occupation_code text,
  occupation_title text,
  occupation_level text,
  job_zone integer,
  field_id uuid,
  field_name text,
  field_role text,
  mapping_kind text,
  classification_code text,
  classification_title text
) as $$
begin
  return query
  select distinct
    ocn.id as occupation_id,
    ocn.code as occupation_code,
    ocn.title as occupation_title,
    ocn.level as occupation_level,
    ocn.job_zone,
    ltf.field_id,
    f.name as field_name,
    ltf.role as field_role,
    ecom.mapping_kind,
    ecn.code as classification_code,
    ecn.title as classification_title
  from public.learning_target_fields ltf
  join public.fields f on f.id = ltf.field_id
  join public.field_external_classifications fec on fec.field_id = ltf.field_id
  join public.external_classification_nodes ecn on ecn.id = fec.classification_node_id
  join public.external_classification_occupation_mappings ecom on ecom.classification_node_id = ecn.id
  join public.occupation_nodes ocn on ocn.id = ecom.occupation_id
  where ltf.target_id = p_target_id
    and ocn.is_active = true
  order by ltf.role asc, ocn.code asc;
end;
$$ language plpgsql stable security definer;

-- 4. CROSS-TARGET SHARED CONCEPTS RPC
-- Identifies canonical concepts shared between learning targets
create or replace function public.get_cross_target_shared_concepts(
  p_target_a_id uuid,
  p_target_b_id uuid
)
returns table (
  concept_id uuid,
  concept_slug text,
  concept_name text,
  short_definition text,
  emoji text,
  target_a_nodes bigint,
  target_b_nodes bigint
) as $$
begin
  return query
  with target_a_concepts as (
    select distinct cnc.concept_id, count(cnc.curriculum_node_id) as node_count
    from public.curriculum_nodes cn
    join public.target_versions tv on tv.id = cn.target_version_id
    join public.curriculum_node_concepts cnc on cnc.curriculum_node_id = cn.id
    where tv.target_id = p_target_a_id
    group by cnc.concept_id
  ),
  target_b_concepts as (
    select distinct cnc.concept_id, count(cnc.curriculum_node_id) as node_count
    from public.curriculum_nodes cn
    join public.target_versions tv on tv.id = cn.target_version_id
    join public.curriculum_node_concepts cnc on cnc.curriculum_node_id = cn.id
    where tv.target_id = p_target_b_id
    group by cnc.concept_id
  )
  select
    kc.id as concept_id,
    kc.slug as concept_slug,
    kc.name as concept_name,
    kc.short_definition,
    kc.emoji,
    ta.node_count as target_a_nodes,
    tb.node_count as target_b_nodes
  from target_a_concepts ta
  join target_b_concepts tb on tb.concept_id = ta.concept_id
  join public.knowledge_concepts kc on kc.id = ta.concept_id
  order by kc.name asc;
end;
$$ language plpgsql stable security definer;

-- 5. SEED REPRESENTATIVE DECENNIAL TAXONOMY LINEAGE DATA
-- Seed CIP 2010 -> CIP 2020 transitions
insert into public.taxonomy_node_lineage (
  source_system, from_version, from_code, to_version, to_code, transition_type, notes
) values
  ('cip', '2010', '11.0101', '2020', '11.0101', 'unchanged', 'Computer and Information Sciences, General retained across decennial revisions.'),
  ('cip', '2010', '11.0701', '2020', '11.0701', 'unchanged', 'Computer Science core program classification unchanged.'),
  ('cip', '2010', '11.0801', '2020', '11.0801', 'renamed', 'Title updated to Web Page, Digital/Multimedia and Information Resources Design.'),
  ('cip', '2010', null, '2020', '11.0105', 'newly_introduced', 'Human-Centered Technology Design introduced in CIP 2020.'),
  ('cip', '2010', null, '2020', '30.7001', 'newly_introduced', 'Data Science, General introduced under Multi/Interdisciplinary Studies in CIP 2020.'),
  ('cip', '2010', '51.9999', '2020', null, 'deleted', 'Historical obsolete catchall classification sunsetted in CIP 2020.'),
  ('bls_soc', '2010', '15-1132', '2018', '15-1252', 'moved_to', 'Software Developers, Applications recoded to 15-1252 Software Developers.'),
  ('bls_soc', '2010', '15-1133', '2018', '15-1252', 'merged_into', 'Software Developers, Systems Software merged into unified 15-1252 in SOC 2018.'),
  ('bls_soc', '2010', null, '2018', '15-2051', 'newly_introduced', 'Data Scientists formally introduced as detailed occupation in SOC 2018.')
on conflict (source_system, from_version, coalesce(from_code, ''), to_version, coalesce(to_code, ''), transition_type) do nothing;

-- 6. SEED LATERAL FIELD RELATIONS (With Canonical Ordering)
-- Directional relations: interdisciplinary_parent, applied_domain_of
-- Symmetric relations: shares_foundations, cross_disciplinary_partner (requires from_field_id < to_field_id)
do $$
declare
  v_f_cs uuid;
  v_f_math uuid;
  v_f_eng uuid;
  v_f_bio uuid;
  v_f1 uuid;
  v_f2 uuid;
begin
  select id into v_f_cs from public.fields where slug in ('computer-sciences', 'computer-science') limit 1;
  select id into v_f_math from public.fields where slug in ('mathematics-statistics-series', 'mathematics-statistics') limit 1;
  select id into v_f_eng from public.fields where slug in ('engineering-disciplines', 'engineering') limit 1;
  select id into v_f_bio from public.fields where slug in ('biological-biomedical-sciences', 'biological-sciences') limit 1;

  if v_f_cs is not null and v_f_math is not null then
    -- CS & Math share foundations (symmetric: from_id < to_id)
    if v_f_cs < v_f_math then
      v_f1 := v_f_cs; v_f2 := v_f_math;
    else
      v_f1 := v_f_math; v_f2 := v_f_cs;
    end if;
    insert into public.field_relations (from_field_id, to_field_id, relation_type, notes)
    values (v_f1, v_f2, 'shares_foundations', 'Discrete mathematics, logic, and graph theory form mutual theoretical bedrock.')
    on conflict (from_field_id, to_field_id, relation_type) do nothing;
  end if;

  if v_f_cs is not null and v_f_eng is not null then
    -- CS & Engineering cross-disciplinary partners (symmetric: from_id < to_id)
    if v_f_cs < v_f_eng then
      v_f1 := v_f_cs; v_f2 := v_f_eng;
    else
      v_f1 := v_f_eng; v_f2 := v_f_cs;
    end if;
    insert into public.field_relations (from_field_id, to_field_id, relation_type, notes)
    values (v_f1, v_f2, 'cross_disciplinary_partner', 'Computer Systems Engineering bridges digital hardware synthesis and systems programming.')
    on conflict (from_field_id, to_field_id, relation_type) do nothing;
  end if;

  if v_f_bio is not null and v_f_cs is not null then
    -- Bio is an applied domain of CS algorithms in Bioinformatics
    insert into public.field_relations (from_field_id, to_field_id, relation_type, notes)
    values (v_f_bio, v_f_cs, 'applied_domain_of', 'Computational genomics and protein folding algorithms apply CS models to biological systems.')
    on conflict (from_field_id, to_field_id, relation_type) do nothing;
  end if;
end $$;

-- 7. SEED MULTIDISCIPLINARY TARGET FIELD BINDINGS
do $$
declare
  v_t_cs uuid;
  v_t_swe uuid;
  v_t_sec uuid;
  v_f_cs uuid;
  v_f_math uuid;
  v_f_eng uuid;
  v_f_sec uuid;
begin
  select id into v_t_cs from public.learning_targets where slug = 'program-bs-computer-science';
  select id into v_t_swe from public.learning_targets where slug = 'career-software-engineer';
  select id into v_t_sec from public.learning_targets where slug = 'cert-comptia-security-plus';

  select id into v_f_cs from public.fields where slug in ('computer-sciences', 'computer-science') limit 1;
  select id into v_f_math from public.fields where slug in ('mathematics-statistics-series', 'mathematics-statistics') limit 1;
  select id into v_f_eng from public.fields where slug in ('engineering-disciplines', 'engineering') limit 1;
  select id into v_f_sec from public.fields where slug in ('homeland-security-protective') limit 1;

  -- B.S. in Computer Science: Primary CS, Supporting Math
  if v_t_cs is not null and v_f_cs is not null then
    insert into public.learning_target_fields (target_id, field_id, role, display_order)
    values (v_t_cs, v_f_cs, 'primary', 1)
    on conflict (target_id, field_id) do update set role = 'primary', display_order = 1;
  end if;
  if v_t_cs is not null and v_f_math is not null then
    insert into public.learning_target_fields (target_id, field_id, role, display_order)
    values (v_t_cs, v_f_math, 'supporting', 2)
    on conflict (target_id, field_id) do update set role = 'supporting', display_order = 2;
  end if;

  -- Software Engineer Career: Primary CS, Supporting Math & Engineering
  if v_t_swe is not null and v_f_cs is not null then
    insert into public.learning_target_fields (target_id, field_id, role, display_order)
    values (v_t_swe, v_f_cs, 'primary', 1)
    on conflict (target_id, field_id) do update set role = 'primary', display_order = 1;
  end if;
  if v_t_swe is not null and v_f_math is not null then
    insert into public.learning_target_fields (target_id, field_id, role, display_order)
    values (v_t_swe, v_f_math, 'supporting', 2)
    on conflict (target_id, field_id) do update set role = 'supporting', display_order = 2;
  end if;
  if v_t_swe is not null and v_f_eng is not null then
    insert into public.learning_target_fields (target_id, field_id, role, display_order)
    values (v_t_swe, v_f_eng, 'supporting', 3)
    on conflict (target_id, field_id) do update set role = 'supporting', display_order = 3;
  end if;

  -- CompTIA Security+: Primary CS, Supporting Protective Services
  if v_t_sec is not null and v_f_cs is not null then
    insert into public.learning_target_fields (target_id, field_id, role, display_order)
    values (v_t_sec, v_f_cs, 'primary', 1)
    on conflict (target_id, field_id) do update set role = 'primary', display_order = 1;
  end if;
  if v_t_sec is not null and v_f_sec is not null then
    insert into public.learning_target_fields (target_id, field_id, role, display_order)
    values (v_t_sec, v_f_sec, 'supporting', 2)
    on conflict (target_id, field_id) do update set role = 'supporting', display_order = 2;
  end if;
end $$;

-- 8. GRANT PRIVILEGES
revoke all on function public.resolve_taxonomy_lineage(text, text, text) from public;
grant execute on function public.resolve_taxonomy_lineage(text, text, text) to authenticated, anon, service_role;

revoke all on function public.get_target_crosswalk_occupations(uuid) from public;
grant execute on function public.get_target_crosswalk_occupations(uuid) to authenticated, anon, service_role;

revoke all on function public.get_cross_target_shared_concepts(uuid, uuid) from public;
grant execute on function public.get_cross_target_shared_concepts(uuid, uuid) to authenticated, anon, service_role;
