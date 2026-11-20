-- ai.managed: free AI lesson generation on LearningApp's own free-tier
-- Gemini key, used only while the free allowance lasts.
--
-- * The Edge Function `managed-ai-generate` holds the key (GEMINI_API_KEY
--   secret); browsers never see it. The key must belong to a Google project
--   WITHOUT billing, so the provider itself enforces a $0 ceiling.
-- * Every call is admitted here first: switch on, not paused, under the
--   shared daily cap and the per-learner daily cap. With the switch OFF the
--   function stops before any provider call (zero cost).
-- * When Gemini reports its daily quota is used up, or the shared cap is
--   reached, generation pauses until the next midnight Pacific time (when
--   Gemini's daily quotas reset) and learners are told why.
-- * Only counts are stored: no prompts, replies or lesson content.
--
-- The switch stays OFF. release_ready is set so the owner can turn it on
-- from the admin panel after setting the secret and deploying the function.

CREATE TABLE IF NOT EXISTS private.ai_managed_settings (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  per_user_daily_limit integer NOT NULL DEFAULT 10
    CHECK (per_user_daily_limit BETWEEN 0 AND 1000),
  shared_daily_limit integer NOT NULL DEFAULT 200
    CHECK (shared_daily_limit BETWEEN 0 AND 100000),
  paused_until timestamptz,
  pause_reason text CHECK (pause_reason IN ('provider_quota', 'shared_limit')),
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO private.ai_managed_settings (id) VALUES (true)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS private.ai_managed_usage (
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  usage_day date NOT NULL,
  requests integer NOT NULL DEFAULT 0 CHECK (requests >= 0),
  PRIMARY KEY (user_id, usage_day)
);

CREATE TABLE IF NOT EXISTS private.ai_managed_daily (
  usage_day date PRIMARY KEY,
  requests integer NOT NULL DEFAULT 0 CHECK (requests >= 0)
);

REVOKE ALL ON TABLE private.ai_managed_settings, private.ai_managed_usage,
  private.ai_managed_daily FROM PUBLIC, anon, authenticated;

-- Gemini's daily quotas reset at midnight Pacific time, so "today" is the
-- Pacific calendar day.
CREATE OR REPLACE FUNCTION private.ai_managed_day(p_at timestamptz DEFAULT now())
RETURNS date LANGUAGE sql STABLE SET search_path = ''
AS $$ SELECT (p_at AT TIME ZONE 'America/Los_Angeles')::date $$;

CREATE OR REPLACE FUNCTION private.ai_managed_next_reset(p_at timestamptz DEFAULT now())
RETURNS timestamptz LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT ((private.ai_managed_day(p_at) + 1)::timestamp
          AT TIME ZONE 'America/Los_Angeles')
$$;

REVOKE ALL ON FUNCTION private.ai_managed_day(timestamptz),
  private.ai_managed_next_reset(timestamptz) FROM PUBLIC, anon, authenticated;

-- What the signed-in learner sees before asking. No other user's data.
CREATE OR REPLACE FUNCTION public.ai_managed_status()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_settings private.ai_managed_settings;
  v_used integer;
  v_paused boolean;
BEGIN
  IF v_user IS NULL OR NOT private.site_feature_enabled('ai.managed') THEN
    RETURN jsonb_build_object('enabled', false);
  END IF;
  SELECT * INTO v_settings FROM private.ai_managed_settings WHERE id;
  SELECT coalesce(max(u.requests), 0) INTO v_used
  FROM private.ai_managed_usage u
  WHERE u.user_id = v_user AND u.usage_day = private.ai_managed_day();
  v_paused := v_settings.paused_until IS NOT NULL
              AND v_settings.paused_until > now();
  RETURN jsonb_build_object(
    'enabled', true,
    'paused', v_paused,
    'resumes_at', CASE WHEN v_paused THEN v_settings.paused_until END,
    'used_today', v_used,
    'daily_limit', v_settings.per_user_daily_limit,
    'remaining_today', greatest(v_settings.per_user_daily_limit - v_used, 0)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.ai_managed_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ai_managed_status() TO authenticated;

-- Admission for one provider call (Edge Function only). Counts the call
-- before it is made, so concurrent requests cannot overshoot the caps.
CREATE OR REPLACE FUNCTION public.ai_managed_admit(p_user uuid)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_settings private.ai_managed_settings;
  v_day date := private.ai_managed_day();
  v_shared integer;
  v_mine integer;
BEGIN
  IF p_user IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_signed_in');
  END IF;
  IF NOT private.site_feature_enabled('ai.managed') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'off');
  END IF;

  SELECT * INTO v_settings FROM private.ai_managed_settings WHERE id FOR UPDATE;
  IF v_settings.paused_until IS NOT NULL AND v_settings.paused_until > now() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'paused',
                              'resumes_at', v_settings.paused_until);
  END IF;

  INSERT INTO private.ai_managed_daily AS d (usage_day, requests)
  VALUES (v_day, 0) ON CONFLICT (usage_day) DO NOTHING;
  SELECT d.requests INTO v_shared FROM private.ai_managed_daily d
  WHERE d.usage_day = v_day FOR UPDATE;
  IF v_shared >= v_settings.shared_daily_limit THEN
    UPDATE private.ai_managed_settings
    SET paused_until = private.ai_managed_next_reset(), pause_reason = 'shared_limit',
        updated_at = now()
    WHERE id;
    RETURN jsonb_build_object('ok', false, 'code', 'paused',
                              'resumes_at', private.ai_managed_next_reset());
  END IF;

  INSERT INTO private.ai_managed_usage AS u (user_id, usage_day, requests)
  VALUES (p_user, v_day, 0) ON CONFLICT (user_id, usage_day) DO NOTHING;
  SELECT u.requests INTO v_mine FROM private.ai_managed_usage u
  WHERE u.user_id = p_user AND u.usage_day = v_day FOR UPDATE;
  IF v_mine >= v_settings.per_user_daily_limit THEN
    RETURN jsonb_build_object('ok', false, 'code', 'user_limit',
                              'resumes_at', private.ai_managed_next_reset());
  END IF;

  UPDATE private.ai_managed_daily SET requests = requests + 1 WHERE usage_day = v_day;
  UPDATE private.ai_managed_usage SET requests = requests + 1
  WHERE user_id = p_user AND usage_day = v_day;
  RETURN jsonb_build_object(
    'ok', true,
    'remaining_today', v_settings.per_user_daily_limit - v_mine - 1
  );
END;
$$;

-- A call that failed for a reason other than quota does not count.
CREATE OR REPLACE FUNCTION public.ai_managed_refund(p_user uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_day date := private.ai_managed_day();
BEGIN
  UPDATE private.ai_managed_usage SET requests = greatest(requests - 1, 0)
  WHERE user_id = p_user AND usage_day = v_day;
  UPDATE private.ai_managed_daily SET requests = greatest(requests - 1, 0)
  WHERE usage_day = v_day;
END;
$$;

-- Gemini said its daily free quota is used up: pause for everyone until
-- the next Pacific midnight, when that quota resets.
CREATE OR REPLACE FUNCTION public.ai_managed_record_quota_stop()
RETURNS timestamptz LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_until timestamptz := private.ai_managed_next_reset();
BEGIN
  UPDATE private.ai_managed_settings
  SET paused_until = v_until, pause_reason = 'provider_quota', updated_at = now()
  WHERE id;
  RETURN v_until;
END;
$$;

REVOKE ALL ON FUNCTION public.ai_managed_admit(uuid), public.ai_managed_refund(uuid),
  public.ai_managed_record_quota_stop() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ai_managed_admit(uuid), public.ai_managed_refund(uuid),
  public.ai_managed_record_quota_stop() TO service_role;

-- Ready for owner activation; still OFF.
WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'ai.managed' AND c.release_ready = false
  FOR UPDATE
),
changed AS (
  UPDATE private.site_feature_controls c
  SET release_ready = true,
      description = 'Free Gemini generation on a no-billing key; pauses when '
                    'the free daily quota or the shared cap is used up',
      revision = b.revision + 1, updated_at = now()
  FROM before b
  WHERE c.feature_key = b.feature_key
  RETURNING c.feature_key
)
INSERT INTO private.site_feature_change_audit
  (feature_key, actor_id, prior_enabled, next_enabled, prior_maturity,
   next_maturity, previous_revision, new_revision, reason)
SELECT b.feature_key, NULL, b.enabled, b.enabled, b.maturity, b.maturity,
       b.revision, b.revision + 1,
       'Server gate, caps and quota pause wired (migration 20261120010000); '
       'switch left OFF for owner activation'
FROM before b JOIN changed USING (feature_key);
