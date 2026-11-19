-- One-person team (owner instruction 2026-11-19): the sole admin may review,
-- publish and decide their OWN community items. Plain moderators keep the
-- two-person rule. Every self-approval is labelled in the audit trail.
--
-- Also activates the three public user-content switches (owner left the
-- call to Claude's recommendation): content.public_contribution,
-- content.refresh_proposals and content.wanted_board. Everything stays
-- moderated: nothing a learner submits is public until an admin publishes
-- it (contributions) or a moderator approves it (Wanted needs), and
-- takedown and reporting work even with the switches off.
--
-- Also activates content.external_companion (link-only outside reading for
-- Bridges, with its own auto-checked questions): the three links were
-- re-checked on 2026-11-19 and respond with HTTP 200.
--
-- Function bodies are copied from 20261112070000 / 20261113020000 with only
-- the self-check changed.

create or replace function public.review_lesson_contribution(
  p_id uuid,
  p_decision text,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.content_contributions;
  v_note text := p_note;
begin
  if v_uid is null or not private.is_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.public_contribution') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select * into v_row from public.content_contributions where id = p_id;
  if not found then
    raise exception 'contribution_not_found' using errcode = 'P0002';
  end if;
  if v_row.contributor_id = v_uid then
    if not private.is_admin() then
      raise exception 'cannot_review_own_contribution' using errcode = '42501';
    end if;
    v_note := left('[self-reviewed by admin] ' || coalesce(btrim(p_note), ''), 1000);
  end if;
  if p_decision = 'approve' then
    v_row := private.contribution_apply(p_id, 'ready_for_publication', 'approved', v_note);
  elsif p_decision = 'reject' then
    if btrim(coalesce(p_note, '')) = '' then
      raise exception 'rejection_reason_required' using errcode = '22023';
    end if;
    v_row := private.contribution_apply(p_id, 'rejected', 'rejected', v_note);
  else
    raise exception 'invalid_decision' using errcode = '22023';
  end if;
  update public.content_contributions
     set reviewer_id = v_uid, review_note = nullif(btrim(coalesce(v_note, '')), '')
   where id = p_id;
  return v_row.status;
end;
$$;

revoke all on function public.review_lesson_contribution(uuid, text, text) from public, anon;
grant execute on function public.review_lesson_contribution(uuid, text, text) to authenticated;

create or replace function public.publish_lesson_contribution(p_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.content_contributions;
  v_prev uuid;
begin
  if v_uid is null or not private.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.public_contribution') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select * into v_row from public.content_contributions where id = p_id for update;
  if not found then
    raise exception 'contribution_not_found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'ready_for_publication' then
    raise exception 'invalid_state_transition: % -> published', v_row.status
      using errcode = '22000';
  end if;
  select id into v_prev from public.content_contributions
   where lesson_id = v_row.lesson_id and status = 'published' and id <> p_id;
  if v_prev is not null then
    perform private.contribution_apply(v_prev, 'superseded', 'superseded',
      format('superseded by version %s', v_row.version));
  end if;
  return (private.contribution_apply(p_id, 'published', 'published',
    case when v_row.contributor_id = v_uid
         then '[self-published by admin]' end)).status;
end;
$$;

revoke all on function public.publish_lesson_contribution(uuid) from public, anon;
grant execute on function public.publish_lesson_contribution(uuid) to authenticated;

create or replace function public.decide_refresh_proposal(
  p_id uuid,
  p_accept boolean,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_proposer uuid;
  v_note text := p_note;
begin
  if v_uid is null or not private.is_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.refresh_proposals') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select proposer_id into v_proposer from public.content_refresh_proposals where id = p_id;
  if not found then
    raise exception 'proposal_not_found' using errcode = 'P0002';
  end if;
  if p_accept is not true and btrim(coalesce(p_note, '')) = '' then
    raise exception 'decline_reason_required' using errcode = '22023';
  end if;
  if v_proposer = v_uid then
    if not private.is_admin() then
      raise exception 'cannot_decide_own_proposal' using errcode = '42501';
    end if;
    v_note := left('[self-decided by admin] ' || coalesce(btrim(p_note), ''), 1000);
  end if;
  perform private.refresh_proposal_apply(
    p_id, case when p_accept then 'accepted' else 'declined' end, v_note);
  update public.content_refresh_proposals
     set reviewer_id = v_uid, review_note = nullif(btrim(coalesce(v_note, '')), '')
   where id = p_id;
  return case when p_accept then 'accepted' else 'declined' end;
end;
$$;

revoke all on function public.decide_refresh_proposal(uuid, boolean, text) from public, anon;
grant execute on function public.decide_refresh_proposal(uuid, boolean, text) to authenticated;

WITH targets(feature_key) AS (
  VALUES ('content.public_contribution'),
         ('content.refresh_proposals'),
         ('content.wanted_board'),
         ('content.external_companion')
),
before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  JOIN targets t USING (feature_key)
  WHERE c.enabled = false
  FOR UPDATE
),
changed AS (
  UPDATE private.site_feature_controls c
  SET release_ready = true, enabled = true,
      revision = b.revision + 1, updated_at = now()
  FROM before b
  WHERE c.feature_key = b.feature_key
  RETURNING c.feature_key
)
INSERT INTO private.site_feature_change_audit
  (feature_key, actor_id, prior_enabled, next_enabled, prior_maturity,
   next_maturity, previous_revision, new_revision, reason)
SELECT b.feature_key, NULL, b.enabled, true, b.maturity, b.maturity,
       b.revision, b.revision + 1,
       'Owner-delegated activation 2026-11-19 (one-person team; migration 20261119050000)'
FROM before b
JOIN changed USING (feature_key);
