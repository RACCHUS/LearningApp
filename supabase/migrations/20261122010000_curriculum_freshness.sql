-- Curriculum freshness (master plan v2.6 §7.1–7.2, §7.5).
--
-- 1. private.target_version_freshness: volatility class, review-by date and
--    source pin for each curriculum target version. Set by the ingestion
--    tool while the version is a draft (from the manifest), backfilled here
--    for versions already published.
--      V0 timeless (36 months), V1 slow (24), V2 software/UI (9),
--      V3 regulated/official (review_by from the source release, required),
--      V4 fast-moving: not authored as durable lessons (refused).
-- 2. private.curriculum_refresh_items: an owner work queue. An item is
--    raised when review_by passes (raise_due_curriculum_refresh_items, run
--    daily) or when a pinned source changes upstream
--    (report_curriculum_source_change, from the scheduled source check).
--    One open item per version and reason. Raising an item changes nothing
--    learners see; a correction still goes through a new version.
-- 3. Admin-only list and resolve RPCs.

CREATE TABLE IF NOT EXISTS private.target_version_freshness (
  target_version_id uuid PRIMARY KEY REFERENCES public.target_versions(id) ON DELETE CASCADE,
  volatility_class text NOT NULL CHECK (volatility_class IN ('V0','V1','V2','V3')),
  review_by date NOT NULL,
  source_pin text CHECK (source_pin IS NULL OR char_length(source_pin) BETWEEN 1 AND 200),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE private.target_version_freshness ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.target_version_freshness FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.curriculum_refresh_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_version_id uuid NOT NULL REFERENCES public.target_versions(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (reason IN ('review_due','source_changed')),
  detail text CHECK (detail IS NULL OR char_length(detail) <= 500),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dismissed')),
  resolution_note text CHECK (resolution_note IS NULL OR char_length(resolution_note) <= 1000),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS curriculum_refresh_items_one_open
  ON private.curriculum_refresh_items (target_version_id, reason) WHERE status = 'open';
ALTER TABLE private.curriculum_refresh_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.curriculum_refresh_items FROM PUBLIC, anon, authenticated;

-- Default review-by for a class, counted from a start date.
CREATE OR REPLACE FUNCTION private.default_review_by(p_class text, p_from date)
RETURNS date LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT CASE p_class
    WHEN 'V0' THEN (p_from + interval '36 months')::date
    WHEN 'V1' THEN (p_from + interval '24 months')::date
    WHEN 'V2' THEN (p_from + interval '9 months')::date
  END;
$$;

-- Ingestion tool (service role), draft versions only. V3 needs review_by.
CREATE OR REPLACE FUNCTION public.set_target_version_freshness(
  p_target_version_id uuid,
  p_volatility_class text,
  p_review_by date DEFAULT NULL,
  p_source_pin text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_status text;
  v_review date;
BEGIN
  SELECT status INTO v_status FROM public.target_versions WHERE id = p_target_version_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Unknown target version' USING ERRCODE = '22023';
  END IF;
  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Freshness can only be set on a draft version' USING ERRCODE = '22023';
  END IF;
  IF p_volatility_class = 'V4' THEN
    RAISE EXCEPTION 'V4 fast-moving content is linked, not authored as durable lessons' USING ERRCODE = '22023';
  END IF;
  IF p_volatility_class NOT IN ('V0','V1','V2','V3') OR p_volatility_class IS NULL THEN
    RAISE EXCEPTION 'Unknown volatility class' USING ERRCODE = '22023';
  END IF;
  IF p_volatility_class = 'V3' AND p_review_by IS NULL THEN
    RAISE EXCEPTION 'V3 regulated content needs a review_by tied to its source release' USING ERRCODE = '22023';
  END IF;
  v_review := coalesce(p_review_by, private.default_review_by(p_volatility_class, current_date));
  IF v_review <= current_date THEN
    RAISE EXCEPTION 'review_by must be in the future' USING ERRCODE = '22023';
  END IF;
  INSERT INTO private.target_version_freshness (target_version_id, volatility_class, review_by, source_pin, updated_at)
  VALUES (p_target_version_id, p_volatility_class, v_review, p_source_pin, now())
  ON CONFLICT (target_version_id) DO UPDATE
    SET volatility_class = EXCLUDED.volatility_class, review_by = EXCLUDED.review_by,
        source_pin = EXCLUDED.source_pin, updated_at = now();
  RETURN jsonb_build_object('volatility_class', p_volatility_class, 'review_by', v_review);
END;
$$;
REVOKE ALL ON FUNCTION public.set_target_version_freshness(uuid, text, date, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_target_version_freshness(uuid, text, date, text) TO service_role;

-- Daily: raise review_due for published versions past their review-by.
CREATE OR REPLACE FUNCTION public.raise_due_curriculum_refresh_items()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_count integer;
BEGIN
  INSERT INTO private.curriculum_refresh_items (target_version_id, reason, detail)
  SELECT f.target_version_id, 'review_due', 'Review-by date ' || f.review_by || ' (' || f.volatility_class || ') has passed'
  FROM private.target_version_freshness f
  JOIN public.target_versions v ON v.id = f.target_version_id AND v.status = 'published'
  WHERE f.review_by <= current_date
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.raise_due_curriculum_refresh_items() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.raise_due_curriculum_refresh_items() TO service_role;

-- Scheduled source check: the pinned source of a target's published
-- version no longer matches the publisher's current release.
CREATE OR REPLACE FUNCTION public.report_curriculum_source_change(
  p_target_slug text,
  p_current_release text
)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_count integer;
BEGIN
  IF p_current_release IS NULL OR char_length(p_current_release) NOT BETWEEN 1 AND 200 THEN
    RAISE EXCEPTION 'current release required' USING ERRCODE = '22023';
  END IF;
  INSERT INTO private.curriculum_refresh_items (target_version_id, reason, detail)
  SELECT v.id, 'source_changed',
         'Pinned ' || coalesce(f.source_pin, 'unknown') || ', publisher now ' || p_current_release
  FROM public.learning_targets t
  JOIN public.target_versions v ON v.target_id = t.id AND v.status = 'published'
  LEFT JOIN private.target_version_freshness f ON f.target_version_id = v.id
  WHERE t.slug = p_target_slug
    AND f.source_pin IS DISTINCT FROM p_current_release
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.report_curriculum_source_change(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.report_curriculum_source_change(text, text) TO service_role;

-- Owner view: published versions with freshness, and the open queue.
CREATE OR REPLACE FUNCTION public.get_curriculum_freshness()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'versions', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'target_slug', t.slug, 'target_title', t.title, 'version_code', v.version_code,
               'volatility_class', f.volatility_class, 'review_by', f.review_by,
               'source_pin', f.source_pin) ORDER BY f.review_by NULLS FIRST, t.slug)
      FROM public.target_versions v
      JOIN public.learning_targets t ON t.id = v.target_id
      LEFT JOIN private.target_version_freshness f ON f.target_version_id = v.id
      WHERE v.status = 'published'), '[]'::jsonb),
    'open_items', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'id', i.id, 'target_slug', t.slug, 'version_code', v.version_code,
               'reason', i.reason, 'detail', i.detail, 'created_at', i.created_at)
             ORDER BY i.created_at)
      FROM private.curriculum_refresh_items i
      JOIN public.target_versions v ON v.id = i.target_version_id
      JOIN public.learning_targets t ON t.id = v.target_id
      WHERE i.status = 'open'), '[]'::jsonb));
