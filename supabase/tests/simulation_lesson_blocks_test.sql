BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(10);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid = 'public.lesson_blocks'::regclass
      AND c.conname = 'lesson_blocks_block_type_check'
      AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%simulation%'
  ),
  'lesson_blocks accepts the simulation block type'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid = 'public.lesson_blocks'::regclass
      AND c.conname = 'lesson_blocks_block_type_check'
      AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%practice_prompt%'
      AND pg_get_constraintdef(c.oid) ILIKE '%markdown%'
  ),
  'lesson_blocks preserves existing supported block types'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid = 'public.lesson_blocks'::regclass
      AND c.conname = 'lesson_blocks_simulation_fallback_check'
      AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%body%'
  ),
  'simulation blocks require body content for older-client fallback'
);

-- Behavioral checks: the constraints must accept and reject real rows.
SET LOCAL ROLE service_role;

INSERT INTO public.lessons (id, title, visibility)
VALUES (
  '77777777-0000-0000-0000-000000000000',
  'Simulation Block Constraint Test Lesson',
  'public'
);

SELECT lives_ok(
  $$
    INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
    VALUES (
      '77777777-0000-0000-0000-000000000000',
      1,
      'simulation',
      '{"simulation_id": "networking-basics", "simulation_version": "1.0.0",
        "body": "Identify the disconnected link and explain the repair."}'::jsonb
    )
  $$,
  'a simulation block with a fallback body is accepted'
);

SELECT throws_ok(
  $$
    INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
    VALUES (
      '77777777-0000-0000-0000-000000000000',
      2,
      'simulation',
      '{"simulation_id": "networking-basics", "simulation_version": "1.0.0"}'::jsonb
    )
  $$,
  '23514',
  NULL,
  'a simulation block without a fallback body is rejected'
);

SELECT throws_ok(
  $$
    INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
    VALUES (
      '77777777-0000-0000-0000-000000000000',
      3,
      'simulation',
      '{"simulation_id": "networking-basics", "body": ""}'::jsonb
    )
  $$,
  '23514',
  NULL,
  'a simulation block with an empty fallback body is rejected'
);

SELECT throws_ok(
  $$
    INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
    VALUES (
      '77777777-0000-0000-0000-000000000000',
      4,
      'simulation',
      '{"simulation_id": "networking-basics", "body": "   "}'::jsonb
    )
  $$,
  '23514',
  NULL,
  'a simulation block with a whitespace-only fallback body is rejected'
);

SELECT lives_ok(
  $$
    INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
    SELECT
      '77777777-0000-0000-0000-000000000000',
      10 + ordinality::integer,
      block_type,
      '{}'::jsonb
    FROM unnest(ARRAY[
      'markdown', 'callout', 'code', 'table',
      'image', 'formula', 'example', 'practice_prompt'
    ]) WITH ORDINALITY AS t(block_type, ordinality)
  $$,
  'existing block types remain accepted without a simulation fallback body'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM public.lesson_blocks
    WHERE lesson_id = '77777777-0000-0000-0000-000000000000'
  ),
  9,
  'only the valid simulation block and existing block types were stored'
);

SELECT throws_ok(
  $$
    INSERT INTO public.lesson_blocks (lesson_id, sort_order, block_type, content)
    VALUES (
      '77777777-0000-0000-0000-000000000000',
      30,
      'unregistered_block',
      '{"body": "Fallback"}'::jsonb
    )
  $$,
  '23514',
  NULL,
  'unknown block types are still rejected'
);

SELECT * FROM finish();
ROLLBACK;
