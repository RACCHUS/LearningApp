# 07 — Readiness, Transfer Validation & Real-World Outcome Calibration

This specification governs how LearningApp evaluates learner readiness, prevents inflated readiness claims, and validates cold-start and empirical models across distinct domains.

---

## 1. The Six Questions of Defensible Readiness

Content verification is not learner mastery, and answering unverified questions does not prove official exam readiness. Before presenting a learner as ready for an examination or milestone, the system evaluates six distinct questions:

1. **Is the content trustworthy?** (`content_trust_level` $\in$ `{editorially_reviewed, authoritatively_verified}`)
2. **Does it cover the intended official blueprint?** (`blueprint_alignment_state == blueprint_weighted` across required exam parts/domains)
3. **Does the learner understand the concepts?** (Acquisition & multi-facet comprehension evidence)
4. **Can the learner retrieve the knowledge after a delay?** (Spaced retrieval stability across intervals, not just same-day repetition)
5. **Can the learner transfer the knowledge to unfamiliar problems?** (Performance on **held-out / novel items** not seen during repetitive drill)
6. **Can the learner execute under actual examination conditions?** (Performance under real timing, reference book manifests, and response format rules in `EXM-03` / mock sessions)

### Hard Honesty Guardrails (Reinforcing `EXM_00` & `UI_ARCHITECTURE_LOCKED.md`)
- **Knowledge evidence and reference-navigation evidence remain separate.** High conceptual quiz accuracy never masks slow or inaccurate code-book lookup in open-book exams.
- **Official requirements remain distinct from app estimates.**
- **Low sample sizes or incomplete blueprint coverage cannot justify high-confidence readiness claims.**
- **Personal imports (`personal_import`) never enter official exam-readiness calculations.**

---

## 2. Domain-Appropriate Cold-Start Validation (Before Crowd Telemetry Exists)

The Florida contractor pilot in `EXM-00` is an end-to-end proving ground for **open-book licensing exams**, not a restriction on the rest of LearningApp—and it cannot by itself validate adult literacy, oral production, or procedural calculations.

Each major task family therefore requires its own domain-appropriate validation protocol:

| Task Family | Proving Ground / Validation Target | Cold-Start Validation Method (Phase 6) |
|---|---|---|
| **Open-Book Reference & Licensing (`EXM`)** | Florida DBPR Certified Contractor (`Pilot A`) & Florida Insurance (`Pilot B`) | Expert-reviewed blueprint mapping, R1–R4 lookup accuracy/pacing on held-out provisions, and candidate mock-to-actual exam comparison |
| **Adult Literacy & Decoding** | Adult Phonics, CVC, Decoding & Functional Survival Words | Alignment with adult reading intervention evidence (`ER-06`), sub-lexical decoding vs. sight-word transfer on held-out decodable passages, and accessibility/screen-reader audit |
| **Oral Production & Civic Milestones** | USCIS 2025 (128-item pool) & Form N-400 Spoken Practice | Acoustic prompt comprehension + spoken free-recall grading against official acceptable answer sets without visual MCQ cues |
| **Procedural & Quantitative Calculations** | Trade Estimating, Dosage & GED Quantitative Bridge | Held-out parameterized word problems testing whether adaptive worked-example fading transfers to unassisted setup and unit-accurate solutions |
| **Conceptual & Technical Systems** | CompTIA Security+ (`SY0-701`) & CS Core | Held-out scenario transfer items and contrastive discrimination between `confusable_group_id` pairs |

---

## 3. Real-World Outcome Capture & Calibration (`Phase 7`)

1. **Opt-In Exam Outcome Reporting**:
   - Learners who sit for an official exam can record their outcome (pass/fail, date, optional official domain breakdown) linked to a frozen snapshot of their pre-exam readiness metrics.
   - Where public state licensing rosters exist (e.g., Florida DBPR), optional consent-based license verification can confirm issued status.
2. **Never Invent Outcomes from Practice Scores**:
   - Practice exam scores, FSRS retrievability, and real-world exam outcomes are stored and reported as strictly distinct facts.
   - Calibration curves compare predicted readiness bands against observed outcomes only when sample size thresholds and privacy guards are met.
