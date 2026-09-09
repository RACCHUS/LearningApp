CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  display_name TEXT
);

CREATE TABLE lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  tags TEXT[] DEFAULT '{}',
  emoji TEXT,
  user_id UUID REFERENCES users(id) NULL, -- Optional - allows public lessons
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_lessons_tags ON lessons USING GIN(tags);
CREATE INDEX idx_lessons_user_id ON lessons(user_id);

CREATE TABLE terms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  term TEXT NOT NULL,
  definition TEXT NOT NULL,
  example TEXT,
  emoji TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  user_id UUID REFERENCES users(id) NULL -- Optional
);
CREATE INDEX idx_terms_lesson_id ON terms(lesson_id);

CREATE TABLE concepts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  concept_text TEXT NOT NULL,
  example_text TEXT,
  key_points TEXT[],
  emoji TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  user_id UUID REFERENCES users(id) NULL -- Optional
);
CREATE INDEX idx_concepts_lesson_id ON concepts(lesson_id);

CREATE TABLE questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  options JSONB NOT NULL, -- ["option1", "option2", "option3", "option4"]
  correct_answer INTEGER NOT NULL, -- 0-based index
  type TEXT DEFAULT 'mcq' CHECK (type IN ('mcq', 'true_false', 'short_answer')),
  explanation TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  user_id UUID REFERENCES users(id) NULL -- Optional
);
CREATE INDEX idx_questions_lesson_id ON questions(lesson_id);

-- No longer needed - direct foreign key relationships

CREATE TABLE user_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  date DATE DEFAULT CURRENT_DATE,
  questions_answered INTEGER DEFAULT 0,
  correct_count INTEGER DEFAULT 0,
  lesson_completed BOOLEAN DEFAULT FALSE,
  study_time_minutes INTEGER DEFAULT 0,
  study_time_seconds INTEGER DEFAULT 0,
  UNIQUE(user_id, lesson_id, date)
);
CREATE INDEX idx_user_progress_user_date ON user_progress(user_id, date);
CREATE INDEX idx_user_progress_lesson ON user_progress(lesson_id);

CREATE TABLE reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  time_of_day TIME NOT NULL, -- e.g., '14:30:00'
  frequency TEXT DEFAULT 'daily' CHECK (frequency IN ('daily', 'weekdays', 'custom')),
  mode TEXT DEFAULT 'lesson' CHECK (mode IN ('lesson', 'flashcard', 'quiz')),
  goal_count INTEGER DEFAULT 5,
  is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE offline_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  cached_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE concepts ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE offline_content ENABLE ROW LEVEL SECURITY;

-- Users can only see/edit their own data
CREATE POLICY user_own_data ON users FOR ALL USING (auth.uid() = id);
CREATE POLICY user_progress_own ON user_progress FOR ALL USING (auth.uid() = user_id);
CREATE POLICY reminders_own ON reminders FOR ALL USING (auth.uid() = user_id);
CREATE POLICY offline_content_own ON offline_content FOR ALL USING (auth.uid() = user_id);

-- Content access policies
-- Read: a lesson (and its content) is visible if it is public (no owner) or owned by the caller.
-- Write: only the owner of the parent lesson may insert/update/delete. Public (ownerless)
-- lessons are read-only to end users and can only be modified via the service role.

CREATE POLICY lessons_read ON lessons FOR SELECT USING (
  user_id IS NULL OR auth.uid() = user_id
);
CREATE POLICY lessons_write ON lessons FOR ALL USING (
  auth.uid() = user_id
) WITH CHECK (
  auth.uid() = user_id
);

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

-- ============================================================================
-- COURSES TABLE
-- ============================================================================
CREATE TABLE courses (
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
CREATE INDEX idx_courses_user_id ON courses(user_id);
CREATE INDEX idx_courses_status ON courses(status);
CREATE INDEX idx_courses_is_public ON courses(is_public);
CREATE INDEX idx_courses_tags ON courses USING GIN(tags);

-- ============================================================================
-- COURSE_LESSONS JUNCTION TABLE
-- ============================================================================
CREATE TABLE course_lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE NOT NULL,
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE NOT NULL,
  order_index INTEGER DEFAULT 0,
  is_required BOOLEAN DEFAULT TRUE,
  section_title TEXT,
  added_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(course_id, lesson_id)
);
CREATE INDEX idx_course_lessons_course_id ON course_lessons(course_id);
CREATE INDEX idx_course_lessons_lesson_id ON course_lessons(lesson_id);

-- ============================================================================
-- STUDY_SETS TABLE
-- ============================================================================
CREATE TABLE study_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  lesson_ids UUID[] DEFAULT '{}',
  question_ids UUID[] DEFAULT '{}',
  term_ids UUID[] DEFAULT '{}',
  concept_ids UUID[] DEFAULT '{}',
  is_favorite BOOLEAN DEFAULT FALSE,
  tags TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_study_sets_user_id ON study_sets(user_id);
CREATE INDEX idx_study_sets_is_favorite ON study_sets(user_id, is_favorite);

-- ============================================================================
-- COURSE_PROGRESS TABLE
-- ============================================================================
CREATE TABLE course_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  course_id UUID REFERENCES courses(id) ON DELETE CASCADE NOT NULL,
  lessons_completed INTEGER DEFAULT 0,
  total_lessons INTEGER DEFAULT 0,
  status TEXT DEFAULT 'not_started' CHECK (status IN ('not_started', 'in_progress', 'completed', 'paused')),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
  total_time_minutes INTEGER DEFAULT 0,
  UNIQUE(user_id, course_id)
);
CREATE INDEX idx_course_progress_user_id ON course_progress(user_id);
CREATE INDEX idx_course_progress_course_id ON course_progress(course_id);

-- ============================================================================
-- STUDY_SET_PROGRESS TABLE
-- ============================================================================
CREATE TABLE study_set_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  study_set_id UUID REFERENCES study_sets(id) ON DELETE CASCADE NOT NULL,
  items_completed INTEGER DEFAULT 0,
  total_items INTEGER DEFAULT 0,
  correct_count INTEGER DEFAULT 0,
  last_studied_at TIMESTAMPTZ,
  sessions_count INTEGER DEFAULT 0,
  total_time_minutes INTEGER DEFAULT 0,
  UNIQUE(user_id, study_set_id)
);
CREATE INDEX idx_study_set_progress_user_id ON study_set_progress(user_id);
CREATE INDEX idx_study_set_progress_study_set_id ON study_set_progress(study_set_id);

-- RLS for new tables
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_set_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY courses_user_crud ON courses FOR ALL USING (auth.uid() = user_id);
CREATE POLICY courses_public_read ON courses FOR SELECT USING (is_public = TRUE);
CREATE POLICY course_lessons_owner ON course_lessons FOR ALL USING (
  EXISTS (SELECT 1 FROM courses WHERE courses.id = course_lessons.course_id AND courses.user_id = auth.uid())
);
CREATE POLICY study_sets_user_crud ON study_sets FOR ALL USING (auth.uid() = user_id);
CREATE POLICY course_progress_user_crud ON course_progress FOR ALL USING (auth.uid() = user_id);
CREATE POLICY study_set_progress_user_crud ON study_set_progress FOR ALL USING (auth.uid() = user_id);

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
