-- EXM-03: Backend-only canonical recording for assigned practice sets.
-- Deliberately NOT a public RPC; production consumer/portability release gate
-- requires authenticated server adapter, full export and tested erasure UI.

create table public.exam_part_practice_assignments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references public.learning_targets(id),
  target_version_id uuid not null references public.target_versions(id),
  exam_part_key text not null check (exam_part_key ~ '^[a-z][a-z0-9_]{0,127}$'),
  curriculum_root_node_id uuid not null references public.curriculum_nodes(id),
  manifest_revision_id uuid not null
    references public.exam_reference_manifest_revisions(id),
  practice_kind text not null check (practice_kind in ('diagnostic','mock')),
  -- Exact server-issued set: [{id: uuid, sha256: canonical item fingerprint}].
  -- No scoring keys, correct answers or protected material stored here.
  assigned_items jsonb not null check (
    jsonb_typeof(assigned_items)='array'
    and jsonb_array_length(assigned_items) between 6 and 50
  ),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  constraint exm03_assignment_bounded_expiry
    check (expires_at > issued_at and
      expires_at <= issued_at + interval '2 hours')
);
create index exm03_assignment_owner_idx
  on public.exam_part_practice_assignments(owner_id,issued_at desc);
alter table public.exam_part_practice_assignments enable row level security;
revoke all on public.exam_part_practice_assignments
  from public,anon,authenticated;
grant select,insert,delete on public.exam_part_practice_assignments
  to service_role;
comment on table public.exam_part_practice_assignments is
  'Immutable backend-issued private practice assignment. No client access; exact reviewed item IDs and SHA-256 snapshots only.';

create function public.exm03_reject_assignment_update()
returns trigger language plpgsql security invoker
set search_path=pg_catalog
as $guard$
begin
  raise exception 'Practice assignment cannot be edited after issuance'
    using errcode='42501';
end
$guard$;
revoke all on function public.exm03_reject_assignment_update()
  from public,anon,authenticated;
create trigger exm03_assignment_immutable
  before update on public.exam_part_practice_assignments
  for each row execute function public.exm03_reject_assignment_update();

alter table public.exam_part_practice_attempts
  add column assignment_id uuid not null unique
    references public.exam_part_practice_assignments(id) on delete cascade,
  add column response_sha256 text not null
    check (response_sha256 ~ '^[a-f0-9]{64}$');

create function public.exm03_record_assigned_practice(
  p_assignment_id uuid,
  p_responses jsonb
)
returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public,pg_temp
as $record$
declare
  a public.exam_part_practice_assignments%rowtype;
  existing public.exam_part_practice_attempts%rowtype;
  v_version record;
  v_manifest public.exam_reference_manifest_revisions%rowtype;
  v_item public.assessment_items%rowtype;
  v_answer jsonb;
  v_entry jsonb;
  v_item_id uuid;
  v_ids uuid[] := array[]::uuid[];
  v_hash text;
  v_response_hash text;
  v_questions integer;
  v_correct integer := 0;
  v_distinct_concepts integer;
  v_expected integer;
  v_actual integer;
  v_edition text;
