-- P1 official numerical evidence: private, versioned CIP/SOC observations.
-- NEVER interpret a CIP-SOC mapping as proof of a license, exam or
-- certification requirement. Figures remain associated with taxonomy codes.
create table public.catalog_official_demand_observations (
  id uuid primary key default gen_random_uuid(),
  taxonomy_system text not null check (taxonomy_system in ('cip','bls_soc')),
  taxonomy_version text not null check (taxonomy_version in ('2020','soc_2018')),
  taxonomy_code text not null check (
    (taxonomy_system='cip' and taxonomy_version='2020'
      and taxonomy_code ~ '^[0-9]{2}\.[0-9]{4}$')
    or
    (taxonomy_system='bls_soc' and taxonomy_version='soc_2018'
      and taxonomy_code ~ '^[0-9]{2}-[0-9]{4}$')
  ),
  metric text not null check (metric in (
    'ipeds_awards_conferred', 'bls_annual_openings_thousands'
  )),
  metric_value numeric(15,2) not null check (metric_value >= 0),
  metric_unit text not null check (metric_unit in ('awards', 'thousands_of_jobs')),
  period text not null check (period in ('2024-2025','2025-2035')),
  geography text not null default 'US' check (geography='US'),
  dimension text not null default 'all'
    check (dimension ~ '^[a-zA-Z0-9_:.-]{1,64}$'),
  publisher text not null check (publisher in ('NCES_IPEDS','BLS_EMP')),
  source_release text not null check (source_release in ('C2025_A_provisional','BLS_EMP_2025_2035')),
  source_url text not null check (source_url ~ '^https://[^[:space:]]+$'),
  source_sha256 text not null check (source_sha256 ~ '^[0-9a-f]{64}$'),
  method_note text not null check (length(btrim(method_note)) >= 20),
  imported_at timestamptz not null default now(),
  constraint demand_observation_semantics check (
    (taxonomy_system='cip' and metric='ipeds_awards_conferred'
      and metric_unit='awards' and period='2024-2025'
      and publisher='NCES_IPEDS' and source_release='C2025_A_provisional')
    or
    (taxonomy_system='bls_soc' and metric='bls_annual_openings_thousands'
      and metric_unit='thousands_of_jobs' and period='2025-2035'
      and publisher='BLS_EMP' and source_release='BLS_EMP_2025_2035'
      and dimension='all')
  ),
  unique(taxonomy_system,taxonomy_version,taxonomy_code,metric,period,geography,dimension,source_release)
);

create index catalog_demand_measure_order_idx
on public.catalog_official_demand_observations (metric, period, metric_value desc);
create index catalog_demand_taxonomy_idx
on public.catalog_official_demand_observations (taxonomy_system, taxonomy_version, taxonomy_code);

alter table public.catalog_official_demand_observations enable row level security;
revoke all on table public.catalog_official_demand_observations from public, anon, authenticated;
grant select, insert, update, delete on table public.catalog_official_demand_observations to service_role;

comment on table public.catalog_official_demand_observations is
  'Private sourced national demand measures linked to CIP or SOC ONLY; a high score is not proof that a certification or legal license is popular. BLS values stay in published thousands, not precise counts.';

create table public.catalog_official_demand_imports (
  source_release text not null primary key
    check (source_release in ('C2025_A_provisional','BLS_EMP_2025_2035')),
  source_url text not null,
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  source_bytes bigint not null check (source_bytes > 0),
  observations integer not null check (observations > 0),
  checked_at timestamptz not null default now(),
  method_note text not null
);
alter table public.catalog_official_demand_imports enable row level security;
revoke all on table public.catalog_official_demand_imports from public, anon, authenticated;
grant select, insert, update on table public.catalog_official_demand_imports to service_role;
