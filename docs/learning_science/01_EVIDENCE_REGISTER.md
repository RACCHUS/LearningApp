# 01 — Evidence Register & Peer-Reviewed Research Baseline

This register records the primary scientific literature governing LearningApp's instructional strategies, task profiles, and measurement rules. In accordance with [`README.md`](README.md), every entry documents its **exact bibliographic citation and DOI/source**, **evidence grade**, **population and sample size**, **effect sizes with 95% confidence intervals and heterogeneity** (where reported), **study-specific limitations and negative/mixed findings**, and **whether a resulting design rule has direct empirical support or is an implementation hypothesis to test**.

---

## Evidence Grade & Claim Status Scale
- **Grade A (Strong Meta-Analytic / Replicated Experimental Consensus)**: Multiple meta-analyses or large-scale experiments with well-characterized confidence intervals and moderators.
- **Grade B (Domain-Specific Experimental / Systematic Review Evidence)**: Peer-reviewed evidence or formal research synthesis within a specific population or task domain; requires verification when generalizing to new adult cohorts.
- **Grade C (Indirect Theoretical Mechanism / Simulation / Mixed Evidence)**: Supports a partial mechanism or simulation condition, but direct transfer to the target learning or assessment context is unverified.
- **Claim Status**:
  - `Direct Empirical Support`: The cited study directly measures the target intervention and outcome in a comparable task.
  - `Implementation Hypothesis`: An engineering or instructional design rule motivated by related cognitive findings that requires empirical validation inside LearningApp before being claimed as proven.

---

## 1. Retrieval Practice, Spacing, Interleaving & Prequestioning

### ER-01: Retrieval Practice, Distributed Practice & Interleaved Practice in Classrooms (2026 Meta-Analysis)
- **Citation**: Ruitenburg, S. K., et al. (2026, published October 29, 2026). A Meta-Analysis of the Effectiveness and Boundary Conditions of Retrieval Practice, Distributed Practice, and Interleaved Practice in Authentic School Classrooms. *Educational Psychology Review* (Springer Nature). `https://doi.org/10.1007/s10648-026-10225-5`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support` for strategy effectiveness & moderator sensitivity; `Implementation Hypothesis` when extrapolating from K–12 classroom cohorts to adult vocational/licensing learners).
- **Methodology**: Meta-analysis of 53 classroom studies.
- **Population & Sample Size**: Overall synthesis covers $k = 53$ studies and $N = 7,303$ learners in primary and secondary school classrooms *(note: the specific number of studies $k$ and participants $n$ contributing to each strategy subgroup differs across retrieval, spacing, and interleaving)*.
- **Measured Outcome & Effect Sizes (with 95% CIs)**:
  - **Retrieval practice**: $g = .37$, **95% CI $[.18, .56]$**
  - **Distributed (spaced) practice**: $g = .20$, **95% CI $[.03, .36]$**
  - **Interleaved practice**: $g = .40$, **95% CI $[.10, .71]$**
- **Limitations & Moderators**:
  1. **Moderator sensitivity**: Effects are moderated by **knowledge type**, **assessment format**, and **feedback**, supporting task-profile-dependent strategy selection over a rigid one-size-fits-all loop.
  2. **Population boundary**: Because the synthesized studies come from primary and secondary school classrooms, this meta-analysis must **not** be cited as direct empirical proof of adult licensing or vocational exam pass rates.
- **Applicability**: `InstructionalPolicy.eligible_strategies[]` selection rules (`03_INSTRUCTIONAL_STRATEGIES.md`).
- **Recommended Implementation**: Configure retrieval, spacing, and interleaving dynamically according to `LearningTaskProfile` and `InstructionalPolicy`.
- **Test Plan**: Evaluate delayed retention and held-out transfer across adult cohorts in Phase 6/7 (`07_READINESS_AND_VALIDATION.md`).

### ER-02: Distributed Practice & Retention Lag Scaling
- **Citation**: Cepeda, N. J., Pashler, H., Vul, E., Wixted, J. T., & Rohrer, D. (2006). Distributed practice in verbal recall tasks: A review and quantitative synthesis. *Psychological Bulletin*, 132(3), 354–380. `https://doi.org/10.1037/0033-2909.132.3.354`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support`).
- **Methodology**: Meta-analysis of 184 articles (317 experiments, 839 assessments).
- **Population & Sample Size**: Primarily adult and undergraduate cohorts ($N > 14,000$).
- **Measured Outcome & Effect Size**: Spaced practice outperformed massed practice in 259 of 271 comparisons; optimal inter-study gap scales non-linearly with the target retention interval.
- **Limitations & Moderators**: Primarily verbal recall tasks; items that fail initial encoding require short-lag relearning before multi-day intervals.
- **Applicability**: Long-term memory scheduling (`review_items`).
- **Recommended Implementation**: Separate intraday acquisition/relearning from multi-day retention scheduling (`06_MEASUREMENT_AND_SCHEDULING.md`).
- **Test Plan**: Compare delayed recall retention rates under `v2_fsrs6` vs. `v1_sm2_ladder`.