begin
  if p_assignment_id is null or
     jsonb_typeof(p_responses) is distinct from 'object' then
    raise exception 'Exact assigned practice and object responses required'
      using errcode='22023';
  end if;

  v_response_hash := encode(
    sha256(convert_to(p_responses::text,'UTF8')),'hex');

  -- Row lock serializes simultaneous retries for one issued set.
  select * into a from public.exam_part_practice_assignments
    where id=p_assignment_id for update;
  if not found then
    raise exception 'Practice assignment is unavailable'
      using errcode='42501';
  end if;

  -- Exactly-once recording: an identical retry may recover a committed result
  -- (including after expiry); a conflicting replay must never overwrite it.
  select * into existing from public.exam_part_practice_attempts
    where assignment_id=a.id;
  if found then
    if existing.response_sha256 <> v_response_hash then
      raise exception 'Conflicting replay for assigned practice'
        using errcode='23505';
    end if;
    return jsonb_build_object(
      'attempt_id',existing.id,
      'target_version_id',existing.target_version_id,
      'exam_part_key',existing.exam_part_key,
      'question_count',existing.question_count,
      'fully_correct_count',existing.fully_correct_count,
      'partial_count',existing.partial_count,
      'practice_score',existing.practice_score,
      'already_recorded',true,
      'official_exam_result',false
    );
  end if;

  if a.issued_at > now()+interval '1 minute'
     or a.expires_at <= now()
     or a.issued_at < now()-interval '2 hours' then
    raise exception 'Practice assignment is outside its issued window'
      using errcode='42501';
  end if;

  select v.status,v.target_id,v.metadata,
    t.status as target_status,t.is_public
    into v_version
    from public.target_versions v
    join public.learning_targets t on t.id=v.target_id
    where v.id=a.target_version_id;
  if not found or v_version.target_id <> a.target_id
     or v_version.status <> 'published'
     or v_version.target_status <> 'published'
     or v_version.is_public is distinct from true
     or jsonb_typeof(v_version.metadata->'exam_preparation'->'exam_parts')
         is distinct from 'array'
     or not exists (
       select 1 from jsonb_array_elements(
         v_version.metadata->'exam_preparation'->'exam_parts'
       ) as part(value)
       where part.value->>'key'=a.exam_part_key
         and part.value->>'curriculum_root_node_id'
             =a.curriculum_root_node_id::text
     ) or not exists (
       select 1 from public.curriculum_nodes cn
       where cn.id=a.curriculum_root_node_id
         and cn.target_version_id=a.target_version_id
     ) then
    raise exception 'No published matching target/version/part curriculum'
      using errcode='42501';
  end if;

  select * into v_manifest from public.exam_reference_manifest_revisions
    where id=a.manifest_revision_id;
  if not found or v_manifest.target_version_id <> a.target_version_id
     or v_manifest.exam_part_key <> a.exam_part_key
     or v_manifest.publication_status <> 'published'
     or v_manifest.review_status <> 'approved'
     or current_date < v_manifest.effective_from
     or (v_manifest.effective_until is not null
         and current_date > v_manifest.effective_until) then
    raise exception 'No current approved source manifest for this part'
      using errcode='42501';
  end if;

  v_questions := jsonb_array_length(a.assigned_items);
  if v_questions not between 6 and 50 or
     (select count(*) from jsonb_object_keys(p_responses)) <> v_questions
     or pg_column_size(p_responses)>65536 then
    raise exception 'Complete bounded assigned responses required'
      using errcode='22023';
  end if;

  for v_entry in select value from jsonb_array_elements(a.assigned_items)
      as assigned(value)
  loop
    if jsonb_typeof(v_entry) is distinct from 'object'
       or (select count(*) from jsonb_object_keys(v_entry)) <> 2
       or coalesce(v_entry->>'id','') !~
          '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'
       or coalesce(v_entry->>'sha256','') !~ '^[a-f0-9]{64}$' then
      raise exception 'Malformed immutable practice assignment'
        using errcode='22023';
    end if;
    v_item_id := (v_entry->>'id')::uuid;
    if v_item_id=any(v_ids) then
      raise exception 'Assigned questions may not repeat'
        using errcode='22023';
    end if;
    v_ids := array_append(v_ids,v_item_id);

    select * into v_item from public.assessment_items
      where id=v_item_id and origin_target_version_id=a.target_version_id;
    v_hash := public.exam_reference_item_fingerprint(v_item_id);
    if not found or v_item.interaction_type <> 'single_choice'
       or v_hash is null or v_hash <> v_entry->>'sha256'
       or not exists (
         select 1 from public.assessment_item_reference_validity b
         where b.assessment_item_id=v_item_id
           and b.manifest_revision_id=a.manifest_revision_id
           and b.publication_status='published'
           and b.review_status='approved'
           and b.rights_review_status='approved'
           and b.item_content_sha256=v_hash
       ) then
      raise exception 'Assigned item is changed, unreviewed or not version-owned'
        using errcode='42501';
    end if;

    -- An item must have at least one core concept *unique* to the selected
    -- subtree and ALL its mapped concepts must be part-unique core concepts.
    -- Shared concepts may support general readiness, never part identity.
    if not exists (
      with recursive subtree(id) as (
        select id from public.curriculum_nodes
         where id=a.curriculum_root_node_id
           and target_version_id=a.target_version_id
        union
        select child.id from public.curriculum_nodes child
        join subtree parent on child.parent_id=parent.id
        where child.target_version_id=a.target_version_id
      )
      select 1 from public.assessment_item_concepts ic
      where ic.assessment_item_id=v_item_id
        and exists (
          select 1 from public.curriculum_node_concepts nc
          where nc.concept_id=ic.concept_id
            and nc.relevance='core'
            and nc.curriculum_node_id in (select id from subtree)
        )
        and not exists (
          select 1 from public.curriculum_node_concepts nc
          join public.curriculum_nodes outside_node
            on outside_node.id=nc.curriculum_node_id
          where nc.concept_id=ic.concept_id
            and outside_node.target_version_id=a.target_version_id
            and outside_node.id not in (select id from subtree)
        )
    ) or exists (
      with recursive subtree(id) as (
        select id from public.curriculum_nodes
         where id=a.curriculum_root_node_id
           and target_version_id=a.target_version_id
        union
        select child.id from public.curriculum_nodes child
        join subtree parent on child.parent_id=parent.id
        where child.target_version_id=a.target_version_id
      )
      select 1 from public.assessment_item_concepts ic
      where ic.assessment_item_id=v_item_id
        and (
          not exists (
            select 1 from public.curriculum_node_concepts nc
            where nc.concept_id=ic.concept_id and nc.relevance='core'
              and nc.curriculum_node_id in (select id from subtree)
          ) or exists (
            select 1 from public.curriculum_node_concepts nc
            join public.curriculum_nodes outside_node
              on outside_node.id=nc.curriculum_node_id
            where nc.concept_id=ic.concept_id
              and outside_node.target_version_id=a.target_version_id
              and outside_node.id not in (select id from subtree)
          )
        )
    ) then
      raise exception 'Assigned question belongs outside selected part'
        using errcode='42501';
    end if;

    if jsonb_typeof(v_item.response_spec->'options') is distinct from 'array'
       or jsonb_array_length(v_item.response_spec->'options') not between 2 and 10
       or jsonb_typeof(v_item.scoring_spec->'correct_index')
          is distinct from 'number'
       or coalesce(v_item.scoring_spec->>'correct_index','') !~ '^[0-9]+$' then
      raise exception 'Unsupported canonical question scoring'
        using errcode='42501';
    end if;
    v_expected := (v_item.scoring_spec->>'correct_index')::integer;
    if v_expected < 0 or
       v_expected >= jsonb_array_length(v_item.response_spec->'options') then
      raise exception 'Invalid canonical correct index'
        using errcode='42501';
    end if;

    v_answer := p_responses -> (v_item_id::text);
    if v_answer is null or jsonb_typeof(v_answer) is distinct from 'number'
       or (v_answer #>> '{}') !~ '^[0-9]+$' then
      raise exception 'Response must be a single-choice option index'
        using errcode='22023';
    end if;
    v_actual := (v_answer #>> '{}')::integer;
    if v_actual >= jsonb_array_length(v_item.response_spec->'options') then
      raise exception 'Response option index out of bounds'
        using errcode='22023';
    end if;
    if v_actual=v_expected then
      v_correct := v_correct+1;
    end if;
  end loop;

  -- At least three separate core concepts, not six copies of one item.
  with recursive subtree(id) as (
    select id from public.curriculum_nodes
      where id=a.curriculum_root_node_id
        and target_version_id=a.target_version_id
    union
    select n.id from public.curriculum_nodes n
      join subtree p on n.parent_id=p.id
      where n.target_version_id=a.target_version_id
  )
  select count(distinct ic.concept_id) into v_distinct_concepts
  from public.assessment_item_concepts ic
    join public.curriculum_node_concepts nc
      on nc.concept_id=ic.concept_id and nc.relevance='core'
  where ic.assessment_item_id=any(v_ids)
    and nc.curriculum_node_id in (select id from subtree);
  if v_distinct_concepts < 3 then
    raise exception 'Practice requires three distinct reviewed concepts'
      using errcode='42501';
  end if;

  v_edition := encode(sha256(convert_to(
    a.manifest_revision_id::text || ':' || a.assigned_items::text,
    'UTF8')),'hex');

  insert into public.exam_part_practice_attempts (
    owner_id,target_id,target_version_id,exam_part_key,
    curriculum_root_node_id,practice_kind,
    question_count,fully_correct_count,partial_count,
    practice_score,question_edition_fingerprint,assignment_id,response_sha256
  ) values (
    a.owner_id,a.target_id,a.target_version_id,a.exam_part_key,
    a.curriculum_root_node_id,a.practice_kind,
    v_questions,v_correct,0,
    round(v_correct::numeric/v_questions,6),v_edition,a.id,v_response_hash
  ) returning * into existing;

  return jsonb_build_object(
    'attempt_id',existing.id,
    'target_version_id',existing.target_version_id,
    'exam_part_key',existing.exam_part_key,
    'question_count',existing.question_count,
    'fully_correct_count',existing.fully_correct_count,
    'partial_count',existing.partial_count,
    'practice_score',existing.practice_score,
    'already_recorded',false,
    'official_exam_result',false
  );
end
$record$;

revoke all on function public.exm03_record_assigned_practice(uuid,jsonb)
  from public,anon,authenticated;
grant execute on function public.exm03_record_assigned_practice(uuid,jsonb)
  to service_role;
comment on function public.exm03_record_assigned_practice(uuid,jsonb) is
  'Service-role only, transactional, idempotent canonical single-choice scoring of preassigned, unchanged, approved part-specific items. Never an official exam score. Not exposed to learner clients.';


-- Erasure must remove the underlying issued assignment as well as its scored
-- row. Otherwise deleting the result and retrying the same assignment would
-- recreate "erased" history. Replace unrestricted owner DELETE with one
-- transaction that cascades assignment -> attempt, then verifies emptiness.
revoke delete on public.exam_part_practice_attempts from authenticated;
drop policy if exists exm03_attempt_delete_owner
  on public.exam_part_practice_attempts;

create function public.exm03_erase_part_attempts(
  p_target_version_id uuid,
  p_exam_part_key text
)
returns integer
language plpgsql security definer
set search_path=pg_catalog,public,pg_temp
as $erase$
declare
  actor uuid;
  deleted_count integer;
begin
  actor := (select auth.uid());
  if actor is null or
     (select (auth.jwt()->>'is_anonymous')::boolean)
        is distinct from false or
     p_target_version_id is null or
     p_exam_part_key is null or
     p_exam_part_key !~ '^[a-z][a-z0-9_]{0,127}$' then
    raise exception 'Permanent account and exact exam part required'
      using errcode='42501';
  end if;

  -- Atomic erasure of both completed and unused assignments for that part.
  -- The attempt FK uses ON DELETE CASCADE, preventing any recorded retry.
  with removed as (
    delete from public.exam_part_practice_assignments a
    where a.owner_id=actor
      and a.target_version_id=p_target_version_id
      and a.exam_part_key=p_exam_part_key
    returning a.id
  )
  select count(*) into deleted_count from removed;

  if exists (
    select 1 from public.exam_part_practice_attempts t
      where t.owner_id=actor
        and t.target_version_id=p_target_version_id
        and t.exam_part_key=p_exam_part_key
  ) or exists (
    select 1 from public.exam_part_practice_assignments a
      where a.owner_id=actor
        and a.target_version_id=p_target_version_id
        and a.exam_part_key=p_exam_part_key
  ) then
    raise exception 'Part history erasure did not complete'
      using errcode='40001';
  end if;
  return deleted_count;
end
$erase$;
revoke all on function public.exm03_erase_part_attempts(uuid,text)
  from public,anon,authenticated;
grant execute on function public.exm03_erase_part_attempts(uuid,text)
  to authenticated;
comment on function public.exm03_erase_part_attempts(uuid,text) is
  'Permanent owner-only atomic exact-part erasure of assignments and attempt history, with no replay re-creation. Requires confirmation in future UI.';
