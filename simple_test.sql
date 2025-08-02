-- SIMPLE TEST - Check if database connection works
-- Run this first to verify basic connectivity

-- Test 1: Simple query
SELECT NOW() as current_time, 'Database connection works!' as message;

-- Test 2: Check if lessons table exists and is accessible
SELECT COUNT(*) as lesson_count FROM lessons;

-- Test 3: Try a simple insert with minimal data
INSERT INTO lessons (title, user_id) 
VALUES ('Connection Test', NULL)
RETURNING id, title, user_id;
