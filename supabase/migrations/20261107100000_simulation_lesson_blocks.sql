-- Add the simulation lesson block as an append-only schema change.
-- Unknown block types still need a populated body for older-client fallback.
BEGIN;

ALTER TABLE public.lesson_blocks
  DROP CONSTRAINT IF EXISTS lesson_blocks_block_type_check;

ALTER TABLE public.lesson_blocks
  ADD CONSTRAINT lesson_blocks_block_type_check
  CHECK (
    block_type IN (
      'markdown',
      'callout',
      'code',
      'table',
      'image',
      'formula',
      'example',
      'practice_prompt',
      'simulation'
    )
  );

ALTER TABLE public.lesson_blocks
  ADD CONSTRAINT lesson_blocks_simulation_fallback_check
  CHECK (
    block_type <> 'simulation'
    OR COALESCE(NULLIF(BTRIM(content ->> 'body'), ''), '') <> ''
  );

COMMIT;
