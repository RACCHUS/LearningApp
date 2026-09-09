-- Migration: Add study_time_seconds column to user_progress
-- Date: 2026-05-23
-- Reason: App code (daily_goal_provider, study_provider, models) reads/writes
--         `study_time_seconds`, but the table only had `study_time_minutes`.
--         This caused daily goal tracking to silently fail (always 0) and
--         lost second-level precision on remote sync.
--
-- Strategy:
--   1. Add new column `study_time_seconds` (nullable, default 0).
--   2. Backfill from existing `study_time_minutes` (multiply by 60).
--   3. Keep `study_time_minutes` for backward compatibility; the model
--      `toJson()` writes both columns going forward.

ALTER TABLE user_progress
  ADD COLUMN IF NOT EXISTS study_time_seconds INTEGER DEFAULT 0;

-- Backfill from minutes so existing data shows up in daily goal ring
UPDATE user_progress
SET study_time_seconds = COALESCE(study_time_minutes, 0) * 60
WHERE study_time_seconds IS NULL OR study_time_seconds = 0;

-- Index to keep daily goal query fast
CREATE INDEX IF NOT EXISTS idx_user_progress_user_date_seconds
  ON user_progress(user_id, date)
  WHERE study_time_seconds > 0;
