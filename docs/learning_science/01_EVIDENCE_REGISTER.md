# 01 — Evidence Register & Peer-Reviewed Research Baseline

This register records the primary scientific literature governing LearningApp's instructional strategies, task profiles, and measurement rules. In accordance with [`README.md`](README.md), it documents **positive, moderator-dependent, mixed, and negative/null findings** so application rules never overreach the evidence.

---

## Evidence Grade Scale
- **Grade A (Strong Meta-Analytic / Replicated Experimental Consensus)**: Multiple meta-analyses or large-scale RCTs across diverse content types with well-characterized boundary conditions.
- **Grade B (Domain-Specific Experimental / Quasi-Experimental Evidence)**: Replicated studies within a specific domain or population; requires careful verification when generalizing to new adult cohorts.
- **Grade C (Theoretical / Preliminary / Mixed Empirical Evidence)**: Plausible cognitive mechanism or mixed findings across sub-skills; must be implemented as an **optional or adaptive support**, never a hard gate.

---

## 1. Retrieval Practice, Spacing & Interleaving (Core Memory & Transfer)

### ER-01: Distributed Practice & Lag Effects
- **Citation**: Cepeda, N. J., Pashler, H., Vul, E., Wixted, J. T., & Rohrer, D. (2006). Distributed practice in verbal recall tasks: A review and quantitative synthesis. *Psychological Bulletin*, 132(3), 354–380. `https://doi.org/10.1037/0033-2909.132.3.354`
- **Methodology**: Meta-analysis of 184 articles (317 experiments).
- **Population & Sample Size**: Primarily adults and young adults across 839 assessments ($N > 14,000$).
- **Measured Outcome**: Delayed verbal recall across retention intervals from minutes to months.
- **Effect Size**: Spaced practice outperformed massed practice in 259 of 271 comparisons; optimal inter-study gap scales as a non-linear fraction (approx. 10–30%) of the target retention interval.
- **Limitations & Moderators**: Mostly verbal/declarative recall materials; optimal gap shrinks if initial encoding fails (requiring short-lag relearning first).
- **Applicability**: All retention-scheduled `knowledge_facets`.
- **Recommended Implementation**: Separate short-lag initial acquisition/relearning steps from multi-day expanding retention intervals; align desired retention with target exam horizon when specified.
- **Test Plan**: Compare delayed recall rates on held-out review items scheduled via expanding stability vs. legacy fixed intervals.

### ER-02: Utility of 10 Learning Techniques Across Task Types
- **Citation**: Dunlosky, J., Rawson, K. A., Marsh, E. J., Nathan, M. J., & Willingham, D. T. (2013). Improving students' learning with effective learning techniques: Promising directions from cognitive and educational psychology. *Psychological Science in the Public Interest*, 14(1), 4–58. `https://doi.org/10.1177/1529100612453266`
- **Methodology**: Comprehensive systematic synthesis of 10 instructional techniques across learner characteristics, materials, and criterion tasks.
- **Population & Sample Size**: Broad educational cohorts (children through adults).
- **Measured Outcome**: Comprehension, delayed retention, and transfer.
- **Effect Size / Rating**: High utility for *Practice Testing* and *Distributed Practice*; Moderate utility for *Interleaved Practice*, *Elaborative Interrogation*, and *Self-Explanation*; Low utility for passive rereading and highlighting.
- **Limitations & Moderators**: **Interleaving and elaborative interrogation show strong moderators by knowledge type**—interleaving helps strongly in mathematical problem-type discrimination and perceptual category learning, but shows weak or null effects when applied to completely unrelated vocabulary sets.
- **Applicability**: `InstructionalStrategy` selection engine.
- **Recommended Implementation**: Default to active retrieval over passive text exposure; activate contrastive interleaving **only** when items belong to a shared `confusable_group_id` or problem-type discrimination family.
- **Test Plan**: Verify session builder applies contrastive interleaving selectively to `confusable_group_id` clusters without scrambling unrelated introductory lessons.

### ER-03: Testing Effect & Transfer of Learning
- **Citation**: Butler, A. C. (2010). Repeated testing produces superior transfer of learning relative to repeated studying. *Journal of Experimental Psychology: Learning, Memory, and Cognition*, 36(5), 1118–1133. `https://doi.org/10.1037/a0019902`
- **Methodology**: Controlled multi-experiment behavioral study ($N = 140$ adults).
- **Measured Outcome**: Far transfer to novel inferential application questions 1 week later.
- **Effect Size**: $d \approx 0.72$ advantage for repeated retrieval with explanatory feedback over repeated restudying on transfer questions.
- **Limitations & Moderators**: Requires explanatory feedback linking the underlying principle to the novel context; verbatim recognition questions alone yield weaker transfer.
- **Applicability**: `conceptual_relational` and `apply_to_scenario` tasks.
- **Recommended Implementation**: Pair retrieval items with principle-based explanations (`rationale`) and test concept transfer using held-out scenario items where surface wording differs from instruction.
- **Test Plan**: Track learner accuracy on first-seen `apply_to_scenario` items after definition-only vs. explanation-backed practice.

