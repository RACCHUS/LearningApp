-- Catalog source integrity. This migration is append-only.
-- A public entry is either an official platform record or a reviewed community record.
-- A private learner draft remains editable/visible to its owner.
alter table public.learning_targets
  add column if not exists review_status text not null default 'unreviewed';

alter table public.learning_targets
  add constraint learning_targets_review_status_check
  check (review_status in ('unreviewed', 'pending', 'approved', 'rejected'));

-- Existing platform-imported public entries remain catalog-visible, without
-- incorrectly labeling them official if their is_official flag is false.
update public.learning_targets
set review_status = case
  when is_official or (created_by is null and status = 'published' and is_public)
    then 'approved'
  when created_by is not null and status = 'published' and is_public
    then 'pending'
  else 'unreviewed'
end;

-- Previously public user-created entries were never vetted: retain them for
-- owners, but remove them from public discovery pending review.
update public.learning_targets
set status = 'draft', is_public = false
where created_by is not null
  and is_official = false
  and review_status = 'pending'
  and status = 'published'
  and is_public = true;

-- Defense in depth: never trust client-supplied origin, review, or publication
-- flags. A future moderator or trusted ingestion job uses service_role.
create or replace function public.enforce_learning_target_catalog_provenance()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_role text := coalesce(auth.role(), '');
begin
  -- Migrations/SQL fixtures run directly as privileged DB users without a JWT.
  -- A security-definer RPC called by an API client retains the caller JWT and
  -- therefore is NOT granted this exception.
  if v_role = 'service_role' or
     (v_role = '' and current_user in ('postgres', 'supabase_admin', 'service_role')) then
    -- Trusted ingestion of system-authored catalog records keeps working
    -- without pretending that all such records are "official".
    if tg_op = 'INSERT'
       and new.created_by is null
       and new.is_public and new.status = 'published'
       and new.review_status = 'unreviewed' then
      new.review_status := 'approved';
    end if;
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if auth.uid() is null then
    raise exception 'Sign in before changing learning goals.' using errcode = '42501';
  end if;

  if tg_op = 'DELETE' then
    if old.created_by is distinct from auth.uid()
       or old.is_official or old.review_status = 'approved' then
      raise exception 'Only trusted reviewers may delete verified goals.'
        using errcode = '42501';
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    if new.created_by is distinct from auth.uid()
       or new.is_official or new.is_public
       or new.status <> 'draft'
       or new.review_status <> 'unreviewed' then
      raise exception 'User goals must begin as private, unreviewed drafts.'
        using errcode = '42501';
    end if;
  else
    if old.created_by is distinct from auth.uid()
       or new.created_by is distinct from old.created_by
       or old.is_official or new.is_official
       or old.review_status = 'approved'
       or new.review_status not in ('unreviewed', 'pending')
       or new.is_public
       or new.status <> 'draft' then
      raise exception 'Only trusted reviewers may publish or verify goals.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_learning_target_catalog_provenance
  on public.learning_targets;
create trigger enforce_learning_target_catalog_provenance
before insert or update or delete on public.learning_targets
for each row execute function public.enforce_learning_target_catalog_provenance();

-- Explicit catalog read contract, while preserving owner access.
drop policy if exists "targets_read" on public.learning_targets;
create policy "targets_read" on public.learning_targets
for select using (
  auth.uid() = created_by
  or (status = 'published' and is_public
      and (is_official or review_status = 'approved'))
);

create index if not exists learning_targets_public_review_idx
on public.learning_targets (target_type, title)
where status = 'published' and is_public
  and (is_official or review_status = 'approved');

comment on column public.learning_targets.review_status is
  'Unreviewed/pending/rejected user drafts are private; approved community entries can be public. Only trusted service-role workflows may approve.';
