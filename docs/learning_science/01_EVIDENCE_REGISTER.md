# 01 — Research & Technical Evidence Register

This register records the primary scientific literature, research synthesis reports, psychometric simulations, and technical implementation references governing LearningApp's instructional strategies, task profiles, and measurement rules. In accordance with [`README.md`](README.md), every empirical entry documents its **exact bibliographic citation and DOI/URL**, **evidence grade**, **population and sample size (including subgroup sample sizes where applicable)**, **effect sizes with 95% confidence intervals and heterogeneity ($I^2$) wherever reported by the source study (and explicitly notes when a statistic is not reported or not applicable, such as in qualitative syntheses, multi-experiment studies without a pooled meta-analytic $I^2$, or Monte Carlo simulations)**, **study-specific limitations and negative/mixed findings**, and **whether a resulting design rule has direct empirical support or is an implementation hypothesis/policy**. Technical software references are explicitly labeled so they are never conflated with empirical educational-outcome studies.

---

## Evidence Grade & Claim Status Scale
- **Grade A (Strong Meta-Analytic / Replicated Experimental Consensus)**: Multiple meta-analyses or large-scale experiments with well-characterized confidence intervals and moderators.
- **Grade B (Domain-Specific Experimental / Systematic Review Evidence)**: Peer-reviewed evidence or formal research synthesis within a specific population or task domain; requires verification when generalizing to new adult cohorts.
- **Grade C (Indirect Theoretical Mechanism / Simulation / Mixed Evidence)**: Supports a partial mechanism or Monte Carlo simulation condition, but direct transfer to the target learning or assessment context is unverified.
- **Technical Implementation Reference (Non-Empirical)**: Software library or algorithmic specification; documents implementation mechanics rather than empirical learner outcomes.
- **Claim Status**:
  - `Direct Empirical Support`: The cited study directly measures the target intervention and outcome in a comparable task.
  - `Implementation Hypothesis`: An engineering or instructional design rule motivated by related cognitive or simulation findings that requires empirical validation inside LearningApp before being claimed as proven.

---

## 1. Retrieval Practice, Spacing, Interleaving & Prequestioning

