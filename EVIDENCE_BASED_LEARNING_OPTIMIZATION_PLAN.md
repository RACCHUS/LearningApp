# LearningApp — Evidence-Based Learning Science & Cold-Start Optimization Plan

**Date:** 2026-11-01 · **Scope:** Cold-Start Efficacy ($N=0$ User Data), Content-Modality Routing, and Research-Backed App Configuration
**Research Directory:** `/docs/learning_science/` · **Status:** Master Architectural & Scientific Plan for Review

---

## 1. Executive Summary: Solving the Cold-Start Problem with Science

At launch—and whenever a learner imports a new topic, YouTube lecture, or niche licensing syllabus—**we will not have thousands of historical user attempts to empirically calibrate question difficulty, forgetting curves, or pass probability.**

If the app relies on crowd data before it can work well, early users get a weak experience. Conversely, if the app uses a "one-size-fits-all" study loop (standard flashcards + 4-option multiple choice + a fixed interval ladder), it violates fundamental findings in cognitive psychology:
- **Pre-readers and emergent adult readers** cannot learn grapheme-phoneme mappings through text-heavy cards or multi-day initial intervals.
- **Open-book licensing candidates** (e.g., Florida DBPR Contractors, NEC Electrical, PE) fail when they try to memorize 1,200-page code tables instead of training **mental indexing + timed lookup fluency**—or when they look up everything and run out of time.
- **Conceptual & technical learners** (e.g., Security+, Nursing, Insurance, CS) develop an **illusion of competence** when they recognize familiar phrasing in blocked MCQs, then fail on exam day when tested on near-neighbor confusable concepts or novel scenarios.
- **Calculation & procedural learners** suffer working-memory overload when thrown straight into unassisted multi-step word problems without **worked-example fading**.
- **Oral interview candidates** (e.g., USCIS 128 Civics & N-400) fail when they practice visual recognition (MCQ) for a test that requires **uncued acoustic comprehension and spoken production**.

### The Architectural Solution
We replace "wait for user data" and "one-size-fits-all study" with a **3-Layer Scientific Optimization Architecture**:
1. **7 Content-Modality Pedagogical Engines (`PedagogicalModality`)**: Content is classified at ingestion time by the *cognitive mechanism required to master it*, and the app automatically reconfigures its delivery UI, scaffolding progression, spacing parameters, and mastery rules per modality.
2. **Research-Backed Cold-Start Psychometric Priors ($N=0$)**: Before a single user answers an item, its initial FSRS stability ($S_0$), difficulty ($D_0$), and IRT difficulty prior ($b_0$) are computed deterministically from linguistic, structural, and cognitive-load features grounded in published educational measurement research—and blended smoothly into empirical data via **Empirical Bayes Shrinkage** as attempts accumulate ($N=1 \to 30+$).
3. **Multi-Angle Concept Triangulation & Modality-Specific Readiness Proof**: A concept is never marked "Exam-Ready" from a single recognition hit; it must satisfy the verification criteria of its modality (e.g., *Definition + Contrastive Boundary + Scenario Application* for conceptual knowledge; *$\le 45\text{s}$ Table Lookup Accuracy* for open-book code items).

---

## 2. The 7 Pedagogical Modalities (Replacing One-Size-Fits-All)

Every `knowledge_concept`, `lesson_block`, and `assessment_item` in LearningApp maps to one of **7 research-verified pedagogical modalities**. Each modality governs how content is structured on import, how the Study View renders it, how FSRS schedules it, and how readiness is proven.

