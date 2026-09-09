-- ============================================================================
-- CAREER PATHS & SKILLS ASSESSMENT SYSTEM
-- Migration: 20241229_career_skills.sql
-- ============================================================================

-- ============================================================================
-- CAREER PATHS (Top-level hierarchy above courses)
-- ============================================================================
CREATE TABLE IF NOT EXISTS career_paths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  image_url TEXT,
  estimated_months INTEGER DEFAULT 6,
  is_public BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  is_official BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_career_paths_slug ON career_paths(slug);
CREATE INDEX IF NOT EXISTS idx_career_paths_public ON career_paths(is_public);
CREATE INDEX IF NOT EXISTS idx_career_paths_featured ON career_paths(is_featured);
CREATE INDEX IF NOT EXISTS idx_career_paths_official ON career_paths(is_official);

-- ============================================================================
-- CAREER PATH → COURSE JUNCTION (Ordered)
-- ============================================================================
CREATE TABLE IF NOT EXISTS career_path_courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  career_path_id UUID REFERENCES career_paths(id) ON DELETE CASCADE NOT NULL,
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE NOT NULL,
  order_index INTEGER DEFAULT 0,
  is_required BOOLEAN DEFAULT TRUE,
  section_title TEXT,
  UNIQUE(career_path_id, course_id)
);
CREATE INDEX IF NOT EXISTS idx_career_path_courses_path ON career_path_courses(career_path_id);
CREATE INDEX IF NOT EXISTS idx_career_path_courses_course ON career_path_courses(course_id);

-- ============================================================================
-- SKILLS TAXONOMY
-- ============================================================================
CREATE TABLE IF NOT EXISTS skills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT UNIQUE NOT NULL,
  category TEXT,  -- "Programming", "Data", "Design", "Business", "Soft Skills"
  description TEXT,
  icon_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_skills_slug ON skills(slug);
CREATE INDEX IF NOT EXISTS idx_skills_category ON skills(category);

-- ============================================================================
-- CAREER PATH → SKILLS JUNCTION
-- ============================================================================
CREATE TABLE IF NOT EXISTS career_path_skills (
  career_path_id UUID REFERENCES career_paths(id) ON DELETE CASCADE,
  skill_id UUID REFERENCES skills(id) ON DELETE CASCADE,
  importance TEXT DEFAULT 'core' CHECK (importance IN ('core', 'recommended', 'optional')),
  PRIMARY KEY (career_path_id, skill_id)
);

-- ============================================================================
-- COURSE → SKILLS JUNCTION (What skills a course teaches)
-- ============================================================================
CREATE TABLE IF NOT EXISTS course_skills (
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
  skill_id UUID REFERENCES skills(id) ON DELETE CASCADE,
  PRIMARY KEY (course_id, skill_id)
);

-- ============================================================================
-- SKILL ASSESSMENTS (Test definitions)
-- ============================================================================
CREATE TABLE IF NOT EXISTS skill_assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_id UUID REFERENCES skills(id) ON DELETE CASCADE NOT NULL,
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
CREATE INDEX IF NOT EXISTS idx_skill_assessments_skill ON skill_assessments(skill_id);
CREATE INDEX IF NOT EXISTS idx_skill_assessments_active ON skill_assessments(is_active);

-- ============================================================================
-- ASSESSMENT QUESTIONS (Separate from lesson questions)
-- ============================================================================
CREATE TABLE IF NOT EXISTS assessment_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID REFERENCES skill_assessments(id) ON DELETE CASCADE NOT NULL,
  question_text TEXT NOT NULL,
  options JSONB NOT NULL,  -- ["option1", "option2", "option3", "option4"]
  correct_answer INTEGER NOT NULL,  -- 0-based index
  explanation TEXT,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_assessment_questions_assessment ON assessment_questions(assessment_id);

-- ============================================================================
-- USER SKILL STATS (User's skill profile)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_skill_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  skill_id UUID REFERENCES skills(id) ON DELETE CASCADE NOT NULL,
  level INTEGER DEFAULT 0 CHECK (level >= 0 AND level <= 100),
  total_assessments INTEGER DEFAULT 0,
  best_score INTEGER DEFAULT 0,
  average_score NUMERIC(5,2) DEFAULT 0,
  last_assessed_at TIMESTAMPTZ,
  is_verified BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, skill_id)
);
CREATE INDEX IF NOT EXISTS idx_user_skill_stats_user ON user_skill_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_user_skill_stats_skill ON user_skill_stats(skill_id);
CREATE INDEX IF NOT EXISTS idx_user_skill_stats_verified ON user_skill_stats(user_id, is_verified);

