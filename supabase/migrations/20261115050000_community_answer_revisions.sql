-- Community answer revisions (learning.answer_revisions, default OFF).
--
-- A rejected answer is revised by submitting a NEW answer (the rejected row
-- stays archived). This links the new answer to its earlier versions so the
-- author and moderators can see what changed and which feedback it answers.
--
-- Privacy: earlier versions were never public. Only the author of the answer
-- and moderators can read them, and only through list_community_answer_revisions.
-- edit_reason copies the learner-facing review note (audit.notes), never the
-- confidential internal_notes or the reviewer's identity.
--
-- Gate: both RPCs refuse with feature_disabled while the key is OFF, so the
-- OFF path writes and returns nothing.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.answer_revisions', 'Q&A answer revision history', 'Learning', 'release', false, 'experimental', false,
  'Links a resubmitted Q&A answer to its rejected earlier versions; visible to the author and moderators only')
ON CONFLICT (feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.community_answer_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  answer_id uuid NOT NULL REFERENCES public.community_answers(id) ON DELETE CASCADE,
  revision_number integer NOT NULL CHECK (revision_number >= 1),
  body_markdown text NOT NULL CHECK (length(body_markdown) <= 20000),
  editor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  edit_reason text CHECK (edit_reason IS NULL OR length(edit_reason) <= 2000),
  source_answer_id uuid REFERENCES public.community_answers(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (answer_id, revision_number)
);

-- No policies: the table is reachable only through the RPCs below.
ALTER TABLE public.community_answer_revisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.community_answer_revisions FROM PUBLIC, anon, authenticated;

-- Links p_answer_id (the resubmission) to p_previous_answer_id (the rejected
-- answer it revises). Copies the rejected answer's own history first, then
-- adds the rejected text as the newest earlier version. Returns how many
-- earlier versions the resubmission now has.
CREATE OR REPLACE FUNCTION public.link_community_answer_resubmission(
  p_answer_id uuid,
  p_previous_answer_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_new public.community_answers%ROWTYPE;
  v_prev public.community_answers%ROWTYPE;
  v_next integer;
  v_reason text;
BEGIN
  IF NOT private.site_feature_enabled('learning.answer_revisions') THEN
    RAISE EXCEPTION 'feature_disabled' USING errcode = '42501';
  END IF;
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING errcode = '42501';
  END IF;
  IF p_answer_id IS NULL OR p_previous_answer_id IS NULL
     OR p_answer_id = p_previous_answer_id THEN
    RAISE EXCEPTION 'invalid_revision_link' USING errcode = '22023';
  END IF;

  -- Lock in a fixed order so concurrent links cannot deadlock.
  PERFORM 1 FROM public.community_answers
   WHERE id IN (p_answer_id, p_previous_answer_id)
   ORDER BY id FOR UPDATE;

  SELECT * INTO v_new FROM public.community_answers WHERE id = p_answer_id;
  SELECT * INTO v_prev FROM public.community_answers WHERE id = p_previous_answer_id;

  -- Same message whether the row is missing or someone else's.
  IF v_new.id IS NULL OR v_prev.id IS NULL
     OR v_new.author_id <> v_caller OR v_prev.author_id <> v_caller THEN
    RAISE EXCEPTION 'answer_not_found' USING errcode = 'P0002';
  END IF;
  IF v_new.question_id <> v_prev.question_id
     OR v_prev.status <> 'archived'
     OR v_new.status NOT IN ('draft', 'under_review') THEN
    RAISE EXCEPTION 'invalid_revision_link' USING errcode = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.community_answer_revisions WHERE answer_id = p_answer_id) THEN
    RAISE EXCEPTION 'already_linked' USING errcode = '23505';
  END IF;
  -- A rejected answer can be revised once; a second resubmission revises the newer one.
  IF EXISTS (SELECT 1 FROM public.community_answer_revisions WHERE source_answer_id = p_previous_answer_id) THEN
    RAISE EXCEPTION 'already_revised' USING errcode = '23505';
  END IF;

  INSERT INTO public.community_answer_revisions
    (answer_id, revision_number, body_markdown, editor_id, edit_reason, source_answer_id, created_at)
  SELECT p_answer_id, r.revision_number, r.body_markdown, r.editor_id, r.edit_reason,
         r.source_answer_id, r.created_at
    FROM public.community_answer_revisions r
   WHERE r.answer_id = p_previous_answer_id;

  SELECT coalesce(max(revision_number), 0) + 1 INTO v_next
    FROM public.community_answer_revisions WHERE answer_id = p_answer_id;

  SELECT left(a.notes, 2000) INTO v_reason
    FROM public.community_review_audit a
   WHERE a.target_type = 'answer'
     AND a.target_id = p_previous_answer_id
     AND a.action IN ('reject', 'archive')
   ORDER BY a.created_at DESC
   LIMIT 1;

  INSERT INTO public.community_answer_revisions
    (answer_id, revision_number, body_markdown, editor_id, edit_reason, source_answer_id, created_at)
  VALUES
    (p_answer_id, v_next, v_prev.body_markdown, v_caller, nullif(trim(v_reason), ''),
     p_previous_answer_id, v_prev.created_at);

  RETURN v_next;
END;
$$;

REVOKE ALL ON FUNCTION public.link_community_answer_resubmission(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.link_community_answer_resubmission(uuid, uuid) TO authenticated;

-- Earlier versions for up to 100 answers. Rows the caller may not see are
-- left out silently: the author sees their own, moderators see all.
CREATE OR REPLACE FUNCTION public.list_community_answer_revisions(p_answer_ids uuid[])
RETURNS TABLE (
  id uuid,
  answer_id uuid,
  revision_number integer,
  body_markdown text,
  editor_id uuid,
  edit_reason text,
  source_answer_id uuid,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_is_moderator boolean;
BEGIN
  IF NOT private.site_feature_enabled('learning.answer_revisions') THEN
    RAISE EXCEPTION 'feature_disabled' USING errcode = '42501';
  END IF;
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING errcode = '42501';
  END IF;
  IF coalesce(cardinality(p_answer_ids), 0) > 100 THEN
    RAISE EXCEPTION 'too_many_answers' USING errcode = '22023';
  END IF;
  v_is_moderator := private.is_moderator();

  RETURN QUERY
  SELECT r.id, r.answer_id, r.revision_number, r.body_markdown, r.editor_id,
         r.edit_reason, r.source_answer_id, r.created_at
    FROM public.community_answer_revisions r
    JOIN public.community_answers a ON a.id = r.answer_id
   WHERE r.answer_id = ANY (coalesce(p_answer_ids, '{}'))
     AND (a.author_id = v_caller OR v_is_moderator)
   ORDER BY r.answer_id, r.revision_number DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_community_answer_revisions(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_community_answer_revisions(uuid[]) TO authenticated;