| # | Modality Slug | Target Content & Learners | Primary Cognitive Bottleneck | Core Scientific Literature |
|---|---|---|---|---|
| **M1** | `orthographic_phonological` | Pre-readers, adult literacy, ESL phonics, decoding & sight/survival words | Sub-lexical grapheme-phoneme mapping & auditory-visual binding | Ehri (2005); Share (1995) *Self-Teaching Hypothesis*; Castles, Rastle & Nation (2018); National Reading Panel (2000) |
| **M2** | `open_book_index_navigation` | Open-book licensing & code exams (FL Contractor, NEC, IBC, OSHA, PE) | Information foraging speed, book routing, index traversal & exception parsing under time pressure | Pirolli & Card (1999) *Information Foraging*; Sparrow et al. (2011) *Transactive Memory*; Sweller (1988) |
| **M3** | `conceptual_schema_discrimination` | Technical vocabulary, domain theory, law/policy rules (Security+, Insurance, Nursing, CS) | Confusing near-neighbor concepts; surface-stem memorization without deep schema transfer | Roediger & Karpicke (2006); Rohrer & Taylor (2007) *Interleaving*; Chi et al. (1994) *Self-Explanation*; Butterfield & Metcalfe (2001) |
| **M4** | `procedural_calculation_fading` | Trade math, construction estimating, clinical dosage, engineering, GED math, currency | Working-memory overload ($>4$ interacting elements) during multi-step setup & unit conversion | Sweller & Cooper (1985) *Worked-Example Effect*; Renkl, Atkinson & Große (2004) *Backward Fading*; Kalyuga et al. (2003) |
| **M5** | `oral_production_fluency` | Oral exams & interviews (USCIS 128 Civics, N-400, clinical handoffs, emergency callouts) | Transfer mismatch: visual recognition (MCQ) does not transfer to uncued spoken retrieval | Morris, Bransford & Franks (1977) *Transfer-Appropriate Processing*; MacLeod et al. (2010) *Production Effect* |
| **M6** | `perceptual_pattern_classification` | DMV road signs, blueprint symbols, hazard recognition, clinical rhythms/labs | Slow verbal rule translation instead of fast, automatic visual feature extraction | Kellman & Garrigan (2009) *Perceptual Learning Modules (PLMs)*; Gibson (1969) |
| **M7** | `critical_step_checklist` | Practical skills, safety procedures, CNA clinical tasks, CDL pre-trip, food safety | Omission of high-consequence safety steps or sequence inversions under stress | Gawande (2009); Hales & Pronovost (2006) *Checklist Science*; Ericsson (2008) *Deliberate Practice* |

---

## 3. Deep-Dive: Scientific Delivery & Configuration Rules per Modality

### 3.1 Modality M1 — `orthographic_phonological` (Pre-Readers & Adult Literacy)
* **Why One-Size-Fits-All Fails**: Standard flashcards assume the user can read the prompt and schedule a 1–3 day gap after a single hit. Per **Ehri's Phase Theory (2005)** and **Share's Self-Teaching Hypothesis (1995)**, orthographic mapping requires **high-density phonological recoding trials** with immediate auditory-visual feedback before consolidating into sight-word memory.
* **App & Content Configuration Rules**:
  1. **Zero-Text-Assumption Chrome**: All instructions and stems auto-play via TTS/recorded phoneme audio with synchronized grapheme highlighting; visual UI uses high-contrast icons and $\ge 56\text{dp}$ touch targets (`LITERACY_ACCESSIBILITY_PLAN.md`).
  2. **Minimal-Pair Contrastive Foils**: Distractors are never random words; they are generated from **phonemic confusion matrices** (e.g., voicing pairs `/b/`–`/p/`, nasal `/m/`–`/n/`, short vowel shifts `cat`–`cut`–`cot`) so every wrong tap diagnoses the exact phoneme or grapheme confusion.
  3. **Strict Decodability Gate (95% Rule)**: Decodable stories and sentence items only unlock when $\ge 95\%$ of their constituent graphemes and sight words have reached FSRS `Familiar` state in the learner's profile (preventing guessing from pictures or context).
  4. **FSRS Cold-Start Priors**: Short initial stability ($S_0 = 0.2\text{ days}$, intraday review loop), high desired retention ($R_{\text{desired}} = 0.95$), and mandatory **3-modality verification** (`Hear -> Tap Grapheme`, `See Grapheme -> Speak/Blend`, `Trace/Build Word`) before graduating to multi-day intervals.

