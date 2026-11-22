-- Prompt-pack feedback signals 3-5 (master plan v2.6 §5.7.6).
--
-- Signal 3: source/rights assessments and optional volunteer or owner
--   review evidence per lesson (accuracy, accessibility, rights), recorded
--   by moderators. No paid reviewer is assumed; each row says who looked
--   (source check, volunteer, owner) and what they found.
-- Signal 4: downstream evidence. For AI-generated lessons a learner added
--   to a goal topic, how that learner's later checks on the same topic's
--   published (non-generated) lessons went. Derived at report time from
--   progress the app already syncs; nothing new is stored. Counted only
--   for accounts whose prompt-quality opt-in covers it (consent scope 2,
--   given with the wording that names it); earlier opt-ins (scope 1) are
--   never widened silently. Groups under 5 accounts are suppressed.
-- Signal 5: maintainer golden runs, recorded by an admin after running the
--   golden suite by hand in a free chat: pack version, AI label, cases
--   passed of total.
--
-- Owner report get_prompt_pack_signals combines all five per pack version.

-- ---------------------------------------------------------------- consent scope
ALTER TABLE analytics.prompt_quality_consents
  ADD COLUMN IF NOT EXISTS scope smallint NOT NULL DEFAULT 1 CHECK (scope IN (1, 2));

