# Held-out checks for general targets: design note

**Status:** owner chose **option B** on 2026-11-24. Built in migration `20261124020000_held_out_item_reviews`, deployed to production 2026-11-24 (guarded path, 160/160); no approvals recorded yet. Decisions 2 and 3 were settled by the owner's operating model (D-16, 2026-11-24); decision 4 is still open.
**Context:** [ingestion plan v1.2](../../LEARNINGAPP_DEMAND_DRIVEN_CONTENT_INGESTION_PLAN_V1_2_2026-11-23.md) §8.6 and D-14; readiness coverage gate (migration `20261124010000`, switch `learning.readiness_coverage_gate`, OFF).

## The problem

The readiness gate counts an item as **held out** only when it has an approved, published `held_out_transfer` binding in `assessment_item_reference_validity`. That table belongs to the exam-reference system (EXM). EXM was built for open-book licensing exams, where an answer must be located in a specific edition of an exam-permitted reference book. A binding requires all of the following:

- a published **exam part** in the target version's metadata, but published target versions can't be changed;
- an effective-dated **reference manifest revision** listing the permitted book editions;
- an **answer location** (section and page) for each item;
- a **different, qualified reviewer** with evidence of access to that exact edition.

That fits a Florida contractor code-book exam. It's a poor fit for College Algebra, where the answer is computed, not looked up. So the first draft set, [`content/held_out/open_openstax_college_algebra_1e_ch1.yaml`](../../content/held_out/open_openstax_college_algebra_1e_ch1.yaml), can't count toward readiness yet. It has 36 original items, 6 for each of sections 1.1 to 1.6, all checked by `tool/verify_held_out_items.py`.

A second gap: the manifest schema only allows assessment items **inside lessons**, and anything in a lesson is study material, not held out.

## Options

| | A. Reuse EXM bindings | **B. General held-out review record (recommended)** | C. Hidden "readiness check" lessons |
|---|---|---|---|
| **How** | Give the target a new version with an exam part, publish a reference manifest naming OpenStax 1e, and bind each item to a section with a reviewer | New private review table for held-out items, separate from EXM; manifests get objective-level `held_out_items` (no lesson); the coverage function counts approved reviews as well as EXM bindings | Put held-out items in special lessons and filter those lessons out of Library and study flows |
| **Schema change** | None | One additive migration (table, guard trigger, updated coverage function, ingestion of objective-level items) | Small, plus app filtering everywhere lessons are listed |
| **Fit** | Forced: invents an "exam part" and "answer locations" for computed math | Direct: records who wrote and who approved each item, for which target version and item content | Fragile: one missed filter shows the answers in a lesson |
| **Delivery to learners** | EXM drills | Existing diagnostic assessment, which already selects items by target version and concept | Diagnostic, if the filter holds |

**Recommendation: B.** Proposed shape, for review before any SQL is written:

- **Review table:** `private.held_out_item_reviews`, holding item, target version, author, whether AI-drafted, reviewer (who must not be the author), review status, rights status, item-content fingerprint and review date. Approved rows are immutable, and a changed item needs a new review, as in EXM. There are no client read grants.
- **Manifests:** objective-level `held_out_items`. They are ingested with no lesson, linked to the objective's concepts and to `origin_target_version_id`, with answer keys protected like every other item.
- **Coverage function:** `get_target_readiness_coverage` counts an item when either an EXM `held_out_transfer` binding or an approved general review exists.
- **Importer:** `tool/import_open_textbook.py` merges an approved held-out file into the next College Algebra version (R5).

## Decisions needed from the owner

1. **Mechanism:** B (recommended), A or C.
2. **Reviewer (settled by D-16):** an **independent AI review** approves an item: a different model, or a fresh session without the author's context, using the checklist below and its own SymPy check. It is recorded as `reviewer_kind: ai` with the model named. A person's review (`reviewer_kind: human`) is an optional upgrade. The readiness card tells learners when the checks were reviewed by AI.
3. **Item statistics before counting (settled by D-16):** an item counts once its independent review approves it; the §16.4 statistics loop flags weak items later.
4. **Exposure:** a diagnostic shows held-out items to learners, so repeated diagnostics wear them out. Recommendation: cap how often each learner sees each item (the parametric-practice exposure limits are the pattern), and grow the set beyond 6 per objective over time.

## How to approve and ingest (option B, as built)

1. **Review:** an independent reviewer (an AI that did not write the items, or a person) reviews each item in [`content/held_out/open_openstax_college_algebra_1e_ch1.yaml`](../../content/held_out/open_openstax_college_algebra_1e_ch1.yaml), checking the math, the wording, the distractors and that it isn't lesson practice.
2. **Record:** add a `review` block to each approved item, with `reviewer_kind` (`ai` or `human`), `reviewer_model` for AI, `reviewer_ref` (never the author), `reviewer_qualification` (for AI, the checklist version and method), `reviewed_on`, `review_status: approved` and `rights_review_status: approved`. CI runs `tool/verify_held_out_items.py`, which refuses an approval by the author, an AI review without its model, a missing qualification or a future date.
3. **New version:** held-out items can only join a **draft** version, so the next College Algebra import becomes R5 (bump `IMPORT_REVISION`, re-import chapter 1).
4. **Ingest:** run the *Controlled curriculum ingestion* workflow with the R5 manifest and `held_out: content/held_out/open_openstax_college_algebra_1e_ch1.yaml`. Only approved items are sent, each with its approval row and a fingerprint of its content. Then publish with `retire_previous`.
5. **Count:** `get_target_readiness_coverage` counts an item while its approval is in place and its fingerprint still matches the item.

## AI review checklist v1 (R1)

For each item, the reviewer works without the author's notes and records pass or fail with a reason:

1. **Correct:** solve the item independently, and confirm the answer with your own SymPy check, not by reading the key.
2. **Single best answer:** exactly one option is right; any equal-valued option is a deliberate "wrong form" distractor that the question asks for explicitly.
3. **Distractors:** each wrong option reflects a real, named misconception and is not trivially wrong.
4. **Clear:** unambiguous wording and notation; plain language; the LaTeX renders.
5. **Aligned:** tests the stated section objective at the stated difficulty.
6. **Held out:** not a copy or near-copy of the lesson's practice or the book's exercises.
7. **Explanation:** the explanation is correct and would help a learner who chose a wrong option.

Approve only when all seven pass. Otherwise mark it `rejected` with the reason, or fix the item, in which case its fingerprint changes and it is reviewed again.

## What the 60% threshold means for College Algebra

The open-textbook version has one domain with no weight, so its six objectives share it equally (reported as editorial weights). Approving all 6 items for 4 of the 6 objectives (24 items) reaches 67%, which is provisional. All 36 reach 100%, which is full.
