# 02 — Multidimensional Learning Task Taxonomy (`LearningTaskProfile`)

This document specifies the **Multidimensional Learning Task Taxonomy** that replaces mutually exclusive concept modalities.

---

## 1. Design Principle: One Concept, Multiple Learning Experiences

In real-world technical, academic, and licensing domains, a single `knowledge_concept` is rarely learned or tested through a single cognitive mechanism. Assigning a single static modality to a concept forces an artificial choice between vocabulary, visual recognition, calculation, reference navigation, and practical execution.

Instead, LearningApp models:
1. **Concept-Level Knowledge Facets**: Which facets of competence exist for a `knowledge_concept`.
2. **Activity/Item-Level `LearningTaskProfile`**: Which specific facet, cognitive operation, stimulus/response channel, and assessment condition a given lesson block, flashcard, drill, or assessment item exercises.

---

## 2. Schema Definition of `LearningTaskProfile`

```json
{
  "knowledge_facet": "conceptual_relational",
  "cognitive_operation": "distinguish_confusable",
  "stimulus_channel": "visual_text",
  "response_channel": "structured_choice",
  "reference_policy": "closed_book",
  "timing_regime": "untimed_mastery",
  "error_criticality": "standard_compensatory",
  "scaffolding_policy": "adaptive_on_error"
}
```

### Axis 1: `knowledge_facet`
| Value | Description | Example |
|---|---|---|
| `sublexical_orthographic` | Phoneme-grapheme mapping, decoding, blending, spelling | CVC word decoding (`cat`, `ship`) |
| `verbal_terminology` | Definitions, nomenclature, statutory terms, abbreviations | Defining *Subrogation* or *Notice to Owner* |
| `conceptual_relational` | Mechanisms, cause-effect, boundary distinctions between concepts | Distinguishing *Claims-Made* vs. *Occurrence* liability policies |
| `procedural_quantitative` | Multi-step formula setup, calculation, unit conversion | Calculating cubic yards of concrete with waste factor |
| `procedural_execution` | Ordered operational, clinical, or safety checklists | CDL pre-trip air brake check sequence |
| `perceptual_diagnostic` | Visual classification of signs, symbols, schematics, or patterns | Identifying a regulatory road sign or schematic symbol |
| `reference_navigation` | Book selection, index/TOC foraging, clause & exception lookup | Locating truss bracing tolerances in the FL Building Code (`EXM`) |

### Axis 2: `cognitive_operation`
- `define_or_identify` — Recall or recognize the core term, symbol, or rule.
- `explain_mechanism` — Articulate *how* or *why* a relationship holds.
- `distinguish_confusable` — Discriminate a concept from a linked `confusable_group_id` neighbor.
- `classify_example_non_example` — Identify whether a concrete case satisfies the concept definition.
- `apply_to_scenario` — Transfer the principle to a novel situational stem.
- `calculate_and_verify_units` — Execute quantitative steps and validate dimensional units.
- `locate_and_interpret_provision` — Navigate an authoritative reference and interpret clauses/exceptions.
- `justify_why_correct` — Self-explanation / rationale selection explaining why alternatives fail.

### Axis 3: `stimulus_channel` & `response_channel`
- **Stimulus**: `visual_text`, `audio_first`, `audio_plus_visual`, `diagram_or_image`, `scenario_with_reference_manifest`.
- **Response**: `structured_choice` (shuffled options), `free_recall_text`, `spoken_production`, `numeric_with_unit`, `ordered_checklist`, `reference_locator_step` (`EXM R1–R4`), `grapheme_trace_or_tap`.

### Axis 4: `reference_policy`, `timing_regime` & `error_criticality`
- **`reference_policy`**: `closed_book`, `open_book_manifest`, `formula_sheet_only`.
- **`timing_regime`**: `untimed_mastery` (acquisition & accuracy first), `paced_practice` (advisory timer), `exam_clock_enforced` (simulates official exam time budget).
- **`error_criticality`**: `standard_compensatory` vs. `authoritative_critical_step_gate` (used **only** when an official regulator rubric or safety standard designates an omission as an automatic failure).

---

## 3. Multi-Facet Concept Progression Example

Consider the canonical concept `electrical-overcurrent-protection`:
1. **Facet 1 (`verbal_terminology` + `define_or_identify`)**: Learn terms *ampacity*, *continuous load*, and *overcurrent*.
2. **Facet 2 (`perceptual_diagnostic` + `define_or_identify`)**: Recognize standard breaker and fuse schematic symbols (`diagram_or_image`).
3. **Facet 3 (`conceptual_relational` + `distinguish_confusable`)**: Distinguish *overload* vs. *short circuit* vs. *ground fault*.
4. **Facet 4 (`procedural_quantitative` + `calculate_and_verify_units`)**: Calculate the $125\%$ continuous load sizing using adaptive worked-example fading.
5. **Facet 5 (`reference_navigation` + `locate_and_interpret_provision`)**: Locate the conductor ampacity table and temperature derating exceptions in the code manual under `open_book_manifest`.

Each facet generates independent evidence toward the learner's profile without forcing every concept into a rigid one-size-fits-all template.