### 3.2 Modality M2 — `open_book_index_navigation` (Open-Book Reference & Code Exams)
* **Why One-Size-Fits-All Fails**: In open-book exams (e.g., Florida DBPR Certified Contractor with 9+ reference volumes, or NEC Electrical exams), candidates fail for two opposite reasons:
  1. They treat it like a closed-book exam and try to memorize thousands of tabular numbers (impossible cognitive load).
  2. They treat it as "I can look everything up on test day," spending 3–4 minutes hunting through the wrong book when the exam only allows 90–120 seconds per question.
* **Scientific Principle — Transactive Memory & Information Foraging (Sparrow et al., 2011; Pirolli & Card, 1999)**:
  - High performers on open-book exams do **not** memorize the payload of the tables; they memorize the **Index & Routing Ontology** (which volume owns the topic, the exact keyword taxonomy of the index, and the structure of the exceptions) and train **timed retrieval foraging**.
* **App & Content Configuration Rules**:
  1. **Mandatory Split-Memory Tagging (`memory_division`)**: Every concept and item in an open-book target is tagged at ingestion into one of two tracks:
     - **`internalize_cold` (~30% of blueprint)**: Core definitions, book-to-domain routing ("Which volume governs truss bracing vs. concrete formwork?"), high-frequency statutory deadlines (e.g., Florida Construction Lien Law 45-day Notice to Owner / 90-day Claim of Lien), and core math formulas. Practiced **closed-book** via FSRS.
     - **`lookup_fluency` (~70% of blueprint)**: Specific code tables, wind-load/span charts, safety tolerances, and multi-condition exceptions. Practiced via the **EXM R1–R4 Reference Drill Engine**.
  2. **4-Step Timed Foraging Decomposition (`EXM R1–R4`)**:
     - `R1 (Book Routing — Target <= 8s)`: Given a scenario stem, select the authoritative reference manual immediately.
     - `R2 (Anchor/Index Keyword Selection — Target <= 12s)`: Identify the exact index term or chapter/section path (training the learner out of using colloquial terms that aren't in the book's index).
     - `R3 (Table/Clause Extraction — Target <= 20s)`: Locate the exact section/table and extract the base value.
     - `R4 (Exception & Footnote Verification — Target <= 15s)`: Check footnotes/exceptions (where exam writers hide 60%+ of distractors).
  3. **Speed-Gated FSRS Rating**: For `lookup_fluency` items, accuracy alone is insufficient. If the learner answers correctly but exceeds the target lookup budget (e.g., $> 90\text{s}$), FSRS automatically caps the rating at `Hard (2)` rather than `Good (3)` or `Easy (4)`, keeping the item in high-frequency drill rotation until lookup speed drops below the exam pace threshold.

### 3.3 Modality M3 — `conceptual_schema_discrimination` (Vocabulary, Theory & Domain Rules)
* **Why One-Size-Fits-All Fails**: Standard flashcards test isolated pairs ($A \leftrightarrow B$). Research by **Rohrer & Taylor (2007)**, **Birnbaum et al. (2013)**, and **Kornell & Bjork (2008)** proves that blocked practice of isolated concepts creates high in-session accuracy (*retrieval fluency*) but poor exam transfer because learners never practice **discriminating between similar concepts** that share surface features.
* **App & Content Configuration Rules**:
  1. **Confusable-Cluster Tagging (`confusable_group_id`) & Mandatory Interleaving**:
     - During content ingestion, closely related or commonly confused concepts are linked under a `confusable_group_id` (e.g., *HMO vs. PPO vs. POS vs. EPO*; *RAID 0 vs. RAID 1 vs. RAID 5 vs. RAID 10*; *Negligence vs. Malpractice vs. Assault vs. Battery*).
     - The session builder **never** schedules two identical-stem items back-to-back, and intentionally interleaves contrasting members of a `confusable_group_id` within the same practice block.
  2. **3-Angle Concept Triangulation (Progressive Cognitive Ladder)**:
     - Every `knowledge_concept` in Modality M3 requires items across three distinct cognitive angles (`cognitive_angle`):
       - **Angle 1 — `core_definition` (Recall-First)**: Cloze / free-recall / term-to-concept mapping before MCQ recognition.
       - **Angle 2 — `contrastive_boundary` ("Why X and not Y?")**: Scenario or comparison question where the primary distractor is the concept's closest neighbor in `confusable_group_id`.
       - **Angle 3 — `novel_application` (Transfer)**: A realistic case/scenario where the concept name never appears in the stem, requiring the learner to diagnose the underlying principle and apply it.
     - **Readiness Gate**: A concept's mastery score is capped at `0.65 (Developing)` until the learner succeeds on at least one `contrastive_boundary` or `novel_application` item.
  3. **Confidence-Weighted Hypercorrection (Butterfield & Metcalfe, 2001)**:
     - Learners tap a fast 3-level confidence selector (`Guess`, `Think So`, `Certain`) on diagnostic and review items.
     - High-confidence errors (`Certain` + Incorrect) trigger the **Hypercorrection Protocol**: an expanded misconception-specific rationale explaining *why* that distractor felt right, paired with an immediate intraday relearning step.

