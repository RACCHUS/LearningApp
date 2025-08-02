-- Cleanup Script for Learning PWA Database
-- Run this FIRST to clean up existing tables, then run schema.sql

-- Drop all policies first (to avoid dependency issues)
DROP POLICY IF EXISTS user_own_data ON users;
DROP POLICY IF EXISTS user_progress_own ON user_progress;
DROP POLICY IF EXISTS reminders_own ON reminders;
DROP POLICY IF EXISTS offline_content_own ON offline_content;
DROP POLICY IF EXISTS lessons_access ON lessons;
DROP POLICY IF EXISTS terms_access ON terms;
DROP POLICY IF EXISTS questions_access ON questions;
DROP POLICY IF EXISTS concepts_access ON concepts;

-- Drop all indexes
DROP INDEX IF EXISTS idx_lessons_tags;
DROP INDEX IF EXISTS idx_lessons_user_id;
DROP INDEX IF EXISTS idx_terms_lesson_id;
DROP INDEX IF EXISTS idx_concepts_lesson_id;
DROP INDEX IF EXISTS idx_questions_lesson_id;
DROP INDEX IF EXISTS idx_user_progress_user_date;
DROP INDEX IF EXISTS idx_user_progress_lesson;

-- Drop all tables (in reverse order due to foreign key dependencies)
DROP TABLE IF EXISTS offline_content CASCADE;
DROP TABLE IF EXISTS reminders CASCADE;
DROP TABLE IF EXISTS user_progress CASCADE;
DROP TABLE IF EXISTS questions CASCADE;
DROP TABLE IF EXISTS concepts CASCADE;
DROP TABLE IF EXISTS terms CASCADE;
DROP TABLE IF EXISTS lessons CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Also drop any old junction tables if they exist
DROP TABLE IF EXISTS lesson_terms CASCADE;
DROP TABLE IF EXISTS lesson_questions CASCADE;
DROP TABLE IF EXISTS lesson_concepts CASCADE;

-- Clean up any remaining sequences or functions
DROP SEQUENCE IF EXISTS users_id_seq CASCADE;
DROP SEQUENCE IF EXISTS lessons_id_seq CASCADE;
DROP SEQUENCE IF EXISTS terms_id_seq CASCADE;
DROP SEQUENCE IF EXISTS concepts_id_seq CASCADE;
DROP SEQUENCE IF EXISTS questions_id_seq CASCADE;

-- Confirmation message
SELECT 'Database cleanup completed successfully!' as status;
