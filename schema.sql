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

-- Content access policies - users can access content for lessons they own or public lessons
CREATE POLICY lessons_access ON lessons FOR ALL USING (
  user_id IS NULL OR -- Public lessons (no owner)
  auth.uid() = user_id OR -- User owns the lesson
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid()) -- Authenticated users can read all
);

CREATE POLICY terms_access ON terms FOR ALL USING (
  EXISTS (
    SELECT 1 FROM lessons 
    WHERE lessons.id = terms.lesson_id 
    AND (lessons.user_id IS NULL OR lessons.user_id = auth.uid() OR auth.uid() IS NOT NULL)
  )
);

CREATE POLICY questions_access ON questions FOR ALL USING (
  EXISTS (
    SELECT 1 FROM lessons 
    WHERE lessons.id = questions.lesson_id 
    AND (lessons.user_id IS NULL OR lessons.user_id = auth.uid() OR auth.uid() IS NOT NULL)
  )
);

CREATE POLICY concepts_access ON concepts FOR ALL USING (
  EXISTS (
    SELECT 1 FROM lessons 
    WHERE lessons.id = concepts.lesson_id 
    AND (lessons.user_id IS NULL OR lessons.user_id = auth.uid() OR auth.uid() IS NOT NULL)
  )
);
