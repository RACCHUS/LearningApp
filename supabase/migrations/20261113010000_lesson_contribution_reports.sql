-- PR-H slice 3 (master plan v2.6 §8.6: community content is "searchable
-- separately with reporting and takedown").
--
-- * Adds `lesson_contribution` to the moderation report target types, using
--   the same drop-and-re-add pattern as 20261024000000 (existing values are
--   kept; no rows change).
-- * Adds public.report_lesson_contribution(), which files a report against
--   a PUBLISHED community copy so moderators see it in the existing Trust &
--   Safety queue. Same reasons, 10-per-hour limit and duplicate guard as
--   submit_moderation_report. Reporting works even when the feature is OFF.

alter table public.moderation_reports
  drop constraint if exists moderation_reports_target_type_check;

alter table public.moderation_reports
  add constraint moderation_reports_target_type_check
  check (target_type in (
    'course', 'lesson', 'study_set', 'word_list', 'curriculum',
    'resource', 'question', 'profile', 'community_question', 'community_answer',
    'lesson_contribution'
  ));

create or replace function public.report_lesson_contribution(
  p_id uuid,
  p_reason text,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_recent integer;
  v_report_id uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_reason is null or p_reason not in (
    'spam', 'harassment', 'misinformation', 'copyright', 'minor_safety',
    'inappropriate', 'other') then
    raise exception 'invalid_reason' using errcode = '22023';
  end if;
  if p_description is not null and char_length(p_description) > 1000 then
    raise exception 'description_too_long' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.content_contributions
     where id = p_id and status = 'published'
  ) then
    raise exception 'not_published' using errcode = 'P0002';
  end if;

  select count(*) into v_recent
    from public.moderation_reports
   where reporter_id = v_uid
     and created_at > now() - interval '1 hour';
  if v_recent >= 10 then
    raise exception 'rate_limited' using errcode = '54000';
  end if;

  begin
    insert into public.moderation_reports
      (reporter_id, target_type, target_id, reason, description)
    values
      (v_uid, 'lesson_contribution', p_id, p_reason,
       nullif(btrim(coalesce(p_description, '')), ''))
    returning id into v_report_id;
  exception when unique_violation then
    raise exception 'already_reported' using errcode = '23505';
  end;
  return v_report_id;
end;
$$;

revoke all on function public.report_lesson_contribution(uuid, text, text)
  from public, anon;
grant execute on function public.report_lesson_contribution(uuid, text, text)
  to authenticated;
