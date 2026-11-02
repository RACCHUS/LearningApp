-- Migration 83: Port Legacy Skills Taxonomy, Career Paths, and Missing Schema
-- Closes FIX-3: Brings legacy database/ tables, views, and RPCs into the canonical migration chain with hardened RLS.

-- 1. Ensure optional leaderboard preference on users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS show_on_leaderboards BOOLEAN DEFAULT FALSE;

-- 2. Career Paths & Course Junctions
CREATE TABLE IF NOT EXISTS public.career_paths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  image_url TEXT,
  estimated_months INTEGER DEFAULT 6,
  is_public BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  is_official BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_career_paths_slug ON public.career_paths(slug);
CREATE INDEX IF NOT EXISTS idx_career_paths_public ON public.career_paths(is_public);
CREATE INDEX IF NOT EXISTS idx_career_paths_featured ON public.career_paths(is_featured);
CREATE INDEX IF NOT EXISTS idx_career_paths_official ON public.career_paths(is_official);

CREATE TABLE IF NOT EXISTS public.career_path_courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  career_path_id UUID REFERENCES public.career_paths(id) ON DELETE CASCADE NOT NULL,
  course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
  order_index INTEGER DEFAULT 0,
  is_required BOOLEAN DEFAULT TRUE,
  section_title TEXT,
  UNIQUE(career_path_id, course_id)
);
CREATE INDEX IF NOT EXISTS idx_career_path_courses_path ON public.career_path_courses(career_path_id);
CREATE INDEX IF NOT EXISTS idx_career_path_courses_course ON public.career_path_courses(course_id);

-- 3. Skills Taxonomy
CREATE TABLE IF NOT EXISTS public.skills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT UNIQUE NOT NULL,
  category TEXT,
  description TEXT,
  icon_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_skills_slug ON public.skills(slug);
CREATE INDEX IF NOT EXISTS idx_skills_category ON public.skills(category);

CREATE TABLE IF NOT EXISTS public.career_path_skills (
  career_path_id UUID REFERENCES public.career_paths(id) ON DELETE CASCADE,
  skill_id UUID REFERENCES public.skills(id) ON DELETE CASCADE,
  importance TEXT DEFAULT 'core' CHECK (importance IN ('core', 'recommended', 'optional')),
  PRIMARY KEY (career_path_id, skill_id)
);

CREATE TABLE IF NOT EXISTS public.course_skills (
  course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
  skill_id UUID REFERENCES public.skills(id) ON DELETE CASCADE,
  PRIMARY KEY (course_id, skill_id)
);

-- 4. Skill Assessments & Questions
CREATE TABLE IF NOT EXISTS public.skill_assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_id UUID REFERENCES public.skills(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  question_count INTEGER DEFAULT 10,
  time_limit_minutes INTEGER DEFAULT 15,
  passing_score INTEGER DEFAULT 70,
  difficulty TEXT DEFAULT 'intermediate' CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_skill_assessments_skill ON public.skill_assessments(skill_id);
CREATE INDEX IF NOT EXISTS idx_skill_assessments_active ON public.skill_assessments(is_active);

CREATE TABLE IF NOT EXISTS public.assessment_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID REFERENCES public.skill_assessments(id) ON DELETE CASCADE NOT NULL,
  question_text TEXT NOT NULL,
  options JSONB NOT NULL,
  correct_answer INTEGER NOT NULL,
  explanation TEXT,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_assessment_questions_assessment ON public.assessment_questions(assessment_id);

-- 5. User Skill Stats & Attempts
CREATE TABLE IF NOT EXISTS public.user_skill_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  skill_id UUID REFERENCES public.skills(id) ON DELETE CASCADE NOT NULL,
  level INTEGER DEFAULT 0 CHECK (level >= 0 AND level <= 100),
  total_assessments INTEGER DEFAULT 0,
  best_score INTEGER DEFAULT 0,
  average_score NUMERIC(5,2) DEFAULT 0,
  last_assessed_at TIMESTAMPTZ,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, skill_id)
);
CREATE INDEX IF NOT EXISTS idx_user_skill_stats_user ON public.user_skill_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_user_skill_stats_skill ON public.user_skill_stats(skill_id);
CREATE INDEX IF NOT EXISTS idx_user_skill_stats_verified ON public.user_skill_stats(user_id, is_verified);

