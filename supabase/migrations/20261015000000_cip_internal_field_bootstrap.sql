-- ============================================================================
-- CIP 2020 internal field bootstrap (CANONICAL_TAXONOMY_ARCHITECTURE.md §3.2,
-- §10.2 Phase 2.2–2.4).
--
-- The official CIP 2020 graph (48 series, 466 groups, 2,295 programs) is
-- imported into external_classification_nodes, but only the 48 series were
-- given internal `fields`. This migration:
--   1. Adds bootstrap_cip_internal_fields(): a transactional, idempotent,
--      fail-closed bootstrap that gives every active CIP 2020 node exactly one
--      permanent internal field (subfield / program_classification) linked by
--      an exact_match mapping and an internal parent_id.
--   2. Adds taxonomy_internal_coverage(): a read-only report that keeps
--      internal-hierarchy completeness separate from external import counts.
--   3. Backfills the hierarchy for whatever CIP 2020 nodes are present.
--
-- Rules:
--   * Existing exact mappings (e.g. the 48 curated broad fields and their
--     catalog cluster memberships) are reused; IDs are never regenerated.
--   * Nothing is merged on title or slug. Generated slugs carry the CIP code,
--     and an existing slug collision aborts instead of merging.
--   * Only CIP 2020 is bootstrapped. Later editions must be mapped to existing
--     fields through reviewed lineage, never duplicated automatically.
--   * Clients cannot run the bootstrap; it is service_role only.
-- ============================================================================

create or replace function public.cip_internal_field_slug(p_title text, p_code text)
returns text
language sql
immutable
set search_path = pg_catalog
as $$
  select coalesce(
           nullif(btrim(left(regexp_replace(lower(coalesce(p_title, '')), '[^a-z0-9]+', '-', 'g'), 80), '-'), ''),
           'field'
         ) || '-cip-' || replace(p_code, '.', '-');
$$;

comment on function public.cip_internal_field_slug(text, text) is
  'Deterministic, code-qualified slug for CIP-bootstrapped internal fields. '
  'Including the code keeps repeated CIP titles (e.g. 11.01 and 11.0101) distinct.';