END;
$$;
REVOKE ALL ON FUNCTION public.get_curriculum_freshness() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_curriculum_freshness() TO authenticated;

CREATE OR REPLACE FUNCTION public.resolve_curriculum_refresh_item(
  p_id uuid, p_status text, p_note text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('resolved','dismissed') THEN
    RAISE EXCEPTION 'Status must be resolved or dismissed' USING ERRCODE = '22023';
  END IF;
  UPDATE private.curriculum_refresh_items
    SET status = p_status, resolution_note = left(p_note, 1000), resolved_at = now()
    WHERE id = p_id AND status = 'open';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No open item with that id' USING ERRCODE = '22023';
  END IF;
  RETURN jsonb_build_object('id', p_id, 'status', p_status);
END;
$$;
REVOKE ALL ON FUNCTION public.resolve_curriculum_refresh_item(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_curriculum_refresh_item(uuid, text, text) TO authenticated;

-- Backfill: published open-textbook versions are V0 (math definitions and
-- methods), pinned to their OpenStax book version, review in 36 months.
INSERT INTO private.target_version_freshness (target_version_id, volatility_class, review_by, source_pin)
SELECT v.id, 'V0', private.default_review_by('V0', v.updated_at::date),
       nullif(lower(substring(v.version_code FROM '^OPENSTAX-([A-Z0-9]+)')), '')
FROM public.target_versions v
JOIN public.learning_targets t ON t.id = v.target_id
WHERE v.status = 'published' AND t.slug LIKE 'open-openstax-%'
ON CONFLICT (target_version_id) DO NOTHING;
