-- Spaced Repetition Review Items Table
-- Stores user's review queue with SM-2 algorithm data

CREATE TABLE IF NOT EXISTS review_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_id TEXT NOT NULL,
  content_type TEXT NOT NULL CHECK (content_type IN ('term', 'question', 'concept')),
  lesson_id TEXT NOT NULL,
  title TEXT NOT NULL,
  subtitle TEXT,
  
  -- SM-2 Algorithm fields
  repetition_level INTEGER DEFAULT 0,
  ease_factor DECIMAL(3,2) DEFAULT 2.50,
  next_review_date TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 day'),
  last_reviewed_at TIMESTAMPTZ,
  
  -- Statistics
  total_reviews INTEGER DEFAULT 0,
  correct_reviews INTEGER DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Prevent duplicate entries
  CONSTRAINT unique_user_content UNIQUE (user_id, content_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_review_items_user_id ON review_items(user_id);
CREATE INDEX IF NOT EXISTS idx_review_items_next_review ON review_items(user_id, next_review_date);
CREATE INDEX IF NOT EXISTS idx_review_items_lesson ON review_items(user_id, lesson_id);

-- Enable Row Level Security
ALTER TABLE review_items ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own review items
CREATE POLICY "Users can view own review items"
  ON review_items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own review items"
  ON review_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own review items"
  ON review_items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own review items"
  ON review_items FOR DELETE
  USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_review_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER trigger_review_items_updated_at
  BEFORE UPDATE ON review_items
  FOR EACH ROW
  EXECUTE FUNCTION update_review_items_updated_at();

-- Comment on table
COMMENT ON TABLE review_items IS 'Stores spaced repetition review items for users with SM-2 algorithm data';
