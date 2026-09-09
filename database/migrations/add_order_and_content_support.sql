-- Add order fields to existing content tables
ALTER TABLE terms ADD COLUMN IF NOT EXISTS order_index INTEGER DEFAULT 0;
ALTER TABLE concepts ADD COLUMN IF NOT EXISTS order_index INTEGER DEFAULT 0;
ALTER TABLE questions ADD COLUMN IF NOT EXISTS order_index INTEGER DEFAULT 0;

-- Create lesson_texts table
CREATE TABLE IF NOT EXISTS lesson_texts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID REFERENCES lessons(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  user_id UUID REFERENCES users(id) NULL -- Optional
);

CREATE INDEX IF NOT EXISTS idx_lesson_texts_lesson_id ON lesson_texts(lesson_id);
CREATE INDEX IF NOT EXISTS idx_lesson_texts_order ON lesson_texts(lesson_id, order_index);

-- Add content field to lessons table for JSON storage
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS content JSONB;

-- Enable RLS on lesson_texts
ALTER TABLE lesson_texts ENABLE ROW LEVEL SECURITY;

-- Content access policy for lesson_texts
CREATE POLICY lesson_texts_access ON lesson_texts FOR ALL USING (
  EXISTS (
    SELECT 1 FROM lessons 
    WHERE lessons.id = lesson_texts.lesson_id 
    AND (lessons.user_id IS NULL OR lessons.user_id = auth.uid() OR auth.uid() IS NOT NULL)
  )
);

-- Add indexes for order fields
CREATE INDEX IF NOT EXISTS idx_terms_order ON terms(lesson_id, order_index);
CREATE INDEX IF NOT EXISTS idx_concepts_order ON concepts(lesson_id, order_index);
CREATE INDEX IF NOT EXISTS idx_questions_order ON questions(lesson_id, order_index);
