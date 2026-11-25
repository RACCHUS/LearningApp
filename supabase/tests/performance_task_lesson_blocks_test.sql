-- Performance task lesson block (migration 20261124040000, ingestion plan §8.8).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(14);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_constraint c
    WHERE c.conrelid = 'public.lesson_blocks'::regclass
      AND c.conname = 'lesson_blocks_block_type_check'
      AND pg_get_constraintdef(c.oid) ILIKE '%performance_task%'
      AND pg_get_constraintdef(c.oid) ILIKE '%simulation%'
      AND pg_get_constraintdef(c.oid) ILIKE '%practice_prompt%'
  ),
  'lesson_blocks accepts performance_task and keeps the existing types'
);
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_constraint c
    WHERE c.conrelid = 'public.lesson_blocks'::regclass
      AND c.conname = 'lesson_blocks_simulation_fallback_check'
  ),
  'the simulation fallback check is untouched'
);

SET LOCAL ROLE service_role;
INSERT INTO public.lessons (id, title, visibility)
VALUES ('88888888-0000-0000-0000-000000000000', 'Performance Task Constraint Test Lesson', 'public');

CREATE TEMP TABLE pt_valid AS SELECT
  '{"task_id": "t-1", "title": "Build it", "body": "Fallback brief and rubric.",
    "verification": "self_check",
    "criteria": [{"id": "a", "text": "First"}, {"id": "b", "text": "Second"}]}'::jsonb AS c;

SELECT lives_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 1, 'performance_task', c FROM pt_valid $$,
  'a complete self-check performance task is accepted');

SELECT throws_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 2, 'performance_task', c - 'body' FROM pt_valid $$,
  '23514', NULL, 'a task without a fallback body is rejected');
SELECT throws_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 3, 'performance_task',
            jsonb_set(c, '{body}', '"   "') FROM pt_valid $$,
  '23514', NULL, 'a whitespace-only body is rejected');
SELECT throws_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 4, 'performance_task', c - 'title' FROM pt_valid $$,
  '23514', NULL, 'a task without a title is rejected');
SELECT throws_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 5, 'performance_task',
            jsonb_set(c, '{verification}', '"checker"') FROM pt_valid $$,
  '23514', NULL, 'only self_check verification is accepted (no verified claim)');
SELECT throws_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 6, 'performance_task', c - 'verification' FROM pt_valid $$,
  '23514', NULL, 'verification must be stated');
SELECT throws_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 7, 'performance_task',
            jsonb_set(c, '{criteria}', '[{"text": "Only one"}]') FROM pt_valid $$,
  '23514', NULL, 'a rubric needs at least two criteria');
SELECT throws_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 8, 'performance_task',
            jsonb_set(c, '{criteria}', '[{"text": "Fine"}, {"text": "  "}]') FROM pt_valid $$,
  '23514', NULL, 'every criterion needs text');
SELECT throws_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 9, 'performance_task',
            jsonb_set(c, '{criteria}', '["a", "b"]') FROM pt_valid $$,
  '23514', NULL, 'criteria must be objects');
SELECT throws_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     SELECT '88888888-0000-0000-0000-000000000000', 10, 'performance_task',
            jsonb_set(c, '{criteria}', '{"text": "not a list"}') FROM pt_valid $$,
  '23514', NULL, 'criteria must be an array (and never raise a different error)');

SELECT lives_ok(
  $$ INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
     VALUES ('88888888-0000-0000-0000-000000000000', 20, 'markdown',
             '{"text": "Other blocks are never inspected", "criteria": {"x": 1}}'::jsonb) $$,
  'other block types ignore the performance task rules');

SELECT is(
  (SELECT count(*)::integer FROM public.lesson_blocks
   WHERE lesson_id = '88888888-0000-0000-0000-000000000000'),
  2, 'only the valid task and the markdown block were stored');

SELECT * FROM finish();
ROLLBACK;
