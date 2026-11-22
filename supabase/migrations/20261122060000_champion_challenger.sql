-- Champion/challenger for curriculum content (master plan v2.6 §7.3).
--
-- A challenger version replaces the published champion of an official
-- target only with a recorded decision that it either fixes a documented
-- defect or beats the champion on a rubric (clarity, accuracy,
-- accessibility; 1-5 each) by at least 2 points in total without scoring
-- lower on accuracy. Deterministic checks are the review_ready gate the
-- challenger must already be in; rights are the reviewed source registry.
-- Otherwise the challenger is kept as an alternate (it stays unpublished)
-- or rejected. Replacing retires the champion: old versions, their lessons
-- and every decision remain.
--
-- publish_target_version now refuses to retire a catalog target's
-- published version (no owning learner, or flagged official; this covers
-- the open-textbook curricula) without a matching 'replace' decision.
-- Learner-owned goals are unchanged.

CREATE TABLE IF NOT EXISTS private.content_version_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id uuid NOT NULL REFERENCES public.learning_targets(id) ON DELETE CASCADE,
  champion_version_id uuid NOT NULL REFERENCES public.target_versions(id) ON DELETE CASCADE,
  challenger_version_id uuid NOT NULL REFERENCES public.target_versions(id) ON DELETE CASCADE,
  decision text NOT NULL CHECK (decision IN ('replace','alternate','reject')),
  basis text NOT NULL CHECK (basis IN ('fixes_defect','rubric_margin','none')),
  defect_ref text CHECK (defect_ref IS NULL OR char_length(defect_ref) BETWEEN 5 AND 500),
  rubric jsonb,
  note text CHECK (note IS NULL OR char_length(note) <= 500),
  decided_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  decided_via text NOT NULL CHECK (decided_via IN ('admin','service_role')),
  decided_at timestamptz NOT NULL DEFAULT now(),
  CHECK (champion_version_id <> challenger_version_id),
  CHECK (decision <> 'replace' OR basis <> 'none'),
  CHECK (basis <> 'fixes_defect' OR defect_ref IS NOT NULL),
  CHECK (basis <> 'rubric_margin' OR rubric IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS content_version_decisions_pair_idx
  ON private.content_version_decisions (champion_version_id, challenger_version_id, decided_at DESC);
ALTER TABLE private.content_version_decisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.content_version_decisions FROM PUBLIC, anon, authenticated;

-- Rubric: {"champion": {"clarity":n,"accuracy":n,"accessibility":n},
--          "challenger": {...}}, integers 1-5. Returns the challenger's
-- margin, or NULL when the shape is wrong.
CREATE OR REPLACE FUNCTION private.rubric_margin(p_rubric jsonb)
RETURNS integer LANGUAGE plpgsql IMMUTABLE SET search_path = ''
AS $$
DECLARE
  v_side text;
  v_key text;
  v_val jsonb;
  v_total integer := 0;
BEGIN
  IF jsonb_typeof(p_rubric) IS DISTINCT FROM 'object' THEN RETURN NULL; END IF;
  FOREACH v_side IN ARRAY ARRAY['champion','challenger'] LOOP
    IF jsonb_typeof(p_rubric->v_side) IS DISTINCT FROM 'object'
       OR (SELECT count(*) FROM jsonb_object_keys(p_rubric->v_side)) <> 3 THEN
      RETURN NULL;
    END IF;
    FOREACH v_key IN ARRAY ARRAY['clarity','accuracy','accessibility'] LOOP
      v_val := p_rubric->v_side->v_key;
      IF jsonb_typeof(v_val) IS DISTINCT FROM 'number'
         OR (v_val)::numeric NOT IN (1, 2, 3, 4, 5) THEN
        RETURN NULL;
      END IF;
      v_total := v_total + CASE WHEN v_side = 'challenger' THEN 1 ELSE -1 END * (v_val)::integer;
    END LOOP;
  END LOOP;
  RETURN v_total;
END;
$$;
REVOKE ALL ON FUNCTION private.rubric_margin(jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_content_version_decision(
  p_champion_version_id uuid,
  p_challenger_version_id uuid,
  p_decision text,
  p_basis text,
  p_defect_ref text DEFAULT NULL,
  p_rubric jsonb DEFAULT NULL,
  p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_service boolean := coalesce((SELECT auth.role()), '') = 'service_role';
  v_user uuid := (SELECT auth.uid());
  v_champ record;
  v_chall record;
  v_margin integer;
  v_id uuid;
BEGIN
  IF NOT v_service AND (v_user IS NULL OR NOT coalesce((SELECT public.is_admin()), false)) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_decision NOT IN ('replace','alternate','reject')
     OR p_basis NOT IN ('fixes_defect','rubric_margin','none') THEN
    RAISE EXCEPTION 'Unknown decision or basis' USING ERRCODE = '22023';
  END IF;

  SELECT v.id, v.target_id, v.status INTO v_champ
  FROM public.target_versions v WHERE v.id = p_champion_version_id;
  SELECT v.id, v.target_id, v.status INTO v_chall
  FROM public.target_versions v WHERE v.id = p_challenger_version_id;
  IF v_champ.id IS NULL OR v_chall.id IS NULL OR v_champ.target_id <> v_chall.target_id
     OR v_champ.id = v_chall.id THEN
    RAISE EXCEPTION 'Champion and challenger must be two versions of one target' USING ERRCODE = '22023';
  END IF;
  IF v_champ.status <> 'published' THEN
    RAISE EXCEPTION 'The champion must be the published version' USING ERRCODE = '22023';
  END IF;

  IF p_decision = 'replace' THEN
    -- Deterministic checks: the challenger must have passed staging.
    IF v_chall.status <> 'review_ready' THEN
      RAISE EXCEPTION 'The challenger must be review-ready (checks passed) to replace' USING ERRCODE = '22023';
    END IF;
    IF p_basis = 'none' THEN
      RAISE EXCEPTION 'Replacing needs a documented defect or a rubric margin' USING ERRCODE = '22023';
    END IF;
    IF p_basis = 'fixes_defect' AND char_length(btrim(coalesce(p_defect_ref, ''))) < 5 THEN
      RAISE EXCEPTION 'Name the documented defect this fixes' USING ERRCODE = '22023';
    END IF;
    IF p_basis = 'rubric_margin' THEN
      v_margin := private.rubric_margin(p_rubric);
      IF v_margin IS NULL THEN
        RAISE EXCEPTION 'Rubric must score clarity, accuracy and accessibility 1-5 for both' USING ERRCODE = '22023';
      END IF;
      IF v_margin < 2 OR (p_rubric->'challenger'->>'accuracy')::int < (p_rubric->'champion'->>'accuracy')::int THEN
        RAISE EXCEPTION 'The challenger does not beat the champion by the required margin' USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  INSERT INTO private.content_version_decisions
    (target_id, champion_version_id, challenger_version_id, decision, basis,
     defect_ref, rubric, note, decided_by, decided_via)
  VALUES (v_champ.target_id, p_champion_version_id, p_challenger_version_id, p_decision, p_basis,
          nullif(btrim(left(p_defect_ref, 500)), ''), p_rubric, nullif(btrim(left(p_note, 500)), ''),
          v_user, CASE WHEN v_service THEN 'service_role' ELSE 'admin' END)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('id', v_id, 'decision', p_decision, 'basis', p_basis,
                            'rubric_margin', v_margin);
EXCEPTION WHEN check_violation THEN
  RAISE EXCEPTION 'Invalid decision: %', SQLERRM USING ERRCODE = '22023';
END;
$$;
REVOKE ALL ON FUNCTION public.record_content_version_decision(uuid, uuid, text, text, text, jsonb, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_content_version_decision(uuid, uuid, text, text, text, jsonb, text) TO authenticated, service_role;

-- Admin list of decisions, newest first.
CREATE OR REPLACE FUNCTION public.get_content_version_decisions(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN coalesce((
    SELECT jsonb_agg(d ORDER BY (d->>'decided_at') DESC)
    FROM (
      SELECT jsonb_build_object(
        'target_slug', t.slug,
        'champion', ch.version_code, 'challenger', cl.version_code,
        'decision', x.decision, 'basis', x.basis, 'defect_ref', x.defect_ref,
        'rubric_margin', private.rubric_margin(x.rubric), 'note', x.note,
        'decided_via', x.decided_via, 'decided_at', x.decided_at) AS d
      FROM private.content_version_decisions x
      JOIN public.learning_targets t ON t.id = x.target_id
      JOIN public.target_versions ch ON ch.id = x.champion_version_id
      JOIN public.target_versions cl ON cl.id = x.challenger_version_id
      ORDER BY x.decided_at DESC
      LIMIT least(greatest(coalesce(p_limit, 50), 1), 200)
    ) s), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.get_content_version_decisions(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_content_version_decisions(integer) TO authenticated;

-- The same publish function, plus the §7.3 gate for official targets.
create or replace function public.publish_target_version(
  p_version_id uuid,
  p_retire_previous boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tv record;
  v_target_owner uuid;
  v_official boolean;
  v_retired_ids uuid[] := array[]::uuid[];
  v_ret record;
begin
  select tv.*, lt.created_by, lt.is_official
  into v_tv
  from public.target_versions tv
  join public.learning_targets lt on lt.id = tv.target_id
  where tv.id = p_version_id;

  if not found then
    raise exception 'Target version not found: %', p_version_id;
  end if;

  v_target_owner := v_tv.created_by;
  -- Catalog content: flagged official, or owned by no learner (the open
  -- textbooks and seeded catalog targets have no created_by).
  v_official := coalesce(v_tv.is_official, false) or v_target_owner is null;

  if coalesce(auth.role(), '') <> 'service_role'
     and (auth.uid() is null or v_target_owner is distinct from auth.uid()) then
    raise exception 'Unauthorized: only service_role or the target owner can publish a target version';
  end if;

  if v_tv.status = 'published' then
    return jsonb_build_object(
      'success', true,
      'target_version_id', p_version_id,
      'status', 'published',
      'already_published', true,
      'retired_version_ids', '[]'::jsonb,
      'retired_previous_count', 0
    );
  end if;

  if v_tv.status <> 'review_ready' then
    raise exception 'Cannot publish TargetVersion with status "%". Publication strictly requires "review_ready" staging status.', v_tv.status;
  end if;

  if p_retire_previous then
    for v_ret in
      select id, version_code
      from public.target_versions
      where target_id = v_tv.target_id
        and status = 'published'
        and id <> p_version_id
    loop
      -- Champion/challenger (plan v2.6 §7.3): a catalog champion is
      -- retired only by a recorded 'replace' decision for this pair.
      if v_official and not exists (
        select 1 from private.content_version_decisions d
        where d.champion_version_id = v_ret.id
          and d.challenger_version_id = p_version_id
          and d.decision = 'replace'
      ) then
        raise exception 'No replace decision recorded for % -> %: record why the new version should replace the published one (a documented defect it fixes, or a rubric margin) before retiring it.',
          v_ret.version_code, v_tv.version_code
          using errcode = '22023';
      end if;
      update public.target_versions
      set status = 'retired', updated_at = now()
      where id = v_ret.id;
      v_retired_ids := array_append(v_retired_ids, v_ret.id);
    end loop;
  end if;

  update public.target_versions
  set status = 'published', updated_at = now()
  where id = p_version_id;

  update public.learning_targets
  set status = 'published', is_public = true, updated_at = now()
  where id = v_tv.target_id;

  return jsonb_build_object(
    'success', true,
    'target_version_id', p_version_id,
    'status', 'published',
    'already_published', false,
    'retired_version_ids', to_jsonb(v_retired_ids),
    'retired_previous_count', coalesce(array_length(v_retired_ids, 1), 0)
  );
end;
$$;

revoke all on function public.publish_target_version(uuid, boolean) from public, anon;
grant execute on function public.publish_target_version(uuid, boolean) to authenticated, service_role;
