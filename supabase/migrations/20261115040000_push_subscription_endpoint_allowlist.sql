-- Study reminders: accept browser push subscriptions only for the real Web
-- Push services, matching the dispatcher's send-time check (PR #285), so an
-- arbitrary URL is never stored. Registration answers 'unsupported_push_service'
-- (22023) for anything else. Existing rows that fail the rule are removed.
-- Additive only; register_push_subscription keeps its signature and grants.

CREATE OR REPLACE FUNCTION private.is_trusted_push_endpoint(p_endpoint text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  -- https, no user info or port, one of: Google FCM (Chrome, Edge on
  -- Android, Opera, Brave), Mozilla, Apple, Windows Push (regional hosts).
  SELECT coalesce(
    p_endpoint ~ '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|web\.push\.apple\.com|[a-z0-9-]+\.notify\.windows\.com)/[^#[:space:]]*$',
    false)
$$;
REVOKE ALL ON FUNCTION private.is_trusted_push_endpoint(text) FROM PUBLIC, anon, authenticated;

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
  IF NOT private.is_trusted_push_endpoint(p_endpoint) THEN
    RAISE EXCEPTION 'unsupported_push_service' USING errcode = '22023';
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

DELETE FROM public.push_subscriptions
 WHERE NOT private.is_trusted_push_endpoint(endpoint);
