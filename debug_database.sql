-- Database Debug Script for Learning PWA
-- Run this to diagnose the 404 issue

-- Step 1: Check if tables exist
SELECT 'Checking table existence...' as step;

SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('lessons', 'terms', 'concepts', 'questions', 'users', 'user_progress', 'reminders', 'offline_content');

-- Step 2: Check RLS status on all tables
SELECT 'Checking RLS status...' as step;

SELECT schemaname, tablename, rowsecurity, enablerls
FROM pg_tables t
JOIN pg_class c ON t.tablename = c.relname
WHERE schemaname = 'public'
AND tablename IN ('lessons', 'terms', 'concepts', 'questions', 'users', 'user_progress', 'reminders', 'offline_content');

-- Step 3: Check existing policies
SELECT 'Checking existing policies...' as step;

SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public';

-- Step 4: Test basic insert into lessons table
SELECT 'Testing basic insert...' as step;

INSERT INTO lessons (id, title, description, user_id, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'Test Lesson',
  'Test Description',
  'guest',
  NOW(),
  NOW()
)
RETURNING id, title;

-- Step 5: Count lessons in table
SELECT 'Counting lessons...' as step;
SELECT COUNT(*) as lesson_count FROM lessons;

-- Step 6: Test guest user exists
SELECT 'Checking guest user...' as step;
SELECT id, email, display_name FROM users WHERE email = 'guest@app.local' OR id = 'guest';
