
-- EXM-02B — safe learner-delivery projection of independently reviewed
-- ORIGINAL practice prompts. No real regulator questions or references seeded.
-- Additive only. The private review tables remain inaccessible to learners.

create function public.exam_reference_drill_steps_valid(p_steps jsonb)
returns boolean language plpgsql immutable security invoker
set search_path=pg_catalog
as $validate$
declare
  step_name text;
  step_spec jsonb;
  choice jsonb;
  choices jsonb;
  token text;
  seen text[];
begin
  if jsonb_typeof(p_steps) is distinct from 'object'
     or (select count(*) from jsonb_object_keys(p_steps)) <> 4 then
    return false;
  end if;
  foreach step_name in array array[
    'resource_choice','section_location','interpretation','application'
  ] loop
    step_spec := p_steps -> step_name;
    if jsonb_typeof(step_spec) is distinct from 'object'
       or (select count(*) from jsonb_object_keys(step_spec)) <> 2
       or jsonb_typeof(step_spec -> 'prompt') is distinct from 'string'
       or length(btrim(step_spec->>'prompt')) not between 8 and 1000
       or jsonb_typeof(step_spec -> 'choices') is distinct from 'array' then
      return false;
    end if;
    choices := step_spec -> 'choices';
    if jsonb_array_length(choices) not between 2 and 6 then
      return false;
    end if;
    seen := array[]::text[];
    for choice in select value from jsonb_array_elements(choices) as item(value)
    loop
      if jsonb_typeof(choice) is distinct from 'object'
         or (select count(*) from jsonb_object_keys(choice)) <> 2
         or jsonb_typeof(choice->'value') is distinct from 'string'
         or jsonb_typeof(choice->'label') is distinct from 'string'
         or length(btrim(choice->>'label')) not between 1 and 200 then
        return false;
      end if;
      token := choice->>'value';
      if token is null or length(token) > 80 or
         token !~ '^[a-z0-9][a-z0-9 _./:-]*$'
         or token <> lower(btrim(token)) or token=any(seen) then
        return false;
      end if;
      seen := array_append(seen,token);
    end loop;
  end loop;
  return true;
end
$validate$;
revoke all on function public.exam_reference_drill_steps_valid(jsonb)
  from public,anon,authenticated;
grant execute on function public.exam_reference_drill_steps_valid(jsonb)
  to service_role;

create table public.exam_reference_drill_presentations (
  id uuid primary key default gen_random_uuid(),
  scoring_key_id uuid not null
    references public.exam_reference_drill_scoring_keys(id)
      on update restrict on delete restrict,
  presentation_revision integer not null check (presentation_revision > 0),
  -- Four original prompts and shuffled/approved response candidates only;
  -- no scoring rules, correct_index, protected book passages or explanations.
  steps jsonb not null check(public.exam_reference_drill_steps_valid(steps)),
  author_ref text not null check(length(btrim(author_ref)) between 3 and 150),
  ai_drafted boolean not null,
  reviewer_ref text,
  reviewer_qualification_evidence text,
  reviewer_edition_access_evidence text,
  rights_review_status text not null default 'pending'
    check(rights_review_status in ('pending','approved','rejected')),
  review_status text not null default 'pending'
    check(review_status in ('pending','approved','rejected')),
  publication_status text not null default 'draft'
    check(publication_status in ('draft','published','retired')),
  reviewed_at timestamptz,
  review_minutes integer check (review_minutes between 1 and 10000),
  created_at timestamptz not null default now(),
  unique(scoring_key_id,presentation_revision),
  constraint exam_drill_presentation_independent_reviewer
    check (reviewer_ref is null or btrim(reviewer_ref) <> btrim(author_ref)),
  constraint exam_drill_presentation_publish_review
    check (publication_status <> 'published' or (
      review_status='approved' and rights_review_status='approved'
      and reviewer_ref is not null and length(btrim(reviewer_ref)) >= 3
      and reviewer_qualification_evidence is not null
      and length(btrim(reviewer_qualification_evidence)) >= 8
      and reviewer_edition_access_evidence is not null
      and length(btrim(reviewer_edition_access_evidence)) >= 8
      and reviewed_at is not null and review_minutes is not null
    ))
);
create unique index exam_drill_one_published_presentation
  on public.exam_reference_drill_presentations(scoring_key_id)
  where publication_status='published';

create function public.guard_exam_reference_drill_presentation()
returns trigger language plpgsql security invoker
set search_path=pg_catalog,public
as $guard$
declare
  approved_key public.exam_reference_drill_scoring_keys%rowtype;
  step_name text;
  token text;
