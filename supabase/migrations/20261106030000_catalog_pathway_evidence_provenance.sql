-- P2e evidence provenance. Existing published revisions remain immutable.
alter table public.catalog_license_pathway_versions
  add column source_retrieved_at timestamptz,
  add column review_note text,
  add column uncertainty_status text not null default 'incomplete'
    check (uncertainty_status in ('verified','conditional','incomplete','disputed','unknown')),
  add column pathway_kind text not null default 'initial_licensure'
    check (pathway_kind in ('initial_licensure','exam_only','prelicense_training','continuing_education','appointment','authorization','renewal','endorsement','reciprocity','other'));

alter table public.catalog_license_pathway_versions
  add constraint license_pathway_source_retrieval_ck
    check (source_retrieved_at is null or source_retrieved_at <= source_checked_at),
  add constraint license_pathway_review_note_ck
    check (review_note is null or length(btrim(review_note)) between 40 and 2000);

comment on column public.catalog_license_pathway_versions.source_retrieved_at is
  'When the cited regulator source was retrieved for this revision; do not infer it from review date.';
comment on column public.catalog_license_pathway_versions.review_note is
  'Reviewer rationale, limitations, and scope of the source review for this immutable revision.';
comment on column public.catalog_license_pathway_versions.uncertainty_status is
  'Evidence confidence/coverage state; conditional and incomplete records must retain visible scope limits.';
comment on column public.catalog_license_pathway_versions.pathway_kind is
  'Distinguishes initial licensure from exam-only, prelicense training, CE, appointment, authorization, renewal, endorsement and reciprocity.';

create function public.guard_catalog_license_pathway_evidence()
returns trigger language plpgsql security invoker
set search_path = pg_catalog
as $$
begin
  -- Preserve legacy published revisions; require provenance for every new publication.
  if new.publication_status = 'published'
     and (tg_op = 'INSERT' or old.publication_status <> 'published') then
    if new.source_retrieved_at is null
       or new.source_retrieved_at > new.source_checked_at
       or new.review_note is null
       or length(btrim(new.review_note)) < 40
       or new.uncertainty_status in ('disputed','unknown') then
      raise exception 'New pathway publication requires retrieval provenance, review note, and non-disputed evidence';
    end if;
  end if;
  return new;
end
$$;

revoke all on function public.guard_catalog_license_pathway_evidence() from public,anon,authenticated;
create trigger trg_guard_catalog_license_pathway_evidence
before insert or update of publication_status,source_retrieved_at,review_note,uncertainty_status
on public.catalog_license_pathway_versions
for each row execute function public.guard_catalog_license_pathway_evidence();
