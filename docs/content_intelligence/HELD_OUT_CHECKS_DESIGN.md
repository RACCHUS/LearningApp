# Held-out checks for general targets: design note

**Status:** proposal, 2026-11-24. Needs owner decisions (below) before any schema change.
**Context:** [ingestion plan v1.2](../../LEARNINGAPP_DEMAND_DRIVEN_CONTENT_INGESTION_PLAN_V1_2_2026-11-23.md) §8.6 and D-14; readiness coverage gate (migration `20261124010000`, switch `learning.readiness_coverage_gate`, OFF).

## The problem

The readiness gate counts an item as **held out** only when it has an approved, published `held_out_transfer` binding in `assessment_item_reference_validity`. That table belongs to the exam-reference system (EXM). EXM was built for open-book licensing exams, where an answer must be located in a specific edition of an exam-permitted reference book. A binding requires all of the following:

- a published **exam part** in the target version's metadata, but published target versions can't be changed;
- an effective-dated **reference manifest revision** listing the permitted book editions;
- an **answer location** (section and page) for each item;
- a **different, qualified reviewer** with evidence of access to that exact edition.

That fits a Florida contractor code-book exam. It's a poor fit for College Algebra, where the answer is computed, not looked up. So the first draft set, [`content/drafts/held_out/open_openstax_college_algebra_1e_ch1.yaml`](../../content/drafts/held_out/open_openstax_college_algebra_1e_ch1.yaml), can't count toward readiness yet. It has 36 original items, 6 for each of sections 1.1 to 1.6, all checked by `tool/verify_held_out_items.py`.

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
2. **Reviewer:** each item needs approval by a **different, qualified person**, such as a math teacher or tutor. I wrote these items with AI, so I can't approve them. Name the reviewer or reviewers, or say how you want to find one.
3. **Item statistics before counting:** plan §9.2 (tier T2) says held-out items need item statistics before they count toward readiness, but statistics need learners to have taken the items. Recommendation: count an item once a person approves it, then use the §16.4 statistics loop to pull weak items later.
4. **Exposure:** a diagnostic shows held-out items to learners, so repeated diagnostics wear them out. Recommendation: cap how often each learner sees each item (the parametric-practice exposure limits are the pattern), and grow the set beyond 6 per objective over time.

## What the 60% threshold means for College Algebra

The open-textbook version has one domain with no weight, so its six objectives share it equally (reported as editorial weights). Approving all 6 items for 4 of the 6 objectives (24 items) reaches 67%, which is provisional. All 36 reach 100%, which is full.
