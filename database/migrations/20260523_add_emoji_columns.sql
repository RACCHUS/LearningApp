-- Migration: Add emoji columns to lessons, terms, concepts
-- Date: 2026-05-23
-- Reason: Sprint 1 added optional `emoji` fields to the Lesson, Term, and
--         Concept models for visual encoding (picture-superiority effect).
--         These fields are persisted to Hive locally but were being dropped
--         on every Supabase round-trip because the tables had no emoji
--         column. Adds nullable TEXT columns to preserve emoji across sync.

ALTER TABLE lessons
  ADD COLUMN IF NOT EXISTS emoji TEXT;

ALTER TABLE terms
  ADD COLUMN IF NOT EXISTS emoji TEXT;

ALTER TABLE concepts
  ADD COLUMN IF NOT EXISTS emoji TEXT;

-- No indexes needed: emoji is purely presentational, never queried/filtered.