### 3.4 Modality M4 — `procedural_calculation_fading` (Math, Estimating, Dosage & Formulas)
* **Why One-Size-Fits-All Fails**: Per **Sweller & Cooper (1985)** and **Renkl, Atkinson & Große (2004)**, throwing a learner into a full multi-step calculation problem when their schema is weak consumes all working memory on search rather than schema acquisition. Conversely, showing full worked examples to an advanced learner triggers the **Expertise Reversal Effect** (Kalyuga et al., 2003).
* **App & Content Configuration Rules**:
  1. **4-Stage Backward Fading Ladder (`fading_stage: 0..3`)**:
     - Every calculation/procedural template in the manifest contains structured `solution_steps[]`:
       - **Stage 0 (`worked_example_inspect`)**: Shows the full step-by-step setup and asks a single conceptual self-explanation question (*"Why did we divide by 27 in Step 2?"*).
       - **Stage 1 (`fade_final_step`)**: Shows Steps 1..$k-1$ completed; learner performs the final computation and selects the unit.
       - **Stage 2 (`fade_setup_and_solve`)**: Shows only the governing formula/principle; learner plugs in the values from the scenario and solves.
       - **Stage 3 (`unassisted_parameterized`)**: Full exam-condition problem with no scaffolding, **randomized numeric parameters** (so the learner cannot memorize "the answer is 42"), numeric input (`numeric_entry`), and unit-trap verification (e.g., feet vs. cubic yards, mg vs. mL).
  2. **Automatic Stage Promotion/Demotion**:
     - If a learner fails a Stage 3 calculation item, the intraday relearning queue automatically drops them down to **Stage 1 or Stage 2** on a sibling problem to rebuild the broken step, then re-tests Stage 3 before advancing FSRS stability.

### 3.5 Modality M5 — `oral_production_fluency` (USCIS Civics, N-400 & Spoken Assessments)
* **Why One-Size-Fits-All Fails**: **Transfer-Appropriate Processing (Morris et al., 1977)** demonstrates that memory retrieval is highly dependent on matching the encoding/practice cue to the test cue. Practicing an oral interview via silent visual multiple-choice trains visual recognition, leaving acoustic parsing and spoken motor production untrained.
* **App & Content Configuration Rules**:
  1. **Acoustic-First Prompting**: The stem is delivered via spoken TTS/audio first (`spokenQuestion`), with text blurred or hidden unless the learner taps *"Show text hint"* (which caps the FSRS rating at `Hard`).
  2. **3-Step Cue Fading**:
     - `Level 1`: Audio prompt + 4 shuffled options (initial encoding only).
     - `Level 2`: Audio prompt + first-word / cloze scaffold.
     - `Level 3 (Exam Standard)`: Audio prompt + **Spoken STT / Self-Graded Oral Recall** matched against the official `acceptableAnswers[]` synonym set within a $\le 5\text{s}$ speech-onset window.

