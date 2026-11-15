-- Study reminders delivered by Web Push.
--
-- The legacy public.reminders table (20241228000000) never matched the client
-- model and references public.users, and the client scheduled reminders with
-- a native-only plugin that does nothing on the web, so no reminder was ever
-- delivered. This replaces it with a server-scheduled design. The legacy
-- table is left untouched (append-only migrations).
--
-- * New gate `learning.study_reminders`, default OFF, not release-ready.
-- * study_reminders: a local time, ISO weekdays (1 = Monday) and an IANA
--   time zone. The server computes next_fire_at; browsers never write it.
-- * push_subscriptions: one row per browser that opted in. Endpoint and
--   keys are personal data: owner-read only, removed with the account.
-- * Browsers write only through gated RPCs. Delivery is done by the
--   send-study-reminders Edge Function with the service role, which claims
--   due reminders at most once and reports each push result.
-- * Gate OFF: browser RPCs are refused and claim_due_study_reminders returns
--   nothing, so a scheduled run sends no pushes and costs nothing beyond
--   the empty query.
-- Additive only.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.study_reminders', 'Study reminders (web push)', 'Learning', 'release', false, 'experimental', false,
  'Opt-in study reminders sent as browser push notifications at times the learner chooses')
ON CONFLICT (feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.study_reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  local_time time NOT NULL,
  days_of_week smallint[] NOT NULL CHECK (
    cardinality(days_of_week) BETWEEN 1 AND 7
    AND days_of_week <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::smallint[]
  ),
  timezone text NOT NULL CHECK (char_length(timezone) BETWEEN 1 AND 64),
  is_active boolean NOT NULL DEFAULT true,
  next_fire_at timestamptz,
  last_sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS study_reminders_due_idx
  ON public.study_reminders (next_fire_at) WHERE is_active;
CREATE INDEX IF NOT EXISTS study_reminders_user_idx
  ON public.study_reminders (user_id);

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint text NOT NULL UNIQUE CHECK (
    endpoint ~ '^https://[^\s]+$' AND char_length(endpoint) <= 1000
  ),
  p256dh text NOT NULL CHECK (char_length(p256dh) BETWEEN 20 AND 200),
  auth_secret text NOT NULL CHECK (char_length(auth_secret) BETWEEN 8 AND 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  last_success_at timestamptz,
  failure_count integer NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS push_subscriptions_user_idx
  ON public.push_subscriptions (user_id);

ALTER TABLE public.study_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.study_reminders FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.push_subscriptions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.study_reminders TO authenticated;
GRANT SELECT ON TABLE public.push_subscriptions TO authenticated;
GRANT ALL ON TABLE public.study_reminders TO service_role;
GRANT ALL ON TABLE public.push_subscriptions TO service_role;

DROP POLICY IF EXISTS "Owners read study reminders" ON public.study_reminders;
CREATE POLICY "Owners read study reminders"
  ON public.study_reminders FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS "Owners read push subscriptions" ON public.push_subscriptions;
CREATE POLICY "Owners read push subscriptions"
  ON public.push_subscriptions FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- Next instant strictly after p_after at which the reminder fires, computed
-- in the reminder's own time zone (so DST shifts follow local wall time).
CREATE OR REPLACE FUNCTION private.next_study_reminder_fire(
  p_local_time time,
  p_days smallint[],
  p_timezone text,
  p_after timestamptz
)
RETURNS timestamptz
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_day date := (p_after AT TIME ZONE p_timezone)::date;
  v_candidate timestamptz;
BEGIN
  FOR i IN 0..7 LOOP
    IF extract(isodow FROM v_day + i)::smallint = ANY (p_days) THEN
      v_candidate := ((v_day + i) + p_local_time) AT TIME ZONE p_timezone;
      IF v_candidate > p_after THEN
        RETURN v_candidate;
      END IF;
    END IF;
  END LOOP;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION private.next_study_reminder_fire(time, smallint[], text, timestamptz)
  FROM PUBLIC, anon, authenticated;

-- Create (p_id NULL) or update one of the caller's reminders. At most 5.
CREATE OR REPLACE FUNCTION public.save_study_reminder(
  p_id uuid,
  p_local_time time,
  p_days smallint[],
  p_timezone text,
  p_is_active boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_days smallint[];
  v_row public.study_reminders%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING errcode = '42501';
  END IF;
  IF NOT private.site_feature_enabled('learning.study_reminders') THEN
    RAISE EXCEPTION 'feature_disabled' USING errcode = '42501';
  END IF;
  IF p_local_time IS NULL THEN
    RAISE EXCEPTION 'invalid_time' USING errcode = '22023';
  END IF;
  SELECT array_agg(DISTINCT d ORDER BY d) INTO v_days FROM unnest(p_days) AS d;
  IF v_days IS NULL OR NOT v_days <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::smallint[] THEN
    RAISE EXCEPTION 'invalid_days' USING errcode = '22023';
  END IF;
  IF p_timezone IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name = p_timezone) THEN
    RAISE EXCEPTION 'invalid_timezone' USING errcode = '22023';
  END IF;

  IF p_id IS NULL THEN
    IF (SELECT count(*) FROM public.study_reminders WHERE user_id = v_uid) >= 5 THEN
      RAISE EXCEPTION 'reminder_limit' USING errcode = '54000';
    END IF;
    INSERT INTO public.study_reminders (user_id, local_time, days_of_week, timezone, is_active)
    VALUES (v_uid, p_local_time, v_days, p_timezone, coalesce(p_is_active, true))
    RETURNING * INTO v_row;
  ELSE
    UPDATE public.study_reminders
       SET local_time = p_local_time,
           days_of_week = v_days,
           timezone = p_timezone,
           is_active = coalesce(p_is_active, true),
           updated_at = now()
     WHERE id = p_id AND user_id = v_uid
    RETURNING * INTO v_row;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found' USING errcode = 'P0002';
    END IF;
  END IF;

  UPDATE public.study_reminders
     SET next_fire_at = CASE WHEN v_row.is_active
           THEN private.next_study_reminder_fire(v_row.local_time, v_row.days_of_week,
                                                 v_row.timezone, now())
           ELSE NULL END
   WHERE id = v_row.id
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row) - 'user_id';
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_study_reminder(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING errcode = '42501';
  END IF;
  -- Deleting is allowed with the gate OFF so learners can always clean up.
  DELETE FROM public.study_reminders WHERE id = p_id AND user_id = v_uid;
END;
$$;

-- Register this browser for the caller. An endpoint belongs to one browser,
-- so re-registering it under another account moves it to that account.
CREATE OR REPLACE FUNCTION public.register_push_subscription(
  p_endpoint text,
  p_p256dh text,
  p_auth text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING errcode = '42501';
  END IF;
  IF NOT private.site_feature_enabled('learning.study_reminders') THEN
    RAISE EXCEPTION 'feature_disabled' USING errcode = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.push_subscriptions WHERE endpoint = p_endpoint)
     AND (SELECT count(*) FROM public.push_subscriptions WHERE user_id = v_uid) >= 10 THEN
    RAISE EXCEPTION 'subscription_limit' USING errcode = '54000';
  END IF;
  INSERT INTO public.push_subscriptions (user_id, endpoint, p256dh, auth_secret)
  VALUES (v_uid, p_endpoint, p_p256dh, p_auth)
  ON CONFLICT (endpoint) DO UPDATE
     SET user_id = excluded.user_id,
         p256dh = excluded.p256dh,
         auth_secret = excluded.auth_secret,
         failure_count = 0;
END;
$$;

CREATE OR REPLACE FUNCTION public.unregister_push_subscription(p_endpoint text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING errcode = '42501';
  END IF;
  DELETE FROM public.push_subscriptions WHERE endpoint = p_endpoint AND user_id = v_uid;
END;
$$;

-- Service role only. Claims due reminders at most once: each claimed row's
-- next_fire_at moves to its next occurrence in the same statement, and
-- SKIP LOCKED keeps overlapping runs from claiming the same row. A reminder
-- more than 30 minutes late (scheduler outage) is advanced without sending.
CREATE OR REPLACE FUNCTION public.claim_due_study_reminders(p_limit integer DEFAULT 200)
RETURNS TABLE (reminder_id uuid, subscription_id uuid, endpoint text, p256dh text, auth_secret text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT private.site_feature_enabled('learning.study_reminders') THEN
    RETURN;
  END IF;
  RETURN QUERY
  WITH due AS (
    SELECT r.id, r.user_id, r.next_fire_at AS due_at
      FROM public.study_reminders r
     WHERE r.is_active AND r.next_fire_at <= now()
     ORDER BY r.next_fire_at
     LIMIT greatest(1, least(coalesce(p_limit, 200), 1000))
       FOR UPDATE SKIP LOCKED
  ), advanced AS (
    UPDATE public.study_reminders r
       SET next_fire_at = private.next_study_reminder_fire(
             r.local_time, r.days_of_week, r.timezone, now()),
           last_sent_at = CASE WHEN due.due_at > now() - interval '30 minutes'
                               THEN now() ELSE r.last_sent_at END
      FROM due
     WHERE r.id = due.id
    RETURNING r.id, r.user_id, due.due_at
  )
  SELECT a.id, s.id, s.endpoint, s.p256dh, s.auth_secret
    FROM advanced a
    JOIN public.push_subscriptions s ON s.user_id = a.user_id
   WHERE a.due_at > now() - interval '30 minutes';
END;
$$;

-- Service role only. 2xx clears failures; 404/410 (subscription gone)
-- deletes it; anything else counts a failure and deletes after 5 in a row.
CREATE OR REPLACE FUNCTION public.record_push_delivery(
  p_subscription_id uuid,
  p_http_status integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_http_status BETWEEN 200 AND 299 THEN
    UPDATE public.push_subscriptions
       SET last_success_at = now(), failure_count = 0
     WHERE id = p_subscription_id;
  ELSIF p_http_status IN (404, 410) THEN
    DELETE FROM public.push_subscriptions WHERE id = p_subscription_id;
  ELSE
    UPDATE public.push_subscriptions
       SET failure_count = failure_count + 1
     WHERE id = p_subscription_id;
    DELETE FROM public.push_subscriptions
     WHERE id = p_subscription_id AND failure_count >= 5;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.save_study_reminder(uuid, time, smallint[], text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_study_reminder(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.register_push_subscription(text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unregister_push_subscription(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_study_reminder(uuid, time, smallint[], text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_study_reminder(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_push_subscription(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unregister_push_subscription(text) TO authenticated;

REVOKE ALL ON FUNCTION public.claim_due_study_reminders(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_push_delivery(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_due_study_reminders(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_push_delivery(uuid, integer) TO service_role;
