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
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_lessons_tags ON lessons USING GIN(tags);
CREATE INDEX idx_lessons_created_by ON lessons(created_by);

CREATE TABLE terms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  term TEXT NOT NULL,
  definition TEXT NOT NULL,
  example TEXT,
  created_by UUID REFERENCES users(id)
);

CREATE TABLE concepts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_text TEXT NOT NULL,
  example_text TEXT,
  created_by UUID REFERENCES users(id)
);

CREATE TABLE questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_text TEXT NOT NULL,
  options JSONB NOT NULL, -- ["option1", "option2", "option3", "option4"]
  correct_answer INTEGER NOT NULL, -- 0-based index
  type TEXT DEFAULT 'mcq' CHECK (type IN ('mcq', 'true_false', 'short_answer')),
  explanation TEXT,
  created_by UUID REFERENCES users(id)
);

CREATE TABLE lesson_terms (
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  term_id UUID REFERENCES terms(id) ON DELETE CASCADE,
  PRIMARY KEY (lesson_id, term_id)
);

CREATE TABLE lesson_questions (
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
  order_index INTEGER DEFAULT 0,
  PRIMARY KEY (lesson_id, question_id)
);

CREATE TABLE lesson_concepts (
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  concept_id UUID REFERENCES concepts(id) ON DELETE CASCADE,
  PRIMARY KEY (lesson_id, concept_id)
);

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

-- Public read access to lessons, terms, concepts, questions
CREATE POLICY lessons_public_read ON lessons FOR SELECT USING (true);
CREATE POLICY terms_public_read ON terms FOR SELECT USING (true);
CREATE POLICY concepts_public_read ON concepts FOR SELECT USING (true);
CREATE POLICY questions_public_read ON questions FOR SELECT USING (true);

-- Join tables inherit parent permissions
CREATE POLICY lesson_terms_public_read ON lesson_terms FOR SELECT USING (true);
CREATE POLICY lesson_questions_public_read ON lesson_questions FOR SELECT USING (true);
CREATE POLICY lesson_concepts_public_read ON lesson_concepts FOR SELECT USING (true);
