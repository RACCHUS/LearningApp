# 08 — Content & Import Alignment Pipeline

This document specifies how existing repository content and future imported material (YouTube, PDFs, official manuals, Anki/CSV decks, and BYOK/MCP AI outputs) receive validated learning-design and provenance metadata.

---

## 1. The 6-Stage Content Pipeline

All content enters LearningApp through a unified six-stage architecture:

### Stage 1: Source Acquisition
- **Supported Inputs**: Official regulator outlines/manuals, open textbooks/PDFs, public YouTube URLs (embedded via `youtube-nocookie`, with optional Gemini API transcript/video analysis via user BYOK within free-tier limits), Anki/CSV/Quizlet exports, and structured BYOK/MCP AI generation.

### Stage 2: Extraction & Provenance
- Records source identity, license/rights, effective date/version, and verbatim citation locators (`source_ref`).
- Assigns initial `content_trust_level`:
  - User/AI imports default to `personal_import` (`is_public = false`).
  - Curated manifest imports with verified source hashes enter as `automated_checked` or `authoritatively_verified` according to the guarded ingestion workflow.

### Stage 3: Knowledge Organization
- Maps extracted topics to canonical taxonomy `fields`, `knowledge_concepts`, prerequisite edges (`concept_relations`), and `confusable_group_id` clusters where applicable.

### Stage 4: Learning Design (`LearningTaskProfile` Assignment)
- Assigns the multidimensional `LearningTaskProfile` (`02_LEARNING_TASK_TAXONOMY.md`) and `content_complexity_profile` (`06_MEASUREMENT_AND_SCHEDULING.md`) to each instructional block and assessment item:
  - Identifies `knowledge_facet`, `cognitive_operation`, `stimulus_channel`, `response_channel`, and `reference_policy`.
  - Attaches adaptive worked-example steps for `procedural_quantitative` items.
  - Formats `structured_choice` options with stable `option_id`, `is_correct`, `rationale`, and optional `misconception_tag`.

### Stage 5: Quality Assurance & Trust Gating
- Runs deterministic validation (`ContentQualityValidator`):
  - Verifies schema completeness, option count/balance, absence of positional cues (`FIX-1`), citation presence for verified tiers, and reading complexity metadata.
- Enforces the readiness boundary: `personal_import` and unreviewed `automated_checked` items are immediately available for personal learning and FSRS review, but cannot enter authoritative exam-readiness calculations until promoted through editorial/authoritative verification (`ECO-02` / `ECO-04`).

### Stage 6: Personalized Learning Delivery
- Routes validated items into the task-aware Study View, adaptive scaffolding controller, and versioned scheduler (`review_items`), recording attempts under the Unified Evidence Contract.

---

## 2. Manifest Schema Extensions (`content/schema/curriculum_manifest.schema.json`)

To support this pipeline without breaking existing manifests on `main` (`bs_computer_science.yaml`, `security_plus_sy0_701.yaml`, `software_engineer_career.yaml`), the manifest schema adds optional, backwards-compatible objects on concepts and assessment items:

```json
{
  "learning_task_profile": {
    "knowledge_facet": "conceptual_relational",
    "cognitive_operation": "apply_to_scenario",
    "stimulus_channel": "visual_text",
    "response_channel": "structured_choice",
    "reference_policy": "closed_book",
    "timing_regime": "untimed_mastery",
    "error_criticality": "standard_compensatory"
  },
  "content_complexity_profile": {
    "reasoning_step_count": 2,
    "reading_grade_estimate": 10.5,
    "has_confusable_distractors": true,
    "has_statutory_exception": false
  },
  "content_trust_level": "authoritatively_verified",
  "measurement_quality_level": "research_informed_prior",
  "blueprint_alignment_state": "blueprint_weighted"
}
```