CREATE TABLE IF NOT EXISTS public.assessment_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID REFERENCES public.skill_assessments(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  score INTEGER,
  correct_count INTEGER DEFAULT 0,
  total_questions INTEGER DEFAULT 0,
  time_taken_seconds INTEGER,
  was_overtime BOOLEAN DEFAULT FALSE,
  is_verified BOOLEAN DEFAULT FALSE,
  is_deleted BOOLEAN DEFAULT FALSE,
  answers JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_assessment_attempts_user ON public.assessment_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_assessment_attempts_assessment ON public.assessment_attempts(assessment_id);
CREATE INDEX IF NOT EXISTS idx_assessment_attempts_verified ON public.assessment_attempts(user_id, is_verified);
CREATE INDEX IF NOT EXISTS idx_assessment_attempts_deleted ON public.assessment_attempts(is_deleted);

-- Reconcile legacy column defaults from TRUE to FALSE for already-existing schemas
ALTER TABLE public.assessment_attempts ALTER COLUMN is_verified SET DEFAULT FALSE;
ALTER TABLE public.user_skill_stats ALTER COLUMN is_verified SET DEFAULT FALSE;

-- Quarantine existing legacy client-asserted attempts and stats as unverified
UPDATE public.assessment_attempts SET is_verified = FALSE WHERE is_verified = TRUE;
UPDATE public.user_skill_stats SET is_verified = FALSE WHERE is_verified = TRUE;

-- 6. User Career Paths & Snapshots
CREATE TABLE IF NOT EXISTS public.user_career_paths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  career_path_id UUID REFERENCES public.career_paths(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'abandoned')),
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, career_path_id)
);
CREATE INDEX IF NOT EXISTS idx_user_career_paths_user ON public.user_career_paths(user_id);
CREATE INDEX IF NOT EXISTS idx_user_career_paths_path ON public.user_career_paths(career_path_id);
CREATE INDEX IF NOT EXISTS idx_user_career_paths_status ON public.user_career_paths(status);
CREATE INDEX IF NOT EXISTS idx_user_career_paths_deleted ON public.user_career_paths(is_deleted);

CREATE TABLE IF NOT EXISTS public.user_data_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  snapshot_type TEXT NOT NULL CHECK (snapshot_type IN ('skill_reset', 'career_reset', 'course_reset', 'full_reset')),
  target_id UUID,
  target_name TEXT,
  snapshot_data JSONB NOT NULL,
  reason TEXT,
  revert_scope TEXT DEFAULT 'full' CHECK (revert_scope IN ('full', 'single_attempt', 'all_attempts')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '30 days',
  is_reverted BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_snapshots_user ON public.user_data_snapshots(user_id);
CREATE INDEX IF NOT EXISTS idx_snapshots_type ON public.user_data_snapshots(snapshot_type);
CREATE INDEX IF NOT EXISTS idx_snapshots_expires ON public.user_data_snapshots(expires_at);
CREATE INDEX IF NOT EXISTS idx_snapshots_reverted ON public.user_data_snapshots(is_reverted);

-- 7. Lesson Texts (Supplementary content)
CREATE TABLE IF NOT EXISTS public.lesson_texts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
  text TEXT NOT NULL,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  user_id UUID REFERENCES public.users(id)
);
CREATE INDEX IF NOT EXISTS idx_lesson_texts_lesson_id ON public.lesson_texts(lesson_id);
CREATE INDEX IF NOT EXISTS idx_lesson_texts_order ON public.lesson_texts(lesson_id, order_index);

-- 8. Views
CREATE OR REPLACE VIEW public.study_progress
WITH (security_invoker = true) AS
SELECT 
  id,
  user_id,
  lesson_id,
  date,
  questions_answered,
  correct_count,
  lesson_completed,
  study_time_minutes,
  study_time_seconds
FROM public.user_progress;

CREATE OR REPLACE VIEW public.skill_leaderboard AS
SELECT 
  uss.skill_id,
  s.name as skill_name,
  u.id as user_id,
  u.display_name,
  uss.level,
  uss.best_score,
  uss.total_assessments,
  ROW_NUMBER() OVER (PARTITION BY uss.skill_id ORDER BY uss.level DESC, uss.best_score DESC) as rank
