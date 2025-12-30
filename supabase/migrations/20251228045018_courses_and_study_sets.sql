-- Migration: courses_and_study_sets
-- Purpose: Add tables for courses, study sets, and their progress tracking
-- This enables: creating subjects/courses, mixing lessons, saving custom study sets

-- ============================================================================
-- 1. COURSES TABLE
-- ============================================================================
-- Courses (subjects) are collections of lessons organized by the user
CREATE TABLE IF NOT EXISTS courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT,
  difficulty TEXT DEFAULT 'beginner' CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
  tags TEXT[] DEFAULT '{}',
  image_url TEXT,
  is_public BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  estimated_hours INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for courses
CREATE INDEX IF NOT EXISTS idx_courses_user_id ON courses(user_id);
CREATE INDEX IF NOT EXISTS idx_courses_status ON courses(status);
CREATE INDEX IF NOT EXISTS idx_courses_is_public ON courses(is_public);
CREATE INDEX IF NOT EXISTS idx_courses_tags ON courses USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_courses_category ON courses(category);

-- ============================================================================
-- 2. COURSE_LESSONS JUNCTION TABLE
-- ============================================================================
-- Links lessons to courses with ordering
CREATE TABLE IF NOT EXISTS course_lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE NOT NULL,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE NOT NULL,
  order_index INTEGER DEFAULT 0,
  is_required BOOLEAN DEFAULT TRUE,
  section_title TEXT, -- Optional grouping within course (e.g., "Week 1", "Introduction")
  added_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(course_id, lesson_id)
);

-- Indexes for course_lessons
CREATE INDEX IF NOT EXISTS idx_course_lessons_course_id ON course_lessons(course_id);
CREATE INDEX IF NOT EXISTS idx_course_lessons_lesson_id ON course_lessons(lesson_id);
CREATE INDEX IF NOT EXISTS idx_course_lessons_order ON course_lessons(course_id, order_index);

-- ============================================================================
-- 3. STUDY_SETS TABLE
-- ============================================================================
-- Saved custom study sets that can mix content from multiple lessons
CREATE TABLE IF NOT EXISTS study_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  -- Arrays of IDs for flexible content mixing
  lesson_ids UUID[] DEFAULT '{}',      -- Full lessons to include
  question_ids UUID[] DEFAULT '{}',    -- Specific questions to include
  term_ids UUID[] DEFAULT '{}',        -- Specific flashcard terms to include
  concept_ids UUID[] DEFAULT '{}',     -- Specific concepts to include
  -- Metadata
  is_favorite BOOLEAN DEFAULT FALSE,
  tags TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for study_sets
CREATE INDEX IF NOT EXISTS idx_study_sets_user_id ON study_sets(user_id);
CREATE INDEX IF NOT EXISTS idx_study_sets_is_favorite ON study_sets(user_id, is_favorite);
CREATE INDEX IF NOT EXISTS idx_study_sets_lesson_ids ON study_sets USING GIN(lesson_ids);

-- ============================================================================
-- 4. COURSE_PROGRESS TABLE
-- ============================================================================
-- Tracks user progress through entire courses
CREATE TABLE IF NOT EXISTS course_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE NOT NULL,
  -- Progress tracking
  lessons_completed INTEGER DEFAULT 0,
  total_lessons INTEGER DEFAULT 0,
  status TEXT DEFAULT 'not_started' CHECK (status IN ('not_started', 'in_progress', 'completed', 'paused')),
  -- Timestamps
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
  -- Time tracking
  total_time_minutes INTEGER DEFAULT 0,
  -- Ensure one progress record per user per course
  UNIQUE(user_id, course_id)
);

-- Indexes for course_progress
CREATE INDEX IF NOT EXISTS idx_course_progress_user_id ON course_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_course_progress_course_id ON course_progress(course_id);
CREATE INDEX IF NOT EXISTS idx_course_progress_status ON course_progress(user_id, status);

-- ============================================================================
-- 5. STUDY_SET_PROGRESS TABLE
-- ============================================================================
-- Tracks user progress through custom study sets
CREATE TABLE IF NOT EXISTS study_set_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  study_set_id UUID REFERENCES study_sets(id) ON DELETE CASCADE NOT NULL,
  -- Progress tracking
  items_completed INTEGER DEFAULT 0,
  total_items INTEGER DEFAULT 0,
  correct_count INTEGER DEFAULT 0,
  -- Timestamps
  last_studied_at TIMESTAMPTZ,
  -- Session tracking
  sessions_count INTEGER DEFAULT 0,
  total_time_minutes INTEGER DEFAULT 0,
  -- Ensure one progress record per user per study set
  UNIQUE(user_id, study_set_id)
);

-- Indexes for study_set_progress
CREATE INDEX IF NOT EXISTS idx_study_set_progress_user_id ON study_set_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_study_set_progress_study_set_id ON study_set_progress(study_set_id);

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all new tables
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_set_progress ENABLE ROW LEVEL SECURITY;

-- Courses policies
-- Users can manage their own courses
CREATE POLICY courses_user_crud ON courses
  FOR ALL USING (auth.uid() = user_id);

-- Users can view public courses
CREATE POLICY courses_public_read ON courses
  FOR SELECT USING (is_public = TRUE);

-- Course lessons policies
-- Users can manage lessons in their own courses
CREATE POLICY course_lessons_owner ON course_lessons
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM courses 
      WHERE courses.id = course_lessons.course_id 
      AND courses.user_id = auth.uid()
    )
  );

-- Users can view lessons in public courses
CREATE POLICY course_lessons_public_read ON course_lessons
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM courses 
      WHERE courses.id = course_lessons.course_id 
      AND courses.is_public = TRUE
    )
  );

-- Study sets policies
-- Users can only access their own study sets
CREATE POLICY study_sets_user_crud ON study_sets
  FOR ALL USING (auth.uid() = user_id);

-- Course progress policies
-- Users can only access their own progress
CREATE POLICY course_progress_user_crud ON course_progress
  FOR ALL USING (auth.uid() = user_id);

-- Study set progress policies
-- Users can only access their own progress
CREATE POLICY study_set_progress_user_crud ON study_set_progress
  FOR ALL USING (auth.uid() = user_id);

-- ============================================================================
-- 7. HELPER FUNCTIONS
-- ============================================================================

-- Function to update course lesson count
CREATE OR REPLACE FUNCTION update_course_lesson_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'DELETE' THEN
    UPDATE course_progress 
    SET total_lessons = (
      SELECT COUNT(*) FROM course_lessons 
      WHERE course_id = COALESCE(NEW.course_id, OLD.course_id)
    )
    WHERE course_id = COALESCE(NEW.course_id, OLD.course_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update lesson counts
CREATE TRIGGER trigger_update_course_lesson_count
AFTER INSERT OR DELETE ON course_lessons
FOR EACH ROW EXECUTE FUNCTION update_course_lesson_count();

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers to new tables
CREATE TRIGGER trigger_courses_updated_at
BEFORE UPDATE ON courses
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_study_sets_updated_at
BEFORE UPDATE ON study_sets
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