### ER-01: Retrieval Practice, Distributed Practice & Interleaved Practice in Classrooms (2026 Meta-Analysis)
- **Citation**: Ruitenburg, S. K., Goos, M., Lambert, K., Kirschner, P. A., Jarodzka, H., & Camp, G. (2026, published October 29, 2026). A Meta-Analysis of the Effectiveness and Boundary Conditions of Retrieval Practice, Distributed Practice, and Interleaved Practice in Authentic School Classrooms. *Educational Psychology Review* (Springer Nature). `https://doi.org/10.1007/s10648-026-10225-5`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support` for strategy effectiveness & moderator sensitivity; `Implementation Hypothesis` when extrapolating from K–12 classroom cohorts to adult vocational/licensing learners).
- **Methodology**: Meta-analysis of 53 authentic classroom studies across three desirable-difficulty strategies.
- **Population, Subgroup Sample Sizes & Heterogeneity ($I^2$)**:
  - **Overall synthesis pool**: $k = 53$ studies, $N = 7,303$ learners in primary and secondary school classrooms *(note: some studies contribute to more than one strategy comparison; strategy-specific subgroup samples and three-level variance decompositions—total $I^2_{\text{total}}$, within-study $I^2_{\text{within}}$, and between-study $I^2_{\text{between}}$—are listed below)*.
  - **Retrieval practice subgroup**: **$k = 31$ studies, $n = 3,391$ participants**, **$g = .37$, 95% CI $[.18, .56]$**, total heterogeneity **$I^2_{\text{total}} = 85.29\%$** (within-study **$I^2_{\text{within}} = 24.50\%$**, between-study **$I^2_{\text{between}} = 60.79\%$**).
  - **Distributed (spaced) practice subgroup**: **$k = 15$ studies, $n = 2,010$ participants**, **$g = .20$, 95% CI $[.03, .36]$**, total heterogeneity **$I^2_{\text{total}} = 73.18\%$** (within-study **$I^2_{\text{within}} = 19.68\%$**, between-study **$I^2_{\text{between}} = 53.50\%$**).
  - **Interleaved practice subgroup**: **$k = 10$ studies, $n = 1,902$ participants**, **$g = .40$, 95% CI $[.10, .71]$**, total heterogeneity **$I^2_{\text{total}} = 73.52\%$** (within-study **$I^2_{\text{within}} = 3.70\%$**, between-study **$I^2_{\text{between}} = 69.82\%$**).
- **Limitations & Moderators**:
  1. **Substantial total and between-study heterogeneity ($I^2_{\text{total}} = 73.18\%\text{--}85.29\%$, $I^2_{\text{between}} = 53.50\%\text{--}69.82\%$) & moderator sensitivity**: Effects vary considerably across and within studies and are moderated by **knowledge type**, **assessment format**, and **feedback**, supporting task-profile-dependent strategy selection over a rigid one-size-fits-all loop.
  2. **Population boundary**: Because the synthesized studies come from primary and secondary school classrooms, this meta-analysis must **not** be cited as direct empirical proof of adult licensing or vocational exam pass rates.
- **Applicability**: `InstructionalPolicy.eligible_strategies[]` selection rules (`03_INSTRUCTIONAL_STRATEGIES.md`).
- **Recommended Implementation**: Configure retrieval, spacing, and interleaving dynamically according to `LearningTaskProfile` and `InstructionalPolicy`.
- **Test Plan**: Evaluate delayed retention and held-out transfer across adult cohorts in Phase 1 empirical validation (`07_READINESS_AND_VALIDATION.md`).

### ER-02: Distributed Practice & Retention Lag Scaling
- **Citation**: Cepeda, N. J., Pashler, H., Vul, E., Wixted, J. T., & Rohrer, D. (2006). Distributed practice in verbal recall tasks: A review and quantitative synthesis. *Psychological Bulletin*, 132(3), 354–380. `https://doi.org/10.1037/0033-2909.132.3.354`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support`).
- **Methodology**: Meta-analysis of 184 articles (317 experiments, 839 assessments).
- **Population & Sample Size**: Primarily adult and undergraduate cohorts ($N > 14,000$).
- **Measured Outcome & Effect Size**: Spaced practice outperformed massed practice in 259 of 271 comparisons; optimal inter-study gap scales non-linearly with the target retention interval *(a single pooled standardized effect size $d$/$g$, 95% CI, and meta-analytic heterogeneity $I^2$ across all 839 assessments are not reported by the source study, as outcomes are analyzed across stratified lag × retention-interval surface bins)*.
- **Limitations & Moderators**: Primarily verbal recall tasks; items that fail initial encoding require short-lag relearning before multi-day intervals.
- **Applicability**: Long-term memory scheduling (`review_items`).
- **Recommended Implementation**: Separate intraday acquisition/relearning from multi-day retention scheduling (`06_MEASUREMENT_AND_SCHEDULING.md`).
- **Test Plan**: Compare delayed recall retention rates under `v2_fsrs6` vs. `v1_sm2_ladder`.

### ER-03: Repeated Testing & Transfer to Novel Application Questions
- **Citation**: Butler, A. C. (2010). Repeated testing produces superior transfer of learning relative to repeated studying. *Journal of Experimental Psychology: Learning, Memory, and Cognition*, 36(5), 1118–1133. `https://doi.org/10.1037/a0019902` (PubMed PMID: `20804289`)
- **Evidence Grade**: **Grade B** (`Direct Empirical Support`).
- **Methodology**: 4 controlled experiments (Experiments 1a, 1b, 2, and 3).
- **Population & Sample Size**: Undergraduate adult learners ($N = 140$ total across the 4 experiments: Exp. 1a $n = 28$, Exp. 1b $n = 28$, Exp. 2 $n = 44$, Exp. 3 $n = 40$).
- **Measured Outcome & Verified Findings**: Retention and far transfer to novel inferential and application questions tested after a 1-week delay. Repeated testing with explanatory feedback consistently produced superior transfer compared to repeated restudying *(primary multi-experiment study: specific condition means and inferential tests are reported per experiment in Butler, 2010 Tables 1–3; a single pooled meta-analytic standardized effect size $d$/$g$, 95% CI, and $I^2$ are not reported / not applicable)*.
- **Limitations & Moderators**: Transfer requires explanatory rationales that articulate the underlying conceptual principle; bare right/wrong scoring does not reliably produce far transfer.
- **Applicability**: `conceptual_relational` and `apply_to_scenario` tasks (`feedback_policy = immediate_explanatory`).
- **Recommended Implementation**: Pair practice items with principle-based rationales and evaluate concept transfer on held-out scenario items.
- **Test Plan**: Measure first-attempt accuracy on held-out `apply_to_scenario` items after explanation-backed retrieval practice.

