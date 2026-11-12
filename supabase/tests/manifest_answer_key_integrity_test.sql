-- ============================================================================
-- Test Suite: manifest_answer_key_integrity_test.sql
-- Migration:  20261112010000_manifest_answer_key_integrity.sql
--   Manifest ingestion must never turn a missing/invalid answer key into
--   option 0. Valid indexes pass, short answers get the -1 sentinel, and
--   everything else raises (rolling back the whole manifest import).
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

-- Valid keys
select is(
  private.manifest_question_correct_index(
    '{"question_text":"Q","options":["a","b","c"],"correct_index":2}'::jsonb, 'L'),
  2, 'correct_index within range is kept');
select is(
  private.manifest_question_correct_index(
    '{"question_text":"Q","options":["a","b"],"correct_answer":0}'::jsonb, 'L'),
  0, 'an explicit 0 is a real answer, not a default');
select is(
  private.manifest_question_correct_index(
    '{"question_text":"Q","options":["a","b"],"correct_answer":"1"}'::jsonb, 'L'),
  1, 'a digit string is accepted');
select is(
  private.manifest_question_correct_index(
    '{"question_text":"Q","options":["a","b"],"correct_answer":1,"correct_index":0}'::jsonb, 'L'),
  1, 'correct_answer takes precedence over correct_index (unchanged behavior)');

-- Short answers
select is(
  private.manifest_question_correct_index(
    '{"question_text":"Q","type":"short_answer","accepted_answers":["x"]}'::jsonb, 'L'),
  -1, 'short_answer without an index gets the unscorable sentinel');
select is(
  private.manifest_question_correct_index(
    '{"question_text":"Q","options":[],"accepted_answers":["x"]}'::jsonb, 'L'),
  -1, 'no options plus accepted answers is treated as short answer');

-- Rejections
select throws_like(
  $$select private.manifest_question_correct_index(
    '{"question_text":"Q","type":"mcq","options":["a","b"]}'::jsonb, 'L')$$,
  'manifest_answer_key_missing%', 'missing key on an MCQ raises');
select throws_like(
  $$select private.manifest_question_correct_index(
    '{"question_text":"Q","options":["a","b"],"correct_answer":""}'::jsonb, 'L')$$,
  'manifest_answer_key_missing%', 'blank key raises');
select throws_like(
  $$select private.manifest_question_correct_index(
    '{"question_text":"Q","options":["a","b"],"correct_answer":"B"}'::jsonb, 'L')$$,
  'manifest_answer_key_invalid%', 'letter key raises');
select throws_like(
  $$select private.manifest_question_correct_index(
    '{"question_text":"Q","options":["a","b"],"correct_answer":-1}'::jsonb, 'L')$$,
  'manifest_answer_key_invalid%', 'negative key raises');
select throws_like(
  $$select private.manifest_question_correct_index(
    '{"question_text":"Q","options":["a","b"],"correct_answer":1.5}'::jsonb, 'L')$$,
  'manifest_answer_key_invalid%', 'fractional key raises');
select throws_like(
  $$select private.manifest_question_correct_index(
    '{"question_text":"Q","options":["a","b"],"correct_answer":2}'::jsonb, 'L')$$,
  'manifest_answer_key_out_of_range%', 'index past the last option raises');

-- Wiring and privileges
select ok(
  pg_get_functiondef('public.ingest_curriculum_manifest(jsonb)'::regprocedure)
    like '%private.manifest_question_correct_index(v_question%'
  and pg_get_functiondef('public.ingest_curriculum_manifest(jsonb)'::regprocedure)
    not like '%v_question->>''correct_index''))::int, 0)%',
  'ingestion uses the validator and no longer defaults keys to 0');
select ok(
  not has_function_privilege(
    'authenticated', 'private.manifest_question_correct_index(jsonb, text)', 'execute'),
  'browser roles cannot call the validator directly');

select * from finish();
rollback;
