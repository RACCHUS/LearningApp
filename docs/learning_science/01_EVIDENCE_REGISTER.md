# 01 — Evidence Register & Peer-Reviewed Research Baseline

This register records the primary scientific literature governing LearningApp's instructional strategies, task profiles, and measurement rules. In accordance with [`README.md`](README.md), every entry explicitly documents its **evidence grade**, **population and sample size**, **effect size and uncertainty** (where established), **moderators and negative/mixed findings**, and **whether a resulting design rule is directly evidenced or an implementation hypothesis to test**.

---

## Evidence Grade & Claim Status Scale
- **Grade A (Strong Meta-Analytic / Replicated Experimental Consensus)**: Multiple meta-analyses or large-scale experiments with well-characterized boundary conditions.
- **Grade B (Domain-Specific Experimental / Systematic Review Evidence)**: Peer-reviewed evidence within a specific population or task domain; requires verification when generalizing to new adult cohorts.
- **Grade C (Indirect Theoretical Mechanism / Mixed Evidence)**: Supports a plausible mechanism or partial rationale, but direct transfer to the target assessment format is unverified.
- **Claim Status**:
  - `Direct Empirical Support`: The cited study directly measures the target intervention and outcome.
  - `Implementation Hypothesis`: An engineering or instructional design hypothesis motivated by related cognitive principles; requires internal empirical validation before being claimed as proven.

---

## 1. Retrieval Practice, Spacing, Interleaving & Prequestioning

### ER-01: Context-Dependent Retrieval, Spacing & Interleaving (2026 Meta-Analysis)
- **Citation**: Ruitenburg, S. K., et al. (2026, published October 29, 2026). Meta-analysis of retrieval practice, distributed practice, and interleaved practice in educational settings. *Educational Psychology Review* (Springer Nature).
- **Evidence Grade**: **Grade A** (`Direct Empirical Support` for strategy effectiveness & moderators; `Implementation Hypothesis` when extrapolating from K–12 to adult licensing).
- **Methodology**: Meta-analysis of 53 classroom studies.
- **Population & Sample Size**: $k = 53$ studies, $N = 7,303$ learners (primary and secondary education classroom populations).
- **Measured Outcome & Effect Sizes**:
  - Retrieval practice: $g = 0.37$
  - Distributed (spaced) practice: $g = 0.20$
  - Interleaved practice: $g = 0.40$
- **Limitations & Moderators**:
  1. **Moderator finding**: Effectiveness varies significantly by **knowledge type**, **assessment format**, and **feedback presence**—confirming that a single uniform study method should not be forced across all concepts.
  2. **Population qualification**: Conducted in primary and secondary education; must **not** be presented as direct validation of adult vocational or professional licensing pass rates.
- **Applicability**: `InstructionalPolicy` strategy selection across `LearningTaskProfile`.
- **Recommended Implementation**: Select retrieval, spacing, and interleaving dynamically based on `knowledge_facet`, `cognitive_operation`, and `feedback_policy` rather than applying a rigid one-size-fits-all template.
- **Test Plan**: Evaluate delayed retention and transfer across task profiles in adult cohorts (`07_READINESS_AND_VALIDATION.md`).

