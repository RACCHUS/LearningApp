-- =============================================================================
-- Migration 54: Quota Usage-Event Hardening (Provider String Bounding)
-- Description:
--   Hardens public.check_and_record_usage against resource-exhaustion and
--   amplification attacks via oversized or empty p_provider text values.
--   Enforces a strict upper bound of 64 characters and non-empty constraint,
--   raising SQL state 22023 on violations.
-- =============================================================================

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

  -- Guard 0: Provider identifier length and non-empty bound (prevent unbounded string / amplification)
  if p_provider is null or length(trim(p_provider)) = 0 or length(p_provider) > 64 then
    raise exception 'Provider identifier must be non-empty and at most 64 characters' using errcode = '22023';
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
