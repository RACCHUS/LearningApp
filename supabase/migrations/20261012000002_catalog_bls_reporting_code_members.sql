-- BLS publication/combined reporting codes are not detailed SOC 2018 codes.
-- These associations state membership ONLY. Job openings for the combined
-- BLS series must never be duplicated/allocated across component SOC codes.
create table public.catalog_bls_reporting_code_members (
  bls_release text not null default 'BLS_EMP_2025_2035'
    check (bls_release = 'BLS_EMP_2025_2035'),
  reporting_code text not null check (reporting_code ~ '^[0-9]{2}-[0-9]{4}$'),
  soc_2018_code text not null check (soc_2018_code ~ '^[0-9]{2}-[0-9]{4}$'),
  relationship text not null default 'includes_occupation'
    check (relationship = 'includes_occupation'),
  allocation_policy text not null default 'not_allocated'
    check (allocation_policy = 'not_allocated'),
  source_url text not null default 'https://www.bls.gov/oes/oes_ques.htm'
    check (source_url = 'https://www.bls.gov/oes/oes_ques.htm'),
  source_note text not null
    check (length(btrim(source_note)) >= 30),
  created_at timestamptz not null default now(),
  primary key (bls_release, reporting_code, soc_2018_code),
  check (reporting_code <> soc_2018_code)
);
alter table public.catalog_bls_reporting_code_members enable row level security;
revoke all on table public.catalog_bls_reporting_code_members from public, anon, authenticated;
grant select, insert, update, delete on table public.catalog_bls_reporting_code_members to service_role;

-- Explicit BLS source-documented hybrid code to 2018 detailed occupation
-- membership. Each composite still has ONE published aggregate number.
with source_members(reporting_code, code, explanation) as (
  values
    ('21-1018','21-1011','BLS combines substance abuse/behavioral disorder and mental health counselors'),
    ('21-1018','21-1014','BLS combines substance abuse/behavioral disorder and mental health counselors'),
    ('25-2052','25-2055','BLS combines kindergarten and elementary special education teachers'),
    ('25-2052','25-2056','BLS combines kindergarten and elementary special education teachers'),
    ('25-9045','25-9042','BLS combines non-postsecondary teaching assistants across several specialties'),
    ('25-9045','25-9043','BLS combines non-postsecondary teaching assistants across several specialties'),
    ('25-9045','25-9049','BLS combines non-postsecondary teaching assistants across several specialties'),
    ('51-2028','51-2022','BLS combines electrical/electronic and electromechanical assemblers'),
    ('51-2028','51-2023','BLS combines electrical/electronic and electromechanical assemblers'),
    ('53-1047','53-1042','BLS combines four transportation/material-moving supervisor SOC occupations'),
    ('53-1047','53-1043','BLS combines four transportation/material-moving supervisor SOC occupations'),
    ('53-1047','53-1044','BLS combines four transportation/material-moving supervisor SOC occupations'),
    ('53-1047','53-1049','BLS combines four transportation/material-moving supervisor SOC occupations')
)
insert into public.catalog_bls_reporting_code_members
(reporting_code, soc_2018_code, source_note)
select reporting_code,code,explanation
from source_members
on conflict (bls_release,reporting_code,soc_2018_code) do nothing;

comment on table public.catalog_bls_reporting_code_members is
'BLS documentation-based combined reporting code membership: never allocate, duplicate or sum combined openings into each component SOC.';

-- No public view or grants. Future reporting must retain raw 831 BLS rows
-- and show one reporting-category total (not fractional allocations).

-- One observation per BLS original code. Membership is a separate relation;
-- this view classifies hybrid codes but NEVER explodes a total across members.
create view public.v_catalog_bls_observation_coverage
with (security_invoker = true) as
select
  o.taxonomy_code as bls_reporting_code,
  o.metric_value as annual_openings_thousands,
  o.period,
  o.source_release,
  case
    when exists (
      select 1 from public.occupation_nodes n
      where n.taxonomy_system='bls_soc'
        and n.taxonomy_version='soc_2018'
        and n.is_active
        and n.code=o.taxonomy_code
    ) then 'exact_soc_2018'
    when exists (
      select 1 from public.catalog_bls_reporting_code_members c
      where c.bls_release=o.source_release
        and c.reporting_code=o.taxonomy_code
    ) then 'combined_reporting_code'
    else 'unmapped'
  end as coverage_status,
  (
    select count(*)::integer
    from public.catalog_bls_reporting_code_members c
    where c.bls_release=o.source_release
      and c.reporting_code=o.taxonomy_code
  ) as member_soc_count
from public.catalog_official_demand_observations o
where o.publisher='BLS_EMP'
  and o.metric='bls_annual_openings_thousands'
  and o.source_release='BLS_EMP_2025_2035';

revoke all on public.v_catalog_bls_observation_coverage
from public, anon, authenticated;
grant select on public.v_catalog_bls_observation_coverage to service_role;

comment on view public.v_catalog_bls_observation_coverage is
  'Private one-row-per-original-BLS-observation coverage classifications; 826 exact SOC 2018 + 5 combined reporting categories, without double counting.';