CREATE OR REPLACE FUNCTION public.set_prompt_quality_consent(p_consent boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
BEGIN
  IF v_user IS NULL OR p_consent IS NULL THEN
    RAISE EXCEPTION 'Authenticated user and explicit choice required'
      USING ERRCODE = '42501';
  END IF;
  -- Withdrawing always works; opting in needs the switch and base consent.
  IF p_consent AND (NOT private.site_feature_enabled('analytics.prompt_quality')
                    OR NOT analytics.prompt_quality_base_ok(v_user)) THEN
    RAISE EXCEPTION 'Prompt-quality sharing is not available for this account'
      USING ERRCODE = '42501';
  END IF;
  -- Opting in now is given with the wording that includes later checks
  -- (scope 2). Withdrawing keeps the row as a refusal.
  INSERT INTO analytics.prompt_quality_consents (user_id, consented, changed_at, scope)
  VALUES (v_user, p_consent, now(), CASE WHEN p_consent THEN 2 ELSE 1 END)
  ON CONFLICT (user_id) DO UPDATE
    SET consented = EXCLUDED.consented, changed_at = EXCLUDED.changed_at,
        scope = EXCLUDED.scope;
  IF NOT p_consent THEN
    DELETE FROM analytics.prompt_quality_events WHERE user_id = v_user;
  END IF;
  RETURN jsonb_build_object('consented', p_consent, 'scope', CASE WHEN p_consent THEN 2 ELSE 1 END);
END;
$$;
REVOKE ALL ON FUNCTION public.set_prompt_quality_consent(boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_prompt_quality_consent(boolean) TO authenticated;

-- Status also reports the scope, so the app can offer the newer wording to
-- learners who opted in before it existed.
CREATE OR REPLACE FUNCTION public.get_prompt_quality_status()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_enabled boolean := private.site_feature_enabled('analytics.prompt_quality');
  v_consent boolean;
  v_scope smallint;
  v_stored integer;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('enabled', false, 'available', false,
                              'consented', false, 'stored_events', 0, 'scope', 0);
  END IF;
  SELECT c.consented, c.scope INTO v_consent, v_scope
  FROM analytics.prompt_quality_consents c WHERE c.user_id = v_user;
  SELECT count(*)::integer INTO v_stored
  FROM analytics.prompt_quality_events e WHERE e.user_id = v_user;
  RETURN jsonb_build_object(
    'enabled', v_enabled,
    'available', v_enabled AND analytics.prompt_quality_base_ok(v_user),
    -- Reported whatever the switch says, so withdrawal is always possible.
    'consented', coalesce(v_consent, false),
    'scope', CASE WHEN coalesce(v_consent, false) THEN v_scope ELSE 0 END,
    'stored_events', v_stored);
END;
$$;
REVOKE ALL ON FUNCTION public.get_prompt_quality_status() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_prompt_quality_status() TO authenticated;

-- ---------------------------------------------------------------- signal 3
CREATE TABLE IF NOT EXISTS private.content_review_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  aspect text NOT NULL CHECK (aspect IN ('accuracy','accessibility','rights')),
  outcome text NOT NULL CHECK (outcome IN ('ok','concern')),
  reviewer_kind text NOT NULL CHECK (reviewer_kind IN ('source_check','volunteer','owner')),
  note text CHECK (note IS NULL OR char_length(note) <= 500),
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS content_review_evidence_lesson_idx
  ON private.content_review_evidence (lesson_id, recorded_at DESC);
ALTER TABLE private.content_review_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.content_review_evidence FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_content_review_evidence(
  p_lesson_id uuid, p_aspect text, p_outcome text, p_reviewer_kind text, p_note text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_id uuid;
BEGIN
  IF v_user IS NULL OR NOT private.is_moderator() THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_aspect NOT IN ('accuracy','accessibility','rights')
     OR p_outcome NOT IN ('ok','concern')
     OR p_reviewer_kind NOT IN ('source_check','volunteer','owner') THEN
    RAISE EXCEPTION 'Unknown aspect, outcome or reviewer kind' USING ERRCODE = '22023';
  END IF;
  -- "Owner" review can only be recorded by the owner (an admin).
  IF p_reviewer_kind = 'owner' AND NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Only the owner can record owner review' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.lessons l WHERE l.id = p_lesson_id) THEN
    RAISE EXCEPTION 'Lesson not found' USING ERRCODE = '22023';
  END IF;
  INSERT INTO private.content_review_evidence
    (lesson_id, aspect, outcome, reviewer_kind, note, recorded_by)
  VALUES (p_lesson_id, p_aspect, p_outcome, p_reviewer_kind,
          nullif(btrim(left(p_note, 500)), ''), v_user)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.record_content_review_evidence(uuid, text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_content_review_evidence(uuid, text, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_content_review_evidence(p_lesson_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT private.is_moderator() THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'aspect', e.aspect, 'outcome', e.outcome, 'reviewer_kind', e.reviewer_kind,
      'note', e.note, 'recorded_at', e.recorded_at) ORDER BY e.recorded_at DESC)
    FROM private.content_review_evidence e WHERE e.lesson_id = p_lesson_id), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.get_content_review_evidence(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_content_review_evidence(uuid) TO authenticated;

-- ---------------------------------------------------------------- signal 5
CREATE TABLE IF NOT EXISTS private.prompt_golden_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_version text NOT NULL CHECK (pack_version ~ '^[a-z0-9][a-z0-9.-]{0,39}$'),
  ai_label text NOT NULL
    CHECK (ai_label IN ('chatgpt','gemini','claude','copilot','other','not_sure')),
  cases_total smallint NOT NULL CHECK (cases_total BETWEEN 1 AND 200),
  cases_passed smallint NOT NULL CHECK (cases_passed >= 0 AND cases_passed <= cases_total),
  run_on date NOT NULL CHECK (run_on <= current_date + 1),
  note text CHECK (note IS NULL OR char_length(note) <= 500),
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS prompt_golden_runs_pack_idx
  ON private.prompt_golden_runs (pack_version, ai_label, run_on DESC);
ALTER TABLE private.prompt_golden_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.prompt_golden_runs FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_prompt_golden_run(
  p_pack_version text, p_ai_label text, p_cases_total integer, p_cases_passed integer,
  p_run_on date DEFAULT NULL, p_note text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_id uuid;
BEGIN
  IF v_user IS NULL OR NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO private.prompt_golden_runs
    (pack_version, ai_label, cases_total, cases_passed, run_on, note, recorded_by)
  VALUES (p_pack_version, p_ai_label, p_cases_total, p_cases_passed,
          coalesce(p_run_on, current_date), nullif(btrim(left(p_note, 500)), ''), v_user)
  RETURNING id INTO v_id;
  RETURN v_id;
EXCEPTION WHEN check_violation THEN
  RAISE EXCEPTION 'Invalid golden run' USING ERRCODE = '22023';
END;
$$;
REVOKE ALL ON FUNCTION public.record_prompt_golden_run(text, text, integer, integer, date, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_prompt_golden_run(text, text, integer, integer, date, text) TO authenticated;

-- ---------------------------------------------------------------- report
-- The pack version a lesson was generated with, from its prompt-pack-* tag.
CREATE OR REPLACE FUNCTION private.lesson_prompt_pack(p_tags text[])
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT substring(t FROM 13) FROM unnest(coalesce(p_tags, '{}')) t
  WHERE t ~ '^prompt-pack-[a-z0-9][a-z0-9.-]{0,39}$' LIMIT 1;
$$;
REVOKE ALL ON FUNCTION private.lesson_prompt_pack(text[]) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_prompt_pack_signals(p_days integer DEFAULT 90)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_golden jsonb;
  v_review jsonb;
  v_downstream jsonb;
BEGIN
  IF v_user IS NULL OR NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_days IS NULL OR p_days NOT IN (30, 90, 365) THEN
    RAISE EXCEPTION 'Unsupported window' USING ERRCODE = '22023';
  END IF;

  -- Signal 5: every golden run in the window, newest first.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'pack_version', g.pack_version, 'ai_label', g.ai_label, 'run_on', g.run_on,
           'cases_total', g.cases_total, 'cases_passed', g.cases_passed,
           'pass_rate', round(g.cases_passed::numeric / g.cases_total, 3), 'note', g.note)
         ORDER BY g.run_on DESC, g.recorded_at DESC), '[]'::jsonb)
  INTO v_golden
  FROM private.prompt_golden_runs g
  WHERE g.run_on >= current_date - p_days;

  -- Signal 3: review evidence on AI-generated lessons, per pack and aspect.
  -- Reviewer notes are moderator text about content, never learner data.
  SELECT coalesce(jsonb_agg(r ORDER BY r->>'pack_version', r->>'aspect'), '[]'::jsonb)
  INTO v_review
  FROM (
    SELECT jsonb_build_object(
      'pack_version', x.pack, 'aspect', x.aspect,
      'lessons', count(DISTINCT x.lesson_id),
      'ok', count(*) FILTER (WHERE x.outcome = 'ok'),
      'concern', count(*) FILTER (WHERE x.outcome = 'concern')) AS r
    FROM (
      SELECT coalesce(private.lesson_prompt_pack(l.tags), 'unknown') AS pack,
             e.aspect, e.lesson_id, e.outcome
      FROM private.content_review_evidence e
      JOIN public.lessons l ON l.id = e.lesson_id
      WHERE 'ai-generated' = ANY (coalesce(l.tags, '{}'))
        AND e.recorded_at >= now() - make_interval(days => p_days)
    ) x
    GROUP BY x.pack, x.aspect
  ) s;

  -- Signal 4: later checks on the same topic after using a generated lesson.
  WITH used AS (
    SELECT r.user_id, r.curriculum_node_id,
           coalesce(private.lesson_prompt_pack(l.tags), 'unknown') AS pack,
           min(p.date) AS first_used
    FROM public.user_curriculum_resources r
    JOIN public.lessons l ON l.id = r.lesson_id AND 'ai-generated' = ANY (coalesce(l.tags, '{}'))
    JOIN public.user_progress p ON p.user_id = r.user_id AND p.lesson_id = r.lesson_id
    JOIN analytics.prompt_quality_consents c
      ON c.user_id = r.user_id AND c.consented AND c.scope >= 2
    WHERE p.date >= current_date - p_days
      AND analytics.prompt_quality_base_ok(r.user_id)
    GROUP BY 1, 2, 3
  ), later AS (
    SELECT u.pack, u.user_id,
           sum(p.questions_answered) AS answered, sum(p.correct_count) AS correct
    FROM used u
    JOIN public.curriculum_node_lessons cnl ON cnl.curriculum_node_id = u.curriculum_node_id
    JOIN public.lessons l2 ON l2.id = cnl.lesson_id
      AND NOT ('ai-generated' = ANY (coalesce(l2.tags, '{}')))
    JOIN public.user_progress p ON p.user_id = u.user_id AND p.lesson_id = cnl.lesson_id
      AND p.date >= u.first_used AND p.questions_answered > 0
    GROUP BY 1, 2
  )
  SELECT coalesce(jsonb_agg(d ORDER BY d->>'pack_version'), '[]'::jsonb) INTO v_downstream
  FROM (
    SELECT CASE WHEN count(*) < 5
      THEN jsonb_build_object('pack_version', pack, 'status', 'small_cohort_suppressed')
      ELSE jsonb_build_object('pack_version', pack, 'status', 'measured',
        'accounts', count(*), 'answered', sum(answered),
        'later_check_accuracy', round(sum(correct)::numeric / nullif(sum(answered), 0), 3))
      END AS d
    FROM later
    GROUP BY pack
  ) s;

  RETURN jsonb_build_object(
    'window_days', p_days, 'as_of', now(),
    'golden_runs', v_golden,
    'review_evidence', v_review,
    'downstream', v_downstream,
    'downstream_coverage', 'scope_2_opted_in_eligible_accounts_only; not a controlled comparison');
END;
$$;
REVOKE ALL ON FUNCTION public.get_prompt_pack_signals(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_prompt_pack_signals(integer) TO authenticated, service_role;
