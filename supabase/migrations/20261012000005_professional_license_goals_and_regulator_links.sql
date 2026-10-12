-- P2c: distinguish a professional license from its licensure examination.
-- Existing goals are untouched; professional-license drafts require jurisdiction.
alter table public.learning_targets
  drop constraint learning_targets_target_type_check;
alter table public.learning_targets
  add constraint learning_targets_target_type_check
  check (target_type = any(array[
    'career','academic_program','certification','licensure_exam',
    'standardized_exam','curriculum_standard','professional_license'
  ]::text[]));

alter table public.learning_targets
  add constraint learning_targets_professional_license_jurisdiction_check
  check (
    target_type <> 'professional_license'
    or (jurisdiction is not null
      and jurisdiction ~ '^[A-Z]{2}(-[A-Z0-9]{2,8})?$')
  );

-- A private license goal may only link to a reviewed professional license
-- in the same jurisdiction. No cross-state implied eligibility.
drop policy destination_goal_links_owner_insert on public.catalog_destination_goal_links;
create policy destination_goal_links_owner_insert
  on public.catalog_destination_goal_links for insert to authenticated
  with check (
    exists (
      select 1 from public.learning_targets t
       where t.id=catalog_destination_goal_links.target_id
         and t.created_by=(select auth.uid())
         and not t.is_official
         and t.is_public=false
         and t.status='draft'
         and t.review_status='unreviewed'
    )
    and exists (
      select 1
      from public.catalog_verified_destinations d
      join public.learning_targets t on t.id=catalog_destination_goal_links.target_id
      where d.source_namespace=catalog_destination_goal_links.source_namespace
        and d.source_key=catalog_destination_goal_links.source_key
        and d.publication_status='published'
        and d.destination_type=t.target_type
        and d.destination_type in (
          'certification','licensure_exam','standardized_exam',
          'academic_program','professional_license'
        )
        and (d.destination_type <> 'professional_license'
          or d.jurisdiction=t.jurisdiction)
    )
  );

-- Prevent a linked goal being retyped or moved to a different state after
-- insertion, which could otherwise evade the INSERT-only RLS checks.
create function public.guard_destination_goal_target_identity()
returns trigger language plpgsql security invoker
set search_path = public, pg_temp
as $$
begin
  if exists(
    select 1 from public.catalog_destination_goal_links l
    join public.catalog_verified_destinations d
      on d.source_namespace=l.source_namespace
     and d.source_key=l.source_key
    where l.target_id=new.id
      and (new.target_type is distinct from d.destination_type
        or (d.destination_type='professional_license'
           and new.jurisdiction is distinct from d.jurisdiction)
        or new.is_official or new.is_public)
  ) then
    raise exception 'Linked goal type, jurisdiction and private status must match reviewed destination';
  end if;
  return new;
end $$;
revoke all on function public.guard_destination_goal_target_identity()
  from public,anon,authenticated;
create trigger trg_guard_destination_goal_target_identity
  before update of target_type,jurisdiction,is_official,is_public
  on public.learning_targets
  for each row execute function public.guard_destination_goal_target_identity();

-- The official regulator checklist is an outbound source; it is NOT a course.
alter table public.catalog_destination_resources
  drop constraint catalog_destination_resources_resource_kind_check;
alter table public.catalog_destination_resources
  add constraint catalog_destination_resources_resource_kind_check
  check (resource_kind in (
    'official_study_guide','issuer_training','official_exam_plan',
    'issuer_prep_directory','regulator_license_checklist'
  ));
