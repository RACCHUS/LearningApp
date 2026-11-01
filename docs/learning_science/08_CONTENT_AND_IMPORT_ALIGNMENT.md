# 08 — Content & Import Alignment Pipeline & Representation Security (`FIX-12`)

This document specifies the six-stage content ingestion pipeline, the **proposed three-representation architecture for `FIX-12` answer-key isolation (and its accurate current implementation status)**, and the **proposed versioned schema extensions** for `content/schema/curriculum_manifest.schema.json`.

---

## 1. Three Content Representations & Accurate `FIX-12` Implementation Status

> **Current Implementation Status (`main` `e538585` & PR `#136`)**:
> The general three-representation architecture below is the **proposed Phase 1 `FIX-12` target** across all assessment routes:
> - On `main` (`e538585`), **`EXM-03` already implements answer-key isolation and authenticated server-side scoring specifically for approved `EXM-02A` assigned exam-part practice** across three migrations:
>   1. `20261101130000_exm_03_assigned_practice_scoring.sql` (private canonical scorer `public.exm03_record_assigned_practice` writing to `public.exam_part_practice_attempts`),
>   2. `20261101140000_exm_03_authenticated_assignment_issuer.sql` (authenticated safe projection issuer `public.exm03_issue_assigned_practice` stripping `scoring_spec`), and
>   3. `20261101150000_exm_03_authenticated_submit_protected_items.sql` (authenticated session- and owner-bound submission wrapper `public.exm03_submit_assigned_practice`, plus restrictive RLS policy `exm03_no_direct_read_of_approved_answers` on `public.assessment_items` blocking direct table reads of approved `EXM-02A` items).
> - However, **non-EXM assessment items on `main` remain readable via general `assessment_items` RLS**, and on Antigravity's PR `#136` general `FIX-12` is scheduled for **Phase 1** (`AssessmentItemRenderer` still performs client-side scoring using `item.scoringSpec` and `correct_index`).
> - Extending the three-representation DTO and server scoring RPCs to **all** non-EXM diagnostic, mock exam, and adaptive practice items therefore remains a **Phase 1 deliverable**.

### 1.1 Target Representation 1: Authoring & Ingestion Representation (Repository / Server Storage Only)
Used during content authoring, import validation, and manifest ingestion (`ingest_curriculum_manifest`). Contains the full instructional and scoring specification:
```json
{
  "item_id": "fl_ins_042",
  "prompt": "Which policy provision specifies how loss valuation is handled when insured property is partially destroyed?",
  "options": [
    {
      "option_id": "opt_a",
      "text": "Coinsurance clause",
      "is_correct": true,
      "rationale": "The coinsurance clause governs partial loss reimbursement relative to required insurance-to-value percentage.",
      "misconception_tag": null
    },
    {
      "option_id": "opt_b",
      "text": "Subrogation clause",
      "is_correct": false,
      "rationale": "Subrogation transfers recovery rights against a negligent third party to the insurer.",
      "misconception_tag": "confuses_recovery_rights_with_valuation"
    }
  ]
}
```

### 1.2 Target Representation 2: Learner Presentation DTO (Delivered to Client Prior to Submission)
In Phase 1 (`FIX-12`), diagnostic, mock exam, and readiness-eligible assessments deliver only the prompt, stimulus, and shuffled options (`option_id`, `text`) **without** `is_correct`, `correct_index`, `scoring_spec`, `misconception_tag`, or answer-revealing `rationale` fields (and bind `presented_option_ids` to a server-issued `attempt_id` whenever authoritative order verification is required; see [`06_MEASUREMENT_AND_SCHEDULING.md`](06_MEASUREMENT_AND_SCHEDULING.md)):
```json
{
  "attempt_id": "0192e8b0-7c2a-7000-8000-000000000001",
  "item_id": "fl_ins_042",
  "prompt": "Which policy provision specifies how loss valuation is handled when insured property is partially destroyed?",
  "options": [
    { "option_id": "opt_b", "text": "Subrogation clause" },
    { "option_id": "opt_a", "text": "Coinsurance clause" }
  ],
  "presented_option_ids": ["opt_b", "opt_a"]
}
```

### 1.3 Target Representation 3: Server Scoring & Controlled Feedback Release
Stored in protected server tables (`scoring_spec`) and evaluated by server scoring RPCs:
- In **study/acquisition mode (`feedback_policy == immediate_explanatory`)**: Submitting the attempt returns the server-computed score plus the relevant option rationales.
- In **timed exam mode (`timing_regime == exam_clock_enforced`, `feedback_policy == deferred_until_submission`)**: Rationales and correctness are withheld until the exam part is submitted, and timing is verified using server-computed `server_elapsed_ms`.