### 3.6 Modality M6 — `perceptual_pattern_classification` (Visual Signs, Diagrams & Symbols)
* **Scientific Basis**: **Perceptual Learning Modules (Kellman & Garrigan, 2009)** show that rapid, high-volume classification of visual stimuli builds automatic feature extraction in visual cortex pathways that verbal rules cannot replicate.
* **App & Content Configuration Rules**:
  - Short-latency visual classification bursts (target response $< 3.5\text{s}$), grouping visually confusable signs/diagrams together with immediate visual overlay feedback.

### 3.7 Modality M7 — `critical_step_checklist` (Practical Trade, Clinical & Safety Protocols)
* **Scientific Basis**: High-reliability checklist engineering (Pronovost; Ericsson, 2008).
* **App & Content Configuration Rules**:
  - Multi-step sequence ordering and scenario verification where steps flagged `is_critical_safety_step: true` act as a **hard binary gate**: missing a critical step scores `0` for the trial regardless of partial credit on minor steps, immediately routing the learner to a critical-fail remediation drill.

---

## 4. Solving "Zero User Data at Launch": Cold-Start Psychometric Priors ($N=0$)

Until an item accumulates $N \ge 30$ real learner attempts (`Tier 4: calibrated`), the platform cannot rely on empirical pass/fail ratios. Instead, we compute **Research-Verified Cold-Start Priors** at the moment content is imported or generated, using established findings from psychometric item-difficulty modeling (Freedle & Kostin, 1993; Bejar, 1993; Haladyna, Downing & Rodriguez, 2002; FSRS-5/6 population parameters).

### 4.1 Deterministic Cold-Start Difficulty Estimator ($b_0$ and $D_0$)
Every item ingested into LearningApp receives an initial IRT difficulty prior $b_0 \in [-2.5, +2.5]$ (logit scale) and FSRS initial difficulty $D_0 \in [1.0, 10.0]$ computed from six objective item features:

$$b_0 = \beta_{\text{bloom}} + \beta_{\text{steps}} + \beta_{\text{foil}} + \beta_{\text{lexical}} + \beta_{\text{format}} + \beta_{\text{exception}}$$

1. **Cognitive Level ($\beta_{\text{bloom}}$)**:
   - Verbatim Recall / Identification: `-0.80`
   - Concept Comprehension / Classification: `-0.20`
   - Scenario Application / Lookup (`R3`): `+0.40`
   - Multi-Variable Analysis / Exception Synthesis (`R4`): `+0.95`
2. **Inferential / Calculation Step Count ($\beta_{\text{steps}}$)**:
   - $+0.30 \times \max(0, \text{step\_count} - 1)$ (capped at $+1.20$).
3. **Distractor Similarity / Confusable Density ($\beta_{\text{foil}}$)**:
   - $+0.45$ if distractors belong to the same `confusable_group_id` or share $>60\%$ semantic/lexical overlap; $0.0$ otherwise.
4. **Linguistic & Reading Load ($\beta_{\text{lexical}}$)**:
   - $+0.25$ if stem + options exceed 75 words or Flesch-Kincaid grade exceeds target baseline by $\ge 2$ grades.
5. **Response Format Demand ($\beta_{\text{format}}$)**:
   - 4-option MCQ: `0.00`
   - Multi-select (`select all that apply`) / Matrix: `+0.50`
   - Cloze / Oral Free Recall / Unassisted Numeric Entry: `+0.65`
6. **Statutory Exception / Negation Clause ($\beta_{\text{exception}}$)**:
   - $+0.35$ if the item tests a code footnote/exception or regulatory conditional override.

From $b_0$, the initial FSRS parameters at $N=0$ are seeded as:
- **Initial FSRS Difficulty**: $D_0 = \text{clamp}(5.5 + 1.5 \cdot b_0,\; 1.0,\; 10.0)$
- **Initial FSRS Stability Multiplier**: Modality-specific baseline $S_0(M) \times \exp(-0.25 \cdot b_0)$