---

## 2. Worked Examples, Fading & Prior-Knowledge Adaptation

### ER-04: Worked-Example Effect & Backward Fading
- **Citation**: Renkl, A., Atkinson, R. K., & Große, C. S. (2004). How fading worked solution steps works—A cognitive load perspective. *Instructional Science*, 32(1–2), 59–82. `https://doi.org/10.1023/B:TRUC.0000021815.74806.f6`
- **Methodology**: Controlled experimental studies in quantitative/procedural problem solving (probability & physics calculations).
- **Measured Outcome**: Near and far procedural problem-solving transfer and error reduction during acquisition.
- **Effect Size**: $d = 0.54\text{--}0.81$ advantage for faded worked examples over unguided problem pairs for novices.
- **Limitations & Moderators**: **Strongly moderated by prior knowledge (see ER-05).** Enforcing fixed multi-stage worked examples on learners who already know the procedure wastes time and lowers performance.
- **Applicability**: `procedural_quantitative` tasks.
- **Recommended Implementation**: Provide worked examples and backward step fading **adaptively** based on initial diagnostic or prior concept performance—never force all learners through 4 rigid stages if they demonstrate competence on unassisted problems.
- **Test Plan**: Unit-test adaptive fading controller so a learner who passes a diagnostic calculation skips Stage 0–2 scaffolding, while a learner who errs receives targeted step fading.

### ER-05: Expertise Reversal Effect & Adaptive Assistance
- **Citation**: Kalyuga, S., Ayres, P., Chandler, P., & Sweller, J. (2003). The expertise reversal effect. *Educational Psychologist*, 38(1), 23–31. `https://doi.org/10.1207/S15326985EP3801_4` (Supported by recent meta-analytic syntheses on instructional assistance for low vs. high prior knowledge learners, 2025).
- **Methodology**: Synthesis of aptitude-treatment interaction experiments across technical and mathematical training.
- **Measured Outcome**: Post-test transfer performance and cognitive efficiency.
- **Effect Size**: Reversal of instructional effectiveness ($d > 0.50$ in favor of guided examples for novices vs. $d < -0.30$ penalty when redundant guidance is forced on advanced learners).
- **Limitations & Moderators**: Requires reliable rapid estimation of learner prior knowledge (via pre-test or rapid rapid-verification tasks).
- **Applicability**: All scaffolded tasks (`procedural_quantitative`, `conceptual_relational`, `sublexical_orthographic`).
- **Recommended Implementation**: Always allow immediate demonstration of competence (Direct Access & Rapid Challenge); fade or remove scaffolding immediately when competence is shown.
- **Test Plan**: Verify scaffolding state machine transitions directly to unassisted practice after 2 consecutive unassisted correct responses.

---

## 3. Adult Literacy & Phonological-Orthographic Learning

### ER-06: Systematic Phonics, Orthographic Mapping & Adult Reading Interventions
- **Citations**:
  1. Ehri, L. C. (2005). Learning to read words: Theory, findings, and issues. *Scientific Studies of Reading*, 9(2), 167–188. `https://doi.org/10.1207/s1532799xssr0902_4`
  2. Castles, A., Rastle, K., & Nation, K. (2018). Ending the reading wars: Reading acquisition from novice to expert. *Psychological Science in the Public Interest*, 19(1), 5–51. `https://doi.org/10.1177/1529100618772271`
  3. Systematic reviews of adult literacy & reading interventions (e.g., National Research Council / adult literacy intervention syntheses through 2026).
- **Methodology**: Systematic reviews and meta-analyses of child and adult reading instruction.
- **Population & Sample Size**: Emergent child readers (large-scale consensus) and adult basic education / ESL learners (smaller, more heterogeneous cohorts).
- **Measured Outcome**: Phonemic decoding, word recognition, spelling, and reading comprehension.
- **Effect Size & Nuance (Mixed Evidence Note)**: Explicit grapheme-phoneme instruction shows consistent positive effects on **decoding accuracy**, but adult reading intervention reviews show **smaller and more mixed transfer effects** on broader reading fluency and passage comprehension unless paired with meaningful adult vocabulary and functional context. Furthermore, there is **no empirical basis for a universal 95% known-grapheme lock** before allowing learners to view functional words or stories.
- **Applicability**: `sublexical_orthographic` and adult literacy tracks.
- **Recommended Implementation**: Preserve `LITERACY_ACCESSIBILITY_PLAN.md`'s principle that stages are **recommendations, not hard gates**; combine systematic phonics/decoding practice with functional adult survival vocabulary (`survival_word_item.dart`) and audio-supported text.
- **Test Plan**: Ensure all literacy screens remain accessible without progression locks and record sub-skill accuracy (decoding vs. functional word comprehension) independently.