### ER-04: Comparative Utility & Boundary Conditions of 10 Learning Techniques
- **Citation**: Dunlosky, J., Rawson, K. A., Marsh, E. J., Nathan, M. J., & Willingham, D. T. (2013). Improving students' learning with effective learning techniques: Promising directions from cognitive and educational psychology. *Psychological Science in the Public Interest*, 14(1), 4–58. `https://doi.org/10.1177/1529100612453266`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support`).
- **Methodology**: Systematic review of 10 learning techniques across learner characteristics, materials, and criterion tasks.
- **Measured Outcome & Findings**: High utility for *Practice Testing* and *Distributed Practice*; Moderate utility for *Interleaved Practice*, *Elaborative Interrogation*, and *Self-Explanation*; Low utility for passive rereading and highlighting *(qualitative/narrative systematic utility synthesis; pooled meta-analytic effect sizes, 95% CIs, and $I^2$ are not applicable)*.
- **Limitations & Moderators**: Interleaving benefits category/problem-type discrimination where concepts are confusable, but shows weak or null results for unrelated vocabulary lists.
- **Applicability**: Strategy eligibility rules in `03_INSTRUCTIONAL_STRATEGIES.md`.
- **Recommended Implementation**: Activate `contrastive_interleaving` selectively when `ContentComplexityProfile.confusable_density == high_confusable_group`.
- **Test Plan**: Verify session builder applies contrastive interleaving only to linked confusable concept groups.

### ER-10: The Prequestion Effect vs. Diagnostic Testing (2023/2024 Meta-Analysis)
- **Citation**: St. Hilaire, K. J., Chan, J. C. K., & Ahn, D. (2023 online / 2024 print). Guessing as a learning intervention: A meta-analytic review of the prequestion effect. *Psychonomic Bulletin & Review*, 31, 411–441. `https://doi.org/10.3758/s13423-023-02353-8` (PubMed PMID: `37550561`)
- **Evidence Grade**: **Grade A** (`Direct Empirical Support` for item-specific prequestioning; `Implementation Hypothesis` for diagnostic prior-knowledge routing).
- **Methodology**: Meta-analysis separating prequestioned content from non-prequestioned content within subsequent study material.
- **Measured Outcome & Effect Sizes (with 95% CIs)**:
  - **Specific prequestion effect** (retention of the exact information targeted by the prequestion): **$g = .54$, 95% CI $[.42, .66]$, $k = 97$**
  - **General prequestion effect** (retention of untested information in the same material): **$g = .04$, 95% CI $[-.04, .11]$, $k = 91$** (statistically indistinguishable from zero; *specific $I^2$ percentages are not reported in the abstract, though substantial moderator variation across study designs is analyzed*)
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
  1. Tetzlaff, L., Simonsmeier, B. A., Peters, M., & Brod, G. (2025). A cornerstone of adaptivity – A meta-analysis of the expertise reversal effect. *Learning and Instruction*, 98, 102142. `https://doi.org/10.1016/j.learninstruc.2025.102142`
  2. Kalyuga, S., Ayres, P., Chandler, P., & Sweller, J. (2003). The expertise reversal effect. *Educational Psychologist*, 38(1), 23–31. `https://doi.org/10.1207/S15326985EP3801_4`
  3. Renkl, A., Atkinson, R. K., & Große, C. S. (2004). How fading worked solution steps works—A cognitive load perspective. *Instructional Science*, 32(1–2), 59–82. `https://doi.org/10.1023/B:TRUC.0000021815.74806.f6`
- **Evidence Grade**: **Grade A** (`Direct Empirical Support` for adapting instructional assistance to prior knowledge; specific step-transition thresholds are `Implementation Hypotheses`).
- **Methodology & Sample Size**: Meta-analysis of **$k = 60$ studies, $N = 5,924$ participants** (Tetzlaff, Simonsmeier, Peters, & Brod, 2025), alongside experimental backward-fading studies (Renkl et al., 2004, Experiments 1 & 2).
- **Measured Outcome & Effect Sizes (with 95% CIs and Heterogeneity)**:
  - **Low-prior-knowledge learners (novices)**: High instructional assistance significantly improves learning compared to low assistance, **$d = .505$, 95% CI $[.260, .750]$**, with **substantial heterogeneity ($I^2 = 90.87\%$)**.
  - **High-prior-knowledge learners (experienced)**: High instructional assistance significantly impairs learning relative to low assistance / unassisted practice, **$d = -.428$, 95% CI $[-.647, -.209]$**, also with **substantial heterogeneity ($I^2 = 87.55\%$)**.
