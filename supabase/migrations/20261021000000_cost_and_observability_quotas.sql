-- ECO-00C: Cost Quotas, Rate Limiting & Observability Architecture
-- Migration Version: 20261021000000

-- -----------------------------------------------------------------------------
-- 1. Table: public.usage_quotas
-- -----------------------------------------------------------------------------
create table if not exists public.usage_quotas (
  user_id uuid primary key references auth.users(id) on delete cascade,
  service_tier text not null default 'learner' check (service_tier in ('learner', 'educator', 'admin')),
  ai_tokens_used_today int not null default 0 check (ai_tokens_used_today >= 0),
  ai_tokens_daily_limit int not null default 15000 check (ai_tokens_daily_limit > 0),
  tts_chars_used_today int not null default 0 check (tts_chars_used_today >= 0),
  tts_chars_daily_limit int not null default 10000 check (tts_chars_daily_limit > 0),
  storage_bytes_used bigint not null default 0 check (storage_bytes_used >= 0),
  storage_bytes_limit bigint not null default 52428800 check (storage_bytes_limit > 0), -- 50 MB
  window_reset_at timestamptz not null default timezone('utc'::text, now() + interval '1 day'),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

-- RLS Enforcement
alter table public.usage_quotas enable row level security;

-- Least privilege: Prevent pg_graphql from exposing table to unauthenticated clients
revoke all on table public.usage_quotas from public, anon;
grant select on table public.usage_quotas to authenticated, service_role;

-- Policies: Users can read their own quota; Admins can read all quotas
create policy usage_quotas_select_policy on public.usage_quotas
  for select
  to authenticated
  using (user_id = auth.uid() or private.is_admin());

-- Modifications restricted to security definer RPCs and service_role
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 2. Table: public.usage_events (Audit & Time-Series Telemetry)
-- -----------------------------------------------------------------------------
create table if not exists public.usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  service_type text not null check (service_type in ('ai_tokens', 'tts_chars', 'stt_seconds', 'storage_bytes')),
  quantity int not null check (quantity > 0),
  provider text not null default 'internal',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- Covering indexes for foreign keys, queries, and time-series aggregation
create index if not exists idx_usage_events_user_id on public.usage_events (user_id);
create index if not exists idx_usage_events_service_type_time on public.usage_events (service_type, created_at desc);
create index if not exists idx_usage_events_created_at on public.usage_events (created_at desc);

-- RLS Enforcement
alter table public.usage_events enable row level security;

revoke all on table public.usage_events from public, anon;
grant select on table public.usage_events to authenticated, service_role;

-- Policies: Users read own events; Admins read all
create policy usage_events_select_policy on public.usage_events
  for select
  to authenticated
  using (user_id = auth.uid() or private.is_admin());

-- -----------------------------------------------------------------------------
-- 3. Atomic Quota Metering & Verification RPC
-- -----------------------------------------------------------------------------
create or replace function public.check_and_record_usage(
  p_service_type text,
  p_quantity int,
  p_provider text default 'internal',
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_quota record;
  v_allowed boolean;
  v_remaining int;
  v_now timestamptz := timezone('utc'::text, now());
  v_tier text;
  v_ai_limit int;
  v_tts_limit int;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantity must be positive' using errcode = '22023';
  end if;

  -- Advisory lock per user to serialize concurrent calls
  perform pg_advisory_xact_lock(hashtext('usage_quota_' || v_uid::text));

  -- Resolve appropriate default tier and limits if inserting
  if private.is_admin() then
    v_tier := 'admin';
    v_ai_limit := 250000;
    v_tts_limit := 100000;
  else
    v_tier := 'learner';
    v_ai_limit := 15000;
    v_tts_limit := 10000;
  end if;

  -- Ensure quota row exists
  insert into public.usage_quotas (
    user_id, service_tier, ai_tokens_daily_limit, tts_chars_daily_limit
  )
  values (
    v_uid, v_tier, v_ai_limit, v_tts_limit
  )
  on conflict (user_id) do nothing;

  -- Fetch current quota row
  select * into v_quota
    from public.usage_quotas
   where user_id = v_uid;

  -- Check if rolling daily window has expired; reset if so
  if v_now >= v_quota.window_reset_at then
    update public.usage_quotas
       set ai_tokens_used_today = 0,
           tts_chars_used_today = 0,
           window_reset_at = v_now + interval '1 day',
           updated_at = v_now
     where user_id = v_uid
     returning * into v_quota;
  end if;

  -- Evaluate quota allowance based on service type
  if p_service_type = 'ai_tokens' then
    if (v_quota.ai_tokens_used_today + p_quantity) <= v_quota.ai_tokens_daily_limit then
      v_allowed := true;
      v_remaining := v_quota.ai_tokens_daily_limit - (v_quota.ai_tokens_used_today + p_quantity);
      update public.usage_quotas
         set ai_tokens_used_today = ai_tokens_used_today + p_quantity,
             updated_at = v_now
       where user_id = v_uid;
    else
      v_allowed := false;
      v_remaining := greatest(0, v_quota.ai_tokens_daily_limit - v_quota.ai_tokens_used_today);
    end if;

  elsif p_service_type = 'tts_chars' then
    if (v_quota.tts_chars_used_today + p_quantity) <= v_quota.tts_chars_daily_limit then
      v_allowed := true;
      v_remaining := v_quota.tts_chars_daily_limit - (v_quota.tts_chars_used_today + p_quantity);
      update public.usage_quotas
         set tts_chars_used_today = tts_chars_used_today + p_quantity,
             updated_at = v_now
       where user_id = v_uid;
    else
      v_allowed := false;
      v_remaining := greatest(0, v_quota.tts_chars_daily_limit - v_quota.tts_chars_used_today);
    end if;

  elsif p_service_type = 'storage_bytes' then
    if (v_quota.storage_bytes_used + p_quantity) <= v_quota.storage_bytes_limit then
      v_allowed := true;
      v_remaining := (v_quota.storage_bytes_limit - (v_quota.storage_bytes_used + p_quantity))::int;
      update public.usage_quotas
         set storage_bytes_used = storage_bytes_used + p_quantity,
             updated_at = v_now
       where user_id = v_uid;
    else
      v_allowed := false;
      v_remaining := greatest(0, (v_quota.storage_bytes_limit - v_quota.storage_bytes_used))::int;
    end if;

  else
    raise exception 'Unsupported service type: %', p_service_type using errcode = '22023';
  end if;

  -- Record audit event if allowed
  if v_allowed then
    insert into public.usage_events (user_id, service_type, quantity, provider, metadata, created_at)
    values (v_uid, p_service_type, p_quantity, p_provider, p_metadata, v_now);
  end if;

  return jsonb_build_object(
    'allowed', v_allowed,
    'service_type', p_service_type,
    'quantity_requested', p_quantity,
    'remaining_balance', v_remaining,
    'window_reset_at', v_quota.window_reset_at
  );
end;
$$;

revoke all on function public.check_and_record_usage(text, int, text, jsonb) from public, anon;
grant execute on function public.check_and_record_usage(text, int, text, jsonb) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. Administrative Observability Telemetry Aggregation RPC
-- -----------------------------------------------------------------------------
create or replace function public.get_system_usage_telemetry(p_hours int default 24)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_since timestamptz;
  v_ai_tokens bigint := 0;
  v_tts_chars bigint := 0;
  v_storage_bytes bigint := 0;
  v_active_users bigint := 0;
  v_total_events bigint := 0;
begin
  -- Access Guard: Only administrators may access aggregate system costs & telemetry
  if not private.is_admin() then
    raise exception 'Access denied: administrator privileges required' using errcode = '42501';
  end if;

  if p_hours <= 0 or p_hours > 720 then
    p_hours := 24;
  end if;

  v_since := timezone('utc'::text, now()) - (p_hours || ' hours')::interval;

  select coalesce(sum(quantity) filter (where service_type = 'ai_tokens'), 0),
         coalesce(sum(quantity) filter (where service_type = 'tts_chars'), 0),
         count(distinct user_id),
         count(*)
    into v_ai_tokens, v_tts_chars, v_active_users, v_total_events
    from public.usage_events
   where created_at >= v_since;

  select coalesce(sum(storage_bytes_used), 0)
    into v_storage_bytes
    from public.usage_quotas;

  return jsonb_build_object(
    'window_hours', p_hours,
    'since', v_since,
    'total_ai_tokens', v_ai_tokens,
    'total_tts_chars', v_tts_chars,
    'total_storage_bytes', v_storage_bytes,
    'active_users', v_active_users,
    'total_events', v_total_events,
    'estimated_cost_usd', round(
      ((v_ai_tokens::numeric / 1000000.0) * 0.15) + -- $0.15 per 1M tokens
      ((v_tts_chars::numeric / 1000000.0) * 16.0) + -- $16.00 per 1M TTS chars
      ((v_storage_bytes::numeric / (1024.0 * 1024.0 * 1024.0)) * 0.021), -- $0.021 per GB
      4
    )
  );
end;
$$;

revoke all on function public.get_system_usage_telemetry(int) from public, anon;
grant execute on function public.get_system_usage_telemetry(int) to authenticated, service_role;