-- Active CIP nodes of one level that still lack an exact internal field.
create or replace function public.cip_bootstrap_pending(p_version text, p_level text)
returns table (
  node_id uuid,
  code text,
  slug text,
  name text,
  description text,
  cross_references text[],
  illustrative_examples text[],
  parent_field_id uuid,
  sort_order integer
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select
    n.id,
    n.code,
    public.cip_internal_field_slug(n.title, n.code),
    regexp_replace(btrim(n.title), '\s*\.+$', ''),
    n.definition,
    coalesce(n.cross_references, '{}'),
    coalesce(n.illustrative_examples, '{}'),
    pf.field_id,
    case
      when p_level = 'series' and n.code ~ '^\d+$' then n.code::integer
      when split_part(n.code, '.', 2) ~ '^\d+$' then split_part(n.code, '.', 2)::integer
      else 0
    end
  from public.external_classification_nodes n
  left join public.field_external_classifications pf
    on pf.classification_node_id = n.parent_id
   and pf.mapping_type = 'exact_match'
  where n.system = 'cip' and n.version = p_version and n.is_active
    and n.level_code = p_level
    and not exists (
      select 1 from public.field_external_classifications fec
      where fec.classification_node_id = n.id and fec.mapping_type = 'exact_match'
    );
$$;

revoke all on function public.cip_bootstrap_pending(text, text) from public, anon, authenticated;
grant execute on function public.cip_bootstrap_pending(text, text) to service_role;

create or replace function public.bootstrap_cip_internal_fields(p_version text default '2020')
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_level text;
  v_kind text;
  v_count bigint;
  v_created jsonb := '{}'::jsonb;
  v_total_created bigint := 0;
  v_problem text;
  v_active bigint;
  v_mapped bigint;
  v_overrides bigint;
begin
  if p_version is distinct from '2020' then
    raise exception 'CIP % cannot be bootstrapped: only CIP 2020 creates internal fields; later editions require reviewed mappings to existing fields',
      coalesce(p_version, '<null>')
      using errcode = '22023';
  end if;

  -- Serialize concurrent runs so two callers cannot both create a node's field.
  perform pg_advisory_xact_lock(hashtext('public.bootstrap_cip_internal_fields'));

  -- 1. Fail closed on unsupported hierarchy levels.
  select string_agg(distinct n.level_code, ', ') into v_problem
  from external_classification_nodes n
  where n.system = 'cip' and n.version = p_version and n.is_active
    and n.level_code not in ('series', 'group', 'program');
  if v_problem is not null then
    raise exception 'CIP % has unsupported level codes: %', p_version, v_problem
      using errcode = 'P0001';
  end if;

  -- 2. Fail closed on broken or inconsistent external parents.
  select string_agg(x.code, ', ' order by x.code) into v_problem
  from (
    select n.code
    from external_classification_nodes n
    left join external_classification_nodes p on p.id = n.parent_id
    where n.system = 'cip' and n.version = p_version and n.is_active
      and (
        (n.level_code = 'series' and n.parent_id is not null)
        or (
          n.level_code <> 'series'
          and (
            p.id is null
            or not p.is_active
            or p.system <> n.system
            or p.version <> n.version
            or p.level_code <> case n.level_code when 'group' then 'series' else 'group' end
            or left(n.code, length(p.code)) <> p.code
          )
        )
      )
    order by n.code
    limit 20
  ) x;
  if v_problem is not null then
    raise exception 'CIP % hierarchy is broken; refusing to bootstrap. Invalid parents for: %', p_version, v_problem
      using errcode = 'P0001';
  end if;

  -- 3. Fail closed on ambiguous existing exact mappings.
  select string_agg(x.code, ', ' order by x.code) into v_problem
  from (
    select n.code
    from field_external_classifications fec
    join external_classification_nodes n on n.id = fec.classification_node_id
    where n.system = 'cip' and n.version = p_version and fec.mapping_type = 'exact_match'
    group by n.code
    having count(*) > 1
    order by n.code
    limit 20
  ) x;
  if v_problem is not null then
    raise exception 'CIP % nodes have multiple exact internal fields: %', p_version, v_problem
      using errcode = 'P0001';
  end if;

  select string_agg(x.slug, ', ' order by x.slug) into v_problem
  from (
    select f.slug
    from field_external_classifications fec
    join external_classification_nodes n on n.id = fec.classification_node_id
    join fields f on f.id = fec.field_id
    where n.system = 'cip' and n.version = p_version and fec.mapping_type = 'exact_match'
    group by f.slug
    having count(*) > 1
    order by f.slug
    limit 20
  ) x;
  if v_problem is not null then
    raise exception 'Internal fields exactly match multiple CIP % nodes: %', p_version, v_problem
      using errcode = 'P0001';
  end if;

  -- 4. Create missing fields top-down so each level's parents already exist.
  foreach v_level in array array['series', 'group', 'program'] loop
    v_kind := case v_level
      when 'series' then 'broad_field'
      when 'group' then 'subfield'
      else 'program_classification'
    end;

    if v_level <> 'series' and exists (
      select 1 from public.cip_bootstrap_pending(p_version, v_level) p
      where p.parent_field_id is null
    ) then
      raise exception 'CIP % % nodes have no internal parent field; refusing to create orphans', p_version, v_level
        using errcode = 'P0001';
    end if;

    select string_agg(x.slug, ', ' order by x.slug) into v_problem
    from (
      select p.slug
      from public.cip_bootstrap_pending(p_version, v_level) p
      join fields f on f.slug = p.slug
      order by p.slug
      limit 20
    ) x;
    if v_problem is not null then
      raise exception 'Refusing to merge CIP % nodes into existing unmapped fields with slugs: %', p_version, v_problem
        using errcode = 'P0001';
    end if;

    -- The pending CTE is evaluated once, before either insert runs.
    with pending as materialized (
      select * from public.cip_bootstrap_pending(p_version, v_level)
    ),
    inserted as (
      insert into fields (
        name, slug, description, field_kind, parent_id, sort_order, is_active,
        cross_references, illustrative_examples, metadata
      )
      select
        p.name, p.slug, p.description, v_kind, p.parent_field_id, p.sort_order, true,
        p.cross_references, p.illustrative_examples,
        jsonb_build_object(
          'bootstrap',
          jsonb_build_object('system', 'cip', 'version', p_version, 'code', p.code)
        )
      from pending p
      returning id, slug
    )
    insert into field_external_classifications (field_id, classification_node_id, mapping_type, notes)
    select i.id, p.node_id, 'exact_match', 'CIP ' || p_version || ' internal field bootstrap'
    from inserted i
    join pending p on p.slug = i.slug;

    get diagnostics v_count = row_count;
    v_created := v_created || jsonb_build_object(v_kind, v_count);
    v_total_created := v_total_created + v_count;
  end loop;

  -- 5. Post-condition: every active node has exactly one exact internal field.
  select count(*), count(*) filter (where m.exact_count = 1)
  into v_active, v_mapped
  from (
    select (
      select count(*) from field_external_classifications fec
      where fec.classification_node_id = n.id and fec.mapping_type = 'exact_match'
    ) as exact_count
    from external_classification_nodes n
    where n.system = 'cip' and n.version = p_version and n.is_active
  ) m;
  if v_active <> v_mapped then
    raise exception 'CIP % bootstrap incomplete: % of % active nodes mapped', p_version, v_mapped, v_active
      using errcode = 'P0001';
  end if;

  -- Curated internal re-homing of pre-existing fields is preserved, but reported.
  select count(*) into v_overrides
  from external_classification_nodes n
  join field_external_classifications c
    on c.classification_node_id = n.id and c.mapping_type = 'exact_match'
  join fields f on f.id = c.field_id
  join field_external_classifications pc
    on pc.classification_node_id = n.parent_id and pc.mapping_type = 'exact_match'
  where n.system = 'cip' and n.version = p_version and n.is_active
    and n.level_code <> 'series'
    and f.parent_id is distinct from pc.field_id;

  return jsonb_build_object(
    'system', 'cip',
    'version', p_version,
    'active_nodes', v_active,
    'mapped_nodes', v_mapped,
    'created', v_created,
    'created_total', v_total_created,
    'reused_existing', v_active - v_total_created,
    'internal_parent_overrides', v_overrides
  );
end;
$$;

comment on function public.bootstrap_cip_internal_fields(text) is
  'Service-role only. Idempotently gives every active CIP 2020 node one permanent internal field '
  'with an exact_match mapping and internal parent. Fails closed on broken parents, ambiguous '
  'mappings, or slug collisions. Rerun after official CIP imports.';

revoke all on function public.bootstrap_cip_internal_fields(text) from public, anon, authenticated;
grant execute on function public.bootstrap_cip_internal_fields(text) to service_role;

create or replace function public.taxonomy_internal_coverage(p_version text default '2020')
returns jsonb
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  with nodes as (
    select n.id, n.level_code, n.parent_id
    from external_classification_nodes n
    where n.system = 'cip' and n.version = p_version and n.is_active
  ),
  node_exact as (
    select nodes.id, nodes.level_code, nodes.parent_id,
           count(fec.id) as exact_count,
           min(fec.field_id::text)::uuid as field_id
    from nodes
    left join field_external_classifications fec
      on fec.classification_node_id = nodes.id and fec.mapping_type = 'exact_match'
    group by nodes.id, nodes.level_code, nodes.parent_id
  ),
  levels as (
    select level_code,
           count(*) as active_nodes,
           count(*) filter (where exact_count = 1) as exact_mapped,
           count(*) filter (where exact_count = 0) as unmapped,
           count(*) filter (where exact_count > 1) as ambiguous
    from node_exact
    group by level_code
  ),
  multi_node_fields as (
    select count(*) as n from (
      select fec.field_id
      from field_external_classifications fec
      join external_classification_nodes n on n.id = fec.classification_node_id
      where n.system = 'cip' and n.version = p_version and fec.mapping_type = 'exact_match'
      group by fec.field_id
      having count(*) > 1
    ) x
  ),
  kinds as (
    select f.field_kind, count(*) as n
    from fields f
    where f.is_active
    group by f.field_kind
  ),
  hierarchy as (
    select
      count(*) filter (where f.field_kind in ('subfield', 'program_classification') and f.parent_id is null)
        as nested_fields_without_parent,
      count(*) filter (where f.field_kind = 'subfield' and p.id is not null and p.field_kind <> 'broad_field')
        as subfields_under_wrong_kind,
      count(*) filter (where f.field_kind = 'program_classification' and p.id is not null and p.field_kind <> 'subfield')
        as programs_under_wrong_kind
    from fields f
    left join fields p on p.id = f.parent_id
    where f.is_active
  ),
  overrides as (
    select count(*) as n
    from node_exact c
    join node_exact pc on pc.id = c.parent_id
    join fields f on f.id = c.field_id
    where c.exact_count = 1 and pc.exact_count = 1
      and f.parent_id is distinct from pc.field_id
  )
  select jsonb_build_object(
    'system', 'cip',
    'version', p_version,
    'levels', coalesce((
      select jsonb_object_agg(level_code, jsonb_build_object(
        'active_nodes', active_nodes,
        'exact_mapped', exact_mapped,
        'unmapped', unmapped,
        'ambiguous', ambiguous))
      from levels), '{}'::jsonb),
    'active_fields_by_kind', coalesce((select jsonb_object_agg(field_kind, n) from kinds), '{}'::jsonb),
    'hierarchy', (
      select jsonb_build_object(
        'fields_matching_multiple_nodes', (select n from multi_node_fields),
        'nested_fields_without_parent', h.nested_fields_without_parent,
        'subfields_under_wrong_kind', h.subfields_under_wrong_kind,
        'programs_under_wrong_kind', h.programs_under_wrong_kind,
        'internal_parent_overrides', (select n from overrides))
      from hierarchy h),
    'complete', (
      exists (select 1 from nodes)
      and not exists (select 1 from node_exact where exact_count <> 1)
      and (select n from multi_node_fields) = 0
      and (select nested_fields_without_parent + subfields_under_wrong_kind + programs_under_wrong_kind
           from hierarchy) = 0
      and (select n from overrides) = 0
    )
  );
$$;

comment on function public.taxonomy_internal_coverage(text) is
  'Read-only internal hierarchy coverage for CIP-backed fields. Separate from external import '
  'counts: an imported CIP graph does not imply an internal hierarchy, and neither implies catalog '
  'completeness. Anonymous callers only see active fields (RLS).';

revoke all on function public.taxonomy_internal_coverage(text) from public;
grant execute on function public.taxonomy_internal_coverage(text) to anon, authenticated, service_role;

-- Children of a field are fetched by parent; keep that lookup indexed and ordered.
create index if not exists fields_parent_active_sort_idx
  on public.fields (parent_id, sort_order, name)
  where is_active;

-- Backfill whatever CIP 2020 graph is present. On a fresh database this only
-- reuses the seeded broad fields; after the official import it creates the
-- 466 subfields and 2,295 program fields.
select public.bootstrap_cip_internal_fields('2020');

-- Refresh planner statistics after the bulk backfill so lookups stay fast.
analyze public.fields;
analyze public.field_external_classifications;