- **Limitations & Moderators**:
  - The high heterogeneity in both novice ($I^2 = 90.87\%$) and experienced ($I^2 = 87.55\%$) subgroups demonstrates that optimal assistance depends heavily on task structure and reliable prior-knowledge measurement. It does **not** validate a universal "1 or 2 correct answers" threshold for removing scaffolding.
- **Applicability**: `procedural_quantitative` tasks and `InstructionalPolicy.scaffolding_policy` (`05_LEARNER_ADAPTATION.md`).
- **Recommended Implementation**: Adapt worked-example fading based on multi-signal prior-knowledge evidence rather than a fixed 4-stage lockstep; treat specific step-up/step-down thresholds as tunable `Implementation Hypotheses`.
- **Test Plan**: Measure error rates and time-to-competence across adaptive vs. static scaffolding rules.

---

## 3. Adult Literacy & Phonological-Orthographic Learning

### ER-06: Adult Reading Component Interventions (2026 Systematic Review) & Orthographic Mapping
- **Citations**:
  1. Tighe, E. L., Greenberg, D., Feinberg, I., Ogrodnick, M. M., Sun, C. D., & Jarrard, C. (2026, September 2). *Systematic Review of Effective Reading Component Interventions for Adult Literacy Learners*. Kentucky Reading Research Center Report (`https://www.kyreadingresearch.org/wp-content/uploads/2026/10/Effective-Adult-Reading-Interventions.pdf` ; `https://kyreadingresearch.org`). *(Research report synthesizing 15 peer-reviewed studies of adult literacy learners; not a journal article).*
  2. Ehri, L. C. (2005). Learning to read words: Theory, findings, and issues. *Scientific Studies of Reading*, 9(2), 167–188. `https://doi.org/10.1207/s1532799xssr0902_4`
  3. Castles, A., Rastle, K., & Nation, K. (2018). Ending the reading wars: Reading acquisition from novice to expert. *Psychological Science in the Public Interest*, 19(1), 5–51. `https://doi.org/10.1177/1529100618772271`
- **Evidence Grade**: **Grade B** (`Direct Empirical Support` for untimed decoding improvements in adults; **mixed/limited evidence** across other reading components; **not direct evidence for ESL-only programs**).
- **Population & Sample Size**:
  - Tighe et al. (2026) synthesizes **15 peer-reviewed studies** covering **adult learners aged 16–76** in adult basic education, English literacy, and correctional/workforce settings. **Importantly, the review excluded studies focused only on English as a Second Language (ESL) populations.**
- **Measured Outcome & Verified Findings (Including Limitations)**:
  - **Decoding**: Explicit reading component interventions produced their most consistent positive effects on **untimed decoding accuracy (study-level effect sizes generally around $d = .12\text{--}.46$; narrative systematic review across 15 studies without a single pooled meta-analytic CI or $I^2$)**, but showed **much smaller gains on timed decoding assessments**.
  - **Fluency, Vocabulary, Spelling, Morphology, Phonological Skills & Comprehension**:
    - **Fluency** findings were **generally positive but mixed**.
    - Evidence for **vocabulary, spelling, morphology, and phonological skills** was **limited**.
    - **Reading comprehension** outcomes **varied by assessment**, with some larger RCTs showing gains.
  - **Child Grade-Equivalency Caution**: Tighe et al. (2026) note that **it has not been empirically determined whether child-based reading-grade equivalencies accurately describe adult reading ability** (adults have markedly different spoken vocabulary, life knowledge, and component profiles than children at the same decoding level).
  - **ESL Boundary**: Because ESL-only studies were excluded from the synthesis, Tighe et al. (2026) must **not** be cited as direct evidence for ESL-only learner programs.
- **Applicability**: `sublexical_orthographic` tasks, `ContentComplexityProfile.reading_demand`, and `LITERACY_ACCESSIBILITY_PLAN.md`.
- **Recommended Implementation**:
  1. Keep literacy progressions as **recommendations, never hard gates** (no 95% grapheme lock).
  2. **Product & Accessibility Policy Informed by Empirical Findings**: Because Tighe et al. (2026) report consistent gains on untimed decoding ($d = .12\text{--}.46$) but much smaller gains on timed decoding assessments (while fluency findings are generally positive but mixed), LearningApp sets core adult decoding mastery to `timing_regime = untimed_mastery` (no punitive speed gates for mastery progression) as a **product and accessibility policy**, while keeping optional, learner-initiated fluency practice available without speed penalties.
  3. Define `reading_grade_estimate` strictly as a measure of **text/passage linguistic demand**, never as a verified label of an adult learner's reading ability level.
