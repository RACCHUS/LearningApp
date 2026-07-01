-- ============================================================================
-- Migration: Fix overly-permissive RLS policies (2026)
-- ============================================================================
-- The previous content policies allowed ANY authenticated user to read (and,
-- because they were FOR ALL, modify) every other user's terms, questions, and
-- concepts via the `OR auth.uid() IS NOT NULL` / `EXISTS (SELECT 1 FROM users)`
-- catch-all clauses.
--
-- This migration replaces them with separate read/write policies:
--   * Read  -> lesson is public (user_id IS NULL) OR owned by the caller.
--   * Write -> caller owns the parent lesson. Public/ownerless content is
--              read-only to end users (service role bypasses RLS for seeding).
--
-- Safe to run multiple times.
-- ============================================================================

-- Drop the old broad policies if they exist.
DROP POLICY IF EXISTS lessons_access ON lessons;
DROP POLICY IF EXISTS terms_access ON terms;
DROP POLICY IF EXISTS questions_access ON questions;
DROP POLICY IF EXISTS concepts_access ON concepts;

-- Also drop the new names first so the migration is idempotent.
DROP POLICY IF EXISTS lessons_read ON lessons;
DROP POLICY IF EXISTS lessons_write ON lessons;
DROP POLICY IF EXISTS terms_read ON terms;
DROP POLICY IF EXISTS terms_write ON terms;
DROP POLICY IF EXISTS questions_read ON questions;
DROP POLICY IF EXISTS questions_write ON questions;
DROP POLICY IF EXISTS concepts_read ON concepts;
DROP POLICY IF EXISTS concepts_write ON concepts;

-- ----------------------------------------------------------------------------
-- LESSONS
-- ----------------------------------------------------------------------------
CREATE POLICY lessons_read ON lessons FOR SELECT USING (
  user_id IS NULL OR auth.uid() = user_id
);
CREATE POLICY lessons_write ON lessons FOR ALL USING (
  auth.uid() = user_id
) WITH CHECK (
  auth.uid() = user_id
);

-- ----------------------------------------------------------------------------
-- TERMS
-- ----------------------------------------------------------------------------
CREATE POLICY terms_read ON terms FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM lessons
    WHERE lessons.id = terms.lesson_id
    AND (lessons.user_id IS NULL OR lessons.user_id = auth.uid())
  )
);
CREATE POLICY terms_write ON terms FOR ALL USING (
  EXISTS (
    SELECT 1 FROM lessons
    WHERE lessons.id = terms.lesson_id AND lessons.user_id = auth.uid()
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM lessons
    WHERE lessons.id = terms.lesson_id AND lessons.user_id = auth.uid()
  )
);

-- ----------------------------------------------------------------------------
-- QUESTIONS
-- ----------------------------------------------------------------------------
CREATE POLICY questions_read ON questions FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM lessons
    WHERE lessons.id = questions.lesson_id
    AND (lessons.user_id IS NULL OR lessons.user_id = auth.uid())
  )
);
CREATE POLICY questions_write ON questions FOR ALL USING (
  EXISTS (
    SELECT 1 FROM lessons
    WHERE lessons.id = questions.lesson_id AND lessons.user_id = auth.uid()
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM lessons
    WHERE lessons.id = questions.lesson_id AND lessons.user_id = auth.uid()
  )
);

-- ----------------------------------------------------------------------------
-- CONCEPTS
-- ----------------------------------------------------------------------------
CREATE POLICY concepts_read ON concepts FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM lessons
    WHERE lessons.id = concepts.lesson_id
    AND (lessons.user_id IS NULL OR lessons.user_id = auth.uid())
  )
);
CREATE POLICY concepts_write ON concepts FOR ALL USING (
  EXISTS (
    SELECT 1 FROM lessons
    WHERE lessons.id = concepts.lesson_id AND lessons.user_id = auth.uid()
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM lessons
    WHERE lessons.id = concepts.lesson_id AND lessons.user_id = auth.uid()
  )
);

-- ----------------------------------------------------------------------------
-- LESSON_TEXTS (only if the table exists in this database)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'lesson_texts') THEN
    EXECUTE 'DROP POLICY IF EXISTS lesson_texts_access ON lesson_texts';
    EXECUTE 'DROP POLICY IF EXISTS lesson_texts_read ON lesson_texts';
    EXECUTE 'DROP POLICY IF EXISTS lesson_texts_write ON lesson_texts';
    EXECUTE '
      CREATE POLICY lesson_texts_read ON lesson_texts FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM lessons
          WHERE lessons.id = lesson_texts.lesson_id
          AND (lessons.user_id IS NULL OR lessons.user_id = auth.uid())
        )
      )';
    EXECUTE '
      CREATE POLICY lesson_texts_write ON lesson_texts FOR ALL USING (
        EXISTS (
          SELECT 1 FROM lessons
          WHERE lessons.id = lesson_texts.lesson_id AND lessons.user_id = auth.uid()
        )
      ) WITH CHECK (
        EXISTS (
          SELECT 1 FROM lessons
          WHERE lessons.id = lesson_texts.lesson_id AND lessons.user_id = auth.uid()
        )
      )';
  END IF;
END $$;
