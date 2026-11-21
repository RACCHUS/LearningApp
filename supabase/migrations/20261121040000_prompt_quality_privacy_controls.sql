-- Privacy review fixes for opt-in prompt-quality telemetry
-- (docs/privacy/PROMPT_QUALITY_PRIVACY_REVIEW.md).
--
-- 1. Withdrawal must stay reachable: get_prompt_quality_status now reports
--    the learner's own opt-in and stored-row count even while the switch is
--    off, so the app can always show "withdraw and delete".
-- 2. Right of access: export_my_prompt_quality_events returns the
--    learner's own rows (codes and counts only), newest first.

CREATE OR REPLACE FUNCTION public.get_prompt_quality_status()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_enabled boolean := private.site_feature_enabled('analytics.prompt_quality');
  v_consent boolean;
  v_stored integer;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('enabled', false, 'available', false,
                              'consented', false, 'stored_events', 0);
  END IF;
  SELECT c.consented INTO v_consent
  FROM analytics.prompt_quality_consents c WHERE c.user_id = v_user;
  SELECT count(*)::integer INTO v_stored
  FROM analytics.prompt_quality_events e WHERE e.user_id = v_user;
  RETURN jsonb_build_object(
    'enabled', v_enabled,
    'available', v_enabled AND analytics.prompt_quality_base_ok(v_user),
    -- Reported whatever the switch says, so withdrawal is always possible.
    'consented', coalesce(v_consent, false),
    'stored_events', v_stored);
END;
$$;
REVOKE ALL ON FUNCTION public.get_prompt_quality_status() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_prompt_quality_status() TO authenticated;

CREATE OR REPLACE FUNCTION public.export_my_prompt_quality_events()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_rows jsonb;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated user required' USING ERRCODE = '42501';
  END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'event_id', e.event_id, 'received_at', e.received_at,
           'pack_version', e.pack_version, 'ai_label', e.ai_label,
           'tier', e.tier, 'mode', e.mode, 'outcome', e.outcome,
           'error_code', e.error_code, 'requested', e.requested,
           'accepted', e.accepted, 'sentinel', e.sentinel)
         ORDER BY e.received_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM analytics.prompt_quality_events e
  WHERE e.user_id = v_user;
  RETURN jsonb_build_object('exported_at', now(), 'events', v_rows);
END;
$$;
REVOKE ALL ON FUNCTION public.export_my_prompt_quality_events() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.export_my_prompt_quality_events() TO authenticated;
