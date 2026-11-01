# LearningApp — Learning Science & Cold-Start Optimization Research (`/docs/learning_science/`)

This directory houses the peer-reviewed cognitive psychology, psychometric measurement, and instructional design specifications that drive LearningApp's **Modality-Adaptive Delivery Engine** and **Cold-Start Psychometric Priors ($N=0$ User Data)**.

See the master execution plan in the repository root: **[`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`](../../EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md)**.

---

## Why This Folder Exists

Most learning apps use a single, uniform loop (e.g., a flashcard or 4-option multiple-choice question scheduled on a static interval ladder) regardless of *what* is being learned or *who* is learning it, and require thousands of user attempts before they can estimate item difficulty or pass readiness.

LearningApp solves both the **One-Size-Fits-All Fallacy** and the **Cold-Start ($N=0$) Problem** by routing every concept and assessment item through **7 Research-Backed Pedagogical Modalities (`M1`–`M7`)** and computing deterministic **Cold-Start Psychometric Priors ($b_0, D_0, S_0$)** at content ingestion time.

---

## Directory Index

| Document | Scope | Key Scientific Foundations |
|---|---|---|
| **[`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`](../../EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md)** | Root Master Plan: 7 Modalities, Cold-Start Priors, Content Tagging & Implementation Roadmap | Dunlosky et al. (2013); Cepeda et al. (2006); Roediger & Karpicke (2006) |
| **`01_MODALITY_TAXONOMY_AND_DELIVERY_RULES.md`** *(Planned — LS-1)* | Exact UI rendering, scaffolding, time budgets, and FSRS multipliers for Modalities `M1`–`M7` | Ehri (2005); Share (1995); Pirolli & Card (1999); Sparrow et al. (2011); Sweller & Cooper (1985); Renkl et al. (2004); Morris et al. (1977); Kellman & Garrigan (2009) |
| **`02_COLD_START_PSYCHOMETRICS_AND_FSRS_PRIORS.md`** *(Planned — LS-1)* | Feature-based difficulty estimation ($b_0$), initial FSRS stability/difficulty ($S_0, D_0$), and Empirical Bayes shrinkage ($N=0 \to N=30+$) | Freedle & Kostin (1993); Bejar (1993); Haladyna, Downing & Rodriguez (2002); Pelánek (2016); FSRS-5/6 benchmark priors |
| **`03_CONTENT_INGESTION_AND_MANIFEST_SCHEMA.md`** *(Planned — LS-2)* | How official blueprints, YouTube transcripts, PDFs, Anki/Quizlet imports, and BYOK AI outputs are compiled into modality-tagged manifests | Retrieval-augmented grounding, deterministic psychometric linting, SCOWL/Flesch-Kincaid readability |
| **`04_CONTRASTIVE_INTERLEAVING_AND_TRIANGULATION.md`** *(Planned — LS-3)* | Confusable concept clusters (`confusable_group_id`), 3-angle concept triangulation, and confidence-weighted hypercorrection | Rohrer & Taylor (2007); Birnbaum et al. (2013); Chi et al. (1994); Butterfield & Metcalfe (2001) |
| **`05_EXAM_READINESS_AND_PASS_PREDICTION_MATH.md`** *(Planned — LS-3)* | Mathematical formulation of Exam-Day Retrievability $\bar{R}(t_{\text{exam}})$, latency-gated lookup fluency, and Brier-score outcome calibration | IRT 1PL/2PL, FSRS power-law forgetting curves, Bayesian readiness bounds |

---

## Summary of the 7 Pedagogical Modalities

1. **`M1: orthographic_phonological`** — Pre-readers, adult emergent literacy, phonics, and decoding (high-density micro-spacing, phonemic minimal-pair distractors, 95% decodability gate, zero-text audio chrome).
2. **`M2: open_book_index_navigation`** — Open-book licensing & code exams (splits blueprint into `internalize_cold` mental index vs. `lookup_fluency` timed `EXM R1–R4` drills; penalizes slow lookups in FSRS even when accurate).
3. **`M3: conceptual_schema_discrimination`** — Vocabulary, domain theory, and regulatory rules (mandatory contrastive interleaving of `confusable_group_id` pairs, 3-angle triangulation cap at `0.65` until application/contrastive items pass, and confidence hypercorrection).
4. **`M4: procedural_calculation_fading`** — Trade math, estimating, clinical dosage, and GED/engineering calculations (4-stage backward worked-example fading ladder `Stage 0 -> Stage 3` with parameterized numbers and automatic step-down on error).
5. **`M5: oral_production_fluency`** — Oral interviews and spoken recall such as USCIS 128 Civics & N-400 (acoustic-first prompt with hidden text, 3-stage cue fading, and spoken STT/production latency check).
6. **`M6: perceptual_pattern_classification`** — Visual signs, blueprint symbols, and rapid hazard/pattern recognition (short-exposure perceptual learning bursts $<3.5\text{s}$).
7. **`M7: critical_step_checklist`** — Practical trade, clinical, and safety protocols (sequence verification with hard binary gates on `is_critical_safety_step` omissions).
