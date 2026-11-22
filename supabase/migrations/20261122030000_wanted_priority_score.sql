-- Reuse-value priority score (master plan v2.6 §6.5, D21) for the Wanted
-- Board and the maintainer seeding list.
--
--   frequency_boost = 1 + min(1, ln(1 + suppressed_gap_count) / ln(101))
--   work_units      = max(1, estimated work)            -- 1 until estimated
--   priority        = max(1, eligible_fan_in) * frequency_boost
--                     * coverage_deficit / work_units
--
-- Terms, all finite, non-negative and clamped:
--   eligible_fan_in      distinct curriculum targets whose published lessons
--                        carry the need's subject tag (floors at 1, so a
--                        genuine individual need still counts)
--   suppressed_gap_count "I need this too" votes, counted only from the
--                        public small-cohort floor up (0 below it)
--   coverage_deficit     1 when nothing is linked; 0.5 when a contribution
--                        is linked but not yet published
-- Only open needs are scored; eligibility (moderation, rights) comes first
-- and the score never overrides it. Learners never see the score: the
-- board is only ordered by it. Moderators see the terms for auditing.

CREATE OR REPLACE FUNCTION private.wanted_need_priority(p_need_id uuid)
RETURNS TABLE (
  fan_in integer,
  gap_count integer,
  frequency_boost numeric,
  coverage_deficit numeric,
  work_units integer,
  priority numeric
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  WITH n AS (
    SELECT id, subject_tag FROM public.content_wanted_needs WHERE id = p_need_id
  ),
  terms AS (
    SELECT
      greatest(1, (
        SELECT count(DISTINCT v.target_id)::integer
        FROM public.lessons l
        JOIN public.target_versions v ON v.id = l.origin_target_version_id AND v.status = 'published'
        WHERE n.subject_tag IS NOT NULL AND n.subject_tag = ANY (l.tags)
      )) AS fan_in,
      (SELECT CASE WHEN count(*) >= private.wanted_vote_floor() THEN count(*)::integer ELSE 0 END
       FROM public.content_wanted_votes x WHERE x.need_id = n.id) AS gap_count,
      CASE WHEN EXISTS (SELECT 1 FROM public.content_wanted_links k WHERE k.need_id = n.id)
           THEN 0.5 ELSE 1.0 END::numeric AS coverage_deficit,
      1 AS work_units
    FROM n
  )
  SELECT fan_in, gap_count,
         round(1 + least(1.0, ln(1 + gap_count) / ln(101))::numeric, 3) AS frequency_boost,
         coverage_deficit, work_units,
         round((fan_in * (1 + least(1.0, ln(1 + gap_count) / ln(101))) * coverage_deficit / work_units)::numeric, 3)
  FROM terms;
$$;
REVOKE ALL ON FUNCTION private.wanted_need_priority(uuid) FROM PUBLIC, anon, authenticated;

-- Same signature and visibility as before; only the order changes, from
-- vote count to the priority score (newest first on ties).
CREATE OR REPLACE FUNCTION public.wanted_board()
RETURNS TABLE (
  id uuid,
  title text,
  details text,
  subject_tag text,
  votes integer,
  has_voted boolean,
  linked integer,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING errcode = '42501';
  END IF;
  IF NOT private.site_feature_enabled('content.wanted_board') THEN
    RAISE EXCEPTION 'feature_disabled' USING errcode = '42501';
  END IF;
  RETURN QUERY
    SELECT n.id, n.title, n.details, n.subject_tag,
           CASE WHEN v.cnt >= private.wanted_vote_floor() THEN v.cnt::integer END,
           EXISTS (SELECT 1 FROM public.content_wanted_votes x
                    WHERE x.need_id = n.id AND x.user_id = auth.uid()),
           (SELECT count(*)::integer FROM public.content_wanted_links l
             WHERE l.need_id = n.id),
           n.created_at
      FROM public.content_wanted_needs n
      LEFT JOIN LATERAL (
        SELECT count(*) AS cnt FROM public.content_wanted_votes x
         WHERE x.need_id = n.id
      ) v ON true
      LEFT JOIN LATERAL private.wanted_need_priority(n.id) p ON true
     WHERE n.status = 'open'
     ORDER BY p.priority DESC NULLS LAST, n.created_at DESC
     LIMIT 200;
END;
$$;
REVOKE ALL ON FUNCTION public.wanted_board() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wanted_board() TO authenticated;

-- Maintainer seeding list: open needs with every term, for auditing.
CREATE OR REPLACE FUNCTION public.wanted_priority_list()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_moderator() THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'id', n.id, 'title', n.title, 'subject_tag', n.subject_tag,
             'priority', p.priority, 'fan_in', p.fan_in, 'gap_count', p.gap_count,
             'frequency_boost', p.frequency_boost, 'coverage_deficit', p.coverage_deficit,
             'work_units', p.work_units)
           ORDER BY p.priority DESC, n.created_at DESC)
    FROM public.content_wanted_needs n
    CROSS JOIN LATERAL private.wanted_need_priority(n.id) p
    WHERE n.status = 'open'), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.wanted_priority_list() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.wanted_priority_list() TO authenticated;
