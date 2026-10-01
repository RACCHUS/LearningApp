-- Existing lessons were readable to everyone. Preserve that state explicitly,
-- then make future user-created lessons private by default.
alter table public.lessons
  add column if not exists visibility text;

update public.lessons
set visibility = 'public'
where visibility is null;

alter table public.lessons
  alter column visibility set default 'private',
  alter column visibility set not null;

alter table public.lessons
  add constraint lessons_visibility_check
  check (visibility in ('private', 'unlisted', 'public'));

alter table public.lessons
  add constraint lessons_ownerless_public_check
  check (user_id is not null or visibility = 'public');

-- Supabase anonymous-auth guests use the authenticated database role and
-- receive a distinct auth.uid(); the pre-login anon role has no owner ID.
drop policy if exists lessons_read_all on public.lessons;
create policy lessons_read_visible on public.lessons
  for select to authenticated, anon
  using (visibility = 'public' or user_id = auth.uid());

-- Every content read follows its parent lesson, including direct REST reads.
do $$
declare
  child_table text;
begin
  foreach child_table in array array['terms', 'questions', 'concepts', 'lesson_texts']
  loop
    if to_regclass('public.' || child_table) is not null then
      execute format('drop policy if exists %I on public.%I',
        child_table || '_read_all', child_table);
      execute format($policy$
        create policy %I on public.%I
          for select to authenticated, anon
          using (exists (
            select 1 from public.lessons l
            where l.id = lesson_id
              and (l.visibility = 'public' or l.user_id = auth.uid())
          ))
      $policy$, child_table || '_read_visible', child_table);
    end if;
  end loop;
end $$;

drop policy if exists lesson_concepts_read on public.lesson_concepts;
create policy lesson_concepts_read on public.lesson_concepts
  for select to authenticated, anon
  using (exists (
    select 1 from public.lessons l
    where l.id = lesson_concepts.lesson_id
      and (l.visibility = 'public' or l.user_id = auth.uid())
  ));

-- Other mapping policies already look through questions/terms, which now
-- inherit lesson visibility. These restrictive policies close junction paths
-- that otherwise expose a private lesson ID from a public course or node.
create policy course_lessons_lesson_visible on public.course_lessons
  as restrictive for select to authenticated, anon
  using (exists (
    select 1 from public.lessons l where l.id = course_lessons.lesson_id
  ));

create policy node_lessons_lesson_visible on public.curriculum_node_lessons
  as restrictive for select to authenticated, anon
  using (exists (
    select 1 from public.lessons l where l.id = curriculum_node_lessons.lesson_id
  ));
