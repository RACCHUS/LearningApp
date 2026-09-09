-- User XP and Level System Tables
-- Tracks XP earned and provides level progression

-- User's total XP (aggregated for performance)
CREATE TABLE IF NOT EXISTS user_xp (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  total_xp INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT unique_user_xp UNIQUE (user_id)
);

-- XP Events (log of all XP earned)
CREATE TABLE IF NOT EXISTS xp_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  xp_amount INTEGER NOT NULL,
  source_id TEXT,
  description TEXT,
  earned_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Index for common queries
  CONSTRAINT valid_xp_amount CHECK (xp_amount > 0)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_xp_user_id ON user_xp(user_id);
CREATE INDEX IF NOT EXISTS idx_xp_events_user_id ON xp_events(user_id);
CREATE INDEX IF NOT EXISTS idx_xp_events_earned_at ON xp_events(user_id, earned_at DESC);
CREATE INDEX IF NOT EXISTS idx_xp_events_type ON xp_events(user_id, event_type);

-- Enable Row Level Security
ALTER TABLE user_xp ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_events ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_xp
CREATE POLICY "Users can view own XP"
  ON user_xp FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own XP"
  ON user_xp FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own XP"
  ON user_xp FOR UPDATE
  USING (auth.uid() = user_id);

-- RLS Policies for xp_events
CREATE POLICY "Users can view own XP events"
  ON xp_events FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own XP events"
  ON xp_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Function to increment user XP (upsert pattern)
CREATE OR REPLACE FUNCTION increment_user_xp(p_user_id UUID, p_xp_amount INTEGER)
RETURNS VOID AS $$
BEGIN
  INSERT INTO user_xp (user_id, total_xp)
  VALUES (p_user_id, p_xp_amount)
  ON CONFLICT (user_id)
  DO UPDATE SET 
    total_xp = user_xp.total_xp + p_xp_amount,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION increment_user_xp TO authenticated;

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_user_xp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_xp_updated_at
  BEFORE UPDATE ON user_xp
  FOR EACH ROW
  EXECUTE FUNCTION update_user_xp_updated_at();

-- Comments
COMMENT ON TABLE user_xp IS 'Aggregated XP totals per user for fast level calculation';
COMMENT ON TABLE xp_events IS 'Log of all XP earning events for history and analytics';
COMMENT ON FUNCTION increment_user_xp IS 'Safely increment user XP with upsert';