### ER-03: Repeated Testing & Transfer to Novel Application Questions
- **Citation**: Butler, A. C. (2010). Repeated testing produces superior transfer of learning relative to repeated studying. *Journal of Experimental Psychology: Learning, Memory, and Cognition*, 36(5), 1118–1133. `https://doi.org/10.1037/a0019902` (PubMed PMID: `20804289`)
- **Evidence Grade**: **Grade B** (`Direct Empirical Support`).
- **Methodology**: 4 controlled experiments (Experiments 1a, 1b, 2, and 3).
- **Population & Sample Size**: Undergraduate adult learners ($N = 140$ total across the 4 experiments: Exp. 1a $n = 28$, Exp. 1b $n = 28$, Exp. 2 $n = 44$, Exp. 3 $n = 40$).
- **Measured Outcome & Verified Findings**: Retention and far transfer to novel inferential and application questions tested after a 1-week delay. Repeated testing with explanatory feedback consistently produced superior transfer compared to repeated restudying *(specific condition means and inferential tests are reported per experiment in Butler, 2010 Tables 1–3; no single pooled Cohen's $d$ is reported in the abstract)*.
- **Limitations & Moderators**: Transfer requires explanatory rationales that articulate the underlying conceptual principle; bare right/wrong scoring does not reliably produce far transfer.
- **Applicability**: `conceptual_relational` and `apply_to_scenario` tasks (`feedback_policy = immediate_explanatory`).
- **Recommended Implementation**: Pair practice items with principle-based rationales and evaluate concept transfer on held-out scenario items.
- **Test Plan**: Measure first-attempt accuracy on held-out `apply_to_scenario` items after explanation-backed retrieval practice.

### ER-04: Comparative Utility & Boundary Conditions of 10 Learning Techniques
- **Citation**: Dunlosky, J., Rawson, K. A., Marsh, E. J., Nathan, M. J., & Willingham, D. T. (2013). Improving students' learning with effective learning techniques: Promising directions from cognitive and educational psychology. *Psychological Science in the Public Interest*, 14(1), 4–58. `https://doi.org/10.1177/1529100612453266`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support`).
- **Methodology**: Systematic review of 10 learning techniques across learner characteristics, materials, and criterion tasks.
- **Measured Outcome & Findings**: High utility for *Practice Testing* and *Distributed Practice*; Moderate utility for *Interleaved Practice*, *Elaborative Interrogation*, and *Self-Explanation*; Low utility for passive rereading and highlighting.
- **Limitations & Moderators**: Interleaving benefits category/problem-type discrimination where concepts are confusable, but shows weak or null results for unrelated vocabulary lists.
- **Applicability**: Strategy eligibility rules in `03_INSTRUCTIONAL_STRATEGIES.md`.
- **Recommended Implementation**: Activate `contrastive_interleaving` selectively when `ContentComplexityProfile.confusable_density == high_confusable_group`.
- **Test Plan**: Verify session builder applies contrastive interleaving only to linked confusable concept groups.

### ER-10: The Prequestion Effect vs. Diagnostic Testing (2023/2024 Meta-Analysis)
- **Citation**: St. Hilaire, K. J., Chan, J. C. K., & Ahn, D. (2023 online / 2024 print). Guessing as a learning intervention: A meta-analytic review of the prequestion effect. *Psychonomic Bulletin & Review*, 31, 537–563. `https://doi.org/10.3758/s13423-023-02353-8`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support` for item-specific prequestioning; `Implementation Hypothesis` for diagnostic prior-knowledge routing).
- **Methodology**: Meta-analysis separating prequestioned content from non-prequestioned content within subsequent study material.
- **Measured Outcome & Effect Sizes (with 95% CIs)**:
  - **Specific prequestion effect** (retention of the exact information targeted by the prequestion): **$g = .54$, 95% CI $[.42, .66]$, $k = 97$**
  - **General prequestion effect** (retention of untested information in the same material): **$g = .04$, 95% CI $[-.04, .11]$, $k = 91$** (statistically indistinguishable from zero)
- **Limitations & Critical Distinction (Prequestioning $\ne$ Diagnostic Test Validity)**:
  1. **No general spillover**: Asking prequestions improves learning of the targeted question's concept, not unrelated material in the lesson.
  2. **Prequestioning vs. Prior-Knowledge Assessment**: St. Hilaire et al. (2023/2024) evaluate prequestioning as a *learning intervention* (guessing before studying), **not** as a psychometric proof that answering a single pre-lesson MCQ correctly proves prior mastery. Because a single 4-option MCQ has a $25\%$ random guessing floor, using a pre-test to skip scaffolding is a separate measurement problem (`05_LEARNER_ADAPTATION.md`).
- **Applicability**: Pre-lesson prequestions and diagnostic prior-knowledge checks (`05_LEARNER_ADAPTATION.md`).
- **Recommended Implementation**: Keep prequestioning (priming specific lesson objectives) distinct from multi-item diagnostic assessment (estimating prior competence to adapt scaffolding).
- **Test Plan**: Evaluate false-positive skip rates when using single-item vs. multi-item/free-recall diagnostics.

---

## 2. Worked Examples, Fading & Prior-Knowledge Adaptation

### ER-05: Expertise Reversal Meta-Analysis (2025) & Worked-Example Backward Fading
- **Citations**:
  1. Tetzlaff, L., et al. (2025). A cornerstone of adaptivity – A meta-analysis of the expertise reversal effect. *Learning and Instruction*, 98, 102142. `https://doi.org/10.1016/j.learninstruc.2025.102142`
  2. Kalyuga, S., Ayres, P., Chandler, P., & Sweller, J. (2003). The expertise reversal effect. *Educational Psychologist*, 38(1), 23–31. `https://doi.org/10.1207/S15326985EP3801_4`
  3. Renkl, A., Atkinson, R. K., & Große, C. S. (2004). How fading worked solution steps works—A cognitive load perspective. *Instructional Science*, 32(1–2), 59–82. `https://doi.org/10.1023/B:TRUC.0000021815.74806.f6`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support` for adapting instructional assistance to prior knowledge; specific step-transition thresholds are `Implementation Hypotheses`).
- **Methodology & Sample Size**: Meta-analysis of **$k = 60$ studies, $N = 5,924$ participants** (Tetzlaff et al., 2025), alongside experimental backward-fading studies (Renkl et al., 2004, Experiments 1 & 2).
- **Measured Outcome & Effect Sizes (with 95% CIs and Heterogeneity)**:
  - **Low-prior-knowledge learners (novices)**: High instructional assistance significantly improves learning compared to low assistance, **$d = .505$, 95% CI $[.260, .750]$**, with **substantial heterogeneity ($I^2 = 90.87\%$)**.
  - **High-prior-knowledge learners (experienced)**: High instructional assistance significantly impairs learning relative to low assistance / unassisted practice, **$d = -.428$, 95% CI $[-.647, -.209]$**.
- **Limitations & Moderators**:
  - The high heterogeneity ($I^2 = 90.87\%$) demonstrates that optimal assistance depends heavily on task structure and reliable prior-knowledge measurement. It does **not** validate a universal "1 or 2 correct answers" threshold for removing scaffolding.
- **Applicability**: `procedural_quantitative` tasks and `InstructionalPolicy.scaffolding_policy` (`05_LEARNER_ADAPTATION.md`).
- **Recommended Implementation**: Adapt worked-example fading based on multi-signal prior-knowledge evidence rather than a fixed 4-stage lockstep; treat specific step-up/step-down thresholds as tunable `Implementation Hypotheses`.
- **Test Plan**: Measure error rates and time-to-competence across adaptive vs. static scaffolding rules.

---

## 3. Adult Literacy & Phonological-Orthographic Learning

### ER-06: Adult Reading Component Interventions (2026 Systematic Review) & Orthographic Mapping
- **Citations**:
  1. Tighe, E., Greenberg, D., Feinberg, I., Ogrodnick, M., Sun, C., & Jarrard, C. (2026). *Systematic Review of Effective Reading Component Interventions for Adult Literacy Learners*. Kentucky Reading Research Center Report (`https://kyreadingresearch.org`). *(Research report synthesizing 15 peer-reviewed studies of adult literacy learners; not a journal article).*
  2. Ehri, L. C. (2005). Learning to read words: Theory, findings, and issues. *Scientific Studies of Reading*, 9(2), 167–188. `https://doi.org/10.1207/s1532799xssr0902_4`
  3. Castles, A., Rastle, K., & Nation, K. (2018). Ending the reading wars: Reading acquisition from novice to expert. *Psychological Science in the Public Interest*, 19(1), 5–51. `https://doi.org/10.1177/1529100618772271`
- **Evidence Grade**: **Grade B** (`Direct Empirical Support` for untimed decoding improvements in adults; **mixed/limited evidence** for timed decoding, fluency, vocabulary, spelling, and comprehension).
- **Population & Sample Size**:
  - Tighe et al. (2026) synthesizes **15 peer-reviewed studies** covering **adult learners aged 16–76** in adult basic education, English literacy, and correctional/workforce settings.
- **Measured Outcome & Verified Findings (Including Limitations)**:
  - **Decoding**: Explicit reading component interventions produced their most consistent positive effects on **untimed decoding accuracy (effect sizes generally around $d = .12\text{--}.46$)**, but showed **much smaller gains on timed decoding assessments**.
  - **Broader Reading Components**: Evidence across **fluency, vocabulary, spelling, and reading comprehension** in adult learners was **limited and mixed**.
  - **Child Grade-Equivalency Caution**: Tighe et al. (2026) specifically caution that **child-based reading-grade equivalencies do not accurately characterize adult reading ability** (adults have markedly different spoken vocabulary, life knowledge, and component profiles than children at the same decoding level).
- **Applicability**: `sublexical_orthographic` tasks, `ContentComplexityProfile.reading_demand`, and `LITERACY_ACCESSIBILITY_PLAN.md`.
- **Recommended Implementation**:
  1. Keep literacy progressions as **recommendations, never hard gates** (no 95% grapheme lock).
  2. Do **not** impose timed decoding gates on adult learners (given the small/weak timed decoding gains in Tighe et al., 2026).
  3. Define `reading_grade_estimate` strictly as a measure of **text/passage linguistic demand**, never as a label of an adult learner's ability level.
- **Test Plan**: Evaluate untimed decoding accuracy, functional word recognition, and comprehension separately in adult literacy validation.

---

## 4. Open-Book Examinations & Reference Navigation

### ER-07: Open-Book vs. Closed-Book Examinations & Reference Foraging
- **Citations**:
  1. Durning, S. J., Dong, T., Ratcliffe, T., Schuwirth, L., Artino, A. R., Boulet, J. R., & Eva, K. (2016). Comparing open-book and closed-book examinations: A systematic review. *Academic Medicine*, 91(4), 583–599. `https://doi.org/10.1097/ACM.0000000000000977` (PubMed PMID: `26826066`)
  2. Pirolli, P., & Card, S. (1999). Information foraging. *Psychological Review*, 106(4), 643–675. `https://doi.org/10.1037/0033-295X.106.4.643`
- **Evidence Grade**: **Grade B** (`Direct Empirical Support` for longer open-book completion times and equivocal preparation findings; timeout-from-underpreparation causation is an `Implementation Hypothesis`).
- **Methodology & Sample**: Systematic review of **37 peer-reviewed studies** comparing open-book examinations (OBEs) and closed-book examinations (CBEs).
- **Verified Findings vs. Implementation Hypotheses**:
  - **Established by Durning et al. (2016)**:
    1. Study findings on examinee preparation behavior were **equivocal**.
    2. Examinees took **longer to complete open-book examinations** than closed-book examinations.
    3. Exam performance often favored closed-book examinations, particularly when closed-book candidates prepared more extensively.
  - **`Implementation Hypothesis` (To Investigate in `Pilot A`)**:
    - The hypothesis that training structured reference navigation (`EXM R1–R4`: resource selection, section navigation, provision location, exception interpretation) reduces open-book lookup time and improves timed licensing exam performance is an **instructional design hypothesis** to be tested empirically in the Florida Certified Contractor pilot (`Pilot A`).
- **Applicability**: `reference_navigation` tasks and `EXM_00`.
- **Recommended Implementation**: Track the 6 open-book competencies independently without assuming an arbitrary 30/70 memorization-to-lookup split.
- **Test Plan**: Measure `R1–R4` lookup time and accuracy trends and correlate with timed mock exam completion in `Pilot A`.

---

## 5. Transfer-Appropriate Processing, Production Effect & Oral Assessment

### ER-08: Transfer-Appropriate Processing, Production Effect & Spoken Exam Answers
- **Citations**:
  1. Morris, C. D., Bransford, J. D., & Franks, J. J. (1977). Levels of processing versus transfer appropriate processing. *Journal of Verbal Learning and Verbal Behavior*, 16(5), 519–533. `https://doi.org/10.1016/S0022-5371(77)80016-9`
  2. MacLeod, C. M., Gopie, N., Hourihan, K. L., Neary, K. R., & Ozubko, J. D. (2010). The production effect: Delineation of a phenomenon. *Journal of Experimental Psychology: Learning, Memory, and Cognition*, 36(3), 671–685. `https://doi.org/10.1037/a0018785`
- **Evidence Grade**: **Grade C for Oral Free-Recall Exams** (`Direct Empirical Support` for recognition memory mechanisms; `Implementation Hypothesis` for spoken free-recall exam preparation).
- **Methodology & Boundaries**:
  1. **Transfer-Appropriate Processing (Morris et al., 1977)**: Recognition experiments demonstrating that memory performance depends on the match between encoding and test processing demands.
  2. **The Production Effect (MacLeod et al., 2010)**: **8 recognition experiments** demonstrating that reading words aloud improves subsequent recognition relative to silent reading.
  3. **Spoken Free-Recall Production (`Implementation Hypothesis`, `experimental` status)**: Neither study tests spoken free-recall answers on oral examinations (such as the USCIS civics interview). Spoken answer practice and evaluation is therefore designated as an **`experimental` implementation hypothesis**.
- **Applicability**: `spoken_production` tasks (`04_TASK_SPECIFIC_DELIVERY.md`).
- **Recommended Implementation**: Provide spoken/free-recall practice for oral exams; never enforce speech-onset latency as a mastery gate; evaluate transfer to oral mock interviews empirically.
- **Test Plan**: Compare uncued oral recall accuracy after spoken free-recall practice vs. MCQ-only practice.

---

## 6. Small-Sample IRT Calibration, Elo & FSRS-6 Memory Modeling

### ER-09: Small-Sample Bayesian IRT Calibration, Elo Ratings & FSRS-6
- **Citations**:
  1. König, C., Spoden, C., & Frey, A. (2020). An Optimized Bayesian Hierarchical Two-Parameter Logistic Model for Small-Sample Item Calibration. *Applied Psychological Measurement*, 44(4), 311–326. `https://doi.org/10.1177/0146621619893786` (PMC: `PMC7245598`)
  2. Pelánek, R. (2016). Applications of the Elo rating system in adaptive educational systems. *Computers & Education*, 98, 169–179. `https://doi.org/10.1016/j.compedu.2016.03.017`
  3. `package:fsrs` v2.0.1 (Dart implementation of **FSRS-6**, verified in package changelog v2.0.0+; `https://pub.dev/packages/fsrs`).
- **Evidence Grade**: **Grade A/B** (`Direct Empirical Support` for model properties; real-world calibration thresholds in LearningApp are governed by empirical convergence and $\text{SE}$).
- **Boundaries & Limitations**:
  1. **Simulation Boundary on König et al. (2020)**: König et al. (2020) demonstrated accurate item parameter recovery down to $N = 100$ **in a Monte Carlo simulation study using a specific optimized hierarchical Bayesian 2PL model with well-behaved assumptions**. This does **not** mean 100 real-world LearningApp users automatically yield calibrated 2PL parameters (where sparse item coverage, non-random item selection, and skewed ability distributions occur). Item promotion to `calibrated` requires verifying actual parameter standard errors ($\text{SE}$) and model fit.
  2. **Elo $\ne$ IRT**: Online Elo provides a relative rating for adaptive item ordering, not a calibrated IRT parameter ($a_i, b_i$).
  3. **FSRS-6 Retrievability $\ne$ Concept Mastery $\ne$ Exam Readiness**: FSRS-6 estimates memory recall probability $R(t)$ for an individual review card based on card ratings (`Again`, `Hard`, `Good`, `Easy`); it does not measure multi-facet concept mastery or exam readiness (`06_MEASUREMENT_AND_SCHEDULING.md`).