- **Test Plan**: Evaluate untimed decoding accuracy, functional word recognition, and comprehension separately in adult literacy validation.

---

## 4. Open-Book Examinations & Reference Navigation

### ER-07: Open-Book vs. Closed-Book Examinations & Reference Foraging
- **Citations**:
  1. Durning, S. J., Dong, T., Ratcliffe, T., Schuwirth, L., Artino, A. R., Boulet, J. R., & Eva, K. (2016). Comparing open-book and closed-book examinations: A systematic review. *Academic Medicine*, 91(4), 583–599. `https://doi.org/10.1097/ACM.0000000000000977` (PubMed PMID: `26826066`)
  2. Pirolli, P., & Card, S. (1999). Information foraging. *Psychological Review*, 106(4), 643–675. `https://doi.org/10.1037/0033-295X.106.4.643`
- **Evidence Grade**: **Grade B** (`Direct Empirical Support` for longer open-book completion times and equivocal preparation findings; timeout-from-underpreparation causation is an `Implementation Hypothesis`).
- **Methodology & Sample**: Narrative systematic review of **37 peer-reviewed studies** comparing open-book examinations (OBEs) and closed-book examinations (CBEs) *(qualitative synthesis across heterogeneous study designs; pooled meta-analytic effect size, 95% CI, and $I^2$ are not reported)*.
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
  1. **Transfer-Appropriate Processing (Morris et al., 1977)**: Primary recognition experiments ($N = 32$ per experiment) demonstrating that memory performance depends on the match between encoding and test processing demands *(multi-experiment primary study; a single pooled meta-analytic standardized effect size $d$/$g$, 95% CI, and $I^2$ are not reported / not applicable)*.
  2. **The Production Effect (MacLeod et al., 2010)**: **8 recognition experiments** demonstrating that reading words aloud improves subsequent recognition relative to silent reading *(multi-experiment primary study; a single pooled meta-analytic standardized effect size $d$/$g$, 95% CI, and $I^2$ are not reported / not applicable)*.
  3. **Spoken Free-Recall Production (`Implementation Hypothesis`, `experimental` status)**: Neither study tests spoken free-recall answers on oral examinations (such as the USCIS civics interview). Spoken answer practice and evaluation is therefore designated as an **`experimental` implementation hypothesis**.
- **Applicability**: `spoken_production` tasks (`04_TASK_SPECIFIC_DELIVERY.md`).
- **Recommended Implementation**: Provide spoken/free-recall practice for oral exams; never enforce speech-onset latency as a mastery gate; evaluate transfer to oral mock interviews empirically.
- **Test Plan**: Compare uncued oral recall accuracy after spoken free-recall practice vs. MCQ-only practice.

---

## 6. Small-Sample IRT Simulation, Elo Ratings & FSRS-6 Technical Reference

### ER-09: Small-Sample Bayesian IRT Simulation (`Grade C`), Elo Ratings & Measurement Limitations (`Grade B/C`) & `package:fsrs` Technical Reference
To avoid conflating Monte Carlo simulation studies, adaptive Elo rating research, and software library documentation, `ER-09` separates its three sub-entries explicitly:

1. **ER-09a — Small-Sample Bayesian 2PL IRT Calibration (Monte Carlo Simulation Evidence — `Grade C`)**:
   - **Citation**: König, C., Spoden, C., & Frey, A. (2020). An Optimized Bayesian Hierarchical Two-Parameter Logistic Model for Small-Sample Item Calibration. *Applied Psychological Measurement*, 44(4), 311–326. `https://doi.org/10.1177/0146621619893786` (PMC: `PMC7245598`)
   - **Evidence Grade**: **Grade C (Monte Carlo Simulation Evidence — `Implementation Hypothesis` for real-world calibration thresholds)**.
   - **Methodology & Simulation Design**: Monte Carlo simulation evaluating an optimized Bayesian hierarchical 2PL model across **sample sizes of $N \in \{50, 75, 100, 150, 200, 500\}$**, **test lengths of $25$ and $50$ items**, and **$100$ simulated datasets per condition**.
   - **Effect Size ($d$/$g$), 95% CI & Heterogeneity ($I^2$)**: *Not applicable* (Monte Carlo psychometric parameter-recovery simulation evaluating bias and RMSE of item parameter estimates $\hat{a}_i, \hat{b}_i$, not an empirical learner-group intervention trial or meta-analysis; no standardized group effect size $d$/$g$, 95% CI, or meta-analytic heterogeneity $I^2$ applies).
   - **Findings & Real-World Boundary**: Demonstrated accurate parameter recovery down to $N = 100$ under well-behaved simulated conditions. Crucially, König et al. (2020) **do not establish a universal maximum $\text{SE}$ or universal convergence rule for every real-world item pool** (where sparse item matrices, adaptive item selection, and skewed learner ability distributions occur). Promoting an item to `item_psychometric_status = 'calibrated'` requires satisfying model-specific convergence diagnostics and an acceptable standard-error bound (`calibration_max_se`) explicitly validated for the target item pool; **until those pool-specific criteria are defined and validated, promotion to `calibrated` remains inactive (`pending_validation`)**.
