-- ECO-00C Hardening: Usage Quotas & Event Table Protection, STT Metering, and Abuse Prevention
-- Migration Version: 20261022000000

-- -----------------------------------------------------------------------------
-- 1. Defense-in-Depth: Explicitly Revoke Direct Write Grants on Usage Tables
-- -----------------------------------------------------------------------------
-- Tables are protected by RLS, but revoking insert/update/delete from authenticated,
-- anon, and public ensures that ordinary clients can only mutate usage via security definer RPCs.
revoke insert, update, delete on table public.usage_quotas from authenticated, anon, public;
revoke insert, update, delete on table public.usage_events from authenticated, anon, public;

-- -----------------------------------------------------------------------------
-- 2. Schema Additions: STT Quota & Daily Event Frequency Bounds
-- -----------------------------------------------------------------------------
alter table public.usage_quotas
  add column if not exists stt_seconds_used_today int not null default 0 check (stt_seconds_used_today >= 0),
  add column if not exists stt_seconds_daily_limit int not null default 3600 check (stt_seconds_daily_limit > 0),
  add column if not exists events_recorded_today int not null default 0 check (events_recorded_today >= 0),
  add column if not exists events_daily_limit int not null default 1000 check (events_daily_limit > 0);

-- Index for per-user event time-series telemetry lookups
create index if not exists idx_usage_events_user_created_at
  on public.usage_events (user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- 3. Hardened Atomic Quota Metering & Abuse-Prevention RPC
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
  v_now timestamptz := now();
  v_tier text;
  v_ai_limit int;
  v_tts_limit int;
  v_stt_limit int;
  v_events_limit int;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantity must be positive' using errcode = '22023';
  end if;

  -- Guard 1: Metadata payload size limit (max 4KB text representation to prevent disk bloat)
  if octet_length(p_metadata::text) > 4096 then
    raise exception 'Usage event metadata exceeds maximum allowed payload size (4KB)' using errcode = '22023';
  end if;

  -- Guard 2: Minimum allocation boundary for storage (prevent 1-byte micro-event table amplification)
  if p_service_type = 'storage_bytes' and p_quantity < 1024 then
    raise exception 'Storage allocation must be at least 1024 bytes (1 KB)' using errcode = '22023';
  end if;

  -- Advisory lock per user to serialize concurrent calls
  perform pg_advisory_xact_lock(hashtext('usage_quota_' || v_uid::text));

  -- Resolve appropriate default tier and limits if inserting
  if private.is_admin() then
    v_tier := 'admin';
    v_ai_limit := 250000;
    v_tts_limit := 100000;
    v_stt_limit := 36000; -- 10 hours
    v_events_limit := 10000;
  else
    v_tier := 'learner';
    v_ai_limit := 15000;
    v_tts_limit := 10000;
    v_stt_limit := 3600;  -- 1 hour
    v_events_limit := 1000;
  end if;

  -- Ensure quota row exists with all columns populated
  insert into public.usage_quotas (
    user_id, service_tier, ai_tokens_daily_limit, tts_chars_daily_limit,
    stt_seconds_daily_limit, events_daily_limit
  )
  values (
    v_uid, v_tier, v_ai_limit, v_tts_limit, v_stt_limit, v_events_limit
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
           stt_seconds_used_today = 0,
           events_recorded_today = 0,
           window_reset_at = v_now + interval '1 day',
           updated_at = v_now
     where user_id = v_uid
     returning * into v_quota;
  end if;

  -- Guard 3: Daily event logging ceiling (prevent event log amplification)
  if v_quota.events_recorded_today >= v_quota.events_daily_limit then
    raise exception 'Daily usage event logging limit exceeded: maximum allowed frequency reached' using errcode = '42900';
  end if;

  -- Evaluate quota allowance based on service type
  if p_service_type = 'ai_tokens' then
    if (v_quota.ai_tokens_used_today + p_quantity) <= v_quota.ai_tokens_daily_limit then
      v_allowed := true;
      v_remaining := v_quota.ai_tokens_daily_limit - (v_quota.ai_tokens_used_today + p_quantity);
      update public.usage_quotas
         set ai_tokens_used_today = ai_tokens_used_today + p_quantity,
             events_recorded_today = events_recorded_today + 1,
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
             events_recorded_today = events_recorded_today + 1,
             updated_at = v_now
       where user_id = v_uid;
    else
      v_allowed := false;
      v_remaining := greatest(0, v_quota.tts_chars_daily_limit - v_quota.tts_chars_used_today);
    end if;

  elsif p_service_type = 'stt_seconds' then
    if (v_quota.stt_seconds_used_today + p_quantity) <= v_quota.stt_seconds_daily_limit then
      v_allowed := true;
      v_remaining := v_quota.stt_seconds_daily_limit - (v_quota.stt_seconds_used_today + p_quantity);
      update public.usage_quotas
         set stt_seconds_used_today = stt_seconds_used_today + p_quantity,
             events_recorded_today = events_recorded_today + 1,
             updated_at = v_now
       where user_id = v_uid;
    else
      v_allowed := false;
      v_remaining := greatest(0, v_quota.stt_seconds_daily_limit - v_quota.stt_seconds_used_today);
    end if;

  elsif p_service_type = 'storage_bytes' then
    if (v_quota.storage_bytes_used + p_quantity) <= v_quota.storage_bytes_limit then
      v_allowed := true;
      v_remaining := (v_quota.storage_bytes_limit - (v_quota.storage_bytes_used + p_quantity))::int;
      update public.usage_quotas
         set storage_bytes_used = storage_bytes_used + p_quantity,
             events_recorded_today = events_recorded_today + 1,
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
-- 4. Hardened System Usage Telemetry Aggregation RPC
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
  v_stt_seconds bigint := 0;
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

  v_since := now() - (p_hours || ' hours')::interval;

  select coalesce(sum(quantity) filter (where service_type = 'ai_tokens'), 0),
         coalesce(sum(quantity) filter (where service_type = 'tts_chars'), 0),
         coalesce(sum(quantity) filter (where service_type = 'stt_seconds'), 0),
         count(distinct user_id),
         count(*)
    into v_ai_tokens, v_tts_chars, v_stt_seconds, v_active_users, v_total_events
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
    'total_stt_seconds', v_stt_seconds,
    'total_storage_bytes', v_storage_bytes,
    'active_users', v_active_users,
    'total_events', v_total_events,
    'estimated_cost_usd', round(
      ((v_ai_tokens::numeric / 1000000.0) * 0.15) + -- $0.15 per 1M blended tokens
      ((v_tts_chars::numeric / 1000000.0) * 16.0) +  -- $16.00 per 1M Cloud TTS chars
      ((v_stt_seconds::numeric / 3600.0) * 0.36) +   -- $0.36 per hour ($0.006/min) Cloud STT
      ((v_storage_bytes::numeric / (1024.0 * 1024.0 * 1024.0)) * 0.021), -- $0.021 per GB-month
      4
    )
  );
end;
$$;

revoke all on function public.get_system_usage_telemetry(int) from public, anon;
grant execute on function public.get_system_usage_telemetry(int) to authenticated, service_role;
