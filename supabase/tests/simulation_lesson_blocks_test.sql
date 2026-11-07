BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(3);

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

SELECT * FROM finish();
ROLLBACK;
