-- COMPLETE RLS DISABLE for Learning PWA Development
-- This will disable ALL row level security policies

-- Step 1: Drop all existing policies first
DROP POLICY IF EXISTS user_own_data ON users;
DROP POLICY IF EXISTS user_progress_own ON user_progress;
DROP POLICY IF EXISTS reminders_own ON reminders;
DROP POLICY IF EXISTS offline_content_own ON offline_content;
DROP POLICY IF EXISTS lessons_access ON lessons;
DROP POLICY IF EXISTS terms_access ON terms;
DROP POLICY IF EXISTS questions_access ON questions;
DROP POLICY IF EXISTS concepts_access ON concepts;

-- Step 2: Disable RLS on ALL tables
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE lessons DISABLE ROW LEVEL SECURITY;
ALTER TABLE terms DISABLE ROW LEVEL SECURITY;
ALTER TABLE concepts DISABLE ROW LEVEL SECURITY;
ALTER TABLE questions DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress DISABLE ROW LEVEL SECURITY;
ALTER TABLE reminders DISABLE ROW LEVEL SECURITY;
ALTER TABLE offline_content DISABLE ROW LEVEL SECURITY;

-- Step 3: Handle empty/null field support
-- Make sure nullable fields can accept empty strings or nulls
ALTER TABLE lessons ALTER COLUMN description DROP NOT NULL;
ALTER TABLE terms ALTER COLUMN example DROP NOT NULL;
ALTER TABLE concepts ALTER COLUMN example_text DROP NOT NULL;

-- Step 4: Create a guest user if it doesn't exist (for consistency)
INSERT INTO users (id, email, display_name) 
VALUES ('00000000-0000-0000-0000-000000000000', 'guest@app.local', 'Guest User')
ON CONFLICT (email) DO NOTHING;

-- Confirmation
SELECT 'ALL RLS disabled - app should work now!' as status;