### 4.2 Empirical Bayes Shrinkage (Seamless Transition from $N=0 \to N=30+$)
As real learners answer the item in `learning_events`, we never suffer a jarring jump between "prior" and "data." On every attempt $N$, effective difficulty $b_{\text{eff}}$ is updated via **Empirical Bayes Shrinkage** with pseudo-count weight $N_0 = 15$:

$$b_{\text{eff}}(N) = \frac{N_0 \cdot b_0 + N \cdot \hat{b}_{\text{Elo}}(N)}{N_0 + N}$$

- **At $N = 0$ (Day 1 Launch / Newly Imported Content)**: $100\%$ driven by the research-verified structural prior $b_0$.
- **At $N = 15$**: $50\%$ research prior + $50\%$ empirical learner performance.
- **At $N \ge 45$**: $\ge 75\%$ empirical learner data (promoting the item to `Tier 4: calibrated`).

---

## 5. Dedicated Research & Optimization Folder (`/docs/learning_science/`)

To make this research permanent, auditable, and directly wired into both the codebase and AI content-generation prompts, we establish `/docs/learning_science/` with the following structure:

```text
/docs/learning_science/
├── README.md                                      # Master index, architecture link, and citation standards
├── 01_MODALITY_TAXONOMY_AND_DELIVERY_RULES.md     # Full scientific rules & UI/FSRS configs for Modalities M1–M7
├── 02_COLD_START_PSYCHOMETRICS_AND_FSRS_PRIORS.md # Mathematical specification of b_0, D_0, S_0, and Empirical Bayes shrinkage
├── 03_CONTENT_INGESTION_AND_MANIFEST_SCHEMA.md    # How existing & future imported content (YouTube, PDF, AI, Anki) is tagged
├── 04_CONTRASTIVE_INTERLEAVING_AND_TRIANGULATION.md # Confusable concept clusters, 3-angle mastery, and hypercorrection rules
└── 05_EXAM_READINESS_AND_PASS_PREDICTION_MATH.md  # Combining FSRS R(t_exam), blueprint weights, and speed gates into Pass Proof
```

---

## 6. How Existing & Future Imported Content Will Be Organized Around This

### 6.1 Extending `content/schema/curriculum_manifest.schema.json`
Every manifest—whether official seed content (`bs_computer_science.yaml`, `security_plus_sy0_701.yaml`, Florida DBPR/Insurance, USCIS/Literacy) or dynamically imported from YouTube/PDF/Anki/BYOK AI—will include these standardized learning-science fields:

1. **On `knowledge_concepts[]`**:
   - `primary_modality`: enum (`orthographic_phonological`, `open_book_index_navigation`, `conceptual_schema_discrimination`, `procedural_calculation_fading`, `oral_production_fluency`, `perceptual_pattern_classification`, `critical_step_checklist`)
   - `confusable_group_id`: optional string grouping frequently confused concepts for mandatory contrastive interleaving
   - `memory_division`: `internalize_cold` | `lookup_fluency` | `hybrid` (critical for open-book exams)
   - `required_angles`: array of cognitive angles required before concept mastery can exceed `0.65` (e.g., `["core_definition", "contrastive_boundary", "novel_application"]`)

2. **On `assessment_items[]` and `flashcards[]`**:
   - `modality`: inherits from concept or overrides per item
   - `cognitive_angle`: `core_definition` | `contrastive_boundary` | `novel_application` | `lookup_routing` | `lookup_extraction` | `faded_step` | `oral_recall`
   - `fading_stage`: integer `0..3` (for procedural/calculation items)
   - `target_latency_ms`: modality-specific time budget (e.g., `45000` for open-book table lookup, `4000` for perceptual sign recognition, `60000` for standard MCQ)
   - `cold_start_features`: `{ bloom_level, step_count, has_exception_clause, distractor_similarity_tier, reading_grade }` → automatically computes `b_0` and `D_0` on ingestion!
   - `options[]`: upgraded from positional strings to `{ id, text, is_correct, rationale, misconception_tag, confusable_concept_slug }`

