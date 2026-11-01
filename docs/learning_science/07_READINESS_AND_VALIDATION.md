# 07 — Provenance, Readiness & Domain-Specific Validation

This specification defines the decomposed provenance model, separates content provenance from measurement quality and learner readiness, corrects the examination classification of the Florida pilots, and defines proving grounds across all seven task approaches.

---

## 1. Six Orthogonal Content Provenance Properties

A user can privately import an official government handbook (`origin = user_import`, `source_authority = primary_regulator_or_statute`), and a cryptographic hash proves file integrity (`source_hash`) without proving factual correctness.

Therefore, content provenance is recorded across **six independent properties** rather than a single conflated `content_trust_level` enum:

| Property | Allowed Values | Purpose |
|---|---|---|
| **1. `origin`** | `official_source`, `curated_editorial`, `community_contribution`, `user_import`, `ai_generated` | Tracks how the material entered the platform (never overwritten when later reviewed) |
| **2. `visibility`** | `private`, `shared_unlisted`, `public_catalog` | Controls access scope (`user_import` and `ai_generated` default to `private`) |
| **3. `rights_status`** | `verified_permissive_or_public_domain`, `licensed_embed_or_link`, `private_fair_use_only`, `restricted_or_unknown` | Governs whether content can be published to `public_catalog` or exported |
| **4. `review_status`** | `unreviewed`, `automated_checks_passed`, `editorially_reviewed`, `authoritatively_verified` | Tracks quality assurance and human/educator verification (`ECO-02` / `ECO-04`) |
| **5. `source_authority`** | `primary_regulator_or_statute`, `accredited_publisher_or_standard`, `secondary_educational`, `user_supplied_unverified` | Identifies the evidentiary standing of the cited source |
| **6. `version_validity`** | `{ effective_from, effective_to, superseded_by_version_id, status: 'active' \| 'expired' \| 'superseded' }` | Ensures outdated regulatory editions are never treated as current exam standards |

### Derived Readiness Eligibility Rule
An assessment item is **Eligible for Official Exam Readiness (`is_official_readiness_eligible`)** if and only if:
- `review_status == 'authoritatively_verified'` (or `'editorially_reviewed'` against an active official blueprint), **AND**
- `source_authority` $\in$ `{'primary_regulator_or_statute', 'accredited_publisher_or_standard'}`, **AND**
- `version_validity.status == 'active'`, **AND**
- `blueprint_alignment_state == 'blueprint_weighted'`.

Items that do not meet this bar (such as `unreviewed` personal imports or AI-generated study sets) remain fully usable for **personal learning and FSRS-6 retention scheduling**, with their progress displayed in a separate *Personal Study Progress* view.

---

## 2. Measurement Quality vs. Learner Mastery vs. Exam Readiness

1. **Measurement Quality (`measurement_quality_level`)**:
   - `unobserved` ($N = 0$) $\to$ `research_informed_prior` (`ContentComplexityProfile`) $\to$ `observed` $\to$ `calibrated` (statistical item estimates with bounded $\text{SE}$) $\to$ `validated_for_intended_use`.
2. **Three Distinct Learner State Layers**:
   - **FSRS-6 Card Retrievability $R(t)$**: Probability of recalling a specific review item.
   - **Concept Mastery (`user_concept_state`)**: Evidence across the facets (`concept_facets[]`) and cognitive operations of a `knowledge_concept`.
   - **Examination Readiness**: Synthesizes (a) authoritative blueprint coverage, (b) delayed spaced retention, (c) transfer accuracy on **held-out unfamiliar items**, and (d) execution under actual exam conditions.

---

## 3. Domain-Specific Proving Grounds Across All Seven Task Families

Notice the critical distinction between **Pilot A (Florida Certified Contractor)** and **Pilot B (Florida Insurance)**:
- **Florida DBPR Construction Examinations (`Pilot A`)** are **open-book examinations** using approved reference manuals.
- **Florida DFS Insurance Licensing Examinations (`Pilot B`)** (per the Florida Insurance Licensing Candidate Handbook / Pearson VUE rules) are **closed-book multiple-choice examinations** (candidates may bring only required identification and an optional approved translation dictionary—no reference manuals).

Both are valuable proving grounds precisely because they test **different** assessment architectures, and they are complemented by dedicated validation targets for the remaining five task families:

| Task Family (`04_TASK_SPECIFIC_DELIVERY.md`) | Validation Target / Proving Ground | Actual Assessment Condition | What This Proving Ground Validates |
|---|---|---|---|
| **1. Open-Book Reference Navigation (`reference_navigation`)** | **Pilot A — Florida DBPR Certified Contractor (`EXM-01..03`)** | **Open-book** (approved reference volumes, timed exam parts) | Resource selection (`R1`), section navigation (`R2`), provision location (`R3`), exception interpretation (`R4`), application, and time management |
| **2. Concepts, Terminology & Closed-Book Licensing (`verbal_terminology`, `conceptual_relational`)** | **Pilot B — Florida DFS Insurance Licensing** & **CompTIA Security+ (`SY0-701`)** | **Closed-book timed MCQ** | Knowledge acquisition, contrastive discrimination (`confusable_group_id`), delayed retrieval, distractor functioning, and closed-book timed readiness |
| **3. Adult Literacy & Decoding (`sublexical_orthographic`)** | **Adult Phonics, CVC, Decoding & Functional Survival Track** | **Audio-first untimed mastery** | Adult decoding progression (`ER-06`), minimal-pair discrimination, sight/survival word transfer, and screen-reader/web semantics accessibility |
| **4. Calculations & Multi-Step Procedures (`procedural_quantitative`)** | **Construction Estimating Math & GED Quantitative Bridge** | **Formula-sheet / closed-book numeric & MCQ** | Prior-knowledge diagnostic routing (`ER-10`), adaptive worked-example backward fading (`ER-05`), parameterized transfer, and unit verification |
| **5. Oral Production & Spoken Interviews (`spoken_production`)** | **USCIS 2025 (128-Question Civics Pool) & Form N-400 Spoken Practice** | **Uncued oral interview** (20 asked, 12 to pass; no visual choices) | Acoustic prompt comprehension and spoken free-recall accuracy against official acceptable answers (compared empirically against MCQ-only prep) |
| **6. Visual Classification & Perceptual Diagnosis (`perceptual_diagnostic`)** | **DMV Regulatory/Warning Signs & Construction Blueprint Symbols** | **Visual stimulus identification** | Visual discrimination accuracy across confusable sign/symbol families before optional fluency pacing |
| **7. Critical-Step Safety & Procedural Checklists (`procedural_execution`)** | **Food Safety (`ServSafe`-aligned), Workplace Lockout/Tagout & CDL Pre-Trip Checklists** | **Ordered checklist with authoritative critical-fail steps** | Step-sequence accuracy and zero-omission reliability on regulatory critical-safety steps |
