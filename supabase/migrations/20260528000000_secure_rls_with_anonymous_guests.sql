-- Re-secure the public schema.
--
-- Previously `database/migrations/nuclear_rls_fix.sql` had disabled RLS on
-- every public table and granted ALL to the `anon` role, which made every
-- row in the database publicly readable and writable. This migration:
--
--   1. Revokes those blanket grants.
--   2. Re-enables RLS on every public table.
--   3. Installs owner-only write policies + public-read on content tables.
--   4. Adds a trigger that limits anonymous (guest) auth users to 5 lessons.
--
-- Guests now use Supabase anonymous auth (auth.signInAnonymously()) instead
-- of a shared placeholder UUID, so each guest has a distinct auth.uid() and
-- can only edit lessons they own. Guests can still read any lesson and
-- duplicate it by inserting a new row owned by themselves.

-- ---------------------------------------------------------------------------
-- 0. Allow anonymous user records (no email) in public.users
-- ---------------------------------------------------------------------------
ALTER TABLE public.users ALTER COLUMN email DROP NOT NULL;

-- ---------------------------------------------------------------------------
-- 1. Helper: is the current JWT an anonymous (guest) session?
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_anonymous_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE((auth.jwt() ->> 'is_anonymous')::boolean, false);
$$;

GRANT EXECUTE ON FUNCTION public.is_anonymous_user() TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Drop every existing policy in the public schema
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                   pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 3. Revoke blanket grants; re-grant only what's needed (RLS still enforced)
-- ---------------------------------------------------------------------------
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;

GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- anon role is only used pre-login. Allow read so the marketing/landing
-- experience still works; everything else requires an auth session
-- (anonymous or full).
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Enable RLS on every public table
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  tbl record;
BEGIN
  FOR tbl IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl.tablename);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 5. users table: each row visible/writable only by its owner
-- ---------------------------------------------------------------------------
CREATE POLICY users_self_select ON public.users
  FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY users_self_insert ON public.users
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

CREATE POLICY users_self_update ON public.users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- 6. lessons: anyone signed in can read; only owner can modify
-- ---------------------------------------------------------------------------
CREATE POLICY lessons_read_all ON public.lessons
  FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY lessons_owner_insert ON public.lessons
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY lessons_owner_update ON public.lessons
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY lessons_owner_delete ON public.lessons
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 7. lesson-child content tables: same pattern, scoped through parent lesson
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['terms', 'concepts', 'questions', 'lesson_texts']
  LOOP
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = t) THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated, anon USING (true)',
        t || '_read_all', t);

      EXECUTE format($f$
        CREATE POLICY %I ON public.%I FOR INSERT TO authenticated
          WITH CHECK (EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.user_id = auth.uid()
          ))
      $f$, t || '_owner_insert', t);

      EXECUTE format($f$
        CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated
          USING (EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.user_id = auth.uid()
          ))
          WITH CHECK (EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.user_id = auth.uid()
          ))
      $f$, t || '_owner_update', t);

      EXECUTE format($f$
        CREATE POLICY %I ON public.%I FOR DELETE TO authenticated
          USING (EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.user_id = auth.uid()
          ))
      $f$, t || '_owner_delete', t);
    END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 8. Per-user tables: strict owner-only
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'user_progress', 'reminders', 'offline_content',
    'user_xp', 'xp_events', 'review_items',
    'study_sets', 'course_progress', 'study_set_progress'
  ]
  LOOP
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = t) THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR ALL TO authenticated
           USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)',
        t || '_owner_all', t);
    END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 9. courses: owner CRUD + public-read when is_public = true
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'courses') THEN
    CREATE POLICY courses_owner_all ON public.courses
      FOR ALL TO authenticated
      USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

    CREATE POLICY courses_public_read ON public.courses
      FOR SELECT TO authenticated, anon USING (is_public = TRUE);
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'course_lessons') THEN
    CREATE POLICY course_lessons_owner_all ON public.course_lessons
      FOR ALL TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.courses c
        WHERE c.id = course_id AND c.user_id = auth.uid()
      ))
      WITH CHECK (EXISTS (
        SELECT 1 FROM public.courses c
        WHERE c.id = course_id AND c.user_id = auth.uid()
      ));

    CREATE POLICY course_lessons_public_read ON public.course_lessons
      FOR SELECT TO authenticated, anon
      USING (EXISTS (
        SELECT 1 FROM public.courses c
        WHERE c.id = course_id AND c.is_public = TRUE
      ));
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 10. Guest lesson limit
-- ---------------------------------------------------------------------------
-- Anonymous (guest) users may own at most 5 lessons. Once they upgrade to a
-- real account (link an email / OAuth identity), the JWT's is_anonymous claim
-- flips to false and the limit no longer applies.
CREATE OR REPLACE FUNCTION public.enforce_guest_lesson_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  max_guest_lessons CONSTANT INT := 5;
  current_count INT;
BEGIN
  IF public.is_anonymous_user() THEN
    SELECT COUNT(*) INTO current_count
    FROM public.lessons
    WHERE user_id = NEW.user_id;

    IF current_count >= max_guest_lessons THEN
      RAISE EXCEPTION
        'guest_lesson_limit_reached: guests may create at most % lessons; sign up to create more',
        max_guest_lessons
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_guest_lesson_limit ON public.lessons;
CREATE TRIGGER trg_enforce_guest_lesson_limit
  BEFORE INSERT ON public.lessons
  FOR EACH ROW EXECUTE FUNCTION public.enforce_guest_lesson_limit();

-- ---------------------------------------------------------------------------
-- 11. Cleanup: orphan legacy guest-owned rows, then drop the placeholder user.
--     Lessons previously owned by the shared 00000000-… guest UUID get
--     user_id = NULL so they remain publicly readable but un-editable
--     (no real session has that auth.uid()). Authenticated/anonymous users
--     can still duplicate them by inserting a new row owned by themselves.
-- ---------------------------------------------------------------------------
UPDATE public.lessons
   SET user_id = NULL
 WHERE user_id = '00000000-0000-0000-0000-000000000000';

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['terms', 'concepts', 'questions', 'lesson_texts']
  LOOP
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = t)
       AND EXISTS (
         SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = t AND column_name = 'user_id'
       )
    THEN
      EXECUTE format(
        'UPDATE public.%I SET user_id = NULL WHERE user_id = %L',
        t, '00000000-0000-0000-0000-000000000000');
    END IF;
  END LOOP;
END $$;

DELETE FROM public.users WHERE id = '00000000-0000-0000-0000-000000000000';
