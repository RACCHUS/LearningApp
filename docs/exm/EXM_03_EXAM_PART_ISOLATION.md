# EXM-03 — Exam-Part Scope Isolation (Draft Engineering Slice)

**Status:** Source and synthetic tests authored in a draft GitHub branch.
Full CI and browser acceptance are separate gates. No regulator-specific exam
profile, question bank, manifest, or passing standard is approved by this work.

## Contract

- Use the **existing** typed `ExamPreparationProfile` in
  `target_versions.metadata.exam_preparation.exam_parts` with a stable
  `exam_part_key` and `curriculum_root_node_id`. Do not infer a part from
  `LearningContext.activeFocusId` or from a generic target-version-only route.
- A selected part is valid only if the key exists in that version's profile
  and its root belongs to the **same target version's** curriculum-node set.
  The resolver rejects malformed/duplicate IDs, outside-version parents,
  cycles, absent roots, unsupported profile shapes, and unknown part keys.
  It returns an immutable descendant-node set and outside-node set.
- Unspecified `examPartKey` retains the explicitly **target-wide**, practice-
  only legacy behavior. A **supplied** but invalid part never silently expands
  into target-wide readiness or item selection.

## Consumer behavior

- **Mock generator:** Scope domain quotas to the validated subtree. Item-to-
  domain mappings are still resolved against the **entire target version**,
  ensuring that a concept linked to another part cannot silently qualify an
  item for the selected part; globally ambiguous domain mappings fail closed.
  Fail if the selected part lacks the requested quantity of unique eligible
  items. Blueprints carry `examPartKey` and `curriculumRootNodeId` in JSON.
  A preloaded blueprint must match the requested version, part and subtree.
  The diagnostic report retains the selected part identity.
- **Diagnostic candidate service:** The availability and canonical-item
  selection functions accept an explicit part key. Only concepts unique to
  the selected subtree qualify a question for this conservative first slice.
  A shared concept, a cross-part question, or an item mixing selected-part
  with foreign concept links cannot be labeled part-specific. Lack of adequate
  coverage disables the scoped diagnostic; it does not borrow other parts.
- **Readiness:** Optional scoped evaluation counts core concept mappings
  within the selected subtree only, while legitimately globally transferable
  concepts can still contribute to a given part's *knowledge* estimate.
  Invalid selected parts propagate an error rather than a misleading zero
  score. Scoped providers use keys containing version+part; legacy
  target-wide provider remains independent.

## Automated synthetic scenarios

`test/services/assessment/exam_part_scope_integration_test.dart` covers:

1. Part A/B descendant isolation, identity, nonexistent root, bad version
   association, duplicates and cycles.
2. Mock A chooses only A-domain questions; shared items and B questions do
   not leak; a shortage is not silently padded with out-of-part content.
3. Mismatched preloaded blueprint is refused; report retains part key.
4. Diagnostic A/B require separate sufficient coverage; a globally shared
   concept and mixed A+B question are withheld rather than relabeled.
5. Readiness A/B each uses only its subtree's concepts, but global shared
   concept evidence is reusable; whole-target readiness remains separate.

## Still out of scope / release gates

- The existing learner diagnostic route and Target Readiness card remain
  **target-wide**. These new part-scoped APIs/providers are **not** silently
  wired into a route simply because a learner focused a Learn subtree.
- A future explicit user-selected part flow must carry `examPartKey` through
  diagnostic session state/report, screens, saved history, NextAction, Progress,
  and account-isolated caches. Scoring/evidence remains globally per-concept
  unless an approved exam-specific durable evidence design says otherwise.
- Current mock item mappings are inferred through concept/objective links,
  not independently reviewed item-to-exam-part assignments. Shared or
  ambiguous mappings are excluded from part-specific claims. Broader
  publisher or exam-vendor fidelity is **not established**.
- A single `exam_part_key` is not a verified exam time limit, scoring model,
  permitted reference policy, edition, test-center navigation rule or official
  candidate eligibility. EXM-03 higher fidelity labels remain blocked.
- Do not merge overlapping PRs independently. Test against newest `main`
  before final approval. No hosted Supabase migrations or production data
  actions are authorized by this change.