---

## 2. The 6-Stage Content & Import Pipeline

1. **Source Acquisition**: Official outlines/manuals, PDFs, YouTube URLs (embedded via `youtube-nocookie`; optional Gemini API YouTube URL analysis via user BYOK within its 8-hour daily free-tier allowance), Anki/CSV exports, and BYOK/MCP AI generation.
2. **Extraction & 6-Property Provenance**: Records `origin`, `visibility` (`private` by default for imports), `rights_status` (`rights_review_required` by default for unverified imports), `review_status` (`unreviewed` on import), `source_authority`, and `version_validity` (`07_READINESS_AND_VALIDATION.md`).
3. **Knowledge Organization**: Maps content to canonical `fields`, `knowledge_concepts`, `concept_relations` prerequisites, and `confusable_group_id` clusters.
4. **Learning Design**: Assigns the canonical `LearningTaskProfile`, `ContentComplexityProfile`, `InstructionalPolicy`, and `AssessmentPolicy` (`02_LEARNING_TASK_TAXONOMY.md`).
5. **Quality Assurance**: Executes deterministic `ContentQualityValidator` checks (schema validity, option length/homogeneity, citation locators, passage reading demand), sets `complexity_assessment_status = 'deterministic_profile'`, and routes candidates for public catalog promotion to the `ECO-02`/`ECO-04` editorial review queue.
6. **Personalized Delivery**: Delivers the Learner Presentation DTO through the task-aware Study View and versioned scheduler (`review_items`), recording attempts via `record_events` (`public.learning_events`).

---

## 3. Proposed Versioned Schema Extension for `curriculum_manifest.schema.json`

> **Implementation Status Note**: On `main` (`e538585`), [`content/schema/curriculum_manifest.schema.json`](../../content/schema/curriculum_manifest.schema.json) specifies `additionalProperties: false` on manifest objects, represents MCQ `options` as string arrays, and stores answer keys in `scoring_spec.correct_index`.
>
> Therefore, the metadata blocks below are **proposed schema extensions (target schema version `2.1.0`)**, not fields already accepted by the `main` validator. A versioned update to `curriculum_manifest.schema.json` and backwards-compatibility tests for existing YAML manifests (`bs_computer_science.yaml`, `security_plus_sy0_701.yaml`, `software_engineer_career.yaml`) must be merged in Phase 2/4 before adding these fields to production manifests.

### Proposed Schema `2.1.0` Activity Metadata Block (Exact Canonical Alignment with `02` & `07`)
```json
{
  "learning_task_profile": {
    "knowledge_facet": "conceptual_relational",
    "cognitive_operation": "distinguish_confusable",
    "stimulus_channel": "visual_text",
    "response_channel": "structured_choice",
    "reference_policy": "closed_book"
  },
  "content_complexity_profile": {
    "reading_demand": {
      "word_count": 42,
      "reading_grade_estimate": 9.5,
      "lexical_rarity_tier": "standard"
    },
    "reasoning_step_count": 2,
    "quantitative_complexity": "none",
    "prerequisite_depth": 1,
    "confusable_density": "high_confusable_group",
    "response_format_demand": "recognition_choice",
    "reference_foraging_depth": "none",
    "has_statutory_exception": false
  },
  "instructional_policy": {
    "eligible_strategies": [
      "active_retrieval_first",
      "contrastive_interleaving",
      "elaborative_rationale_feedback"
    ],
    "scaffolding_policy": "adaptive_on_error",
    "feedback_policy": "immediate_explanatory"
  },
  "assessment_policy": {
    "timing_regime": "untimed_mastery",
    "error_criticality": "standard_compensatory",
    "scoring_protection": "server_protected_scoring"
  },
  "provenance_metadata": {
    "origin": "official_source",
    "visibility": "public_catalog",
    "rights_status": "verified_permissive_or_public_domain",
    "review_status": "authoritatively_verified",
    "source_authority": "primary_regulator_or_statute",
    "version_validity": {
      "effective_from": "2026-01-01",
      "effective_to": null,
      "superseded_by_version_id": null,
      "status": "active"
    }
  },
  "complexity_assessment_status": "deterministic_profile",
  "item_psychometric_status": "unobserved",
  "readiness_validation_status": "unvalidated",
  "blueprint_alignment_state": "blueprint_weighted"
}
```