---

## 4. Open-Book Examinations & Reference Navigation

### ER-07: Open-Book vs. Closed-Book Assessment & Information Foraging
- **Citations**:
  1. Durning, S. J., Dong, T., Ratcliffe, T., Schuwirth, L., Artino, A. R., Boulet, J. R., & Eva, K. (2016). Comparing open-book and closed-book examinations: A systematic review. *Academic Medicine*, 91(4), 583–599. `https://doi.org/10.1097/ACM.0000000000000977`
  2. Pirolli, P., & Card, S. (1999). Information foraging. *Psychological Review*, 106(4), 643–675. `https://doi.org/10.1037/0033-295X.106.4.643`
- **Methodology**: Systematic review of 37 studies comparing open-book and closed-book exams; cognitive modeling of information search.
- **Measured Outcome**: Exam score, time per item, preparation behavior, and deep vs. surface retrieval.
- **Findings & Moderators (Mixed Evidence Note)**: Open-book vs. closed-book performance is **highly dependent on preparation and timing conditions**. Learners frequently under-prepare for open-book exams assuming they can look up every answer, leading to severe time-outs when they lack mental indexing of the reference structure. There is **no universal "30% memorize / 70% lookup" ratio**—the optimal balance depends on the specific exam's item count, time limit, and reference book structure.
- **Applicability**: `reference_navigation` tasks and `EXM_00` architecture.
- **Recommended Implementation**: Measure the **6 distinct open-book competencies** independently: (1) Resource selection, (2) Section location, (3) Provision location, (4) Exception comprehension, (5) Scenario application, and (6) Execution within the exam's specific time budget (`EXM-01..03`).
- **Test Plan**: Verify `EXM` progress and diagnostics report each of the 6 competencies separately rather than blending them into a single lookup score.

---

## 5. Transfer-Appropriate Processing, Confidence & Psychometric Calibration

### ER-08: Transfer-Appropriate Processing & Production Modality
- **Citations**:
  1. Morris, C. D., Bransford, J. D., & Franks, J. J. (1977). Levels of processing versus transfer appropriate processing. *Journal of Verbal Learning and Verbal Behavior*, 16(5), 519–533. `https://doi.org/10.1016/S0022-5371(77)80016-9`
  2. MacLeod, C. M., Gopie, N., Hourihan, K. L., Neary, K. R., & Ozubko, J. D. (2010). The production effect: Delineation of a phenomenon. *Journal of Experimental Psychology: Learning, Memory, and Cognition*, 36(3), 671–685. `https://doi.org/10.1037/a0018785`
- **Measured Outcome**: Cued/uncued recall when test format requires spoken or generative production.
- **Findings & Limitations**: Recognition practice (4-option MCQ) poorly predicts uncued oral recall, **but speech-onset latency varies widely across individuals, second-language speakers, and age groups** and must **never** be used as a disqualifying mastery gate.
- **Recommended Implementation**: Match practice response format to target exam format (e.g., oral/free-recall practice for USCIS civics interview) while treating response latency as non-punitive diagnostic metadata.

### ER-09: Small-Sample Psychometric Calibration & Memory Modeling
- **Citations**:
  1. ETS Research Reports on Small-Sample IRT Item Calibration & Prior Specification (e.g., Mislevy, 1986; Haberman / ETS small-sample linking and Bayesian prior studies).
  2. Pelánek, R. (2016). Applications of the Elo rating system in adaptive educational systems. *Computers & Education*, 98, 169–179. `https://doi.org/10.1016/j.compedu.2016.03.017`
  3. Jarrett, D., Ye, J., et al. (2023–2025). Open-Spaced-Repetition / FSRS (Free Spaced Repetition Scheduler) benchmark & memory equations.
- **Findings & Limitations**:
  - IRT 2PL/3PL item parameters ($a_i, b_i$) require substantial sample sizes ($N \ge 200\text{--}500$ for stable 2PL discrimination) and cannot be fabricated from deterministic text features at $N=0$.
  - **Content complexity priors**, **psychometric item difficulty ($b_i$)**, and **individual FSRS memory difficulty ($D$)** measure different phenomena and must remain separate fields in the database and analytics engine.
- **Recommended Implementation**: Keep cold-start content complexity (`content_complexity_profile`) separate from empirical item parameters (`item_psychometrics`, initialized as `unobserved`) and from versioned FSRS learner memory state (`review_items`).