### 6.2 Retrofitting Existing Content in the Repo
As part of executing this plan, we reorganize our existing repository content into this framework immediately:
1. **Literacy & Pre-Reader Catalog (`cvc_word_item.dart`, `phonics_item.dart`, `decodable_story_item.dart`, `survival_word_item.dart`)** → Migrated to **Modality M1 (`orthographic_phonological`)** with phoneme-confusion foil tags and the 95% decodability gate.
2. **Florida Contractor & Regulator Pathways (`data/catalog/florida_contractors_p2g_*`, `EXM-01..03`)** → Configured as **Modality M2 (`open_book_index_navigation`)** with explicit `internalize_cold` vs. `lookup_fluency` splits and latency-gated FSRS scoring.
3. **Security+, CS Degree & Florida Insurance (`content/*.yaml`, `assets/lessons/*.json`)** → Upgraded to **Modality M3 (`conceptual_schema_discrimination`)** with `confusable_group_id` clusters and 3-angle concept triangulation.
4. **Currency Survival, GED Math & Engineering/Estimating Items (`currency_survival_item.dart`, `ged_bridge_item.dart`)** → Configured as **Modality M4 (`procedural_calculation_fading`)** with 4-stage backward-faded solution steps.
5. **USCIS 128 Civics & N-400 (`uscis_civics_item.dart`)** → Configured as **Modality M5 (`oral_production_fluency`)** with acoustic-first delivery and 3-step cue fading.
6. **DMV Road Signs & Workplace/Food/Health Safety (`dmv_exam_item.dart`, `food_safety_item.dart`, `workplace_safety_item.dart`, `health_safety_item.dart`)** → Split cleanly between **Modality M6 (`perceptual_pattern_classification`)** for visual signs/hazards and **Modality M7 (`critical_step_checklist`)** for safety procedures.

---

## 7. Phased Implementation Plan (Coordinated with Antigravity)

While Antigravity upgrades platform infrastructure, security fixes, and general quality, this Learning Science & Cold-Start Optimization track executes in **4 cleanly bounded workstreams**:

### Workstream LS-1 — Research Repository & Cold-Start Psychometric Spec (`/docs/learning_science/`)
- Complete all 5 specification documents inside `/docs/learning_science/`.
- Implement the pure-Dart `ColdStartPsychometricEstimator` (`lib/services/learning_science/cold_start_estimator.dart`) that computes $b_0$, $D_0$, $S_0$, and `target_latency_ms` deterministically for any item at $N=0$ and blends with empirical Elo ratings via Empirical Bayes shrinkage.

### Workstream LS-2 — Manifest Schema & Content Classifier Upgrade
- Extend `content/schema/curriculum_manifest.schema.json` and `ContentQualityValidator` to require and validate `primary_modality`, `cognitive_angle`, `confusable_group_id`, `memory_division`, and per-option `misconception_tag`.
- Update the AI Generation & Universal Import prompts (`.github/prompts/generate-lesson.prompt.md` and `AiPromptService`) so **every newly imported or AI-generated lesson automatically produces modality-specific item sets** (e.g., generating a 3-angle triangulation set + confusable pairs for concepts, or a 4-stage faded worked example for calculations).

### Workstream LS-3 — Modality-Adaptive Session Builder & FSRS Scheduler
- Upgrade `SpacedRepetitionService` and `NextActionEngine` to use modality-aware scheduling rules:
  - Contrastive interleaving of `confusable_group_id` siblings in Modality M3.
  - Latency-adjusted FSRS grading in Modality M2 (penalizing slow open-book lookups even when accurate).
  - Automatic backward-fading step-down (`Stage 3 -> Stage 1/2`) on calculation errors in Modality M4.
  - 3-angle triangulation cap (`max 0.65 mastery` until application/contrastive angles pass).

### Workstream LS-4 — Retrofitting Bundled Curricula & Simulators
- Tag and upgrade the bundled curricula (`content/*.yaml`, `assets/lessons/*.json`, and the Literacy/Civic simulators) into the 7-modality schema, fixing the Option-A bias (`FIX-1`) and validating cold-start readiness calculations end-to-end with unit tests.