FROM public.user_skill_stats uss
JOIN public.users u ON u.id = uss.user_id
JOIN public.skills s ON s.id = uss.skill_id
WHERE u.show_on_leaderboards = TRUE 
  AND uss.is_verified = TRUE
  AND uss.level > 0;

-- 9. Row Level Security Configuration
ALTER TABLE public.career_paths ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_path_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_path_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skill_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessment_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_skill_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessment_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_career_paths ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_data_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_texts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS career_paths_read ON public.career_paths;
CREATE POLICY career_paths_read ON public.career_paths FOR SELECT USING (
  is_public = TRUE OR created_by = (SELECT auth.uid())
);

DROP POLICY IF EXISTS career_paths_write ON public.career_paths;
CREATE POLICY career_paths_write ON public.career_paths FOR ALL 
USING (created_by = (SELECT auth.uid()))
WITH CHECK (
  created_by = (SELECT auth.uid()) 
  AND is_official = FALSE 
  AND is_featured = FALSE
);

DROP POLICY IF EXISTS career_path_courses_read ON public.career_path_courses;
CREATE POLICY career_path_courses_read ON public.career_path_courses FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.career_paths 
    WHERE career_paths.id = career_path_courses.career_path_id 
    AND (career_paths.is_public = TRUE OR career_paths.created_by = (SELECT auth.uid()))
  )
);

DROP POLICY IF EXISTS career_path_courses_write ON public.career_path_courses;
CREATE POLICY career_path_courses_write ON public.career_path_courses FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.career_paths 
    WHERE career_paths.id = career_path_courses.career_path_id 
    AND career_paths.created_by = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS skills_read ON public.skills;
CREATE POLICY skills_read ON public.skills FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS career_path_skills_read ON public.career_path_skills;
CREATE POLICY career_path_skills_read ON public.career_path_skills FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.career_paths 
    WHERE career_paths.id = career_path_skills.career_path_id 
    AND (career_paths.is_public = TRUE OR career_paths.created_by = (SELECT auth.uid()))
  )
);

DROP POLICY IF EXISTS course_skills_read ON public.course_skills;
CREATE POLICY course_skills_read ON public.course_skills FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS skill_assessments_read ON public.skill_assessments;
CREATE POLICY skill_assessments_read ON public.skill_assessments FOR SELECT USING (is_active = TRUE);

DROP POLICY IF EXISTS assessment_questions_read ON public.assessment_questions;
CREATE POLICY assessment_questions_read ON public.assessment_questions FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.skill_assessments 
    WHERE skill_assessments.id = assessment_questions.assessment_id 
    AND skill_assessments.is_active = TRUE
  )
);

-- user_skill_stats: client can only read own stats; modifications are strictly server-side
DROP POLICY IF EXISTS user_skill_stats_own ON public.user_skill_stats;
DROP POLICY IF EXISTS user_skill_stats_select ON public.user_skill_stats;
CREATE POLICY user_skill_stats_select ON public.user_skill_stats FOR SELECT 
USING (user_id = (SELECT auth.uid()));

-- assessment_attempts: client can read and submit own attempts, but cannot self-certify verified status
DROP POLICY IF EXISTS assessment_attempts_own ON public.assessment_attempts;
DROP POLICY IF EXISTS assessment_attempts_select ON public.assessment_attempts;
CREATE POLICY assessment_attempts_select ON public.assessment_attempts FOR SELECT 
USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS assessment_attempts_insert ON public.assessment_attempts;
CREATE POLICY assessment_attempts_insert ON public.assessment_attempts FOR INSERT 
WITH CHECK (user_id = (SELECT auth.uid()) AND is_verified = FALSE);

DROP POLICY IF EXISTS assessment_attempts_update ON public.assessment_attempts;
CREATE POLICY assessment_attempts_update ON public.assessment_attempts FOR UPDATE 
USING (user_id = (SELECT auth.uid())) 
WITH CHECK (user_id = (SELECT auth.uid()) AND is_verified = FALSE);

DROP POLICY IF EXISTS user_career_paths_own ON public.user_career_paths;
CREATE POLICY user_career_paths_own ON public.user_career_paths FOR ALL USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS user_data_snapshots_own ON public.user_data_snapshots;
CREATE POLICY user_data_snapshots_own ON public.user_data_snapshots FOR ALL USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS lesson_texts_read ON public.lesson_texts;
DROP POLICY IF EXISTS lesson_texts_read_all ON public.lesson_texts;
DROP POLICY IF EXISTS lesson_texts_read_visible ON public.lesson_texts;
CREATE POLICY lesson_texts_read_visible ON public.lesson_texts
  FOR SELECT TO authenticated, anon
  USING (public.is_lesson_visible(lesson_id));

