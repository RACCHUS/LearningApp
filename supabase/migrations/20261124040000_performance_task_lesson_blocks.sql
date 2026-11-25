-- Performance task lesson block (ingestion plan v1.2 §8.8): an authentic task
-- that produces real output (a workbook, code, a configuration or a written
-- artifact), checked by the learner against a published rubric with an
-- exemplar. Self-checked only: nothing is written to the server, nothing
-- counts toward readiness or skills, and the app labels it "not independently
-- verified". Append-only schema change.
--
-- Every performance task must carry a markdown `body` (older clients render
-- unknown block types as markdown), at least two rubric criteria with text,
-- and `verification: self_check`, the only mode supported so far. A future
-- deterministic checker would add a new mode in its own reviewed migration.
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
      'simulation',
      'performance_task'
    )
  );

-- Inline checks only (no helper function), so ordinary inserts of other block
-- types by any role never need an extra privilege.
ALTER TABLE public.lesson_blocks
  ADD CONSTRAINT lesson_blocks_performance_task_check
  CHECK (
    -- CASE fixes the evaluation order, so other block types are never
    -- inspected and jsonb_array_length only ever sees an array.
    CASE
      WHEN block_type <> 'performance_task' THEN true
      WHEN jsonb_typeof(content -> 'criteria') IS DISTINCT FROM 'array' THEN false
      ELSE
        COALESCE(NULLIF(BTRIM(content ->> 'body'), ''), '') <> ''
        AND COALESCE(NULLIF(BTRIM(content ->> 'title'), ''), '') <> ''
        AND content ->> 'verification' IS NOT DISTINCT FROM 'self_check'
        AND jsonb_array_length(content -> 'criteria') BETWEEN 2 AND 20
        AND NOT jsonb_path_exists(
          content,
          '$.criteria[*] ? (@.type() != "object" || !exists(@.text) || @.text.type() != "string" || @.text like_regex "^[[:space:]]*$")'
        )
    END
  );

COMMIT;
