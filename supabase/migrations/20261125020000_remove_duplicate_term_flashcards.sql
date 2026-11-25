-- Remove the glossary-term flashcards that importer revision 7 added to the
-- open-textbook College Algebra and Prealgebra R7 versions (#413,
-- published 2026-11-25).
--
-- They duplicated the lesson terms, which already reach a learner's review
-- queue on lesson completion and count toward the objective through the
-- lesson's concept. Worse, their concept links made the reinforcement list
-- skip its lesson fallback, so a weak concept showed no reviewable items.
-- Importer revision 8 no longer creates them; this removes the 34 already
-- published. Concepts are shared across versions, so retiring R7 alone
-- would not remove the links.
--
-- Only rows that are exactly those cards are touched: created by an R7
-- version of these two targets, with the generated front "What does
-- “term” mean?", no owner, and no review item or study set using them
-- (production had none on 2026-11-25). Concept links cascade; provenance
-- rows are removed the way clean_target_version does. Nothing else in the
-- versions changes.
BEGIN;

CREATE TEMP TABLE _term_cards ON COMMIT DROP AS
SELECT f.id
FROM public.flashcards f
JOIN public.target_versions v ON v.id = f.origin_target_version_id
JOIN public.learning_targets t ON t.id = v.target_id
WHERE t.slug IN ('open-openstax-college-algebra-1e', 'open-openstax-prealgebra-1e')
  AND v.version_code IN ('OPENSTAX-EBC5BEB-R7', 'OPENSTAX-EB2E29D-R7')
  AND f.user_id IS NULL
  AND f.front LIKE 'What does “%” mean?'
  AND NOT EXISTS (SELECT 1 FROM public.review_items r WHERE r.content_id::text = f.id::text)
  AND NOT EXISTS (SELECT 1 FROM public.study_set_flashcards s WHERE s.flashcard_id = f.id);

DELETE FROM public.content_source_mappings
WHERE entity_type = 'flashcard'
  AND entity_id IN (SELECT id FROM _term_cards);

DELETE FROM public.flashcards
WHERE id IN (SELECT id FROM _term_cards);

COMMIT;
