-- DIAGNOSTIC: Test the exact same operation that's failing in Flutter
-- This will help identify if it's a table/permission issue

-- Step 1: Verify table exists and is accessible
SELECT 'Testing table access...' as step;
SELECT COUNT(*) as lesson_count FROM lessons;

-- Step 2: Test the exact same insert that Flutter is trying
SELECT 'Testing exact Flutter insert...' as step;

INSERT INTO lessons (
  id, 
  title, 
  description, 
  user_id, 
  created_at, 
  updated_at
) 
VALUES (
  gen_random_uuid(),
  'Sample Lesson',
  'This is a sample lesson',
  '00000000-0000-0000-0000-000000000000',
  '2025-08-01T20:10:02.765',
  '2025-08-01T20:10:02.765'
)
RETURNING id, title, description, user_id;

-- Step 3: Check if our guest user exists
SELECT 'Checking guest user exists...' as step;
SELECT id, email, display_name FROM users WHERE id = '00000000-0000-0000-0000-000000000000';

-- Step 4: Check RLS status
SELECT 'Checking RLS status...' as step;
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables t
WHERE schemaname = 'public' AND tablename = 'lessons';

-- Step 5: Check table permissions
SELECT 'Checking table permissions...' as step;
SELECT table_name, privilege_type, grantee
FROM information_schema.role_table_grants 
WHERE table_name = 'lessons' AND table_schema = 'public';

SELECT 'Diagnostic complete!' as result;