2. **ER-09b — Elo Rating Systems in Adaptive Learning & Their Measurement Limitations (`Grade B` Overview / `Grade C` Simulation Critique)**:
   - **Citations**:
     1. Pelánek, R. (2016). Applications of the Elo rating system in adaptive educational systems. *Computers & Education*, 98, 169–179. `https://doi.org/10.1016/j.compedu.2016.03.017`
     2. Bolsinova, M., Gergely, B., & Brinkhuis, M. J. S. (2026; first published online June 2025). Keeping Elo alive: Evaluating and improving measurement properties of learning systems based on Elo ratings. *British Journal of Mathematical and Statistical Psychology*, 79(1), 95–110. `https://doi.org/10.1111/bmsp.12395` (PubMed PMID: `40528359`)
   - **Evidence Grade**: **Grade B/C** (Pelánek, 2016 provides a practical overview and case study for heuristic ordering; Bolsinova et al., 2026 provide simulation evidence demonstrating measurement limitations in adaptive Elo systems).
   - **Effect Size ($d$/$g$), 95% CI & Heterogeneity ($I^2$)**: *Not applicable* (Pelánek, 2016 is a methodological overview and system case study, and Bolsinova et al., 2026 is a psychometric simulation study of adaptive Elo rating properties; neither is an empirical learner-group intervention trial or meta-analysis, so no standardized group effect size $d$/$g$, 95% CI, or meta-analytic heterogeneity $I^2$ applies).
   - **Findings, Limitations & Boundaries**:
     - Pelánek (2016) shows that online Elo updates can serve as a lightweight heuristic for preliminary adaptive ordering, but **does not establish a universal minimum number of observations for preliminary ordering** nor guarantee that every Elo implementation produces reliable item-difficulty estimates.
     - **Bolsinova, Gergely, & Brinkhuis (2026)** demonstrate via simulation analysis that when item selection and learner/item Elo ratings update jointly in an adaptive learning system, standard Elo ratings can exhibit **systematic bias**, **context-dependent variance**, and **failure to converge**, and propose **parallel rating chains** to address these pathologies.
     - **Implication for LearningApp**: (a) A single learner response ($N = 1$) only marks an item as empirically observed (`observed_uncalibrated`), **not** as having a meaningful item-difficulty estimate; (b) transitioning from `observed_uncalibrated` to `preliminary_elo_ordering` is governed by a configurable LearningApp policy parameter (**`elo_min_observations`**) that must be selected and validated for the relevant item pool (**until `elo_min_observations` is set and validated for that pool, the transition to `preliminary_elo_ordering` remains inactive**); and (c) standard Elo ratings are treated strictly as low-stakes ordering heuristics, never as unbiased or calibrated psychometric parameters ($b_i$).
3. **ER-09c — `package:fsrs` v2.0.1 (`Technical Implementation Reference`, Non-Empirical)**:
   - **Reference**: `package:fsrs` v2.0.1 (Dart implementation of **FSRS-6**, verified in package changelog v2.0.0+; `https://pub.dev/packages/fsrs`).
   - **Classification**: **Technical Implementation Reference** (documents the FSRS-6 memory scheduling state machine and parameter formulas used in `scheduler_version = 'v2_fsrs6'`; not cited as an empirical educational-outcome study).
   - **Effect Size ($d$/$g$), 95% CI & Heterogeneity ($I^2$)**: *Not applicable* (non-empirical software library and algorithm specification).
   - **Boundary Rule**: FSRS-6 estimates memory recall probability $R(t)$ for an individual review card based on card recall ratings (`Again`, `Hard`, `Good`, `Easy`); it does not measure multi-facet concept mastery or exam readiness (`06_MEASUREMENT_AND_SCHEDULING.md`).
