-- Phase P0: private credential/license/exam/program candidate intake.
-- Candidate names and issuer links are NOT approved catalog destinations.
-- New bulk sources and requirements must be reviewed before publication.
-- Never expose raw candidates/demand evidence to the public API.
create table public.catalog_intake_candidates (
  id uuid primary key default gen_random_uuid(),
  source_namespace text not null check (source_namespace ~ '^[a-z0-9_]{3,48}$'),
  source_key text not null check (length(source_key) between 1 and 128),
  destination_type text not null check (destination_type in (
    'certification', 'professional_license', 'licensure_exam',
    'standardized_exam', 'academic_program', 'training_course'
  )),
  title text not null check (length(btrim(title)) between 3 and 240),
  issuer_name text not null check (length(btrim(issuer_name)) between 2 and 200),
  issuer_url text not null check (issuer_url ~ '^https://[^[:space:]]+$'),
  source_url text not null check (source_url ~ '^https://[^[:space:]]+$'),
  jurisdiction text not null default 'US' check (length(jurisdiction) between 2 and 48),
  description text,
  cip_code text,
  onet_code text,
  edition text,
  source_rights text not null default 'link_metadata_only'
    check (source_rights in ('link_metadata_only', 'approved_for_display', 'blocked')),
  review_status text not null default 'pending'
    check (review_status in ('pending', 'approved', 'rejected')),
  verified_at timestamptz,
  publication_status text not null default 'draft'
    check (publication_status in ('draft', 'published', 'retired')),
  linked_target_id uuid references public.learning_targets(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_namespace, source_key),
  constraint intake_publish_review_gate check (
    publication_status <> 'published' or (
      review_status = 'approved'
      and verified_at is not null
      and source_rights = 'approved_for_display'
    )
  )
);

create index catalog_intake_review_idx
  on public.catalog_intake_candidates (review_status, destination_type, jurisdiction);
create index catalog_intake_title_idx
  on public.catalog_intake_candidates (lower(title));
create index catalog_intake_target_idx
  on public.catalog_intake_candidates (linked_target_id)
  where linked_target_id is not null;

comment on table public.catalog_intake_candidates is
  'Private issuer-linked discovery intake; pending candidates are NOT published credentials or verified license requirements.';

create table public.catalog_intake_demand_signals (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.catalog_intake_candidates(id) on delete cascade,
  metric text not null check (metric in (
    'bls_annual_openings', 'ipeds_completions', 'onet_job_postings',
    'issuer_exam_participants', 'search_interest_index',
    'community_goal_saves', 'community_searches'
  )),
  metric_value numeric not null check (metric_value >= 0),
  observed_period text not null check (observed_period ~ '^20[0-9]{2}(-[0-9]{2})?$'),
  geography text not null check (length(geography) between 2 and 48),
  publisher text not null check (length(btrim(publisher)) between 2 and 120),
  evidence_url text not null check (evidence_url ~ '^https://[^[:space:]]+$'),
  method_note text not null check (length(btrim(method_note)) > 0),
  data_rights text not null default 'metadata_only'
    check (data_rights in ('metadata_only', 'approved_aggregate')),
  observed_at timestamptz not null default now(),
  unique (candidate_id, metric, observed_period, geography, publisher)
);

create index catalog_intake_demand_recent_idx
  on public.catalog_intake_demand_signals (metric, observed_period, geography);

comment on table public.catalog_intake_demand_signals is
  'Evidence only: nonnegative observed metrics with source, period and geography. No imputed popularity and no unlicensed provider text.';

-- Intentional explicit deny for browser clients. Administrative ingestion is
-- service-role only; no user can promote a candidate to official status.
alter table public.catalog_intake_candidates enable row level security;
alter table public.catalog_intake_demand_signals enable row level security;

revoke all on table public.catalog_intake_candidates from public, anon, authenticated;
revoke all on table public.catalog_intake_demand_signals from public, anon, authenticated;
grant select, insert, update, delete on table public.catalog_intake_candidates to service_role;
grant select, insert, update, delete on table public.catalog_intake_demand_signals to service_role;