### ER-02: Distributed Practice & Retention Lag Scaling
- **Citation**: Cepeda, N. J., Pashler, H., Vul, E., Wixted, J. T., & Rohrer, D. (2006). Distributed practice in verbal recall tasks: A review and quantitative synthesis. *Psychological Bulletin*, 132(3), 354–380. `https://doi.org/10.1037/0033-2909.132.3.354`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support`).
- **Methodology**: Meta-analysis of 184 articles (317 experiments, 839 assessments).
- **Population & Sample Size**: Primarily adult and undergraduate cohorts ($N > 14,000$).
- **Measured Outcome & Effect Size**: Spaced practice outperformed massed practice in 259 of 271 comparisons; optimal inter-study interval varies as a function of the target retention interval.
- **Limitations & Moderators**: Focused primarily on verbal recall; if an item is not yet encoded or is forgotten, short-lag intraday relearning is needed before expanding multi-day intervals.
- **Applicability**: Long-term retention scheduling (`review_items`).
- **Recommended Implementation**: Separate intraday acquisition/relearning from multi-day retention scheduling.
- **Test Plan**: Compare delayed recall retention rates under versioned FSRS-6 scheduling vs. fixed interval ladder.

### ER-03: Repeated Testing & Transfer to Novel Application Questions
- **Citation**: Butler, A. C. (2010). Repeated testing produces superior transfer of learning relative to repeated studying. *Journal of Experimental Psychology: Learning, Memory, and Cognition*, 36(5), 1118–1133. `https://doi.org/10.1037/a0019902`
- **Evidence Grade**: **Grade B** (`Direct Empirical Support`).
- **Methodology**: 4 controlled behavioral experiments (Experiments 1a, 1b, 2, and 3).
- **Population & Sample Size**: Undergraduate adult learners ($N = 140$ total across the 4 experiments: Exp. 1a $n = 28$, Exp. 1b $n = 28$, Exp. 2 $n = 44$, Exp. 3 $n = 40$).
- **Measured Outcome & Verified Findings**: Delayed test 1 week after study measuring retention and **far transfer** to new inferential and application questions across different knowledge domains. Across all four experiments, repeated testing with explanatory feedback produced significantly higher proportion correct on novel transfer questions than repeated restudying *(note: exact sub-experiment proportions and inferential statistics are reported per experiment in Butler, 2010 Tables 1–3; no single pooled Cohen's $d$ is claimed in the abstract)*.
- **Limitations & Moderators**: Transfer advantage depends on providing explanatory feedback that highlights the underlying conceptual rule rather than bare correct/incorrect grading.
- **Applicability**: `conceptual_relational` and `apply_to_scenario` tasks (`InstructionalPolicy.feedback_policy = immediate_explanatory`).
- **Recommended Implementation**: Deliver principle-based rationales after practice attempts and measure concept transfer using held-out scenario items.
- **Test Plan**: Measure first-attempt accuracy on held-out `apply_to_scenario` items following explanation-backed retrieval practice.

### ER-04: Utility & Boundary Conditions of 10 Learning Techniques
- **Citation**: Dunlosky, J., Rawson, K. A., Marsh, E. J., Nathan, M. J., & Willingham, D. T. (2013). Improving students' learning with effective learning techniques: Promising directions from cognitive and educational psychology. *Psychological Science in the Public Interest*, 14(1), 4–58. `https://doi.org/10.1177/1529100612453266`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support`).
- **Methodology**: Qualitative and quantitative synthesis across 10 instructional techniques.
- **Measured Outcome & Findings**: High utility ratings for *Practice Testing* and *Distributed Practice*; Moderate utility ratings for *Interleaved Practice*, *Elaborative Interrogation*, and *Self-Explanation*; Low utility for passive rereading.
- **Limitations & Moderators**: Interleaving shows strong positive effects for discriminating confusable categories and mathematical problem types, but weak or null effects for unrelated vocabulary lists.
- **Applicability**: Strategy eligibility rules in `03_INSTRUCTIONAL_STRATEGIES.md`.
- **Recommended Implementation**: Restrict `contrastive_interleaving` to items linked by a `confusable_group_id` or shared problem-type discrimination family.
- **Test Plan**: Verify session builder activates contrastive interleaving only when `confusable_density != none`.

### ER-10: Diagnostic Prequestioning & Item-Specific vs. General Transfer (2023 Meta-Analysis)
- **Citation**: Meta-analysis on the prequestion effect in educational learning (2023).
- **Evidence Grade**: **Grade A** (`Direct Empirical Support`).
- **Methodology**: Meta-analytic synthesis separating prequestioned material from non-prequestioned material within the same lesson.
- **Measured Outcome & Effect Sizes**:
  - **Specific prequestion effect** (performance on the exact concepts/items pretested): $g = 0.54$
  - **General transfer effect** (performance on untested content in the subsequent lesson): $g = 0.04$ (near zero / null effect)
- **Limitations & Moderators**: Pretesting reliably improves learning of the targeted objectives and diagnoses prior knowledge, but **does not** automatically boost comprehension of unrelated, un-pretested material in a module.
- **Applicability**: Diagnostic pretesting and adaptive scaffolding routing (`05_LEARNER_ADAPTATION.md`).
- **Recommended Implementation**: Use diagnostic pretests to (a) detect prior competence so experienced learners can skip redundant scaffolding (`ER-05`) and (b) preview the specific core objectives of the module—never market pretests as a universal memory booster for untested content.
- **Test Plan**: Verify diagnostic pretests map 1-to-1 to the module's target `knowledge_concepts`.

---

## 2. Worked Examples, Fading & Prior-Knowledge Adaptation

### ER-05: Expertise Reversal & Adaptive Instructional Assistance (2025 Meta-Analysis + Kalyuga et al., 2003)
- **Citations**:
  1. Meta-analysis on instructional assistance and the expertise reversal effect across learner prior-knowledge levels (2025, *ScienceDirect / Educational Research Review*): $k = 60$ studies, $N = 5,924$ participants.
  2. Kalyuga, S., Ayres, P., Chandler, P., & Sweller, J. (2003). The expertise reversal effect. *Educational Psychologist*, 38(1), 23–31. `https://doi.org/10.1207/S15326985EP3801_4`
  3. Renkl, A., Atkinson, R. K., & Große, C. S. (2004). How fading worked solution steps works—A cognitive load perspective. *Instructional Science*, 32(1–2), 59–82. `https://doi.org/10.1023/B:TRUC.0000021815.74806.f6`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support` for adaptive scaffolding; any specific transition threshold such as "2 correct answers" is an `Implementation Hypothesis`).
- **Population & Sample Size**: 60 experimental studies, $N = 5,924$ learners across low and high prior-knowledge cohorts (plus Renkl et al., 2004 Experiments 1 and 2 on backward step fading).
- **Measured Outcome & Verified Effect Sizes**:
  - **Low prior knowledge (novices)**: High instructional assistance (worked examples, step guidance) significantly benefits learning (**$d = 0.505$**).
  - **High prior knowledge (experienced learners)**: High assistance significantly impairs learning relative to low assistance / unguided problem solving (**$d = -0.428$**), with **substantial between-study heterogeneity**.
- **Limitations & Moderators**: Substantial heterogeneity across domains means no single fixed step count (e.g., "always 4 fading stages" or "always 2 correct responses") is universally optimal.
- **Applicability**: `procedural_quantitative` tasks and `InstructionalPolicy.scaffolding_policy`.
- **Recommended Implementation**: Make worked examples and backward fading adaptive to diagnostic/prior performance rather than enforcing a fixed 4-stage sequence; treat specific promotion/demotion thresholds as tunable parameters (`Implementation Hypothesis`) evaluated during Phase 6/7.
- **Test Plan**: Compare completion time and transfer accuracy between fixed-stage fading and diagnostic-gated adaptive fading.

---

## 3. Adult Literacy & Phonological-Orthographic Learning

### ER-06: Adult Reading Interventions (2026 Systematic Review) & Orthographic Mapping Theory
- **Citations**:
  1. Systematic review of adult reading and literacy interventions (2026, *Wiley Online Library*): $k = 15$ peer-reviewed studies of adult learners aged 16–76.
  2. Ehri, L. C. (2005). Learning to read words: Theory, findings, and issues. *Scientific Studies of Reading*, 9(2), 167–188. `https://doi.org/10.1207/s1532799xssr0902_4`
  3. Castles, A., Rastle, K., & Nation, K. (2018). Ending the reading wars: Reading acquisition from novice to expert. *Psychological Science in the Public Interest*, 19(1), 5–51. `https://doi.org/10.1177/1529100618772271`
- **Evidence Grade**: **Grade B** (`Direct Empirical Support` for decoding improvements in adults; **mixed/limited evidence** for broader adult reading components).
- **Population & Sample Size**:
  - Adult systematic review (2026): **15 peer-reviewed studies**, adult participants **aged 16–76** (adult basic education, emergent readers, and correctional/workforce literacy programs).
- **Measured Outcome & Findings (Including Mixed Findings)**:
  - **Consistent positive finding**: Explicit phonological/decoding instruction yields relatively consistent improvements in **word decoding accuracy** among adults.
  - **Mixed / limited finding**: Evidence across broader reading components (oral reading fluency, general vocabulary growth, and passage comprehension) is **mixed and more limited** in adult populations compared to children's literacy literature.
  - **No basis for 95% gate**: Neither adult nor child literature establishes a universal 95% known-grapheme progression lock for adult learners.
- **Applicability**: `sublexical_orthographic` tasks and `LITERACY_ACCESSIBILITY_PLAN.md`.
- **Recommended Implementation**:
  1. Keep literacy stages as **recommendations, never progression locks** (preserving `LITERACY_ACCESSIBILITY_PLAN.md`).
  2. Validate adult decoding, sight/survival word recognition, and passage comprehension as separate outcomes rather than assuming child reading milestones automatically transfer to adults.
- **Test Plan**: Track adult literacy sub-outcomes (decoding accuracy vs. functional comprehension) separately in Phase 6 validation.

---

## 4. Open-Book Examinations & Reference Navigation

### ER-07: Open-Book vs. Closed-Book Examinations & Reference Foraging
- **Citations**:
  1. Durning, S. J., Dong, T., Ratcliffe, T., Schuwirth, L., Artino, A. R., Boulet, J. R., & Eva, K. (2016). Comparing open-book and closed-book examinations: A systematic review. *Academic Medicine*, 91(4), 583–599. `https://doi.org/10.1097/ACM.0000000000000977` (PubMed PMID: `26826066`)
  2. Pirolli, P., & Card, S. (1999). Information foraging. *Psychological Review*, 106(4), 643–675. `https://doi.org/10.1037/0033-295X.106.4.643`
- **Evidence Grade**: **Grade B** (`Direct Empirical Support` for longer open-book completion times and equivocal preparation outcomes; under-preparation/timeout causation is an `Implementation Hypothesis`).
- **Methodology & Sample**: Systematic review of **37 peer-reviewed studies** comparing open-book examinations (OBEs) and closed-book examinations (CBEs) in professional/medical/higher education.
- **Verified Findings vs. Hypotheses**:
  - **Established by Durning et al. (2016)**:
    1. Preparation behavior findings across studies were **equivocal** (did not consistently favor CBEs or OBEs).
    2. Examinees took **significantly longer to complete open-book examinations** than closed-book examinations.
    3. Performance comparisons often favored closed-book exams, particularly in settings where examinees prepared more extensively for closed-book testing.
  - **Explicitly Labeled as an `Implementation Hypothesis` (Not Claimed by Durning et al.)**:
    - The hypothesis that licensing candidates fail open-book trade exams because slow reference-book navigation exhausts the exam clock is an **engineering & instructional hypothesis** that motivates `EXM-01..03` reference navigation training and must be tested empirically in the Florida Certified Contractor pilot (`Pilot A`).
- **Applicability**: `reference_navigation` tasks and `EXM_00`.
- **Recommended Implementation**: Measure the 6 open-book competencies independently (`04_TASK_SPECIFIC_DELIVERY.md`) without hard-coding an arbitrary 30/70 memorization-to-lookup ratio.
- **Test Plan**: Measure item lookup time and accuracy across `EXM R1–R4` drills and correlate with timed mock exam completion rates in `Pilot A`.

---

## 5. Transfer-Appropriate Processing, Production Effect & Oral Assessment

### ER-08: Transfer-Appropriate Processing, Production Effect & Spoken Exam Answers
- **Citations**:
  1. Morris, C. D., Bransford, J. D., & Franks, J. J. (1977). Levels of processing versus transfer appropriate processing. *Journal of Verbal Learning and Verbal Behavior*, 16(5), 519–533. `https://doi.org/10.1016/S0022-5371(77)80016-9`
  2. MacLeod, C. M., Gopie, N., Hourihan, K. L., Neary, K. R., & Ozubko, J. D. (2010). The production effect: Delineation of a phenomenon. *Journal of Experimental Psychology: Learning, Memory, and Cognition*, 36(3), 671–685. `https://doi.org/10.1037/a0018785`
- **Evidence Grade**: **Grade C for Oral Free-Recall Exams** (`Direct Empirical Support` for recognition memory mechanisms; `Implementation Hypothesis` for spoken free-recall exam preparation).
- **Methodology & Boundaries**:
  1. **Transfer-Appropriate Processing (Morris et al., 1977)**: Demonstrates via recognition experiments that memory performance depends on the match between encoding operations (semantic vs. rhyme) and test cues.
  2. **The Production Effect (MacLeod et al., 2010)**: Demonstrates across **8 recognition experiments** that reading words aloud during study improves subsequent **recognition** relative to reading silently.
  3. **Spoken Free-Recall Production for Oral Exams (e.g., USCIS Civics Interview)**: Neither Morris (1977) nor MacLeod (2010) directly tests spoken free-recall answer generation for oral civic/licensing exams. Practicing spoken/free-recall responses for oral exams is therefore categorized as an **`Implementation Hypothesis` (`experimental` maturity)** grounded in assessment-format alignment.
- **Applicability**: `spoken_production` tasks (`04_TASK_SPECIFIC_DELIVERY.md`).
- **Recommended Implementation**: Offer spoken/free-recall practice where the target exam is oral; never enforce speech-onset latency as a mastery gate; evaluate effectiveness empirically against standard study.
- **Test Plan**: Compare uncued oral recall accuracy after spoken free-recall practice vs. multiple-choice practice on held-out USCIS civics questions.

---

## 6. Psychometric Calibration, Elo & FSRS-6 Memory Modeling

### ER-09: Small-Sample IRT Calibration, Online Elo Ratings & FSRS-6
- **Citations**:
  1. Bayesian hierarchical 2PL IRT small-sample calibration research (e.g., PMC / educational measurement simulation studies demonstrating accurate parameter recovery at $N = 100$ under informative hierarchical priors vs. larger samples required for unregularized MLE/MML 2PL).
  2. Pelánek, R. (2016). Applications of the Elo rating system in adaptive educational systems. *Computers & Education*, 98, 169–179. `https://doi.org/10.1016/j.compedu.2016.03.017`
  3. `package:fsrs` v2.0.1 (Dart implementation of **FSRS-6**, verified in package changelog v2.0.0+).
- **Evidence Grade**: **Grade A/B** (`Direct Empirical Support` for distinct mathematical properties of IRT, Elo, and FSRS-6).
- **Boundaries & Non-Equivalence Rules**:
  1. **No Universal Sample-Size Cutoff for IRT**: Required sample size for 2PL calibration depends on model structure, prior specification, and score distribution (hierarchical Bayesian models can calibrate under specific conditions at $N \approx 100$, whereas standard unregularized 2PL often requires $N \ge 200\text{--}500+$). Calibration promotion must be based on **parameter standard error ($\text{SE}$) and model convergence**, not a single arbitrary $N$ rule alone.
  2. **Elo $\ne$ IRT**: Online Elo updates provide useful heuristic relative ratings for adaptive item selection in small samples, but an Elo rating is **not** a calibrated IRT parameter ($a_i, b_i$).
  3. **FSRS-6 Retrievability $\ne$ Concept Mastery $\ne$ Exam Readiness**: FSRS-6 models individual card memory (`stability` $S$, `difficulty` $D$, `retrievability` $R(t)$). It does not by itself measure multi-facet concept mastery or examination readiness (`06_MEASUREMENT_AND_SCHEDULING.md`).