-- ============================================================================
-- ASSESSMENT ATTEMPTS (User's test attempts)
-- ============================================================================
CREATE TABLE IF NOT EXISTS assessment_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID REFERENCES skill_assessments(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  score INTEGER,
  correct_count INTEGER DEFAULT 0,
  total_questions INTEGER DEFAULT 0,
  time_taken_seconds INTEGER,
  was_overtime BOOLEAN DEFAULT FALSE,
  is_verified BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,  -- Soft delete for revert
  answers JSONB,  -- { "question_id": chosen_answer_index, ... }
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_assessment_attempts_user ON assessment_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_assessment_attempts_assessment ON assessment_attempts(assessment_id);
CREATE INDEX IF NOT EXISTS idx_assessment_attempts_verified ON assessment_attempts(user_id, is_verified);
CREATE INDEX IF NOT EXISTS idx_assessment_attempts_deleted ON assessment_attempts(is_deleted);

-- ============================================================================
-- USER CAREER PATH ENROLLMENT
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_career_paths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  career_path_id UUID REFERENCES career_paths(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'abandoned')),
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  is_deleted BOOLEAN DEFAULT FALSE,  -- Soft delete for revert
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, career_path_id)
);
CREATE INDEX IF NOT EXISTS idx_user_career_paths_user ON user_career_paths(user_id);
CREATE INDEX IF NOT EXISTS idx_user_career_paths_path ON user_career_paths(career_path_id);
CREATE INDEX IF NOT EXISTS idx_user_career_paths_status ON user_career_paths(status);
CREATE INDEX IF NOT EXISTS idx_user_career_paths_deleted ON user_career_paths(is_deleted);

-- ============================================================================
-- USER DATA SNAPSHOTS (For reset/revert functionality)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_data_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  snapshot_type TEXT NOT NULL CHECK (snapshot_type IN ('skill_reset', 'career_reset', 'course_reset', 'full_reset')),
  target_id UUID,  -- skill_id, career_path_id, course_id, or NULL for full reset
  target_name TEXT,  -- Human-readable name for display
  snapshot_data JSONB NOT NULL,  -- Full state before reset
  reason TEXT,  -- Optional user-provided reason
  revert_scope TEXT DEFAULT 'full' CHECK (revert_scope IN ('full', 'single_attempt', 'all_attempts')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '30 days',
  is_reverted BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_snapshots_user ON user_data_snapshots(user_id);
CREATE INDEX IF NOT EXISTS idx_snapshots_type ON user_data_snapshots(snapshot_type);
CREATE INDEX IF NOT EXISTS idx_snapshots_expires ON user_data_snapshots(expires_at);
CREATE INDEX IF NOT EXISTS idx_snapshots_reverted ON user_data_snapshots(is_reverted);

-- ============================================================================
-- ADD LEADERBOARD OPT-IN TO USERS
-- ============================================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS show_on_leaderboards BOOLEAN DEFAULT FALSE;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE career_paths ENABLE ROW LEVEL SECURITY;
ALTER TABLE career_path_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE career_path_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE skill_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_skill_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_career_paths ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_data_snapshots ENABLE ROW LEVEL SECURITY;

-- Career paths: public read, owner/admin write
CREATE POLICY career_paths_read ON career_paths FOR SELECT USING (
  is_public = TRUE OR created_by = auth.uid()
);
CREATE POLICY career_paths_write ON career_paths FOR ALL USING (
  created_by = auth.uid()
);

-- Career path courses: follow parent career_path permissions
CREATE POLICY career_path_courses_read ON career_path_courses FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM career_paths 
    WHERE career_paths.id = career_path_courses.career_path_id 
    AND (career_paths.is_public = TRUE OR career_paths.created_by = auth.uid())
  )
);
CREATE POLICY career_path_courses_write ON career_path_courses FOR ALL USING (
  EXISTS (
    SELECT 1 FROM career_paths 
    WHERE career_paths.id = career_path_courses.career_path_id 
    AND career_paths.created_by = auth.uid()
  )
);

-- Skills: public read (taxonomy is public)
CREATE POLICY skills_read ON skills FOR SELECT USING (TRUE);

-- Career path skills: follow parent permissions
CREATE POLICY career_path_skills_read ON career_path_skills FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM career_paths 
    WHERE career_paths.id = career_path_skills.career_path_id 
    AND (career_paths.is_public = TRUE OR career_paths.created_by = auth.uid())
  )
);

-- Course skills: follow course permissions (already have course policies)
CREATE POLICY course_skills_read ON course_skills FOR SELECT USING (TRUE);

-- Skill assessments: public read
CREATE POLICY skill_assessments_read ON skill_assessments FOR SELECT USING (is_active = TRUE);

-- Assessment questions: public read
CREATE POLICY assessment_questions_read ON assessment_questions FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM skill_assessments 
    WHERE skill_assessments.id = assessment_questions.assessment_id 
    AND skill_assessments.is_active = TRUE
  )
);

-- User skill stats: own data only
CREATE POLICY user_skill_stats_own ON user_skill_stats FOR ALL USING (user_id = auth.uid());

-- Assessment attempts: own data only
CREATE POLICY assessment_attempts_own ON assessment_attempts FOR ALL USING (user_id = auth.uid());