DROP POLICY IF EXISTS lesson_texts_write ON public.lesson_texts;
DROP POLICY IF EXISTS lesson_texts_owner_write ON public.lesson_texts;
CREATE POLICY lesson_texts_owner_write ON public.lesson_texts
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.lessons 
    WHERE lessons.id = lesson_texts.lesson_id 
    AND lessons.user_id = (SELECT auth.uid())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.lessons 
    WHERE lessons.id = lesson_texts.lesson_id 
    AND lessons.user_id = (SELECT auth.uid())
  ));

-- 10. RPCs: calculate_skill_level, update_skill_stats_after_assessment, soft_delete_skill_attempts, increment_course_time
CREATE OR REPLACE FUNCTION public.calculate_skill_level(p_user_id UUID, p_skill_id UUID) 
RETURNS INTEGER AS $$
DECLARE
  v_level INTEGER;
BEGIN
  SELECT COALESCE(AVG(score)::INTEGER, 0) INTO v_level
  FROM (
    SELECT aa.score
    FROM public.assessment_attempts aa
    JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
    WHERE aa.user_id = p_user_id
      AND sa.skill_id = p_skill_id
      AND aa.is_verified = TRUE
      AND aa.is_deleted = FALSE
      AND aa.score IS NOT NULL
    ORDER BY aa.score DESC
    LIMIT 3
  ) best_attempts;
  
  RETURN v_level;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.calculate_skill_level(UUID, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.calculate_skill_level(UUID, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.calculate_skill_level(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_skill_level(UUID, UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.recompute_user_skill_stat(p_user_id UUID, p_skill_id UUID) 
RETURNS VOID AS $$
DECLARE
  v_new_level INTEGER := 0;
  v_best_score INTEGER := 0;
  v_avg_score NUMERIC(5,2) := 0;
  v_total INTEGER := 0;
  v_has_verified BOOLEAN := FALSE;
BEGIN
  IF p_user_id IS NULL OR p_skill_id IS NULL THEN
    RETURN;
  END IF;

  -- Advisory transaction lock to serialize concurrent recalculations per user and skill
  PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text), hashtext(p_skill_id::text));

  -- Count eligible, non-deleted, completed attempts with a score
  SELECT COUNT(*) INTO v_total
  FROM public.assessment_attempts aa
  JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
  WHERE aa.user_id = p_user_id
    AND sa.skill_id = p_skill_id
    AND aa.is_deleted = FALSE
    AND aa.completed_at IS NOT NULL
    AND aa.score IS NOT NULL;

  -- If no completed non-deleted attempts remain, remove aggregate record from user_skill_stats
  IF v_total = 0 THEN
    DELETE FROM public.user_skill_stats
    WHERE user_id = p_user_id
      AND skill_id = p_skill_id;
    RETURN;
  END IF;

  -- Check if any verified, non-deleted attempts exist for this user and skill
  SELECT EXISTS (
    SELECT 1 FROM public.assessment_attempts aa
    JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
    WHERE aa.user_id = p_user_id
      AND sa.skill_id = p_skill_id
      AND aa.is_verified = TRUE
      AND aa.is_deleted = FALSE
      AND aa.completed_at IS NOT NULL
      AND aa.score IS NOT NULL
  ) INTO v_has_verified;

  IF v_has_verified THEN
    v_new_level := public.calculate_skill_level(p_user_id, p_skill_id);
    
    SELECT 
      MAX(score),
      AVG(score)::NUMERIC(5,2),
      COUNT(*)
    INTO v_best_score, v_avg_score, v_total
    FROM public.assessment_attempts aa
    JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
    WHERE aa.user_id = p_user_id
      AND sa.skill_id = p_skill_id
      AND aa.is_verified = TRUE
      AND aa.is_deleted = FALSE
      AND aa.completed_at IS NOT NULL
      AND aa.score IS NOT NULL;
  ELSE
    -- Practice / unverified aggregate derived from all non-deleted completed attempts
    SELECT COALESCE(AVG(score)::INTEGER, 0) INTO v_new_level
    FROM (
      SELECT aa.score
      FROM public.assessment_attempts aa
      JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
      WHERE aa.user_id = p_user_id
        AND sa.skill_id = p_skill_id
        AND aa.is_deleted = FALSE
        AND aa.completed_at IS NOT NULL
        AND aa.score IS NOT NULL
      ORDER BY aa.score DESC
      LIMIT 3
    ) recent_attempts;

    SELECT 
      MAX(score),
      AVG(score)::NUMERIC(5,2),
      COUNT(*)
    INTO v_best_score, v_avg_score, v_total
    FROM public.assessment_attempts aa
    JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
    WHERE aa.user_id = p_user_id
      AND sa.skill_id = p_skill_id
      AND aa.is_deleted = FALSE
      AND aa.completed_at IS NOT NULL
      AND aa.score IS NOT NULL;
  END IF;
  
  INSERT INTO public.user_skill_stats (user_id, skill_id, level, best_score, average_score, total_assessments, last_assessed_at, is_verified)
  VALUES (p_user_id, p_skill_id, v_new_level, COALESCE(v_best_score, 0), COALESCE(v_avg_score, 0), COALESCE(v_total, 0), NOW(), v_has_verified)
  ON CONFLICT (user_id, skill_id) 
  DO UPDATE SET
    level = v_new_level,
    best_score = COALESCE(v_best_score, user_skill_stats.best_score),
    average_score = COALESCE(v_avg_score, user_skill_stats.average_score),
    total_assessments = COALESCE(v_total, user_skill_stats.total_assessments),
    is_verified = v_has_verified,
    last_assessed_at = NOW(),
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.recompute_user_skill_stat(UUID, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.recompute_user_skill_stat(UUID, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.recompute_user_skill_stat(UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_user_skill_stat(UUID, UUID) TO service_role;

CREATE OR REPLACE FUNCTION public.update_skill_stats_after_assessment() 
RETURNS TRIGGER AS $$
DECLARE
  v_old_skill_id UUID;
  v_new_skill_id UUID;
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    SELECT skill_id INTO v_old_skill_id
    FROM public.skill_assessments
    WHERE id = OLD.assessment_id;

    IF v_old_skill_id IS NOT NULL AND OLD.user_id IS NOT NULL THEN
      PERFORM public.recompute_user_skill_stat(OLD.user_id, v_old_skill_id);
    END IF;
  END IF;

  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    SELECT skill_id INTO v_new_skill_id
    FROM public.skill_assessments
    WHERE id = NEW.assessment_id;

    IF v_new_skill_id IS NOT NULL AND NEW.user_id IS NOT NULL THEN
      -- If UPDATE touched neither user_id nor skill_id, it was already recomputed in the block above
      IF TG_OP = 'UPDATE' AND NEW.user_id = OLD.user_id AND v_new_skill_id = v_old_skill_id THEN
        NULL;
      ELSE
        PERFORM public.recompute_user_skill_stat(NEW.user_id, v_new_skill_id);
      END IF;
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.update_skill_stats_after_assessment() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_skill_stats_after_assessment() FROM anon;
GRANT EXECUTE ON FUNCTION public.update_skill_stats_after_assessment() TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_skill_stats_after_assessment() TO service_role;

DROP TRIGGER IF EXISTS trg_update_skill_stats ON public.assessment_attempts;
CREATE TRIGGER trg_update_skill_stats
AFTER INSERT OR UPDATE OF score, completed_at, is_deleted, is_verified, assessment_id, user_id OR DELETE
ON public.assessment_attempts
FOR EACH ROW
EXECUTE FUNCTION public.update_skill_stats_after_assessment();

CREATE OR REPLACE FUNCTION public.check_assessment_attempt_immutability()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.assessment_id IS DISTINCT FROM OLD.assessment_id THEN
    RAISE EXCEPTION 'assessment_id is immutable once an attempt is created';
  END IF;
  IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    RAISE EXCEPTION 'user_id is immutable once an attempt is created';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.check_assessment_attempt_immutability() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_assessment_attempt_immutability() FROM anon;
GRANT EXECUTE ON FUNCTION public.check_assessment_attempt_immutability() TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_assessment_attempt_immutability() TO service_role;

DROP TRIGGER IF EXISTS trg_assessment_attempt_immutability ON public.assessment_attempts;
CREATE TRIGGER trg_assessment_attempt_immutability
BEFORE UPDATE OF assessment_id, user_id ON public.assessment_attempts
FOR EACH ROW
EXECUTE FUNCTION public.check_assessment_attempt_immutability();

CREATE OR REPLACE FUNCTION public.soft_delete_skill_attempts(p_user_id UUID, p_skill_id UUID)
RETURNS VOID AS $$
DECLARE
  v_auth_uid UUID := (SELECT auth.uid());
BEGIN
  IF v_auth_uid IS NULL OR (v_auth_uid <> p_user_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE public.assessment_attempts
  SET is_deleted = TRUE,
      is_verified = FALSE
  WHERE user_id = p_user_id
    AND assessment_id IN (
      SELECT id FROM public.skill_assessments WHERE skill_id = p_skill_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

CREATE OR REPLACE FUNCTION public.increment_course_time(p_user_id UUID, p_course_id UUID, p_minutes INTEGER)
RETURNS VOID AS $$
DECLARE
  v_auth_uid UUID := (SELECT auth.uid());
BEGIN
  IF v_auth_uid IS NULL OR (v_auth_uid <> p_user_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_minutes <= 0 THEN
    RETURN;
  END IF;

  UPDATE public.course_progress
  SET total_time_minutes = COALESCE(total_time_minutes, 0) + p_minutes,
      last_accessed_at = NOW()
  WHERE user_id = p_user_id
    AND course_id = p_course_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.soft_delete_skill_attempts(UUID, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.soft_delete_skill_attempts(UUID, UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.soft_delete_skill_attempts(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.soft_delete_skill_attempts(UUID, UUID) TO service_role;

REVOKE EXECUTE ON FUNCTION public.increment_course_time(UUID, UUID, INTEGER) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_course_time(UUID, UUID, INTEGER) FROM anon;
GRANT EXECUTE ON FUNCTION public.increment_course_time(UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_course_time(UUID, UUID, INTEGER) TO service_role;

-- 11. Explicit Least-Privilege Grants for PostgREST / Data API Exposure

-- Revoke all by default from PUBLIC, anon, and authenticated to eliminate legacy blanket grants
REVOKE ALL ON public.career_paths,
              public.career_path_courses,
              public.skills,
              public.career_path_skills,
              public.course_skills,
              public.skill_assessments,
              public.assessment_questions,
              public.user_skill_stats,
              public.assessment_attempts,
              public.user_career_paths,
              public.user_data_snapshots,
              public.lesson_texts,
              public.study_progress,
              public.skill_leaderboard
FROM PUBLIC, anon, authenticated;

-- Public / Catalog tables: read-only for anon, authenticated
GRANT SELECT ON public.skills TO anon, authenticated;
GRANT SELECT ON public.career_paths TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.career_paths TO authenticated;
GRANT SELECT ON public.career_path_courses TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.career_path_courses TO authenticated;
GRANT SELECT ON public.career_path_skills TO anon, authenticated;
GRANT SELECT ON public.course_skills TO anon, authenticated;
GRANT SELECT ON public.skill_assessments TO anon, authenticated;
GRANT SELECT ON public.assessment_questions TO anon, authenticated;

-- Supplementary lesson texts: visibility-gated SELECT for anon & authenticated, owner writes
GRANT SELECT ON public.lesson_texts TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.lesson_texts TO authenticated;

-- User-specific tables: authenticated access matching RLS policies
GRANT SELECT, INSERT, UPDATE ON public.assessment_attempts TO authenticated;
GRANT SELECT ON public.user_skill_stats TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_career_paths TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_data_snapshots TO authenticated;

-- Views: authenticated user access for private study progress, public read for leaderboard
GRANT SELECT ON public.study_progress TO authenticated;
GRANT SELECT ON public.skill_leaderboard TO anon, authenticated;

-- Service role: full access on all ported tables and views
GRANT ALL ON public.career_paths,
              public.career_path_courses,
              public.skills,
              public.career_path_skills,
              public.course_skills,
              public.skill_assessments,
              public.assessment_questions,
              public.user_skill_stats,
              public.assessment_attempts,
              public.user_career_paths,
              public.user_data_snapshots,
              public.lesson_texts,
              public.study_progress,
              public.skill_leaderboard
TO service_role;