begin
  if tg_op='DELETE' then
    if old.publication_status <> 'draft' then
      raise exception 'Reviewed practice presentations cannot be deleted';
    end if;
    return old;
  end if;
  if tg_op='UPDATE' and old.publication_status in ('published','retired') then
    if old.publication_status='published'
       and new.publication_status='retired'
       and (to_jsonb(new)-'publication_status') =
           (to_jsonb(old)-'publication_status') then
      return new;
    end if;
    raise exception 'Published practice presentations are immutable';
  end if;
  if new.publication_status='published' then
    select * into approved_key
      from public.exam_reference_drill_scoring_keys
      where id=new.scoring_key_id;
    if not found or approved_key.publication_status <> 'published'
       or approved_key.review_status <> 'approved'
       or approved_key.rights_review_status <> 'approved' then
      raise exception 'Presentation needs a published, reviewed private rubric';
    end if;
    if new.review_status <> 'approved'
      or new.rights_review_status <> 'approved'
      or new.reviewer_ref is null
      or btrim(new.reviewer_ref)=btrim(new.author_ref)
      or new.reviewer_qualification_evidence is null
      or new.reviewer_edition_access_evidence is null
      or new.reviewed_at is null
      or new.reviewed_at > now() or new.review_minutes is null then
      raise exception 'Independent review of original prompt required';
    end if;
    -- Every accepted answer must be among the visible candidates. This
    -- prevents an unsolvable/incorrectly versioned question from publishing.
    foreach step_name in array array[
      'resource_choice','section_location','interpretation','application'
    ] loop
      for token in select value from jsonb_array_elements_text(
        approved_key.step_tokens -> step_name
      ) as candidate(value) loop
        if not exists (
          select 1 from jsonb_array_elements(
            new.steps -> step_name -> 'choices'
          ) as ch(value)
          where ch.value->>'value'=token
        ) then
          raise exception 'Reviewed answer missing from visible options';
        end if;
      end loop;
    end loop;
  end if;
  return new;
end
$guard$;
revoke all on function public.guard_exam_reference_drill_presentation()
  from public,anon,authenticated;
create trigger trg_guard_exam_reference_drill_presentation
before insert or update or delete on public.exam_reference_drill_presentations
for each row execute function public.guard_exam_reference_drill_presentation();

alter table public.exam_reference_drill_presentations enable row level security;
revoke all on public.exam_reference_drill_presentations
  from public,anon,authenticated;
grant select,insert,update,delete on public.exam_reference_drill_presentations
  to service_role;
comment on table public.exam_reference_drill_presentations is
 'Private original prompts + answer candidates with separate human editorial approval; only exact server projection is learner-facing.';

-- Project ONLY original reviewed prompts/choices from eligible practice
-- presentations; never assessment_items.scoring_spec, step_tokens, private
-- reviewer evidence, unapproved material, or held-out exercises.
create function public.get_exam_reference_drill_practice(
  p_manifest_revision_id uuid,
  p_exam_part_key text,
  p_administration_date date
)
returns jsonb
language plpgsql stable security definer
set search_path=pg_catalog,public,pg_temp
as $delivery$
declare
  owner_uid uuid;
  chosen jsonb;
begin
  owner_uid := (select auth.uid());
  if owner_uid is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false
     or p_manifest_revision_id is null
     or p_exam_part_key is null
     or p_administration_date is null then
    raise exception 'Permanent sign-in and exam identity required'
      using errcode='42501';
  end if;

  select jsonb_build_object(
    'assessment_item_id',b.assessment_item_id,
    'approved_binding_id',b.id,
    'manifest_revision_id',m.id,
    'exam_part_key',m.exam_part_key,
    'administration_date',p_administration_date,
    'item_content_revision',b.item_content_revision,
    'answer_location_revision',b.answer_location_revision,
    'steps',p.steps
  ) into chosen
  from public.exam_reference_drill_presentations p
  join public.exam_reference_drill_scoring_keys k
    on k.id=p.scoring_key_id
  join public.assessment_item_reference_validity b
    on b.id=k.approved_binding_id
  join public.exam_reference_manifest_revisions m
    on m.id=b.manifest_revision_id
  where m.id=p_manifest_revision_id
    and m.exam_part_key=p_exam_part_key
    and p_administration_date>=m.effective_from
    and (m.effective_until is null or p_administration_date<=m.effective_until)
    and m.publication_status='published'
    and m.review_status='approved'
    and k.publication_status='published'
    and k.review_status='approved'
    and k.rights_review_status='approved'
    and b.publication_status='published'
    and b.review_status='approved'
    and b.rights_review_status='approved'
    and b.item_content_sha256=public.exam_reference_item_fingerprint(
      b.assessment_item_id
    )
    and p.publication_status='published'
    and p.review_status='approved'
    and p.rights_review_status='approved'
  order by p.id
  limit 1;
  return chosen; -- NULL means no independently reviewed practice available.
end
$delivery$;

revoke all on function public.get_exam_reference_drill_practice(uuid,text,date)
  from public,anon,authenticated;
grant execute on function public.get_exam_reference_drill_practice(uuid,text,date)
  to authenticated;