-- User career paths: own data only
CREATE POLICY user_career_paths_own ON user_career_paths FOR ALL USING (user_id = auth.uid());

-- Snapshots: own data only
CREATE POLICY user_data_snapshots_own ON user_data_snapshots FOR ALL USING (user_id = auth.uid());

-- ============================================================================
-- SKILL LEADERBOARD VIEW
-- ============================================================================
CREATE OR REPLACE VIEW skill_leaderboard AS
SELECT 
  uss.skill_id,
  s.name as skill_name,
  u.id as user_id,
  u.display_name,
  uss.level,
  uss.best_score,
  uss.total_assessments,
  ROW_NUMBER() OVER (PARTITION BY uss.skill_id ORDER BY uss.level DESC, uss.best_score DESC) as rank
FROM user_skill_stats uss
JOIN users u ON u.id = uss.user_id
JOIN skills s ON s.id = uss.skill_id
WHERE u.show_on_leaderboards = TRUE 
  AND uss.is_verified = TRUE
  AND uss.level > 0;

-- ============================================================================
-- CLEANUP FUNCTION (Scheduled job for permanent deletion)
-- ============================================================================
CREATE OR REPLACE FUNCTION cleanup_expired_data() RETURNS void AS $$
BEGIN
  -- Delete expired snapshots
  DELETE FROM user_data_snapshots 
  WHERE expires_at < NOW();
  
  -- Hard delete soft-deleted attempts older than 30 days
  DELETE FROM assessment_attempts 
  WHERE is_deleted = TRUE 
  AND created_at < NOW() - INTERVAL '30 days';
  
  -- Hard delete soft-deleted career enrollments older than 30 days
  DELETE FROM user_career_paths 
  WHERE is_deleted = TRUE 
  AND started_at < NOW() - INTERVAL '30 days';
  
  -- Log cleanup (optional - for debugging)
  RAISE NOTICE 'Cleanup completed at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Calculate skill level from assessment attempts
CREATE OR REPLACE FUNCTION calculate_skill_level(p_user_id UUID, p_skill_id UUID) 
RETURNS INTEGER AS $$
DECLARE
  v_level INTEGER;
BEGIN
  -- Average of best 3 verified, non-deleted attempts
  SELECT COALESCE(AVG(score)::INTEGER, 0) INTO v_level
  FROM (
    SELECT aa.score
    FROM assessment_attempts aa
    JOIN skill_assessments sa ON sa.id = aa.assessment_id
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
$$ LANGUAGE plpgsql;

-- Update user skill stats after assessment completion
CREATE OR REPLACE FUNCTION update_skill_stats_after_assessment() 
RETURNS TRIGGER AS $$
DECLARE
  v_skill_id UUID;
  v_new_level INTEGER;
  v_best_score INTEGER;
  v_avg_score NUMERIC(5,2);
  v_total INTEGER;
BEGIN
  -- Only process if attempt is completed and not deleted
  IF NEW.completed_at IS NOT NULL AND NEW.is_deleted = FALSE THEN
    -- Get the skill_id from the assessment
    SELECT skill_id INTO v_skill_id
    FROM skill_assessments
    WHERE id = NEW.assessment_id;
    
    -- Calculate new stats
    v_new_level := calculate_skill_level(NEW.user_id, v_skill_id);
    
    SELECT 
      MAX(score),
      AVG(score)::NUMERIC(5,2),
      COUNT(*)
    INTO v_best_score, v_avg_score, v_total
    FROM assessment_attempts aa
    JOIN skill_assessments sa ON sa.id = aa.assessment_id
    WHERE aa.user_id = NEW.user_id
      AND sa.skill_id = v_skill_id
      AND aa.is_verified = TRUE
      AND aa.is_deleted = FALSE
      AND aa.score IS NOT NULL;
    
    -- Upsert user_skill_stats
    INSERT INTO user_skill_stats (user_id, skill_id, level, best_score, average_score, total_assessments, last_assessed_at, is_verified)
    VALUES (NEW.user_id, v_skill_id, v_new_level, COALESCE(v_best_score, 0), COALESCE(v_avg_score, 0), COALESCE(v_total, 0), NOW(), TRUE)
    ON CONFLICT (user_id, skill_id) 
    DO UPDATE SET
      level = v_new_level,
      best_score = COALESCE(v_best_score, user_skill_stats.best_score),
      average_score = COALESCE(v_avg_score, user_skill_stats.average_score),
      total_assessments = COALESCE(v_total, user_skill_stats.total_assessments),
      last_assessed_at = NOW(),
      updated_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update skill stats
DROP TRIGGER IF EXISTS trg_update_skill_stats ON assessment_attempts;
CREATE TRIGGER trg_update_skill_stats
AFTER INSERT OR UPDATE OF score, completed_at, is_deleted, is_verified
ON assessment_attempts
FOR EACH ROW
EXECUTE FUNCTION update_skill_stats_after_assessment();
