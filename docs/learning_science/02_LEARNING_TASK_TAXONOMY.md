# 02 — Canonical Learning Task, Complexity & Policy Schemas

This document defines the **single canonical schema specification** referenced across all LearningApp learning-science documents (`03`–`08`) and root plans.

> **Ontology Scope Note**: This classification system is an **engineering ontology** designed to organize instructional delivery, adaptive scaffolding, and evidence collection in LearningApp. It is not claimed to be an empirically validated psychological taxonomy.

---

## 1. Concept-Level vs. Activity-Level Metadata

1. **Concept-Level (`knowledge_concepts`)**:
   - A single concept can involve multiple learning facets (`concept_facets[]`), prerequisites (`concept_relations`), and optional `confusable_group_id` links.
2. **Activity / Item-Level (`lesson_blocks`, `flashcards`, `assessment_items`)**:
   - A specific learning block or assessment item exercises a specific profile described by **four separate, composable objects**:
     1. **`LearningTaskProfile`** — What knowledge facet, cognitive operation, channels, and reference policy are exercised?
     2. **`ContentComplexityProfile`** — What intrinsic task characteristics make this item demanding at cold start ($N=0$)?
     3. **`InstructionalPolicy`** — Which teaching/scaffolding/feedback rules apply during study?
     4. **`AssessmentPolicy`** — What timing, error-criticality, and server-scoring rules apply during evaluation?

---

## 2. Canonical Schema 1: `LearningTaskProfile`

```json
{
  "knowledge_facet": "conceptual_relational",
  "cognitive_operation": "distinguish_confusable",
  "stimulus_channel": "visual_text",
  "response_channel": "structured_choice",
  "reference_policy": "closed_book"
}
```

### Fields
- **`knowledge_facet`**:
  - `sublexical_orthographic` — Phoneme-grapheme mapping, decoding, blending, spelling.
  - `verbal_terminology` — Definitions, nomenclature, statutory terms, abbreviations.
  - `conceptual_relational` — Mechanisms, cause-effect, boundary distinctions between concepts.
  - `procedural_quantitative` — Multi-step formula setup, calculation, unit conversion.
  - `procedural_execution` — Ordered operational, clinical, or safety checklists.
  - `perceptual_diagnostic` — Visual classification of signs, symbols, schematics, or patterns.
  - `reference_navigation` — Resource selection, section navigation, provision location, exception interpretation (`EXM`).
- **`cognitive_operation`**:
  - `define_or_identify`
  - `explain_mechanism`
  - `distinguish_confusable`
  - `classify_example_non_example`
  - `apply_to_scenario`
  - `calculate_and_verify_units`
  - `locate_and_interpret_provision`
  - `justify_why_correct`
- **`stimulus_channel`**:
  - `visual_text` | `audio_first` | `audio_plus_visual` | `diagram_or_image` | `scenario_with_reference_manifest`
- **`response_channel`**:
  - `structured_choice` | `free_recall_text` | `spoken_production` | `numeric_with_unit` | `ordered_checklist` | `reference_locator_step` | `grapheme_trace_or_tap`
- **`reference_policy`**:
  - `closed_book` | `open_book_manifest` | `formula_sheet_only`

---

## 3. Canonical Schema 2: `ContentComplexityProfile`

This single schema is used identically in [`06_MEASUREMENT_AND_SCHEDULING.md`](06_MEASUREMENT_AND_SCHEDULING.md) and [`08_CONTENT_AND_IMPORT_ALIGNMENT.md`](08_CONTENT_AND_IMPORT_ALIGNMENT.md) to represent cold-start cognitive/content complexity (Construct 1 of difficulty, kept strictly separate from IRT item difficulty and FSRS memory difficulty):

```json
{
  "reading_demand": {
    "word_count": 42,
    "reading_grade_estimate": 9.5,
    "lexical_rarity_tier": "standard"
  },
  "reasoning_step_count": 2,
  "quantitative_complexity": "single_formula",
  "prerequisite_depth": 1,
  "confusable_density": "high_confusable_group",
  "response_format_demand": "recognition_choice",
  "reference_foraging_depth": "none",
  "has_statutory_exception": false
}
```

### Fields
- **`reading_demand`**: `{ word_count: integer, reading_grade_estimate: number, lexical_rarity_tier: 'decodable' | 'high_frequency' | 'standard' | 'technical_specialized' }`
- **`reasoning_step_count`**: integer ($\ge 1$)
- **`quantitative_complexity`**: `none` | `arithmetic` | `single_formula` | `multi_step_with_unit_conversion`
- **`prerequisite_depth`**: integer ($\ge 0$, topological depth in `concept_relations`)
- **`confusable_density`**: `none` | `low` | `high_confusable_group`
- **`response_format_demand`**: `recognition_choice` | `cued_recall` | `uncued_production` | `multi_step_execution`
- **`reference_foraging_depth`**: `none` | `r1_resource` | `r2_section` | `r3_provision` | `r4_exception`
- **`has_statutory_exception`**: boolean

---

## 4. Canonical Schema 3: `InstructionalPolicy`

```json
{
  "eligible_strategies": [
    "active_retrieval_first",
    "contrastive_interleaving",
    "elaborative_rationale_feedback"
  ],
  "scaffolding_policy": "adaptive_on_error",
  "feedback_policy": "immediate_explanatory"
}
```

- **`eligible_strategies[]`**: Subset of `active_retrieval_first`, `contrastive_interleaving`, `worked_example_backward_fading`, `elaborative_rationale_feedback`, `reference_foraging_decomposition`, `multimodal_audio_orthographic`.
- **`scaffolding_policy`**: `none` | `adaptive_on_error` | `diagnostic_gated_fading`.
- **`feedback_policy`**: `immediate_explanatory` | `deferred_until_submission` | `minimal_verification`.

---

## 5. Canonical Schema 4: `AssessmentPolicy`

```json
{
  "timing_regime": "untimed_mastery",
  "error_criticality": "standard_compensatory",
  "scoring_protection": "server_protected_scoring"
}
```

- **`timing_regime`**: `untimed_mastery` | `paced_practice` | `exam_clock_enforced`.
- **`error_criticality`**: `standard_compensatory` | `authoritative_critical_step_gate`.
- **`scoring_protection`**: `client_practice` | `server_protected_scoring` (determines whether answer keys remain server-only per `FIX-12` / `08_CONTENT_AND_IMPORT_ALIGNMENT.md`).
