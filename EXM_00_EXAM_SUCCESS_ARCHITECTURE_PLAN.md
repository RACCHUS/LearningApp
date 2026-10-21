# LearningApp — Exam Success, Reference Mastery & Adaptive Preparation

**Document ID:** `EXM-00`  
**Status:** **APPROVED ARCHITECTURE v6 — owner-authorized EXM-P0 development only; no production deployment**  
**Prepared:** October 18, 2026  
**Revised:** October 18, 2026 (v6: staged reviewer recruitment, capped separate selection probes, 2027-effective learner gate, mandatory current-outline verification; no development date schedule)  
**Repository path:** `EXM_00_EXAM_SUCCESS_ARCHITECTURE_PLAN.md`  
**Repository:** `RACCHUS/LearningApp`  
**Code baseline reviewed:** `main` at `8ef15b99092a4dcb31f1a934facfdbfc97ac96a1` (latest returned by the GitHub connector during this review). Recheck HEAD before implementation.  
**Inputs:** Original EXM-00 proposal, two subsequent architecture reviews, direct GitHub code inspection, and primary examination authority documents listed in §15.  
**Implementation authorization:** Owner authorized creation of a feature branch, root-level plan, and EXM-P0 implementation. No authorization to merge or deploy to production.
**Scheduling policy:** Phases and gates define dependencies and authorization checkpoints, **not calendar deadlines or promised delivery dates**. Official examination and reference-manifest effective dates remain mandatory data because they determine which rules and answer keys are valid.  
**Single source of truth:** **This is the only EXM planning document required for repository use.** It supersedes the earlier EXM plan and the separately circulated critique/review drafts. Technical design, phase gates, acceptance tests, and the executable Antigravity handoff are contained here. Append agent findings **only to Appendix A**; substantive changes to approved design decisions require owner review. Do not require, create or reference companion EXM audit/handoff/decision Markdown files unless the owner specifically asks.

---

## 0. Decision summary

**Product decision proposed:** Build an *exam-aware preparation layer* inside LearningApp, not a separate examination platform and not merely a collection of exam courses.

A candidate might need to **memorize**, **recognize the right reference**, **find a provision**, **interpret an exception**, **calculate**, **make a decision**, **perform a task**, or **finish within a time limit**. Those are different competencies. Exam preparation must reflect the rules and skill demands of each exam and each relevant exam part.

**Recommended implementation decisions:**

1. Preserve the existing **Learn / Library / Progress**, direct-choice, canonical concept, versioned target, assessment, and pathway architectures.
2. Keep **stable exam-part structure and strategy** in a typed, validated configuration associated with the existing target version; keep **approved reference lists, editions, and room-specific rules in an independently versioned, effective-dated manifest**. Do not clone curriculum merely because a reference list changes.
3. Represent **official requirements** separately from **LearningApp recommendations** and **app estimates**. An unknown requirement must not inherit a generic default and become an apparent official fact.
4. Keep reference-navigation, interpretation, and exam-execution evidence distinct from global `user_concept_state` knowledge evidence. Keep administrative checklist completion separate again.
5. Start **reference drills with candidates' own eligible physical books** and original, reviewed practice items. Do not upload protected books or copied exam banks.
6. Reuse existing assessment interaction types for the first vertical slice. Add a distinct interaction type or table only when a concrete gap is demonstrated and reviewed across Dart, renderer, scoring, SQL constraints, ingestion, and tests.
7. Ship an **independent EXM-P0 exam-engine safety PR immediately after authorization**, ahead of the wider EXM-00/01/02 work: no unsupported issuer-scale display or misleading aligned-mode defaults and fallbacks.
8. Pilot **one Florida construction exam part** before broad expansion; use a verified Florida insurance exam as a contrasting second pilot, with digital-reference and hands-on assessments later.
9. Treat improved **real-world results** as an evaluation goal, not an unverified claim. Test accuracy, retrieval, speed, interpretation, transfer, and—if voluntarily reported—actual outcomes.
10. Fix a **24-item production pilot budget** (16 practice, 8 held-out), **separate from at most four nonproduction pilot-selection probes across all candidate parts**. Begin scouting people with general Florida construction/code-book competence alongside EXM-P0; confirm part-specific expertise, exact-edition access and the final independent reviewer **after the part is selected**. **One authoritative human-author/independent-reviewer rule governs reviewed items (§3.4)**, including AI-assisted items and recurring re-review. This is a learning-UX pilot, not a defensible full-exam simulator.
11. Version **item answer-location validity against the exact immutable reference-manifest revision**. Define the contract in EXM-00, but **implement binding and re-review with actual items in EXM-02A**, not EXM-01. An edition update blocks unreviewed locations; no silent inheritance of answer keys.
12. Complete **durable, account-isolated drill-attempt persistence in EXM-02B**, following the reference-drill MVP and **before any external pilot**. Leave EXM-03 to focus on realistic timed simulation. Select the contractor pilot principally for its ability to prove **building-code/reference navigation**, using edition churn as a secondary budget constraint—not the deciding factor.

13. **Author and review the first live pilot items for the officially verified 2027 reference-manifest revision** (or the correct current successor). **Initially offer those reference-specific drills only to learners whose actual exam administration is covered by that effective revision.** Learners testing under 2026 rules retain access to general study, but cannot be shown 2027-specific checklists/drills as applicable; verified 2026 practice requires a separately approved 2026 manifest and item bindings. Confirm the official exam-part content outline is still current before the owner approves pilot selection. Independently validate every effective-date or midyear edition transition in primary PDFs before publication.

**Not in scope now:** Marketplace, creator monetization, full standards-text hosting, uncontrolled AI generation, official pass-rate prediction, large-scale multi-exam authoring, production Supabase writes, and speculative delivery-date estimates.

---

## 1. Problem, outcomes, and non-goals

### 1.1 Core problem

Traditional preparation often teaches examinable content without teaching *how* the actual assessment must be completed. An open-reference candidate can know construction concepts but still fail to locate the correct rule in time; another can locate a code section but misapply an exception. Conversely, a closed-reference exam may require reliable retrieval under time pressure, and a practical assessment may require safe, observable task execution.

**Product law:** *Knowledge is global. Learning is scoped. Exam conditions are versioned and exam-specific. Exam skills are demonstrated under those conditions.*

### 1.2 Outcomes

The learner should be able to answer, in plain language:

- What must I **remember**? What may I **look up**? What must I **apply or demonstrate**?
- Which references, editions, tools, modifications, and navigation actions are actually permitted for **my exam part and date**?
- Am I weak at choosing a book, finding a chapter, reading exceptions, calculating, or pacing?
- What is the **next useful exercise**, and why?
- How much evidence supports a readiness statement—and what remains unassessed?

### 1.3 Explicit non-goals / honest claims

- Completing a course, an eligibility pathway, a practice examination, and passing the real examination are **distinct** events.
- LearningApp cannot authorize someone to sit an exam, issue a professional license, or determine legal eligibility.
- The app will not promise a passing result or claim an empirical probability of passing without validated longitudinal outcome data.
- No exam-prep recommendation overrides the candidate handbook, regulator, or testing vendor's actual policy.
- A browser simulation is not guaranteed to reproduce a secure examination center, prevent external assistance, or be psychometrically equivalent to an official test.

---

## 2. Existing implementation and immediate safety findings

**Verified in source (not a hosted-behavior claim):** `MockExamBlueprint`, `MockExamGeneratorService`, `MockExamSession`, `ExamEvaluationService`, `ExamSessionNotifier`, `AssessmentItemRenderer`, target-version metadata/provenance, `ScopeResolver`, knowledge/readiness services and P2h route readiness all exist on the audited `main` commit. The specific files are linked in §15; code-path evidence and implementation acceptance criteria are included in this document. Recheck newer `main` and CI before implementation.

**Confirmed hazards requiring a separate near-term PR:**

- Generic `90`-minute / `750` / `100-900` defaults may be misrepresented as authoritative exam facts.
- `_calculateScaledScore` performs a linear percentage-to-100–900 conversion, not a validated issuer scoring model.
- Unmapped mock items can be assigned to the highest-weight domain; a content shortage can yield fewer items than requested.
- One-second ticker / unconstrained pause/resume require hardening before a high-fidelity timer claim.
- Eight assessment types are declared but the inspected renderer has working branches for four; use supported types for the pilot.
- Pathway readiness writes device-wide base keys, creating a shared-device account-isolation concern.

**Part-scoping audit:** `ScopeResolver._resolveTargetScope` already uses `LearningContext.activeFocusId` to select a subtree for Learn. The generic `scope_config` itself does **not** currently supply the exam-part filter. `DiagnosticAssessmentService`, `TargetReadinessService` and `MockExamGeneratorService` query by whole `targetVersionId`, not the selected part subtree; **part-specific diagnostics, readiness and mock generation need explicit scope propagation and regression tests**. Do not claim a part has isolated readiness merely because Learn displays its focused lessons.

**Hosted status:** not audited here. Each claim remains distinct as proposed / coded / tested / hosted / learner-validated.

---

## 3. Configuring an examination: multidimensional profile

Avoid a single `is_open_book` boolean. Treat archetypes as **preparation recommendations**, not official categories.

| Dimension | Example values / considerations |
|---|---|
| Credential and exam identity | Issuer, jurisdiction, exam code, language, part, administration date, destination linkage |
| Source validity | Official source, rule-level anchor, review date, effective/superseded interval, verification state |
| Reference access | None, candidate-supplied paper, exam-supplied digital, restricted selection, mixed |
| Reference constraints | Exact editions, permitted formats, binder requirements, tab/annotation/highlight rules, allowed calculators |
| Exam structure | Sections, item/task counts, weights, conditional/variable item counts, breaks |
| Timing | Whole-exam versus section clocks, fixed versus variable duration, timeouts, scheduled breaks |
| Navigation | Can revisit? flag? skip? navigate sections? change earlier answers? |
| Item format | Single choice, multiple response, case, numeric, written, oral, adaptive, practical |
| Scoring | Raw/percentage, rubric, scaled, pass/fail, multi-component requirements; unknown conversion stays unknown |
| Demonstrated abilities | Recall, reference selection/location, interpretation, application, practical task, execution |
| Access and accommodations | Language, accessible mode, documented official request process; individual accommodation conditions |

**Field states:** `verified`, `unverified`, `unknown`, `not_applicable` (with an optional `superseded` at the source/record level). Every asserted **official** field must link to reviewable primary-source evidence and an applicable effective period. Recommendations are separately labeled and can change without rewriting history of official requirements.

### 3.1 Exam archetypes (combinable)

1. **Closed-reference knowledge** — retrieval, understanding, mixed questions and recall under timed conditions.
2. **Candidate-supplied physical reference** — source recognition, allowed-book familiarity, indexed chapter/section location, interpretation and pacing.
3. **Supplied digital reference** — document navigation, keyword search, chapter-only interfaces, interpretation, prohibited external copies.
4. **Case/scenario judgment** — clinical, compliance, legal, engineering and other case-based decisions and multi-step justification.
5. **Practical/performance** — real task demonstration, safety, sequence, calibrated rubrics, observable evidence.
6. **Written/oral/project** — communication, defensible reasoning, time-bounded composition or live demonstration.

An examination may combine several archetypes and contain **unreferenced field-experience questions even when some references are permitted**. The blueprint—not a convenient label—determines what the learner practices.

### 3.2 Exam-part modeling: avoid accidental target duplication

**First-choice proposal:** Retain the existing learning destination as the overall credential/licensure goal and identify exam parts by stable keys within a versioned exam configuration (e.g., `contract_administration`, `project_management`, `business_finance`). Each part maps to a verified **curriculum-subtree root ID** (or an explicitly defined set where a tree cannot represent the part cleanly). Part-specific rules identify the part, never silently borrow another part's reference list.

**Scope implementation reality:** Learn can already focus descendants via `activeFocusId`, but mock generation, diagnostics, and target readiness are currently target-version-wide. Introduce a stable `exam_part_key` + validated node-scope resolution contract that each consumer uses; ensure the selected part and profile revision travel through the diagnostic/session/evidence/report pipeline. `scope_config` alone is **not currently sufficient**. Distinct part session state/caches must not bleed into another part, and cross-part knowledge concepts may still be reused globally. 

Create standalone `learning_targets` for parts **only if** those parts truly need independent public discovery, course scoping, cross-credential reuse or long-lived version governance. Do not equate a credential, licensing path, exam administration, exam part and course. Audit the catalog/linking schema before choosing a cross-reference table.

### 3.3 Example configuration: illustrative schema, not verified exam facts

The following is a **draft design shape** and must not be inserted as official data:

```json
{
  "exam_preparation": {
    "schema_version": 1,
    "exam_parts": [
      {
        "key": "illustrative_part",
        "display_name": "Illustrative exam part",
        "requirements": {
          "reference_mode": {
            "state": "unknown",
            "value": null,
            "evidence_ids": []
          },
          "time_limit_minutes": {
            "state": "unknown",
            "value": null,
            "evidence_ids": []
          },
          "navigation_can_revisit": {
            "state": "unknown",
            "value": null,
            "evidence_ids": []
          },
          "passing_standard": {
            "state": "unknown",
            "value": null,
            "evidence_ids": []
          }
        },
        "reference_manifest_selector": {
          "exam_part_key": "illustrative_part",
          "exam_date": null,
          "source": "independent_effective_dated_manifest"
        },
        "preparation_strategy_key": "reference_learning_v1",
        "simulation_fidelity": "practice_only"
      }
    ],
    "source_evidence": [],
    "review_status": "draft"
  }
}
```

`source_evidence` needs stable source IDs, publisher, official URL, page/section/anchor, checked-at date, applies-from/until, copyright/access condition, reviewer and verification outcome. Avoid putting personal data in this public configuration. Extend existing provenance records where possible; the JSON above is *not* a final production schema.

**Storage boundary (decision):** Stable part identity and selected curriculum/strategy configuration may begin in typed, schema-validated `target_versions.metadata`. **Do not embed the authoritative approved-reference manifest or mutable examination-room reference policy there.** Annual/periodic changes would otherwise require an unnecessary new immutable target version and potentially new curriculum snapshots.

Introduce a **minimal independent, effective-dated reference-manifest version record** for the first real pilot (candidate design: `exam_reference_manifest_versions`): stable exam/part key, manifest revision, effective `from/until`, official source URL and checked-at/reviewer metadata, review/publication status, list of reference titles/editions/allowed forms, and policy fields for binding, tabs, annotation, highlighting, copies and materials. Use validated JSONB **inside the independently versioned record** for the small list initially; relationalize entries only when necessary. A changed list publishes a new manifest revision, not a target-version clone. A source-governed status-only retirement transition is permitted; published content is otherwise immutable. Exact identity/FK/RLS/publication design is an EXM-00 schema-decision item.

**Resolution policy:** Select the manifest based on **exam + part + actual administration date**, never the current calendar alone. Detect overlapping coverage, no match, unknown date, withdrawn lists and contradictory source facts; display `unknown`/`historical` and withhold list-specific official claims rather than guessing. Preserve the exact selected manifest revision on each attempt. Historical content mappings must not silently shift to newer editions.

**Evidence:** Reuse `content_source_releases` / `content_source_mappings` where the entity model and cardinality permit; independently versioned manifest facts still need rule-level anchors and validation. Partial profiles and draft/unknown fields are allowed; only **unsupported official assertions** and higher-fidelity operations are gated.

### 3.4 Answer-location validity is edition/revision-specific (mandatory)

**New explicit item-level contract:** Each reference-dependent exercise has reviewed answer-location bindings that state **which immutable reference-manifest revision(s) make that answer key valid**. **EXM-00 specifies this contract; EXM-02A implements and tests it with actual reviewed items. EXM-01 publishes reference manifests without prematurely constructing an untestable item workflow.** Proposed conceptual fields (not approved SQL) are:

```yaml
assessment_item_id: <existing UUID>
item_content_revision: 1
location_answer_revision: 1
valid_for_manifest_revision_ids: [<immutable manifest UUID>]
reference_edition_key: <verified exact publication/edition ID>
expected_location: { chapter: "...", section: "...", table: null }
citation_source_release_id: <source release UUID>
author_id: <accountable human author of record; never AI>
ai_drafted: false  # true when AI materially drafted/rewrote content; AI is not the author of record
review_status: approved
reviewed_by: <independent qualified human reviewer ID>
reviewed_at: <timestamp>
```

The manifest identifier must not be a bare calendar year, reused string label or mutable "latest" pointer. Implement with a reviewed, versioned JSON mapping **only if its cardinality, authorship, independent reviewer identity, RLS, source anchors and append-only changes can be enforced**. Otherwise use a minimal additive `assessment_item_reference_validity`-style table linked to the item, answer revision and manifest-version identity. Review whether existing `content_source_mappings` uniqueness permits all required per-item and multi-location citations; do not assume it does.

**Canonical editorial rule (the single authoritative definition for all phases):** The **author of record is always an accountable human**, including when AI produces a first draft or substantial rewrite; **AI is never an author of record or an eligible approving reviewer**. Store the human author ID and `ai_drafted` provenance truthfully. 

**The accountable author may not be the sole reviewer**: publication requires recorded approval by at least one **different, demonstrably qualified human reviewer**, with access to every exact cited source edition, source/section/exception validation, rights review, approval date and reviewer identity. This applies equally to owner-authored, externally authored and AI-assisted items, and to every new manifest binding. If independence, qualifications, access or provenance is missing, block publication. **Recruitment is two-stage:** alongside EXM-P0, scout and assess a pool with general Florida construction, code-book and technical-reference competence; **after EXM-00 selects the exact category/part**, confirm the approving reviewer's part-specific expertise, independence, actual access to every cited **applicable edition**, availability and terms before assigning production items. A reviewer of an early selection probe must be competent for, and have access to, that probe's exact sources; exploratory sketches without this evidence are not reviewed probes. Do not assume the owner is licensed or qualified, and do not commit to a part-specific hire merely to start scouting. All further mentions of item approval in this plan refer to **this §3.4 rule**; do not restate a potentially drifting alternate rule elsewhere.

**Manifest transition workflow (implemented and tested in EXM-02A, after item creation):** On a new manifest or amended approved edition: (1) diff books, editions, included provisions and room rules; (2) mark previously approved item-location bindings **pending re-review for the new revision**, even when a book title appears unchanged; (3) have a qualified reviewer holding the exact new editions re-validate every location, exception and solution; (4) publish new signed-off bindings or withhold/remove unsupported items; (5) preserve prior bindings/attempt history unchanged. Verified unaffected items can be **batch re-approved with recorded evidence**, never automatically carried forward. If no sufficient approved items remain, block that drill or downgrade to an appropriate non-reference practice mode.

**Recurring editorial cost:** Each annual or interim revision triggers a potentially full review of the **24 initial items** (and every item added later). Budget `items requiring re-review × measured reviewer minutes per item`, plus acquisition of updated editions, dispute resolution and re-testing. Time/cost estimates must be based on the pilot's actual reviewer logs, not an arbitrary prediction. This becomes a recurring operating expense, not a one-off authoring cost.

**Exam-specific timing, passing criteria and navigation:** Static, reviewed facts can remain in the profile for the pilot; if these also evolve independently of curriculum, follow the same separate revision mechanism without copying courses or concepts. Prove the versioning boundary with two-year manifest fixtures.

---

## 4. Skill and evidence model: what is actually being learned?

| Dimension | Observed evidence | Must not be confused with |
|---|---|---|
| **Concept knowledge** | Correct recall, understanding, application across varied items; existing `user_concept_state` | Finishing a lesson or fast lookup |
| **Reference selection** | Choosing the correct allowed resource for an unfamiliar scenario | Memorizing a book title |
| **Reference location** | Correct chapter/section/table; timed with clearly defined start and stop events | Guessed section, claimed physical lookup |
| **Interpretation** | Correct scope, definition, exception, applicability | Merely finding text |
| **Calculation/application** | Correct calculation, rationale or resultant action | Guessing a final multiple-choice answer |
| **Exam execution** | Completion, timed accuracy, pacing, handling flags and navigation | General cognitive mastery |
| **Practical performance** | Validated rubric, safety and procedural steps; observer/self-report labels | Academic MCQ score |
| **Administrative checklist** | Self-reported IDs, registration, materials and other logistics | Legal eligibility or exam readiness score |

**Strong invariant:** A reference-lookup exercise must not automatically update `user_concept_state`. Only an appropriate independent assessment of underlying concept understanding may create concept evidence, even if it appears in a reference drill. Implement separate skill evidence and provenance; keep metrics parallel, not one blended grade.

### 4.1 Evidence sufficiency and provenance

Report **not assessed / limited / developing / strong practice evidence** with a sample size, date range, difficulty/mix and appropriate calibration. “Strong practice evidence” is not “licensed,” “officially passed,” or “will pass.”

Store distinct fields for **app-observed**, **self-reported**, and **instructor-verified** behavior. For an exercise using a physical book, the app can observe the time between taps and the entered answer but **cannot prove** that the learner physically navigated the book rather than guessed. This limitation belongs in reporting and learner validation.

A timed drill needs: profile revision; exam part; **immutable reference-manifest revision ID**; exact reference edition; **item ID and reviewed item/answer-location revision**; response; intended/actual mode; timestamps; elapsed active time; help/hints used; expected citation; source/section correctness; interpretive correctness; device-session/user namespace; and scoring algorithm version. Historical attempt reports must resolve against the revisions saved when the attempt occurred, not the current manifest. Minimize stored data and retain only what the product uses.

---

## 5. Reference Mastery: the first differentiating feature

### 5.1 The four drills

**Drill R1 — Which reference?** Present a new problem and a shortlist of allowed resources. Score selection accuracy and show why the source applies.

**Drill R2 — Where in the reference?** Learner finds chapter, section, table, figure or procedure. Use reviewed identifiers and versioned editions. Capture step-level accuracy and time; do not equate page number with stable identity.

**Drill R3 — Does it apply?** After presenting or finding the provision, learner identifies controlling scope, definition, exception or formula, then chooses the appropriate interpretation.

**Drill R4 — Full chain.** Given a realistic scenario, the learner selects source → locates rule → interprets → solves → finishes under a budget. Analyze where time and errors arose.

Practice feedback example (illustrative, not measured):

> Correct reference: 9/10. Correct location: 6/10. Correct interpretation: 5/10. Median app-measured response time: 2m 45s. Priority: finding sections and reading exceptions.

Avoid a composite mastery score that hides the weak link.

### 5.2 Reference acquisition strategy

**MVP: learner's own eligible physical books.** Link to verified official reference lists, distinguish books permitted in the room from *study-only* materials, ask the learner to identify owned editions, use original questions, and validate *section identifiers* against reviewed answer keys. Hosting no book text reduces licensing exposure, but **does not authorize copying third-party questions or protected table-of-contents content**.

**Next: metadata/navigation model.** Use book-level metadata, author/publisher, edition, chapter IDs and permitted snippets only where rights and attribution permit. Metadata may still require verification of public reuse rights or provider terms.

**Later: licensed/public-domain digital references.** Support realistic search, linked chapters, and versioned displays only under documented rights and technical constraints. Do not redistribute protected PDF handbooks without permission.

### 5.3 Rule-aware physical preparation

The official Florida DBPR site currently publishes **separate construction reference lists effective January 1, 2026 and January 1, 2027**, with categories and reference requirements differentiated by exam type. Its construction-examination page identifies approved reference requirements and links the candidate information booklet. Never prefill a learner's checklist using the wrong effective-year list. [DBPR reference lists](https://www2.myfloridalicense.com/examination-information/construction-examinations-reference-lists/) · [DBPR construction examinations](https://www2.myfloridalicense.com/examination-information/construction-examinations/)

**Primary-document example only (not a CGC/CBC rule):** The [Florida DBPR *Service Pool Contractors Trade Knowledge Exam Reference List*, pp. 1–2, valid January–December 2026 (official PDF)](https://www2.myfloridalicense.com/servop/testing/documents/Service%20Pool%20CBT%20Reference%20List%20-%20Even.pdf) says reference books must remain bound, allows existing underlining/highlighting, prohibits handwritten/typewritten notes and movable tabs, and prohibits making marks *during* examination administration. It allows specified bound PDF copies, subject to its binding conditions; bringing other editions is at the candidate's risk. Thus "no marks during exam" is **not** "no highlighting already in the book." This is an exam-specific example and **must never be automatically carried over to CGC/CBC**. The exact latest official requirements for the chosen part/date still need review.

For tabs, binding, copies, notes, highlighting, calculators and bring-to-room permissions, require **current, exam-part-specific** handbook evidence. A personally useful tab, annotation or homemade index can still be forbidden inside a live exam. The future private reference-index feature must carry a conspicuous *study-only unless independently authorized* distinction.

### 5.4 Digital-reference contrast

NCEES PE Civil examinations use **exam-supplied electronic handbooks and specified design standards**, not candidate-brought copies; the supplied PDFs are searchable and chapter-linked. NCEES lists **design-standard revisions effective April 2027** for affected disciplines. The public page is sufficient to establish the model contrast, but the exact discipline's standards and period need their own profile review. [NCEES PE Civil](https://ncees.org/exams/pe-exam/civil/) · [NCEES handbook use restrictions](https://help.ncees.org/article/87-ncees-exam-reference-handbooks)

A digital-navigation simulator must model the **actual supplied interface constraints** rather than simply granting unrestricted web or PDF search. Do not infer the testing center's search behavior from a third-party PDF viewer.

---

## 6. Reusable exam skill modules

Modules are normal reusable learning resources with objectives. Exams **attach/configure** them; they are not copied into a new course for every credential.

| ID | Reusable module | Example skills | Priority |
|---|---|---|---|
| `SKL-01` | Pacing, triage and finishing | Budget, skip/return **only where permitted**, unfinished-item prevention | MVP |
| `SKL-02` | Physical open-reference strategy | Choosing a book, section search, legal book preparation, over-search avoidance | MVP |
| `SKL-03` | Digital-reference navigation | Keywords, chapters, results, cross-references, allowed search scope | Later |
| `SKL-04` | Multiple-choice reasoning | Read the stem, check units, distractors, justified selection | MVP |
| `SKL-05` | Calculations under time | Estimate, compute, validate, authorized calculator use | Later |
| `SKL-06` | Case and scenario reasoning | Facts, priorities, exceptions, decision rationale | Later |
| `SKL-07` | Exam-software familiarity | Flagging, navigation, locks, tutorial | Later |
| `SKL-08` | Exam-day logistics | IDs, material eligibility, check-in, accommodation instructions | Profile-specific checklist |
| `SKL-09` | Managing pressure and attention | Realistic rehearsal, error reduction, recovery | Later |
| `SKL-10` | Practical assessment execution | Safe order, observable rubrics, equipment checks | Later |

**No mandatory course wizard.** An exam profile may propose appropriate modules; direct learner choice remains available within the locked navigation architecture.

### 6.1 Time management is exam-conditioned

Reusable pacing logic may compute a *suggested* average time per item from **verified** question count and time allowance, adjusted for section locks, mixed difficulty and permitted breaks. A two-pass/flag/revisit strategy appears **only when** navigation permits return. If time or question count is variable, surface a range or decline numerical pacing rather than invent an exact target. Do not punish learners using approved accommodations by applying the standard clock blindly.

---

## 7. Practice modes and simulation fidelity

### 7.1 Four modes

- **Learn:** guidance, reasoning, answer explanations; optional clock.
- **Baseline:** low-pressure diagnostic using available reviewed items; no mandatory onboarding.
- **Skill drill:** single targeted skill, repeated on varied scenarios; step-level timing and feedback.
- **Exam simulation:** only verified constraints, locked feedback, appropriate timing/navigation/reference rules and explicit fidelity label.

### 7.2 Fidelity labels and publication gates

**Delivery sequencing:** The table is the **future EXM-03 fidelity model**, not a mandate to implement four tiers in EXM-P0. Until it exists, EXM-P0 makes all reachable existing mock exams visibly **practice-only by default**, with no issuer-equivalent claim or silent official defaults.

| Label | Meaning | Minimum gate |
|---|---|---|
| `practice_only` | General educational questions or partial configuration | Clear disclaimer; cannot show official pass prediction |
| `blueprint_aligned` | Source-verified domains and sufficient mapped items | Validated domains, quotas, item counts, coverage and scoring caveats |
| `format_aligned` | Also emulates verified time, item formats, navigation and permitted resources | Policy-driven timer, no prohibited assistance, correct interaction support |
| `validated_simulation` | Independent evidence supports realism beyond format | Documented learner/outcome evaluation and limitations |

A simulator **must fail closed** to a lower label or prevent launch if:

- It has fewer unique eligible questions than required.
- Item-to-domain mappings are missing or replaced by the highest-weight-domain fallback.
- Required format types cannot be rendered and scored accurately.
- The source-effective period does not cover the selected exam date.
- Allowed materials or navigation conditions are unverified for the claimed fidelity.
- Official passing/scaling claims cannot be supported.

### 7.3 Scoring and history rules

- Display **practice raw score / accuracy / domain performance**, not a synthetic issuer-scaled prediction.
- Distinguish official passing standard, if published, from an app's scoring method and practice-only cutoff.
- Avoid a universal 80% readiness threshold as a reliable estimate of passing every exam.
- Use versioned scoring behavior. Never retrospectively rewrite historic learner results without an explicit migration/data-governance decision.
- Track the test session's profile revision, scoring version and content set. Keep archived results reproducible where feasible.

### 7.4 Clock, interruption and integrity

- Base strict timed mode on elapsed wall-clock or monotonic-time accounting designed to handle background throttling; document sleep, tab suspension and clock-change limitations.
- Define permitted pause/break behavior per mode; normal practice may pause, strict timed simulation may not unless documented rule/accommodation allows it.
- Prevent inadvertent double-submission and scoring after timeout; test refresh, app resume, network loss and repeated clicks.
- Clearly indicate that a browser cannot enforce all external-resource restrictions. The learner must voluntarily practice under equivalent conditions.

---

## 8. Learner experience: fit the locked UI

**Library:** Exam-aware published destinations show what is available, the trusted source and a concise “Exam preparation” entry. Never treat unreviewed user-created goals as official.

**Target detail:** Present a short *Before you study* card explaining the reference rule, applicable exam part, relevant date/edition, main challenge, unknowns and link to regulator instructions. When the learner's date is unknown, ask only when it materially changes the permitted reference list; never block access to general study.

**Learn:** Reuse the current context and Continue card. Suggested next action might be **Practice finding a code section**, **Study this concept**, **Do a short timed drill**, **Review exceptions**, or **Read the exam rules**. Keep first-run direct access; do not add another main navigation destination.

**Progress:** Show separated knowledge, source recognition, location, interpretation, timed execution, blueprint coverage and self-reported administrative checklist. “No evidence” is different from “poor performance.”

**Access:** Plain language, oral guidance where available, keyboard operation, responsive layout, reduced-complexity alternatives, accessible timer announcements, and legitimate accommodation-policy guidance. Do not imply app accessibility settings confer official examination accommodations.

---

## 9. Minimal implementation strategy

### 9.1 Recommended initial choices (subject to EXM-00 design gate)

1. **Config:** Validated stable exam-part/strategy information may use `target_versions.metadata`; approved reference lists and room policies use **independently effective-dated, immutable manifest revisions**. Confirm migration constraints, draft/stage/publish mechanics, resolver selectors and source-level evidence.
2. **Exam parts:** Stable keys within an overall learning target version, each mapped to scoped curriculum subtree(s). Extend diagnostics, readiness and mock selection to honor `exam_part_key` consistently; current `activeFocusId` support is **only partial**.
3. **Content:** Existing `assessment_items` with `single_choice`, `ordered_response`, or `matching` as appropriate and `metadata` marking the drill step; verified citations using `content_source_mappings` when supported.
4. **Reference answers (EXM-02A implementation):** EXM-00 documents the schema contract; build the versioned item answer-location binding and re-review workflow **alongside actual exercises in EXM-02A**, not the EXM-01 profile/references PR. Each binding needs **explicit immutable `valid_for_manifest_revision_ids`** (or normalized equivalent), item-content revision and reviewed source/edition/section; publication follows the **single editorial rule in §3.4**. Default to **no validity** for a newly released manifest until signed-off re-review. Add a table only when existing provenance/JSONB cannot safely enforce its identity/history/authorization constraints. Never mutate historical mappings or redirect past results.
5. **Progress:** Local-only **disposable** attempts may power internal EXM-02A developer prototyping. Choose the canonical storage/retention/deletion model **by the EXM-01 exit gate**; implement tested, durable owner-scoped attempts and read-time skill reporting in an **EXM-02B follow-up PR immediately after drills**. **No outside learner pilot, no claims of persistent Progress, and no EXM-03 dependency** until EXM-02B storage, RLS, guest isolation, auth-switch and deletion tests pass. Use a projection table only if evidence proves it necessary.
6. **UI:** Integrate into the existing target detail, Learn and Progress surfaces; no new global destination.
7. **Governance:** Existing guarded Supabase and content-authoring workflows; migrations append-only and deployed only with explicit authorization.

### 9.2 Existing item interaction types first

The first reference MVP does **not** require two new global assessment interaction types (`select source`, `locate section`). Source selection can initially use supported `single_choice`; a staged section/location exercise can use supported selection/ordering or a small specialized drill UI. **Do not extend the global interaction enum and SQL check constraint until the first pilot establishes a need for a genuinely new answer shape.** New type implementation requires validation in the generator, renderer, evaluator, manifest pipeline, history and database.

### 9.3 Trust and content workflow

- **Private personal exam plans** stay owner-scoped and must isolate account switching and guest mode.
- **Official exam facts** require authoritative citations; a third-party prep school's claims are not official.
- **Reviewer-edited study recommendations** stay distinct from regulator requirements.
- **Item authorship, AI provenance and review:** follow the canonical **§3.4 editorial rule**. The named human author is accountable for AI-assisted drafts; editorial approval cannot be generated by the AI.
- **Minors** and educators/creators follow existing ECO trust-and-safety architecture; do not prematurely expose public contributions.

---

## 10. Pilot sequence

### Pilot A — Florida certified contractor, **one code/reference-relevant exam part** (fixed reviewer budget)

**Selection priority: validate the original product hypothesis.** The first pilot must demonstrate **finding and correctly interpreting building-code or comparable technical-reference provisions under realistic constraints**. A lower-maintenance Business & Finance part is not automatically a better pilot if it measures accounting/statutory lookup instead. A **code-heavy Project Management or other suitable contractor part may justify higher edition acquisition and re-review costs**. Match exam category (General vs Building), part, source editions and reviewer competence precisely; do not conflate their curricula.

**Initial official outline comparison — relevant but not yet an item-level lookup analysis:** DBPR's published [Business & Finance outline](https://www2.myfloridalicense.com/servop/testing/documents/bus_fin_eci.pdf) emphasizes business administration, accounting and regulation; its [General Contractor Contract Administration outline](https://www2.myfloridalicense.com/servop/testing/documents/GC%20Contract%20Administration%20ECI%20January%202020.pdf) includes project contracts, preconstruction, approvals and interpretation of plans/codes; its [General Contractor Project Management outline](https://www2.myfloridalicense.com/servop/testing/documents/GC%20Project%20Management%20ECI%20January%202020.pdf) emphasizes construction methods/materials and expressly includes interpreting plans, specifications and codes. DBPR also provides corresponding Building Contractor outlines on its [construction examination page](https://www2.myfloridalicense.com/examination-information/construction-examinations/). These source outlines are dated **2009/2020**; **EXM-00 must verify that the cited outline is still the current official outline for EACH shortlisted category/part** by checking DBPR's current official examination page, linked outline, candidate materials and any issued updates/superseding notices. Record the official URL, document title/version, the regulator's current-listing evidence, check date, exam code/category/part and any uncertainty in Appendix A. **Do not approve or select a pilot part on an outline whose current applicability is unconfirmed**; resolve discrepancies with DBPR before relying on it. The age of an outline alone neither proves obsolescence nor establishes current validity. **An outline saying “read and interpret codes” does not establish the fraction of questions that require code-book lookup.** Measure that feasibility with a capped expert-reviewed selection sample, as defined below.

**Pilot-choice worksheet (complete from primary sources before owner approval):**

| Candidate part | Demonstrable technical-code/lookup opportunities | Other competences prominent in the outline | Reference-maintenance cost to validate |
|---|---|---|---|
| General/Building **Project Management** | Strong candidate for technical codes, construction methods, tables and plan/specification interpretation; verify the exact sample exercises against the applicable official blueprint. | Site/construction operations, materials, quantitative problem solving. | Compare 2027 official editions and any intrayear changes; estimate only after mapping proposed items to sources. |
| General/Building **Contract Administration** | Some code, permit, lien/statutory and contract-document lookup; determine whether enough original code-centric exercises are representative. | Contract terms, estimating, bids, permits and payment/closeout. | Shared GC/BC/RC list may produce similar acquisition costs; *item-specific* affected sources may differ. |
| **Business & Finance** | Useful for statutory and finance/reference navigation but not necessarily for **building-code** mastery. | Business administration, accounting and regulations. | Possibly lower edition churn, but this cannot outweigh failure to test the intended product skill. |

**Selection probe budget (separate from production items):** Allow **at most four original, nonproduction probes in total across all shortlisted parts**, not four per part and **not part of the 24-item live-pilot budget**. Use them solely to test whether a realistic task can require correct reference selection, locating and interpreting an applicable code/technical provision. Any probe counted as *expert-reviewed* must satisfy the evidence and independence requirements in **§3.4**, including an expert with the actual applicable source editions. Unreviewed concepts/sketches may guide discussion but are not evidence that a part is lookup-heavy. If reviewer/source access is unavailable for a candidate, record the assessment as **inconclusive** rather than fabricating a finding. Keep these four probes **out of the published drill bank and the held-out evaluation set**. If an owner later approves converting one to production, it must pass the full EXM-02A item/manifest review gate and **consume one of the existing 24 production slots**, rather than expanding that budget silently.

**Selection gate:** Confirm current official content outlines **first**, then demonstrate reference-navigation learning value and representative task coverage using the **maximum four selection probes**; afterward consider reviewer access/independence, exact book availability, source permissions, initial effort and **recurring revision cost**. Document tradeoffs and obtain owner approval of the specific category + part. Favor a more code-relevant part even if annual reviews are more expensive, provided the budget and reviewer can support it. Do not convert the worksheet into an unsupported “most lookup-heavy exam” ranking.

**Reference vintage and validation:** The DBPR site separately publishes [2026 and 2027 examination reference lists](https://www2.myfloridalicense.com/examination-information/construction-examinations-reference-lists/). **Build the first official-authoring and reviewer workflow around the applicable 2027 manifest**, after confirming its exact effective date(s), exam part, edition/room policies and any intrayear changes from the PDFs. Author the 24 initial items against those **2027-authorized editions**, and bind them to the exact immutable 2027 manifest revision(s). **Do not create or approve 2026 bindings by default**; do so only for an owner-approved 2026 study requirement using a separately verified 2026 manifest. A synthetic 2026→2027 regression fixture may test historical behavior without spending reviewer effort on live 2026 content. For the **initial reference-specific pilot rollout**, **only learners with an administration date covered by the reviewed, effective 2027 manifest revision are eligible** for its reference checklist and drills; this includes checking any verified intra-year change that supersedes the first 2027 revision. Learners taking an exam **before that revision takes effect** (including 2026 administrations) may use general study, but must not receive 2027-specific reference instructions or an implied 2027 readiness score. Earlier-period reference practice requires a separately verified and owner-approved period-specific manifest and reviewed item bindings. When a learner's exam date is unknown, withhold date-specific claims/drills until the applicable revision can be selected; general study stays available. Do not hardcode January 1 as a universal effective date without verifying the exact selected part's primary PDF.

**Primary-PDF comparison is an EXM-00 verification gate, not a settled finding.** Before deciding cost or publishing a checklist, open each relevant DBPR PDF **directly**, compare the full book/edition inventory and page-level effective-date notes, reconcile cover text versus possibly stale running headers and confirm midyear switches with DBPR if ambiguous. Specifically **investigate**, without treating as established, the previously reported **March 1, 2027 statute** and **August 1, 2027 OSHA/building-code** change dates and any 2026 transition needed for historical tests. Verify that each change applies to the selected category, reference and item. Never substitute a third-party prep-site summary or a preliminary AI diff for regulator evidence. Baseline primary PDFs: [GC/BC/RC 2026](https://www2.myfloridalicense.com/servop/testing/documents/GC%20BC%20RC%20CBT%20Reference%20List%20-%20Even.pdf) · [GC/BC/RC 2027](https://www2.myfloridalicense.com/servop/testing/documents/GC%20BC%20RC%20CBT%20Reference%20List%20-%20odd.pdf) · [B&F 2026](https://www2.myfloridalicense.com/servop/testing/documents/Business%20and%20Finance%20CBT%20Reference%20List%20-%20Even.pdf) · [B&F 2027](https://www2.myfloridalicense.com/servop/testing/documents/Business%20and%20Finance%20CBT%20Reference%20List%20-%20odd.pdf). Verify the latest links and any corrigenda at the time of execution.

**MVP vertical slice:** Verified profile → clear reference checklist → source-selection question → section-location drill → interpretation question → timed full-chain drill → honest skill-specific feedback.

**No licensed-book hosting.** Candidate owns/obtains authorized references. Develop a small collection of original, reviewed scenarios and location keys rather than an unverified question bank.

**Reviewer operations:** Start **general expertise scouting** alongside EXM-P0, not a premature hire for an unchosen part. Once EXM-00 selects and the owner approves the specific contractor category/part, **confirm the final reviewer's exact-part and exact-edition fit before production authoring or approvals**, following §3.4. For selection probes, secure competent exact-source review only for the specific material being tested. Record licensing or equivalent demonstrated competence, source access, conflicts, availability and cost at the appropriate stage. The **production pilot excludes the separate four-probe selection allowance** and comprises **24 distinct original items: 16 practice items** (four each for source selection, section location, interpretation, and full chain) plus **eight held-out transfer probes** (two each). A multi-step item counts as one item. Budget measured author/reviewer minutes, initial source acquisition and renewed editorial review for each applicable new manifest. A weak source match or missing independent approval blocks the affected item. This tiny set validates learning flows and reviewer feasibility; it is **not** an official blueprint-aligned mock or pass prediction. Additional items require owner approval.

### Pilot B — Florida insurance 2-20 or 2-15

Choose one verified exam and version after reading the current DFS/Pearson VUE official candidate materials. This contrasting pilot should emphasize exam-appropriate recall, interpretation, application and timed practice. **Do not hardcode “closed-book” as an official fact without a checked primary source.**

### Pilot C — One NCEES PE Civil discipline (later)

Test exam-supplied digital navigation with source/rights restrictions. NCEES posts design-standard updates for the April 2027 administration and limits handbook distribution; verify exact version and permitted testing interface before constructing any realistic simulator. [NCEES PE Civil](https://ncees.org/exams/pe-exam/civil/)

### Later

Case-based adaptive exams, CLEP/college exams, regulated safety testing, practical trade exams, oral and written assessments. Each expands a demonstrated requirement, not a speculative database category.

---

## 11. Dependency-ordered delivery phases and acceptance gates

**No project date estimates or calendar deadlines are assigned here.** Execute each authorized phase when its prerequisites, reviewer capacity and quality gates are satisfied. Exam/reference effective dates remain an independent legal/source requirement, not a software schedule.

### EXM-P0 — Immediate existing mock-exam safety PR (**first authorized engineering work**)

**Order:** First focused code PR after explicit owner authorization. In parallel, scout general Florida construction/code-book reviewer candidates; **do not assume a final part, hire, or exact-edition purchase until EXM-00 selection and owner approval**. The approving reviewer must satisfy **§3.4** after the exact part is selected; **do not publish or buy reference content without owner direction**.

- Hide, remove or unambiguously relabel unsupported issuer-scaled score estimates in learner-facing mock-exam results; preserve historical learner data.
- Separate practice presets from verified official values. Missing official timing/passing standards must remain unknown, not `90`/`750`/`100–900` masquerading as official facts.
- Refuse claims of `blueprint_aligned` or higher status on unmapped/highest-weight-fallback domain items or underfilled exams. **If the current code has no fidelity-label system, add only a minimal safe `practice_only` indicator/default (or equivalent explicit learner-facing label), not the full profile/fidelity framework.** No existing mock may imply official alignment without verified evidence; defer the other labels and their full gating framework to EXM-03.
- Add regression tests for official-value missingness, conversion, mapping and item counts; inspect all learner-facing screens and reports.
- Limit this PR to existing mocks: **do not bundle exam profile schemas, source manifests, the complete fidelity-tier system, timed-clock redesign, pilot items, or production migrations**.

**Exit:** Reviewed PR and passing relevant tests; all reachable existing mocks default to **practice-only** unless demonstrably qualified otherwise, including when no prior fidelity-label code exists; no surprise legacy-score changes, no production writes.

### EXM-00 — Technical inventory and design decision (**audit-only; after or parallel with EXM-P0**)

- Recheck `origin/main`, tests, existing migration constraints, profile metadata/ingestion, provenance mapping cardinality and hosted behavior only via authorized **read-only** verification.
- Resolve independent reference-manifest identity, effective date selection and immutable publication; prove 2026→2027 update **without cloning curriculum**.
- **Design** the item-level `valid_for_manifest_revision_ids`/answer revision contract, cross-edition re-review queue and **§3.4 editorial signoff**, including handling multiple source locations; **do not implement the item workflow until EXM-02A**.
- Trace stable exam-part keys through Learn (`activeFocusId`/`ResolvedScope`), diagnostics, target readiness, mock generator, reports, NextAction and caches.
- Specify durable learner attempts, account/guest isolation, retention/deletion, RLS and minimum safe migration.
- **Hard gate: independently confirm each shortlisted content outline is still the current official DBPR outline for its exact contractor category/part.** Read the current official exam page and candidate materials, check supersession/version notices, and record source links/check date in Appendix A; withhold the pilot-part recommendation if this cannot be verified. Next evaluate realistic code-book navigation using **no more than four separately budgeted nonproduction, expert-reviewed selection probes across all candidates** (§10), then select with owner approval. Scout general reviewer expertise alongside EXM-P0 but confirm exact-part/edition fit only once the part is chosen (§3.4). Independently compare **2026 and 2027 primary reference PDFs** for edition transitions, including intrayear effective dates and inconsistencies; **2027 is the first live authoring baseline**, while 2026 is historical/optional and not exposed as 2027 practice. Assess reviewer churn/cost second. Preserve the separate **24-item production cap** and recurring costs (see §10).
- Mark claims `proposed | coded | tested | hosted | learner_validated`; do not promote one status to another.

**Output:** Record code findings, unresolved questions, fixture results and review evidence **only in Appendix A of this plan** (and summarize concisely in the documentation PR). Do not rewrite approved Sections 0–16 while appending audit observations. Propose any substantive architecture change to the owner first; apply it to the body only after approval. No separate mandatory audit/decision/handoff documents.

**Exit:** Owner reviews the consolidated technical decision and the specific proposed migration(s); EXM-01 work and any hosted writes still need explicit approval.

### EXM-01 — Verified exam/part profile and independently versioned references (**reduced scope**)

- Schema-validate typed stable profile/part configuration and part-to-curriculum subtree mapping.
- Publish independently effective-dated, reviewed **reference-manifest revisions** with exact official source/date and room-policy evidence, never borrowing Service Pool rules for CGC/CBC. Validate date selection, overlaps, source consistency and rule-level citation anchors.
- Deliver **one plain-language learner overview** with unknown-state behavior, official reference checklist and existing Learn/Library/Progress access.
- Decide the canonical attempt storage, retention, deletion and RLS model **by the EXM-01 exit gate**; do not implement attempts here or defer the decision to EXM-03.
- Carry forward the **EXM-00 conceptual contract** for item-to-manifest validity and author/reviewer separation, but **do not implement item bindings, affected-item queues, item review UI or edition re-review workflows in EXM-01**. Those need real items and belong in EXM-02A.

**Acceptance:** A verified 2027 manifest can be the **first production reference baseline** without building 2026 learning items; a synthetic or optional earlier manifest demonstrates supersession **without a `target_version` clone**. **The 2027-specific overview/checklist cannot be presented as applicable for an exam administration governed by 2026 rules or an unknown applicable revision**; general study remains available. Exact administration dates select the proper effective revision; official claims are source-anchored or unknown; the overview respects direct access. No reference drill is considered ready until EXM-02A approves the actual item-to-manifest bindings.


### EXM-02A — Reference Mastery drill MVP

- Build `R1` resource choice, `R2` section location, `R3` interpretation and `R4` full-chain with reviewed content; use supported assessment interactions and a small specialized workflow where needed. **Implement and exercise the versioned item-to-manifest validity binding and cross-edition re-review process here**, with real authored items and primary-source diff fixtures; a new manifest never inherits item approval automatically.
- Capture per-step feedback, time, app-observed versus self-reported book use, and immutable manifest/answer-location revisions. **Use the 2027-authorized editions by default** (unless the owner explicitly requests another applicable exam administration period). Persist the source edition, reviewer minutes and **the canonical §3.4 human-author/independent-reviewer approval record**.
- Mark internal local attempts as **disposable prototype-only** until EXM-02B is complete. Never promise persistent Progress or begin an external learner pilot from disposable storage.
- Keep concept mastery distinct from navigation skill evidence and do not reproduce copyrighted source material.

**Acceptance:** Reviewer-approved exact sources; **item validity fails closed when manifest revision changes** until independent review signs a new binding; actionable affected-item queue and traceable historical approvals; meaningful skill-specific correction; no false physical-observation claims or unnecessary global enum.

### EXM-02B — Durable learner attempts (**small separate PR; immediately after EXM-02A**)

- Implement the EXM-01-approved owner-scoped attempt store with RLS, `exam_part_key`, profile/spec revision, immutable reference-manifest revision, item/answer version, timestamps, score/skill components, scoring version and provenance.
- Provide consistent Progress derived from stored attempts; add a materialized skill-projection table only after a demonstrated performance need.
- Cover shared device account A→B, guest isolation and optional guest transfer, offline/online merge rules if supported, access control, retention, deletion and duplicate-submit idempotency.
- **This is a prerequisite for any external pilot or EXM-05 measurement**, and should not wait for the EXM-03 timed-simulator clock rewrite.

**Acceptance:** A refresh, sign-out or device/account switch cannot expose another learner's records; history remains pinned to the correct source versions; privacy/RLS, deletion and durability tests pass.

### EXM-03 — Exam-aware simulation and part-scope completion

- Build on EXM-P0 safety fixes and EXM-02B durable evidence; implement exact quota/part mappings, inventory checks and verified simulation-fidelity conditions.
- Propagate selected part subtree to diagnostics, `TargetReadinessService`, mock generator, NextAction and Progress; test unrelated part exclusion and legitimate shared concepts.
- Implement profile-governed timer, navigation/revisit, pause, permitted references and interruption/refresh handling; test predictable state and honest fidelity labels.
- Do **not** re-implement drill-attempt persistence here; extend the established EXM-02B storage contract only for simulation-specific fields.

**Acceptance:** No aligned label for sparse/unmapped banks; no unsupported issuer scoring; no cross-part readiness bleed; browser/timer limitations visible; history preserves previous scoring conventions where required.

### EXM-04 — Explainable adaptive preparation

- Recommend the next exercise from discrete, durable skill evidence; no opaque pass predictions.
- Optional exam date/time plan, reusable `SKL-01`, `SKL-02`, `SKL-04`; direct learner choice always available.

**Acceptance:** All suggestions show why, low sample sizes remain low-confidence, cross-target concepts reuse global evidence without mixing exam-part scores.

### EXM-05 — Effectiveness validation (additional content budget required)

- Measure novel held-out equivalent tasks with accuracy, interpretation and time; use durable EXM-02B attempts; record sample size and uncertainty.
- Test whether speed improvements preserve or improve correctness; distinguish transfer from re-answering familiar items.
- Track which approved manifest and item revisions were in effect for every observation. **New editions require fresh item review and potentially new equivalent held-out forms**, separately budgeted.
- Actual licensing outcomes are voluntary and observational unless a stronger study design supports inference.

**Acceptance:** Measured outcomes stated with limitations. The first eight held-out probes are sufficient only for early feasibility, not broad pass-rate claims; approve further reviewer capacity and study design before scaling claims.

### EXM-06 — Creator and educator contributions (deferred)

Introduce contributions only when rights, provenance, expert review, moderation and child protection requirements from ECO are operational. No creator functionality is required for the first pilot.

---

## 12. Critical regression tests and acceptance matrix

| Test case | Expected result |
|---|---|
| Verified profile lacks official timing | No official timing displayed; strict format simulation unavailable; practice mode may remain |
| Missing passing score or nonpublic scale conversion | No invented issuer score; raw practice results remain accessible |
| Exam date changes from 2026 to 2027 | Independently versioned reference manifest updates; **no target curriculum clone**; past attempt retains historical revision |
| Existing item has approved 2026 location but no 2027 validity binding | 2027 location drill is unavailable pending exact-edition reviewer approval; neither answer location nor cited page silently carries forward |
| Same book title is retained but edition or provision changes | Explicit re-review and new reviewed mapping for 2027; historical 2026 answer remains immutable |
| Reviewer cannot obtain exact new edition | Related item withheld from 2027 practice, not inferred from old edition or AI search |
| Reviewer scouting begins before pilot part selection | Recruit for general Florida code-book competence only; final part-specific qualification, independence and edition access are checked **after** the owner approves the selected part (§3.4) |
| Selection study proposes five probes or counts probes as pilot questions | Reject above **four total nonproduction probes**; do not count them toward the separately capped **24 production items**, and require owner approval plus EXM-02A review to convert one into a production slot |
| Current applicability of an old-dated DBPR content outline is unconfirmed | **No pilot part selection** based on the outline until current official applicability is verified and cited during EXM-00 |
| Learner is testing under 2026 rules but opens the 2027 pilot | Withhold 2027-specific reference checklist, drills and readiness; offer general study or separately approved period-appropriate practice only |
| Item author is also the only recorded reviewer | Item publication blocked under the **§3.4 rule** |
| AI drafted or materially rewrote an item, but `ai_drafted` is omitted | Publication blocked under the **§3.4 rule**, which also requires a human author of record |
| Official 2027 PDF contains stale running validity header on a later page | Flag source inconsistency for reviewer/regulator reconciliation; never infer the applicable effective date from one footer/header |
| Existing mock engine has no fidelity-tier field | EXM-P0 shows a minimal `practice_only` indicator; no synthetic official-alignment claim or full EXM-03 tier framework is introduced |
| Internal prototype attempts exist but durable EXM-02B has not shipped | No external learner pilot, persistent-Progress claim or study run until owner-scoped RLS and privacy tests pass |
| Wrong book / right section text | Source-selection evidence reflects incorrect resource; does not award full reference mastery |
| Right section / wrong exception | Navigation can pass, interpretation fails |
| User guesses a physical-book section without opening book | App scores entered location but labels observed behavior appropriately; no claim of physically verified lookup |
| Assessment bank lacks domain mapping | Aligned simulation fails closed or lowers fidelity, never silently assigns all missing items to largest domain |
| Question bank insufficient for requested count | Fail aligned-mode launch, don't silently shorten claimed official format |
| Unsupported assessment interaction | Cannot enter aligned-mode bank until correctly rendered and scored; no fabricated pass result |
| Browser backgrounded / refreshed | Clock and resume behavior follow documented mode policy; no lost answers or unbounded time bonus |
| Account A signs out, account B signs in | No private profile, attempt, score or checklist leakage |
| Part A selected but Part B has weak knowledge | Learn, diagnostics, readiness and mock generator evaluate Part A's subtree/eligible items only; global concept evidence remains reusable |
| `scope_config` provided without valid part mapping | No claim that a part is isolated; fail validation until `activeFocusId` / scoped APIs are consistently handled |
| 2026 Service Pool list loaded for CGC/CBC | Block as exam/part identity mismatch; never inherit notes/tabs/highlighting policy |
| Reference list changes but curriculum does not | No curriculum version clone; history pins old approved manifest |
| Private attempts on shared device or account switch | No cross-account state leakage or stale local keyed state; user-scoped RLS enforced |
| Learner has excellent recall but slow reference navigation | Distinct scorecards and targeted location practice, not one misleading readiness percent |
| Reviewed source is superseded | No new 'current official' claim; published historical practice remains labeled historical |
| Creator includes copyrighted exam-bank question | Publishing workflow blocks/remediates; no official affiliation claim |
| Minor accesses preparation | Private safe learning path; social contribution restrictions remain enforced |
| No exam data available | Learner can still use general study; no forced setup or fictitious exam profile |

**Verification pipeline:** focused Dart unit/widget tests; relevant Supabase pgTAP/RLS tests; manifest schema and linter fixtures including negative cases; Playwright responsive/keyboard navigation; `flutter analyze`, `flutter test`, `flutter build web --release`; existing guarded migration checks. Source truth and model compatibility should be tested at the **new** main commit before each PR.

---

## 13. Risks and mitigations

| Risk | Mitigation / owner action |
|---|---|
| Outdated or mixed 2026/2027 books | Verified 2027-first authoring, effective-dated manifests keyed by part and actual administration date; never assume the entire year uses one unchanging edition |
| Generic defaults misrepresented | Untangle practice presets from verified official fields; fail closed on missing facts |
| False 'scaled score' or inflated readiness | Raw practice scores, scoring version, sufficiency labels; no unvalidated pass prediction |
| Insufficient/misassigned items | Strict bank coverage checks and no domain fallback for aligned simulations |
| Auth/privacy leakage on shared device | User-scoped keys, auth lifecycle test, RLS, guest separation; no secrets in Hive/preferences |
| Simulated physical-book lookup is not observable | Label response-time proxy and self-reported use; validate with supervised pilot |
| Copyright, DRM or item-bank contamination | Use learner-owned books, original authored prompts, minimal metadata, rights review |
| Wrong source citations or AI hallucination | Scout general code-book reviewer expertise alongside EXM-P0; confirm exact part/edition access after owner selection; enforce **§3.4** approval and source-location sign-off; cap live pilot at 24 |
| Reference manifest changes invalidate item answer locations | Item-level `valid_for_manifest_revision_ids` binding, conservative invalidation and **mandatory edition-specific re-review**; no silent answer migration |
| Recurring reviewer labor and acquisition costs | **Code-book teaching value comes first; stability is secondary**. Begin with applicable 2027 editions to avoid needless initial 2026 rework; budget up to four nonproduction part-selection probes **separately** from 24 reviewed pilot items; confirm official change dates and budget re-review for affected items and editions |
| Local-only progress blocks learner validation | Decide storage by EXM-01; ship durable owner-scoped drill attempts and RLS/deletion tests in **EXM-02B**, prior to outside pilot or EXM-03 |
| Reviewer hired for the wrong part or current-outline status assumed | Two-stage reviewer selection (§3.4), EXM-00 current-outline verification gate and documented owner-approved part before exact-edition reviewer commitment |
| 2027 reference pilot shown to a learner sitting a 2026 administration | Restrict the first reference-specific pilot to administration dates covered by the verified effective 2027 manifest; allow unrestricted general study, not misdated reference practice |
| Annual reference updates churn immutable target versions | Separate independently versioned effective-dated reference manifest; keep curriculum snapshots stable |
| Metadata field growth and conflict | Only stable exam/part configuration in namespaced, typed target metadata; separate version records where requirements evolve independently |
| New type breaks renderer/SQL/scorer | Reuse four supported types initially; isolated migration and cross-layer tests if added |
| Wasted work alongside creator roadmap | Separate EXM/ECO phases; no dependence on social publishing for MVP |
| Improves quiz speed but not real-world outcomes | Novel-item validation, accuracy-speed tradeoff analysis, later voluntary actual outcomes |

---

## 14. Product owner decisions requested

**Recommended defaults are marked below; they are proposals only.**

| # | Question | Recommended decision |
|---|---|---|
| D1 | First vertical-slice domain? | **Yes:** a Florida CGC/CBC contractor exam part selected to **prove technical-code/reference lookup**; compare official outlines before selection |
| D2 | Second contrasting exam? | **Yes:** one verified Florida insurance exam; confirm official reference policy first |
| D3 | MVP reference delivery? | **Yes:** learner's own approved physical books + original exercises and section IDs |
| D4 | Initial storage boundary? | **Stable** exam-part information may use typed `target_versions.metadata`; **approved reference lists/policies always have independent effective-dated version records** |
| D5 | New assessment item types in EXM-02? | **No by default:** compose existing types first; add only on proven need |
| D6 | Separate skill and concept evidence? | **Required:** don't pollute `user_concept_state` |
| D7 | Reusable skill modules? | Begin with `SKL-01`, `SKL-02`, `SKL-04`; schedule others based on pilot |
| D8 | Predict pass probability or issuer score? | **No:** defer until calibrated validation and official scoring availability |
| D9 | Private reference index builder? | **Defer**; potentially study-only with explicit exam-room restrictions |
| D10 | Creator-contributed exam questions and marketplace? | **Defer** until ECO safety, rights, review and moderation are operational |
| D11 | Pilot reviewer and content cap? | **24 production items:** 16 practice + 8 held-out, **plus at most four separate, nonproduction part-selection probes across candidates**. Scout general code-book reviewer expertise alongside EXM-P0; confirm exact part/edition reviewer fit after part selection. Editorial rule: **§3.4** |
| D12 | Durable evidence phase gate? | **Storage decision by EXM-01; deployed/tested owner-scoped drill attempts in EXM-02B, immediately after drills and before external pilots** |
| D13 | Part scoping? | **Explicitly extend** `activeFocusId`/node scope to diagnostics, readiness and mock generator; scope-config alone is insufficient |
| D14 | Existing mock-engine safety fixes? | **EXM-P0 immediate separate PR**, before longer exam-profile work |
| D15 | Answer locations and new reference lists? | **Item-level validity for immutable manifest IDs and independent review; implement binding/re-review in EXM-02A**, with historical attempts pinned |
| D16 | How many documents are authoritative? | **One**: this plan; agent handoff inline; factual execution findings go only in **Appendix A**, not the approved decision summary |
| D17 | How select contractor pilot part? | **First verify current official DBPR outlines for every shortlisted category/part**, then measure code-navigation fit with up to four separately capped expert-reviewed probes, then compare 2027 editions/2026 history, reviewer fit, update burden and cost. Owner approves the exact part; no automatic final choice |
| D18 | How handle mock fidelity in EXM-P0? | **Minimal `practice_only` default** if no fidelity system exists; defer full fidelity taxonomy to EXM-03 |
| D19 | Which reference vintage for initial authorship? | **Officially verified 2027 manifest first**, with 2026 validity only on explicit owner request; each intrayear switch still requires exact applicable-revision review |
| D20 | Project dates or deadline estimates? | **None in this plan.** Phases follow dependencies and approvals, while official source/exam effective dates remain mandatory facts |

---

## 15. Sources, authority and verification boundaries

### Official source pointers (verify current applicability before publishing)

- [Florida DBPR — Construction Examinations](https://www2.myfloridalicense.com/examination-information/construction-examinations/) — exam format, links to exam-part content outlines, approved-reference guidance, testing context.
- [DBPR — GC Project Management official content outline](https://www2.myfloridalicense.com/servop/testing/documents/GC%20Project%20Management%20ECI%20January%202020.pdf) · [GC Contract Administration outline](https://www2.myfloridalicense.com/servop/testing/documents/GC%20Contract%20Administration%20ECI%20January%202020.pdf) · [Business & Finance outline](https://www2.myfloridalicense.com/servop/testing/documents/bus_fin_eci.pdf) — used for the preliminary educational-fit distinctions in §10; confirm older document versions remain applicable before approving an exam profile.
- [Florida DBPR — Service Pool Contractors Trade Knowledge 2026 Reference List](https://www2.myfloridalicense.com/servop/testing/documents/Service%20Pool%20CBT%20Reference%20List%20-%20Even.pdf) — source-confirmed example of unique binding/highlighting/notes/tabs rules; **not automatically applicable to CGC/CBC**.
- [Florida DBPR — Construction Examination Reference Lists](https://www2.myfloridalicense.com/examination-information/construction-examinations-reference-lists/) — separate 2026 and 2027 effective reference-list branches; **not** a substitute for checking each exact part and exam date.
- [Florida DBPR — Candidate Information Booklets](https://www2.myfloridalicense.com/examination-information/candidate-information-booklets/) — current examination-room instructions and restrictions by profession.
- [NCEES — PE Civil](https://ncees.org/exams/pe-exam/civil/) — exam-supplied electronic references, discipline-specific specs, April 2027 design-standard effective period.
- [NCEES — Handbook reproduction terms](https://help.ncees.org/article/87-ncees-exam-reference-handbooks) — personal use versus copying/distribution constraints.
- [Florida DFS — Insurance Licensing Qualifications](https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications) — qualification routes; obtain the **exam-specific** candidate handbook and blueprint separately before a pilot.

### Repository files inspected (selected traceable audit pointers)

- [`LEARNING_ARCHITECTURE_V2.md`](https://github.com/RACCHUS/LearningApp/blob/main/LEARNING_ARCHITECTURE_V2.md)
- [`README.md`](https://github.com/RACCHUS/LearningApp/blob/main/README.md)
- [`AGENTS.md`](https://github.com/RACCHUS/LearningApp/blob/main/AGENTS.md)
- [`lib/models/assessment_engine/mock_exam_blueprint.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/models/assessment_engine/mock_exam_blueprint.dart)
- [`lib/models/assessment_engine/mock_exam_session.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/models/assessment_engine/mock_exam_session.dart)
- [`lib/services/assessment/mock_exam_generator_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/assessment/mock_exam_generator_service.dart)
- [`lib/services/assessment/exam_evaluation_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/assessment/exam_evaluation_service.dart)
- [`lib/providers/assessment_engine_provider.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/providers/assessment_engine_provider.dart)
- [`lib/widgets/assessment/assessment_item_renderer.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/widgets/assessment/assessment_item_renderer.dart)
- [`lib/services/scope_resolver.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/scope_resolver.dart)
- [`lib/services/assessment/diagnostic_assessment_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/assessment/diagnostic_assessment_service.dart)
- [`lib/services/target_readiness_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/target_readiness_service.dart)
- [`lib/services/pathway_readiness_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/pathway_readiness_service.dart)
- [`tool/lint_manifest.dart`](https://github.com/RACCHUS/LearningApp/blob/main/tool/lint_manifest.dart)
- [`tool/ingest_curriculum.dart`](https://github.com/RACCHUS/LearningApp/blob/main/tool/ingest_curriculum.dart)
- [`supabase/migrations/20261003000000_content_provenance.sql`](https://github.com/RACCHUS/LearningApp/blob/main/supabase/migrations/20261003000000_content_provenance.sql)
- [`supabase/migrations/20261004000000_content_primitives_v2.sql`](https://github.com/RACCHUS/LearningApp/blob/main/supabase/migrations/20261004000000_content_primitives_v2.sql)
- [`docs/catalog/P2H_LEARNER_FACING_PATHWAY_PREPARATION.md`](https://github.com/RACCHUS/LearningApp/blob/main/docs/catalog/P2H_LEARNER_FACING_PATHWAY_PREPARATION.md)

### Further review required before public launch

These official pages establish the **types of conditions** the model must handle, not complete verified datasets for a specific individual, location, exam date or exam part. Each pilot still requires the currently effective full official candidate requirements, an exam-parts/edition check, appropriately licensed original exercises, test coverage, and an operational review process.

**Engineering execution:** Use the **embedded Antigravity handoff in §16 below**. This plan is the sole required EXM planning artifact; do not treat chat reviews or previously circulated handoff/audit drafts as sources of truth.

---

## 16. Embedded Antigravity / IDE engineering handoff (single-document execution)

**This section replaces separate EXM handoff, audit and schema-decision documents.** An agent should read **this plan** and existing project files and produce focused PRs. **Append factual engineering observations and evidence only to Appendix A**, keeping the owner-controlled decision summary and Sections 0–16 stable. Material changes to design decisions, phase gates or scope must be proposed for owner approval **before** changing the main body. Do not create another authoritative `EXM_00_*` Markdown document by default. Use PR descriptions, test outputs and code-review comments for operational detail.

### 16.1 Authorization boundaries and sequence

1. **EXM-P0 is a separate, small code PR**, started only after explicit owner authorization. Scope: mock safety fixes, regression tests and documentation of any deferred timer work; no migrations or reference-profile construction bundled in.
2. **EXM-00 is an audit/design-only task**, separately authorized. It can proceed concurrently with EXM-P0 after approval, but cannot silently implement EXM-01 or create production tables.
3. Each further phase requires its own focused branch, PR, tests and owner go/no-go. **No production Supabase writes, migration repairs, reference publication, or destructive operations without explicit authorization.** Only the guarded workflow may be used when later authorized. **Follow all repository backup, recovery, migration and deployment requirements in force for the operation; this plan does not waive or make those safeguards optional.**
4. Review `AGENTS.md`, `UI_ARCHITECTURE_LOCKED.md`, `LEARNING_ARCHITECTURE_V2.md`, `LITERACY_ACCESSIBILITY_PLAN.md`, `docs/catalog/P2H_LEARNER_FACING_PATHWAY_PREPARATION.md` and current code; keep three-destination navigation and direct learner choice intact.

### 16.2 Copy/paste-ready EXM-00 task

> Work on **EXM-00 audit and technical design only** in `RACCHUS/LearningApp` using current `origin/main`. Read `EXM_00_EXAM_SUCCESS_ARCHITECTURE_PLAN.md` and the current repository governing documents. Audit existing models, assessment UI, SQL constraints, manifest pipeline, source provenance, part scoping, session persistence and tests. Mark findings as proposed / coded / tested / hosted / learner-validated, with exact paths. Verify published-target immutability and design the smallest independent, effective-dated reference-manifest record **without curriculum cloning**; **specify** immutable item-level `valid_for_manifest_revision_ids` bindings and independent review rules but schedule their implementation, with the re-review workflow, for **EXM-02A** when reviewed items exist. Confirm `activeFocusId` scopes Learn but assess whether diagnostics, readiness, mock selection, NextAction, Progress and caches correctly honor an exam-part key. Design the canonical durable attempts/RLS model **by EXM-01 exit** and implementation in **EXM-02B**. For **each shortlisted contractor category/part**, independently verify the outline linked by DBPR remains the **current official content outline** (including candidate materials and superseding notices); **do not select a part if current applicability is unconfirmed**. Then prioritize a part that genuinely teaches **building-code / technical reference navigation**, using **at most four separately budgeted, nonproduction, expert-reviewed selection probes total** across candidates; favor educational fit over minimum edition churn. Independently audit the **2026 and 2027 primary DBPR PDFs**, including potential March/August 2027 changes, mismatched running headers, edition/review costs and intra-year effective rules: treat any previously quoted change dates as **unverified until primary-PDF reconciliation**. Plan the initial **2027-applicable** 24-item production authoring set (16 practice, eight held-out), **excluding** the maximum four part-selection probes; 2026 item validity is optional and needs explicit owner approval. The first live 2027-reference pilot/checklist is **only for learners whose actual exam administration falls under the verified effective 2027 manifest**; earlier-period and unknown-date learners retain general study, not mismatched reference drills. Begin **general Florida construction/code-book reviewer scouting** alongside EXM-P0, then verify final reviewer qualification and exact-edition access **after the owner picks the part**, subject to **§3.4**. No project delivery dates or calendar estimates are required. Append factual traceability, tests and open issues **only to Appendix A**; proposed design changes require owner approval and must not silently rewrite the decision summary. Do not create separate required EXM Markdown files. Work on a documentation-only branch/PR. Do not create/apply migrations, change hosted Supabase, publish content or implement EXM-01+ without explicit authorization.

### 16.3 Separate EXM-P0 task (requires explicit permission)

> After the owner authorizes **EXM-P0**, create a focused branch from current main and inspect `MockExamBlueprint`, `MockExamGeneratorService`, `ExamEvaluationService`, mock learner-facing results and tests. Prevent 90-minute / 750 / 100–900 practice defaults from being displayed as verified official exam facts; remove or unmistakably relabel the synthetic linear issuer-scaled score; ensure insufficient or unmapped item banks cannot claim blueprint alignment. If the code has no fidelity labels, use a **minimal `practice_only` label/default** on reachable existing mocks; do not build the multi-level fidelity system until EXM-03. Preserve prior results/history, add narrowly targeted regressions and run relevant Flutter checks. Record what was coded and tested; note the EXM-03 clock/session improvements as separate work. No production DB writes, no migration repair and no deployed changes without explicit owner approval. Open a small reviewable PR.

### 16.4 Cross-phase checks and fixtures (specified in EXM-00, implemented at the named gate)

**EXM-00 defines the test design; it does not implement EXM-01 manifest persistence or EXM-02A item-review workflows.**

| Audit / fixture | Expected evidence and pass condition |
|---|---|
| Effective-manifest transition fixture (**EXM-01**) | 2027 can be the first live authoring baseline; use a synthetic 2026 predecessor (or real 2026 only if approved) to show the same curriculum IDs survive a non-overlapping manifest transition, while exact administration dates and intra-year overrides resolve correctly |
| Item key-validity revision fixture (**EXM-02A**) | A binding valid for **manifest A** is invalid for new **manifest B** until an explicit independently reviewed new binding exists; demonstrate with synthetic 2026→2027 fixtures without mandating 2026 production item authoring |
| Reviewer workload/eligibility (**EXM-02A**) | Validate and test **§3.4 canonical editorial rule** (human author of record, truthfully flagged AI drafting, distinct qualified approving reviewer with exact edition); track minutes/item and edition-revision cost |
| Part A versus Part B | Consistent part-node filtering in Learn, diagnostic, readiness, mock, NextAction and Progress; legitimate global concept sharing retained |
| Source mapping cardinality | Demonstrate exact source release/section/exception mappings, multiple locations and immutable review revisions without losing citations |
| Storage/RLS design | Decide data model by EXM-01; implement in EXM-02B; signed-in/guest switch, deletions and refresh tests pass before external pilots |
| Existing mock reachability | Identify misleading default/scaled output; focused EXM-P0 fix includes **minimal practice-only label if none exists**, not a full fidelity system; preserve history |
| Official reference restrictions | Use primary DBPR PDF and source-page anchors; reconcile cover/running-date discrepancies and **verify reported intrayear transitions** before publishing. Never copy Service Pool rules into CGC/CBC defaults or use third-party paraphrases as official evidence |
| Current-outline verification (**EXM-00 hard gate**) | For each shortlisted contractor category/part, record direct DBPR outline URL, current-page/candidate-material corroboration, applicable version, supersession check and date; block owner part selection while applicability is unresolved |
| Pilot educational fit | Verify outlines first; then use **at most four total separately budgeted, nonproduction, expert-reviewed selection probes across candidates** to demonstrate building-code/reference-navigation feasibility; unavailable expert/source access means inconclusive, not verified |
| Two-stage reviewer suitability | Scout general Florida construction/code-book expertise alongside EXM-P0; confirm specific part qualification, independence and exact-edition access once owner selects part (§3.4) |
| 2027-first authorship and learner eligibility | New pilot authoring cites exact effective 2027 revision; **do not serve 2027-specific reference drills/checklists to learners whose exam dates are governed by 2026 or an unknown revision**; no unrequested production 2026 item set; fixture tests transition without legacy approvals |

### 16.5 What to submit for owner review

- A small EXM-00 documentation PR with findings/evidence **only in Appendix A**, or a small EXM-P0 code PR if independently authorized. Do not alter owner-approved body sections without separate approval.
- A short PR description stating risks, code paths checked, decisions still open, tests actually run, and what remains **unverified**. Prefer PR comments to accumulating more permanent plan documents.
- Explicit approval requests before any migration, data publication, pilot launch or work that exceeds **four separate nonproduction part-selection probes or 24 production pilot items**, or changes a reviewed probe into a production item without consuming an approved 24-item slot.

**Current authorization status:** The owner has explicitly authorized **EXM-P0 development on a feature branch** and placement of this approved plan at the repository root. This does **not** authorize merging, deployment, production data writes, reference publication, or later phases.

---

## Appendix A — Engineering findings and verification log (**non-normative; append here only**)

**Purpose:** This appendix is the **only in-document destination** for new agent-run audit notes, observed code discrepancies, DBPR primary-source comparisons, test evidence and unresolved implementation questions. It does **not** amend owner-approved requirements or give implementation permission. The decision summary and Sections 0–16 remain stable unless the owner approves a targeted specification revision; that approved change should receive an explicit version/date update in the document header.

**Append entry format:**

- **Date / agent / Git commit:** _record exact values_
- **Phase / PR link:** _EXM-P0, EXM-00, EXM-01, etc._
- **Observation and status:** _proposed, coded, tested, hosted, or learner-validated; never silently upgrade evidence_
- **Evidence:** _exact source URL/page/edition or source-code path, line range, tests and result_
- **Impact / risk:** _what changes and what remains unverified_
- **Decision requested:** _explicit owner signoff needed, or "none"_
- **Status:** _open, approved for specification change, resolved, or deferred_

**EXM-P0 execution record (development branch; tests not yet verified in CI):**

- **Date / scope:** Owner authorized first EXM-P0 code changes; no migrations, Supabase writes or production deployment.
- **Coded changes:** Practice-only learner UI; official values and issuer-scaled estimates withheld absent verification; remove highest-weight-domain fallback; reject underfilled practice sets; restrict displayed practice items to renderer-supported formats.
- **Evidence:** `lib/models/assessment_engine/mock_exam_blueprint.dart`, `lib/models/assessment_engine/exam_diagnostic_report.dart`, `lib/services/assessment/mock_exam_generator_service.dart`, `lib/services/assessment/exam_evaluation_service.dart`, `lib/screens/assessment/mock_exam_screen.dart`, `lib/screens/assessment/exam_report_screen.dart`, and focused `test/unit/assessment_engine/` plus `test/widgets/mock_exam_screen_test.dart`.
- **Verification status:** Source edits coded. Flutter/Dart commands and GitHub Actions must be checked and recorded separately; do not claim they passed until confirmed. The practice timer still uses its prior ticker mechanism; interruption-safe EXM-03 clock redesign remains deferred.
- **Impact / risk:** Old metadata passing standards and legacy timer values no longer appear as official facts. Insufficient or ambiguously mapped banks may now refuse to start instead of silently filling with unrelated items.
- **Decision requested:** None for EXM-P0 code review; separate signoff before merge/deployment or EXM-01+.
  
The official-content-outline observations and pilot-choice worksheet in §10 are editorial inputs, not a verified item-level lookup study or completed 2026/2027 DBPR PDF diff. EXM-00 must record its primary-source reconciliation here before any reference-list detail is accepted as final.

---

### A.1 — EXM-00 technical inventory and design decision record (documentation-only)

**Scope and evidence status.** This is a read-only source-code and primary-DBPR-document audit, not an implemented schema or live learner validation. Status tags: **coded** = code in the repository; **tested** = a completed named test run (not merely a test file); **hosted** = live database verified; **proposed** = design to approve. No production Supabase reads/writes, migrations, or content publication were performed for this EXM-00 record. P0 work is tracked separately in its draft PR; do not mistake its presence in a branch for successful CI.

#### A.1.1 Source inventory and scoped-behavior gaps

| Question | Coded evidence on main | EXM-00 finding / next gate |
|---|---|---|
| Can Learn focus on one exam part? | `lib/models/learning_context.dart:48-58` has `targetVersionId`, `activeFocusId`, `scopeConfig`; `lib/services/scope_resolver.dart:235-246` restricts target nodes to the active focus and descendants. `lib/models/scope.dart:118-145` carries selected node and concept sets. | **Coded, partial.** Represent each part by a stable `part_key` and a validated curriculum root node; pass selected root as `activeFocusId`. Reject absent, foreign-version, missing or non-part roots rather than silently widening to the whole target. |
| Are diagnostics scoped to that part? | `lib/services/assessment/diagnostic_assessment_service.dart:267-336` queries all nodes, core concepts, and items for `targetVersionId`. | **Coded, gap.** Introduce a scoped node-set/part-key parameter for diagnostic item selection and evidence sufficiency; no default whole-version fallback when the learner explicitly requested a part. |
| Is concept readiness scoped to that part? | `lib/services/target_readiness_service.dart:29-68` takes `userId` and `targetVersionId` only; it loads all target-version nodes and concepts. | **Coded, gap.** Evaluate weighted core concepts against selected part node IDs; keep the global user concept state unchanged. |
| Is mock selection scoped to that part? | `lib/services/assessment/mock_exam_generator_service.dart:140-236` selects by target-version item ownership, retrieves all domain and objective nodes; the EXM-P0 branch makes mapping and inventory selection fail closed but does not add `part_key`. | **Coded, gap.** Enforce selected subtree and per-part quotas in EXM-03, including multi-part/overlapping-concept regressions; do not advertise part-aligned mocks before then. |
| Do NextAction and Progress consistently inherit the scope? | `lib/providers/next_action_provider.dart:139-181` consumes a resolved scope for activities; `lib/screens/progress/progress_screen.dart:238-240` passes only `targetVersionId` to `TargetReadinessCard`. | **Coded, mixed.** Scope-aware activities exist; readiness card can still aggregate unrelated parts. Verify caches, secondary links, and explicit item sets in part-switch tests. |
| Are exam attempts durable? | `lib/models/assessment_engine/mock_exam_session.dart:15-43` holds a session in memory; `lib/providers/assessment_engine_provider.dart:35-122` ticks in RAM, pause/resume, and evaluates. | **Coded, not sufficient for durable evidence.** No EXM-02B attempt store verified. Keep refresh/session persistence and interruption-safe clock in later gates. |
| Can pathway-readiness local storage leak between accounts? | `lib/services/pathway_readiness_service.dart:18-69` keys `SharedPreferences` by pathway and optional target and additionally writes a base key, not an authenticated-user prefix. | **Coded, cross-account isolation risk.** Keep as an explicitly scoped follow-up; do not use this storage pattern for durable exam skill evidence. |
| Are source releases and citation mappings reusable? | `supabase/migrations/20261003000000_content_provenance.sql:10-46` creates source releases/mappings with `citation_location` and `reference_citation`; `20261004000000_content_primitives_v2.sql:395-412` permits `assessment_item` mapping. | **Coded.** Reuse source-release/citation records for provenance. A relationship tuple is not by itself a complete per-edition answer-validity/reviewer workflow; EXM-02A needs explicit independently reviewed bindings. |
| Is content ingestion versioned and immutable? | `tool/ingest_curriculum.dart:128-143, 538-570, 1134-1156` validates schema, lints, stages and publishes; `supabase/migrations/20261002000000_retired_version_immutability.sql` restricts published/retired target edits. | **Coded.** Reference-list maintenance should not require cloning `target_versions`; independent immutable manifest revisions are necessary. |
| Are there automated tests already? | `test/services/scope_resolver_test.dart`; `test/services/assessment/diagnostic_assessment_service_test.dart`; `test/unit/assessment_engine/mock_exam_generator_test.dart`; `test/unit/assessment_engine/exam_evaluation_test.dart`; `test/widgets/mock_exam_screen_test.dart`. | **Tests exist; not a new pass claim.** Add part-A/part-B isolation, edition transition, unknown-rule and guest/account isolation fixtures at their assigned implementation phases. |

#### A.1.2 Proposed smallest EXM-01 reference-manifest design (not yet a migration)

**Proposed, subject to owner approval and authoritative schema audit:** Add only one independently revisioned public reference-manifest record family, conceptually `exam_reference_manifest_revisions`; keep stable part definitions in the existing versioned target's typed metadata. Candidate immutable record fields:

- Identity: `id` UUID, `target_version_id` UUID, stable `exam_part_key` text, `revision` positive integer, unique `(target_version_id, exam_part_key, revision)`, optional `supersedes_revision_id` pointing to the same part.
- Applicability: `effective_from` inclusive, `effective_until` inclusive or null, explicit jurisdiction and administration/delivery variant if relevant. Reject overlapping published date windows for an identical target-version / part / administration variant. Select by **actual administration date**, not study date, and return **unknown** on a missing, conflicting, expired, or unverified match. A future-effective record must not be served to a past-date learner.
- Evidence: source release ID and exact official source URL, PDF page/section anchors per rule and per reference, retrieved/source-checked timestamps, human review identity and audit timestamp, editorial notes about discrepancies, a normalized provenance fingerprint. Distinguish authoritative text from app guidance.
- Payload: versioned, schema-validated reference IDs, titles, edition codes, eligibility policy, permitted medium/binding/marking/tab rules, rule-level verification state, and ordered intra-year edition overrides. Store **no protected book text** absent reviewed rights.
- Governance: `draft` / `review_ready` / `published` / `retired` lifecycle; publication requires source review, independent approver and valid dates. Published payloads are immutable, with at most a narrowly audited published→retired status transition; new source list or correction creates the next revision. Enforce at the database boundary and through the manifest linter/CI, not only in Flutter.
- Access: published, effective metadata may be read by guests and signed-in learners under restrictive RLS; drafts/retired source detail requires authorized review. Writes are limited to existing privileged editorial/service pipelines; no client-side publish.
- Fixture: same target and curriculum-node IDs remain stable across synthetic 2026→2027 revision changes; date selects correct revision or unknown, and a change to reference content cannot silently mutate an earlier revision.

**Schema-decision caution.** Existing `content_source_releases` and `content_source_mappings` are provenance primitives, not clearly sufficient to enforce effective-date overlaps, independent manifest immutability, or per-reference room rules. Reuse them as source evidence, but do **not** overload `target_versions.metadata` with annually changing approved books. Existing `catalog_license_pathway_versions` has useful review fields and guarded publication logic but represents selected administrative licensing steps, not examination reference manifests; do not reuse it as an exam-part table.

#### A.1.3 EXM-02A item/answer binding design, specified only (not implemented)

- A reference-dependent answer must be approved **for explicit immutable manifest revision ID(s)**, not for a generic exam or calendar year. Conceptual per-item binding: `assessment_item_id`, `manifest_revision_id`, `answer_version`, stable `part_key`, expected source-release/edition, one-or-more exact section/table/exception locations, `author_of_record_user_id`, `independent_reviewer_user_id`, `ai_drafted` boolean, review timestamp, review outcome, human verification notes, and content/hash identifiers.
- Apply the canonical §3.4 human-author/independent-reviewer rule: the author cannot solely approve their own answer location. AI is never author of record. A revised edition does not inherit validity; generate an affected-item queue and explicitly review every potentially changed binding before it becomes available to learners.
- Historical attempts retain the exact item, answer, manifest, and scoring versions. Maintain multiple legitimate locations and cross-references without treating a lone citation text field as the entire approval contract. No new generic `AssessmentInteractionType` is required for initial reference drills.

#### A.1.4 EXM-01 decision target for EXM-02B durable attempts (not implemented)

- Proposed canonical owner field is an **authenticated subject ID** checked by the database against `auth.uid()`, not an unverified FK assumption to `public.users.id`; confirm the exact current auth and user schema before authoring migrations.
- Proposed immutable attempt identity: attempt UUID, owner auth subject, idempotent client attempt key, target-version ID, stable part key, manifest revision ID, approved answer binding/version ID, skill-step type, started/completed timestamps, observed app interaction timings versus self-reported physical-book use, accuracy/correctness, scoring version, and source/reviewer provenance where safe. Keep sensitive answer-key details server-protected rather than in broad public attempt payloads.
- RLS must prove account A cannot read/insert/update account B attempts, guests cannot access signed-in history, and sign-out clears private caches. Allow one authenticated subject to create/read their attempts; reject anonymous durable server records until a reviewed guest-transfer design exists. Use explicit retention, user deletion and duplicate-submit idempotency tests. A derived skill projection is optional, not a prerequisite table.
- Choose this model definitively by EXM-01 exit; implement and test in EXM-02B immediately after drills. Do not claim hosted data or passing RLS tests yet.

#### A.1.5 Official DBPR examination-source verification (source review, not publication)

**Current official index:** https://www2.myfloridalicense.com/examination-information/construction-examinations/ links General Contractor **Project Management**, General Contractor **Contract Administration**, and Building Contractor **Project Management** content outlines. On source inspection the linked documents are headed **January 2020**. The official index says its construction examinations are open-book, multiple-choice, and links reference lists separately. The index currently offering these documents is stronger evidence of current distribution than the PDF's old cover date alone; nevertheless candidate booklet consistency, later revision/supersession notices, vendor/category changes, and exact applicability still require final review before declaring the EXM-00 current-outline hard gate satisfied.

- General Contractor Project Management outline: https://www2.myfloridalicense.com/servop/testing/documents/GC%20Project%20Management%20ECI%20January%202020.pdf (PDF pages 1–2). The PDF states 60 equally weighted questions, 63% construction methods/materials/equipment, 20% safety, and 17% reading plans/specifications, including ability to read, understand and apply building codes and standards. This establishes **strong code-navigation educational fit** but does not verify a ready-to-publish reference answer key.
- General Contractor Contract Administration outline: https://www2.myfloridalicense.com/servop/testing/documents/GC%20Contract%20Administration%20ECI%20January%202020.pdf (PDF pages 1–2). The PDF states 60 questions, with 27% preconstruction, 40% contracts, 20% licensing/permits/approvals and 13% procedures/operations; it also lists code/plan interpretation. Educational fit may be more contracts-and-law-oriented than code-navigation, subject to the fixed ≤4 independently reviewed selection probes.
- Building Contractor Project Management outline: https://www2.myfloridalicense.com/servop/testing/documents/BC%20Project%20Management%20ECI%20January%202020.pdf (PDF pages 1–2). The PDF states 50 equally weighted questions, 64% construction methods, and code/plan interpretation. It is a plausible second code-heavy candidate, not a selected part.
- Official 2026 and 2027 General/Building/Residential reference lists are both linked from https://www2.myfloridalicense.com/examination-information/construction-examinations-reference-lists/ . The directly linked 2026 list: https://www2.myfloridalicense.com/servop/testing/documents/GC%20BC%20RC%20CBT%20Reference%20List%20-%20Even.pdf . The directly linked 2027 list: https://www2.myfloridalicense.com/servop/testing/documents/GC%20BC%20RC%20CBT%20Reference%20List%20-%20odd.pdf .
- **Observed PDF discrepancy:** the 2027 document cover (PDF page 1) says valid January–December 2027, but its **second page's running header says 'Valid January 2025 - December 2025'**, unlike its body notes and third-page header. Treat the inner-page date as an unresolved document conflict. **Do not normalize this away or publish as settled without regulator/source-owner confirmation.**
- **Observed body, not independently regulator-clarified:** 2027 PDF page 2 lists OSHA 29 CFR Part 1926 July 1, 2025 followed by an **August 1, 2027** transition to the July 1, 2026 edition, and 2023 Florida Building Code volumes followed by an **August 1, 2027** transition to 2026 volumes. Its Contractor's Manual is listed 2025; Energy Efficient Building Construction 2023; BCSI-ED2-D 2025. The 2026 PDF page 2 lists 2023 FBC, a **July 1, 2026** in-year Contractor's Manual 2025 switch, and BCSI 2025 switch. These are primary-PDF observations **only**; the apparent out-of-date header and differing Energy Efficient Building Construction editions require reconciliation. Never apply the 2027 rules to a 2026 exam date.
- **Reference-room rule observation on 2027 PDF page 1:** bound originals (with specifically indicated PDF copies allowed subject to binding rules), underlining/highlighting already present permitted, no handwritten/typewritten notes, no movable tabs, no additional marks during the exam, no electronic tablets. Do not generalize to Service Pool or other trade categories. Confirm the exact selected part, list, delivery mode, and candidate-booklet rules again immediately before pilot publication.

#### A.1.6 Open decision gate; no schema or pilot authorization implied

1. **Owner to choose/authorize the proposed independent manifest record design** after review. No DDL was created; EXM-01 is still an implementation gate.
2. **Owner to approve the initial candidate part** only after current-outline applicability and independently reviewed ≤4 nonproduction selection probes. Based on official outlines alone, General Contractor Project Management and Building Contractor Project Management are the most promising code-oriented *candidates*, not a final selection. Reviewer recruitment begins with broad construction expertise, followed by a specific part/edition/independence check.
3. **Unresolved source confirmation:** address 2027 list's mismatched running header and establish which effective-dated rules/regulator publications actually govern the chosen administration period. Until reconciled, all affected fields remain unknown and are not published.
4. **EXM-P0 status — tested:** mock-safety changes are in PR #62, now ready for review but not merged. On the final P0 commit `2cf197ca29020a9b1c3163697c011adb9e19ec9d`, **GitHub Flutter CI run 39185681566 succeeded**: Analyze, Run tests, Build web release, migration governance and local clean-slate migration steps all finished successfully. Official Taxonomy Data run 39185681555 also succeeded. No local Flutter SDK was available; the claim is CI-tested, not locally tested or deployed. Historical user records have not been transformed.
5. **EXM-01+ boundaries:** no live or local database schema changes, no staging/publishing reference lists, no source book purchases, no user-facing pilot, no cross-account migration, and no separate mandatory EXM documents were authorized by this audit.

**EXM-00 evidence classification:** Source and existing-code inspection = observed/coded. Proposed entity/contracts = proposed. New CI and DB validation = **not tested**. Hosted schema/data state = **not verified**. Actual learner effectiveness = **not validated**.

---
### A.2 — EXM-01 initial implementation / hosted-schema verification

- **Branch and review:** `feature/exm-01-reference-manifest-foundation-20261018`, draft PR #64, stacked on EXM-00 PR #63. This is a first implementation slice, **not EXM-01 acceptance/completion**.
- **Coded:** `lib/models/assessment_engine/exam_reference_manifest.dart` defines validated part keys, draft-allowed unknown official facts, primary-source evidence-ID integrity, independently versioned manifest read records, and a fail-closed effective-date selector using actual administration date. The synthetic 2026→2027 and within-2027 fixtures test transition boundaries without publishing official dates/editions. `lib/widgets/targets/exam_preparation_overview_card.dart` is used from existing `TargetDetailScreen` and makes no unsupported checklist/passing claims.
- **Focused test sources and result:** `test/unit/assessment_engine/exam_reference_manifest_test.dart`, `test/widgets/exam_preparation_overview_card_test.dart`. First GitHub CI identified a test-fixture mismatch (an unapproved manifest incorrectly marked published), corrected in commit `1f75d39c239fc10ce07e424dd6859f27f66bd865`. On that commit GitHub Flutter CI run `39187946124` completed **Analyze**, **Run tests**, and **Build web release** successfully. The separate clean-slate Supabase migration/pgTAP job also completed successfully, and the full GitHub Flutter CI run `39187946124` concluded **success**. Official Taxonomy Data run `39187946090` concluded **success**. These are CI checks on the code commit, not a production migration or deployment.
- **Hosted read-only verification:** Information-schema inspection confirms existing public `target_versions`, `curriculum_nodes`, `assessment_items`, `content_source_releases`, `content_source_mappings`, and `catalog_license_pathway_versions` fields align with expected identities. Migration history contains releases through `20261016020000`; recheck the repository's **complete** migration set and guarded tooling before generating any new migration. Hosted EXM-01 reference-manifest table is not present or published by this work. No user records were queried.
- **Supabase API/RLS gate:** A future new `public` table requires explicit role grants alongside row-level security, per https://supabase.com/docs/guides/api/securing-your-api and the Supabase API exposure change. Never equate RLS with REST exposure or grant authenticated users review/publish privileges. Keep default draft data private and publication gated by independent source review.
- **Still outstanding:** Generate the uniquely numbered append-only SQL migration using the repository's Supabase CLI/guarded process, implement immutable publication and overlap enforcement, test clean-slate DB/RLS and revision rollover, connect approved manifest retrieval to a dated checklist, verify official sources and part-root membership, finalize EXM-02B attempt storage design. No production data changes, regulatory reference publication, or part selection.
- **Decision:** Owner authorized development through this phase, but not automatic merge/deployment or any production SQL writes. Publication gates in §3.4 and phase EXM-01 remain in force.

---

### A.3 — EXM-01 manifest governance and date-specific learner lookup

- **Scope and review branches:** [PR #65](https://github.com/RACCHUS/LearningApp/pull/65) adds one independent effective-dated schema and pgTAP tests, based on EXM-01 profile PR #64. [PR #66](https://github.com/RACCHUS/LearningApp/pull/66) adds the read-only retrieval and goal-page date picker, based on #65. Both are review-stage development, not a production release; the owner-approved Sections 0–16 are unchanged.
- **Coded schema:** `supabase/migrations/20261025010000_exm_01_reference_manifest_revisions.sql` defines `exam_reference_manifest_revisions` with a FK to immutable curriculum versions but independent `revision`, source release/provenance, reviewer/source timestamps, verified reference entries, room-rule state, effective dates, GiST exclusion of overlapping published date windows, a guarded published→retired transition, and RLS with explicit SELECT-only access for public learners. There are no seeded regulator list records or physical exam source books.
- **Source/publication guard:** Publication requires a public, published target version, a profile exam-part key with a real same-version curriculum root, independent accountable author/reviewer aliases, source-release URL match, source evidence review after capture, and citation pages. Internal reviewer notes are not stored in the public manifest payload. Missing claims stay unknown; source provenance is not a substitute for expert confirmation of the regulator's actual effective PDF.
- **Database tests:** `supabase/tests/exam_reference_manifest_revisions_test.sql` contains 25 pgTAP assertions, including privileges, publication guards, immutability, overlap and adjacent-year windows, foreign exam-part failure and retired-history isolation. GitHub Flutter CI [run 39190140377](https://github.com/RACCHUS/LearningApp/actions/runs/39190140377) passed Analyze, Run tests, Web build, incremental migration upgrade, clean-slate migration and pgTAP (source commit `56f083d9b978d4491a1eedddb451c97972648433`). Source registry workflow also passed.
- **Client implementation:** `lib/services/assessment/exam_reference_manifest_service.dart` reads only approved published revision metadata and calls the fail-closed selector with the learner's actual administration date; network/parse problems are separate from genuine no-applicable-revision. `lib/widgets/targets/exam_preparation_overview_card.dart` adds in-context part/date selection, factual non-availability messaging and links to approved primary sources while retaining Learn/Library/Progress. Dedicated service and widget tests cover valid lookup, 2026→2027 isolation, ambiguity and unavailable-source responses. GitHub Flutter CI [run 39190144153](https://github.com/RACCHUS/LearningApp/actions/runs/39190144153) passed before the branch cleanup. **Post-rebase full CI [run 39190899533](https://github.com/RACCHUS/LearningApp/actions/runs/39190899533) passed** on source/docs commit `5e89736dea959ddc517924b34e0dbbbad8cae0fe`, including Flutter analysis/tests/web build, incremental/clean-slate local migrations, pgTAP and post-ingestion checks. [Official Taxonomy Data run 39190899539](https://github.com/RACCHUS/LearningApp/actions/runs/39190899539) also passed.
- **Hosted safety:** The project was queried for schema metadata **read-only** earlier in EXM-01. No `apply_migration`, hosted DDL/DML, published DBPR list, item binding, learner attempts, production build or merge was executed. The local environment lacks a cached Supabase CLI; the new migration follows the repository's established append-only filename contract and has been tested by CI's pinned CLI, but the local CLI generator command could not be run.
- **Branch review hygiene:** The lookup branch was rebased onto the verified governance branch after both received equivalent SQL test corrections. A Git comparison confirms PR #66 contains only its service, model, widget, tests, and this Appendix A entry; the schema and pgTAP files are separately reviewed in PR #65. The post-rebase head was verified successfully by CI run 39190899533. All production writes and reference publication remain unperformed.
- **Open phase gates:** Verify the correct official DBPR 2027 PDF dates, editorial source credentials and part selection with a qualified independent reviewer. Populate/publish a real approved manifest only through a separate authorized source-review and guarded release. EXM-02A item-to-manifest answer validity, EXM-02B owner-scoped durable attempts/RLS, and EXM-03 part-specific mock fidelity remain unimplemented; EXM-01 learner overview is a safe scaffold, not evidence of a complete real pilot.

---

### A.4 — EXM-02A item/edition validity foundation (synthetic fixtures only)

- **Branch / review:** `feature/exm-02a-item-manifest-validity-20261018`, draft PR #68, stacked after EXM-01 reference-lookup PR #66. This is **technical groundwork only**, not a completed R1–R4 drill, expert review or pilot.
- **Coded migration:** `supabase/migrations/20261025020000_exm_02a_item_reference_validity.sql` adds private `assessment_item_reference_validity` with one exact manifest UUID per binding, canonical item UUID/content fingerprint/revisions, exact reference-edition key and source release, reviewer-authored section/page locations (no protected book text), explicit AI-draft flag, accountable author, separate human reviewer and qualification/edition-access evidence, rights status, and review minutes. A published item/content and approved answer location are immutable except recorded retirement; changing editions requires a separate independently approved binding.
- **Missing-next-edition queue:** the service-role-only `exam_reference_items_requiring_review(prior_manifest,new_manifest)` lists previously approved items for which an approved binding to the new revision is **missing**. A new manifest or a merely drafted binding never auto-approves answers, even if the book's title appears unchanged. Prior historical bindings remain traceable.
- **Privacy / scope:** table access is service-role-only, with RLS enabled and no end-user SELECT or write grants. No confidential review notes or held-out answer locations are published via the Data API. The future learner drill API must return only authorized learner-safe tasks after enforcing the manifest/current-date selection and approved binding gate.
- **Synthetic verification source:** `supabase/tests/exam_item_reference_validity_test.sql` tests publication gating, independent review, AI provenance immutability, item-content freeze, manifest rollover, re-review queue and private RLS privileges using entirely fictional references/items. **Verified in GitHub CI:** `supabase/tests/exam_item_reference_validity_test.sql` includes 30 synthetic pgTAP assertions, including DB-calculated SHA-256 fingerprint verification and forged-fingerprint rejection. [Flutter CI run 39192747582](https://github.com/RACCHUS/LearningApp/actions/runs/39192747582) completed successfully on code commit `e6eac6b52345cc994fe53dc9d86b3656dd08883d`: Flutter analyze/tests/web build, incremental migration upgrade, clean-slate migrations/pgTAP, and post-ingestion integrity. [Official Taxonomy Data run 39192747576](https://github.com/RACCHUS/LearningApp/actions/runs/39192747576) also passed. These are **local disposable CI** tests, not real content validation or production deployment.
- **EXM-02B storage decision carried forward:** Canonical drill attempts should be append-only per authenticated `auth.users.id` subject, using `auth.uid()` RLS and a per-owner idempotency key; store exact manifest/binding/item and scoring versions, part key, R1–R4 step, timestamps, separate observed-app vs self-reported book-use duration, minimal correctness/skill components, and user-directed deletion/retention controls. No anonymous server attempts or account-crossing local cache keys; do not store protected book text or reviewer-only answer keys. This describes the EXM-01 decision for the **separate EXM-02B implementation**, not an already implemented table.
- **Unmet content gates:** qualified external reviewer, owner-approved code-heavy pilot part, exact authorized source editions, independent source and rights review, and the 16 practice/8 held-out authored exercises. Until these exist, there is no EXM-02A learner pilot and no credible measured learning benefit. No hosted DDL, publication or merge was performed here.

---

### A.5 — EXM-02A R1–R4 practice-engine slice

- **Coded in a separate review branch:** `feature/exm-02a-r1-r4-drill-engine-20261020`, stacked on draft EXM-02A validity PR #68. `lib/models/assessment_engine/reference_drill_engine.dart` introduces four independently observed reference-navigation stages: R1 source choice, R2 section, R3 interpretation and R4 application. Each step records separate correctness and elapsed *in-app* time, with physical-book duration accepted only when explicitly self-reported. No issuer-scaled score or composite mastery prediction is generated.
- **Tests:** `test/unit/assessment_engine/reference_drill_engine_test.dart` covers step ordering, independent R2 drills, weak-link isolation, missing responses, negative-time rejection and no approval inheritance across manifest revisions. All test inputs are invented and do not validate any DBPR answer.
- **Important boundaries:** The in-memory task includes synthetic expected answers and therefore **must not** be fetched directly from the private editorial answer-binding table by the learner; learner-safe prompts/scoring require a separately designed trusted review-scoring endpoint or properly secured review-gated delivery model. This foundation is not integrated with a live UI or EXM-02B attempt store, and no real reviewer-approved items exist yet.
- **Verification:** Pending CI verification at the corresponding code commit; no hosted database activity, item publication or deployment.

---

### A.6 — EXM-02B durable, owner-isolated UNGRADED attempt-event foundation

- **Branch:** `feature/exm-02b-durable-drill-attempts-20261020` (stacked on EXM-02A R1–R4 drill-engine PR #76); no hosted Supabase migration, merge, or deployment authorized.
- **Additive migration:** `supabase/migrations/20261025030000_exm_02b_durable_drill_events.sql` defines append-only per-step `exam_reference_drill_events` with FK to actual `auth.users.id`, per-owner client-attempt ID and step uniqueness, exact canonical item/answer binding/manifest IDs and content revisions, part and actual exam administration date, bounded app elapsed and separately identified self-reported book time, and database receipt timestamp. Client-submitted records are always `verification_state='unverified'`; they contain no answer-key text or verified correctness/mastery score.
- **Database admission checks:** A privileged trigger only checks private editor-approved version-pinned bindings and manifest applicability, item fingerprint and same-attempt consistency. It never exposes private keys. New events for unsupported dates, wrong revision/part or unapproved answers are rejected. The trigger is not callable as an RPC. The user can explicitly delete their own practice history; no update grant/policy exists and account removal cascades history.
- **Guest and ownership RLS:** Authenticated **permanent** users alone may select/insert/delete their own rows, combining `owner_auth_uid=auth.uid()` with the documented Supabase JWT `is_anonymous=false` test. Supabase anonymous Auth guests use the same `authenticated` DB role but have no server attempt history; they may use disposable in-memory practice until an approved identity-transfer design is implemented. Cross-account READ, INSERT reassignment and DELETE must all fail tests.
- **Client:** `lib/services/assessment/exam_reference_drill_event_service.dart` records and retrieves owner-only observations without global account-shared cache or client-side scores. It rejects signed-out and anonymous users, validates step/revision/timing and handles idempotent retry collisions without UPDATE privileges. `test/services/assessment/exam_reference_drill_event_service_test.dart` covers client guards and unscored payloads.
- **Synthetic database tests:** `supabase/tests/exam_reference_drill_events_test.sql` exercises API role privileges, RLS account isolation, anonymous users, version/date pinning, duplicate event rejection, immutable user history and owner-directed deletion. The fictional fixtures do not prove real exam learning or licensed-reference correctness.
- **State of completion:** EXM-02B **foundation**, not end-to-end accepted phase. No real R1–R4 learner screens are connected to durable persistence and there is no trusted private answer-scoring endpoint, authenticated-user deletion export UX or retention review. Neither app-observed times nor client-completion assertions are treated as verified learning evidence. **Verified on source commit `22b40576ebc31c510087c1b5118c799d0b68e0cd`:** GitHub [Flutter CI run 39524986354](https://github.com/RACCHUS/LearningApp/actions/runs/39524986354) completed successfully, including Flutter analyze, unit/widget tests, web release, append-only migration gate, incremental local migration upgrade from current main, clean-slate pgTAP (29 new synthetic RLS/ownership checks) and post-ingestion integrity. [Official Taxonomy Data run 39524986376](https://github.com/RACCHUS/LearningApp/actions/runs/39524986376) also succeeded. All database work ran against disposable CI infrastructure only.
- **Migration governance:** This feature branch was based on a stacked EXM branch while `main` continued evolving with separate governance migrations. All three unmerged EXM-01/02A/02B migrations were re-sequenced as 20261025010000, 20261025020000 and 20261025030000, respectively, after the latest 20261022000000 main baseline. No migration already in main was altered. Reconcile the branch with current `main` under the repository's append-only guard before merge; local Supabase CLI was unavailable, so the migration file was created following existing repository convention, not by claiming to run `supabase migration new`.

---

### A.7 — EXM-02B saved-practice history and account-switch isolation

- **Development scope:** `feature/exm-02b-owned-history-ui-20261020` stacked on EXM-02B attempt-event PR #77. Adds `SavedReferenceDrillHistoryCard` **only beneath an independently approved and applicable reference manifest** in the existing Target Details exam overview; no new top-level app navigation, no unreviewed 2027 list or scored item release.
- **Safe account and edition scope:** A permanent authenticated learner can expand the private history panel for that **exact manifest UUID**. `authProvider` drives a keyed per-owner session so account A's mounted widgets/futures are destroyed on switch to B. `ExamReferenceDrillEventService.listMyEvents` now accepts `expectedOwnerId` and manifest ID, filters both at the Data API and in returned rows, and rechecks `auth.currentUser` after the request; out-of-date requests must fail closed.
- **Deletion:** A learner may explicitly confirm deletion of all saved step observations for an attempt in that manifest, not another edition. The service verifies owner ID at the time of deletion and keeps the existing server-side `auth.uid()`/RLS boundary. Failed deletions are surfaced as failures, not successes. The history panel distinguishes ungraded observations from officially verified correctness/pass predictions and caps display at 100 recent step records, stating when truncated.
- **Regression tests:** `test/widgets/saved_reference_drill_history_card_test.dart` exercises guest/sign-out states, foreign-owner/wrong-manifest filtering, account-A delayed response after switch to B, and confirmed/canceled deletion. Service tests add owner-mismatch fail-closed and edition isolation; the existing official-reference date-picker test receives an explicit guest auth scope.
- **Content boundaries:** This UX is non-functional for real exam practice until an owner-approved code-heavy pilot part, real edition manifest and independently reviewed tasks are published through their separate gates. It does not connect the R1–R4 scoring engine or claim learner effectiveness. Secure answer checking and full data export/retention governance still require future development. No production Supabase writes, merge or deployment.
- **Verification status:** **Verified on code-and-doc tree `48cd5d82e4d1ac2e8914ea8ad289c2ae9aedf8b9`:** GitHub [Flutter CI run 39531133041](https://github.com/RACCHUS/LearningApp/actions/runs/39531133041) succeeded (Flutter analyze, tests, web build, append-only migration history, incremental upgrade from the latest main baseline, clean-slate pgTAP and post-ingestion integrity). [Official Taxonomy Data run 39531133051](https://github.com/RACCHUS/LearningApp/actions/runs/39531133051) also succeeded. This is code/database CI verification, not a real exam-content review, hosted migration or production deployment.

---

**Final proposed implementation principle:** *Prepare a learner for the actual tasks and constraints of the exam: know what must be remembered, find what may be referenced, interpret correctly, act accurately, and finish within permitted time—while stating exactly what the app has and has not measured.*

---

### A.8 — EXM-02B R1–R4 durable step recorder (development only; CI verified)

- **Date / phase / branch:** October 20, 2026; EXM-02B continuation on `feature/exm-02b-r1-r4-attempt-recorder-20261020`, stacked above draft PR #79. **Status: coded and CI-tested on `2badce579bbc6853634f6ea3ab82da121da93cb0`; owner/security review pending**.
- **Implementation:** `lib/services/assessment/reference_drill_attempt_recorder.dart` introduces an answer-free, attempt-scoped R1–R4 adapter with the exact assessment item, approved binding, reference manifest revision, exam part, administration date, and content/answer revisions. A permanent-account owner is captured by the caller; `recordStep` now accepts `expectedOwnerId` and rejects an account switch before the insert. Steps are sequential, have a stable UUID per attempt, and record distinct app-measured proxy duration and optional self-reported physical-book time. A failed write retains the *same* pending step, timestamps and attempt UUID for safe idempotent retry. No answer/score/protected book text is posted by the recorder.
- **Test coverage added (verified by CI):** `test/services/assessment/reference_drill_attempt_recorder_test.dart` checks R1–R4 ordering and metadata, standalone R2, guest rejection, changed-account refusal, version identity validation, and missing private key/score fields in outgoing events.
- **Security boundary:** This class is **not** a verified learner task-delivery service or scoring authority. The existing SQL trigger still validates a supplied binding against private editorial review and correct source/date/part, but no real approved pilot item is seeded. `DisposableReferenceDrillSession` contains expected answers for synthetic in-memory unit fixtures only; never expose that structure or those keys in a learner bundle for a live drill. Client timing/responded flags remain *unverified observations*. A separate server-private reviewed-answer delivery/scoring contract, protected item selection, learner-facing integration, export/retention acceptance, CI and owner review are still outstanding.
- **Verified test run (tested code commit `2badce579bbc6853634f6ea3ab82da121da93cb0`):** [Flutter CI 39534083897](https://github.com/RACCHUS/LearningApp/actions/runs/39534083897) **SUCCESS**, including analysis, Flutter tests, web release build, migration-history checks, incremental and clean-slate migration/pgTAP checks and taxonomy ingestion integrity. [Official Taxonomy Data 39534083921](https://github.com/RACCHUS/LearningApp/actions/runs/39534083921) **SUCCESS**. The subsequent Appendix A status update is documentation-only and does not change the tested implementation blobs.
- **Scoring/design limitation:** The private EXM-02A binding currently represents reviewed edition and `expected_locations`; that does not, by itself, supply a complete independently reviewed per-step R3 interpretation / R4 application scoring schema. A trusted server-side contract for all step responses, key revisions, private reviewer-approved answer material and retryable verified scoring is needed before graded evidence or a public practice screen. No client claim may be upgraded from `unverified`.
- **Hosted state:** No merge, production Supabase migration, hosted DML, official content publication or deployment was attempted.

---

### A.9 — EXM-02B private reviewed R1–R4 scorer (draft development; CI verified)

- **Date / code branch:** October 20, 2026; `feature/exm-02b-trusted-step-scoring-20261020`, stacked on draft PR #81. **Status: coded and CI-tested at commit `c3e8baf45a955d80b1ae354b80fe3cd467b2f6f1`; independent owner/security review pending**.
- **New migration (unapplied):** `supabase/migrations/20261026000000_exm_02b_private_scoring.sql` introduces `exam_reference_drill_scoring_keys`, a **private editorial** exact-binding/version R1–R4 token rubric with explicit AI provenance, human author, independent qualified reviewer, exact-edition access and rights approval. The production item content and manifest binding must also be published, fingerprint-consistent and effective for the learner's exam date. A published rubric cannot be rewritten. R1 book and R2 location must reconcile with the already reviewed binding.
- **Server-grade path:** `score_exam_reference_drill_step(event_id, answer_token)` is an authenticated-only SECURITY DEFINER RPC that checks permanent Supabase Auth ownership and a prior responded event before accessing reviewer-only answer tokens; returns **only** step, boolean correctness, scoring version and server timestamp. Grade rows are owner-read-only, server-inserted, unique per event and cascade-deleted with the user's private event; no submitted answers, raw text, answer keys or response hashes are persisted in the grade table. Retries return the original grade even with a different guess; a per-owner/binding rolling 24-hour cap of 20 graded events limits brute-force probing. Physical book handling, app timing and self-reported durations remain explicitly **unverified**.
- **Client:** `lib/services/assessment/exam_reference_drill_scoring_service.dart` strictly parses the minimal RPC receipt, validates response tokens and refuses guest, wrong-owner or account-switched async results. It does not carry private reviewed answer material, locally derive correctness or cache scores. The existing synthetic `DisposableReferenceDrillSession` must **not** be connected to a live learner route: it still carries expected answers in memory.
- **Tests:** `supabase/tests/exam_reference_drill_private_scoring_test.sql` covers editorial publication, private RLS/grants, direct-score forgery denial, R1–R4 correctness, duplicate-submit, skipped step, account B/anonymous guest, rate cap and owner delete cascade. `test/services/assessment/exam_reference_drill_scoring_service_test.dart` covers auth lifecycle and malformed RPC receipts. Initial CI found one pgTAP error-code expectation mismatch (expected SQLSTATE `23514` where the reviewer trigger correctly returned `P0001`); the assertion was corrected without altering the security behavior. All 32 scoring assertions then passed in the verified rerun.
- **Outstanding / stop gate:** No published real 2027 pilot items/rubrics, regulator-source reconciliation, secure learner-facing *question delivery* contract, UI wiring, full learner Progress aggregation, browser/session-restoration, complete data export or retention policy approval. This private correctness check measures a submitted reviewed token, **not** independently observed open-book navigation or an issuer pass prediction. Review any over-permissive tokens, grader oracle policy, privacy/logging and rubric-authoring UI before any external pilot.
- **Verification:** [Flutter CI 39537282182](https://github.com/RACCHUS/LearningApp/actions/runs/39537282182) **SUCCESS** on code commit `c3e8baf45a955d80b1ae354b80fe3cd467b2f6f1`, including Flutter analysis/tests, web release build, migration-history governance, incremental migration upgrade, clean-slate migrations/pgTAP, and post-ingestion database integrity; [Official Taxonomy Data 39537282380](https://github.com/RACCHUS/LearningApp/actions/runs/39537282380) **SUCCESS**. Subsequent note-only commit updates Appendix A and must not be mistaken for a fresh code test. Security-owner review and hosted production verification still pending.
- **Production boundary:** No merge, hosted DDL/DML, guarded production migration, editorial publication or deployment.

---

### A.10 — EXM-02B original reviewed prompt delivery + in-context R1–R4 learner practice (draft; CI pending)

- **Code / date:** October 20, 2026; branch `feature/exm-02b-reviewed-practice-delivery-20261020`, based on draft PR #82. **Status: coded, automated tests added, pending CI and independent review**.
- **Additive private schema:** `supabase/migrations/20261026010000_exm_02b_reviewed_practice_delivery.sql` adds a private `exam_reference_drill_presentations` editorial record with four original prompts, explicit answer candidates, item-specific publication/revision, rights approval, AI provenance, human author and separate qualified reviewer. Published originals are immutable and must have a published, independently reviewed exact-binding scoring key. All approved response tokens must be among the displayed choices; draft/held-out/unreviewed items have no delivery route. No practice items or regulatory sources are seeded.
- **Safe projection:** An authenticated-only, permanent-account `get_exam_reference_drill_practice` RPC returns only a reviewed original prompt and choices with immutable item/binding/manifest/content revision identity, exact part and administration date. It does not fetch/return `assessment_items.scoring_spec`, private `step_tokens`, reviewer evidence or protected reference excerpts. Date/part/version unavailability returns NULL, not guessed questions. Reviewer and rights diligence remain necessary; string-length checks are not automated copyright review.
- **Flutter:** `exam_reference_drill_practice_service.dart` rejects extra/private response fields, wrong date/part/edition, guests, and async owner changes; `reviewed_reference_drill_practice_card.dart` is displayed only after the existing verified reference lookup in Target Details. The learner explicitly chooses to load reviewed questions; R1–R4 prompt choices are recorded via the existing version-pinned attempt recorder, then scored by the server-owned scorer. Skip is persisted as an ungraded step. App proxy time and optional self-reported physical-book seconds remain separate. If a step was saved but scoring fails, the UI retries the original event ID/response without writing another event; it retains the active step until scoring succeeds. Account/date/revision keyed widget state prevents cross-account or stale-revision presentation.
- **Tests added:** `supabase/tests/exam_reference_drill_presentation_delivery_test.sql` covers private grants, reviewer signoff, immutable publication, 2026/2027 fail-close, part matching, safe output field boundaries and guest denial; service tests cover stale account completions and strict projection parsing; widget tests cover guest restrictions, no automatic fetch, R1–R4 ordered recording, transient scoring retries, no approved item and account-switch disposal. **Tests not yet a pass claim.**
- **Remaining gates:** Current scoring protocol supports original multiple-choice answer tokens, **not** free-form text interpretation or supervised proof of physical reference navigation; educator editorial workflow, held-out inventory partition, real verified 2027 content, privacy/logging security review, grade/Progress history integration, export, data-retention approval and pilot testing remain incomplete. No unsupported issuer passing prediction is shown. External pilot remains blocked.
- **Production:** No merge, real item publication, production Supabase DDL/DML, migration repair or deployment.

---

### A.11 — EXM-02B current-main compatibility integration (code review; CI pending)

- **Branch / base:** `feature/exm-02b-integration-20261020`, current `main` at `8dee5aa9b185887b968bc507cfebb51ad34b2da3`, retaining all independent ECO-01 and governance changes. **Status: assembled, CI pending; no merge or production writes**. The earlier draft PR stack #76 / #77 / #79 / #81 / #82 / #84 remains unmodified for focused review.
- **Why:** `main` added `20261026000000_eco_01_insert_hardening.sql` after the prior EXM tests, causing an exact migration timestamp collision and new-file backdating failures in CI. None of those checks are bypassed or repaired in the hosted migration ledger.
- **Reconciliation:** Five **unmerged EXM-only** SQL migration files were copied with their tested source blobs, preserving order and source contents but using monotonically appended names after latest `main`:
  - `20261027010000_exm_01_reference_manifest_revisions.sql`
  - `20261027020000_exm_02a_item_reference_validity.sql`
  - `20261027030000_exm_02b_durable_drill_events.sql`
  - `20261027040000_exm_02b_private_scoring.sql`
  - `20261027050000_exm_02b_reviewed_practice_delivery.sql`
- **Merge/review gate:** This is a cumulative integration branch to run checks on current `main`. Compare its implementation/test/documentation blobs with the corresponding individual draft PR slices before any consolidation. Do not merge overlapping cumulative and stacked PRs separately. An approved final strategy must reconcile exact migration filenames, review findings, production RLS and guarded deployment preflight, with no alternate version aliases and no direct hosted SQL.
- **Verification — TESTED:** [Flutter CI 39540166533](https://github.com/RACCHUS/LearningApp/actions/runs/39540166533) **SUCCESS** against integration code commit `5da2acba9c23ce1739439ccf97f7e929c2f7e374`: Flutter analysis, tests, web build, migration immutability, incremental upgrade from `main`, clean-slate migrations/pgTAP and official taxonomy ingestion integrity. [Official Taxonomy Data 39540166499](https://github.com/RACCHUS/LearningApp/actions/runs/39540166499) **SUCCESS**. A first integration run uncovered an incorrect widget assertion that disallowed the existing explicit 'do not predict licensing-exam success' disclaimer; the test was corrected without weakening the disclaimer. All six new learner-service/widget/SQL test and implementation blobs, plus the reviewed-delivery migration content, were confirmed SHA-identical between focused PR #84 and tested integration commit (renamed migration path only).
- **Open:** Technical CI is complete; the required independent privacy/security/owner review, 2027 original pilot item authoring, data export, retention and learner validation remain pending. Any new `main` migrations before merge must be reconciled with append-only governance. No production write or deployment was performed.

---

### A.12 — EXM-02B R1–R4 graded-evidence Progress and owner-owned JSON export (draft; CI verified)

- **Branch / ancestor:** `feature/exm-02b-skill-progress-export-20261020`, stacked above current-main integration draft #85 at `86b9bbcfe51132269372e85e07e2594b9213a826`. **Status: code and automated checks passed at `5a86d323f9149223d38c421ea533e9793567ecc9`; independent owner/security review pending**.
- **Additive SQL migration:** `supabase/migrations/20261027060000_exm_02b_progress_export_page.sql` adds a matching owner+manifest+receipt cursor index and `exam_reference_drill_progress_page(manifest_uuid, limit<=100, before_recorded_at, before_event_id)`. This deliberately uses `SECURITY INVOKER`, requiring the caller's existing ordinary `SELECT` grants and independent RLS policies on both events and server grades; a permanent Supabase Auth identity is checked before any data. Composite timestamp/UUID cursor order avoids silent 100-row truncation. Projection excludes reviewer keys, original question text, submitted learner answers and issuer score claims.
- **Flutter model/service:** `exam_reference_drill_progress_service.dart` validates exact event owner/manifest and strict projection fields, compares server-returned timestamps/IDs for stable descending keyset pagination, rejects duplicates or malformed/fabricated scoring states, and fails CLOSED above 5,000 rows rather than labelling truncated material a complete export. Within a completed scoped read, `ReferenceDrillProgressSnapshot` counts R1–R4 correct and incorrect server-graded responses separately from saved responses awaiting grading and skipped steps. Timings remain unverified client/self-report observations. JSON export includes original item, binding and answer/source revisions, exam part/date, observation times and grade-version provenance—**never answers, private keys, reviewer evidence or unsupported passing probabilities**.
- **Learner UI:** `reference_drill_progress_card.dart` is owner-session + manifest keyed, explicitly lazy-loaded within the existing approved-date Exam Preparation overview. R1–R4 totals explain the low-sample counts without conflating score with mastery. The scoped export is a **confirmed copy-to-clipboard JSON** operation, not a disk download or whole-account archive; clipboard privacy is clearly disclosed. Refresh, sign-out or account switching invalidates the view. Existing delete-attempt cascades through scored rows; no new client UPDATE capability.
- **Verification added:** pgTAP `exam_reference_drill_progress_export_test.sql` exercises `SECURITY INVOKER`, private-key denial, exact version scoping, server-only grades, unscored/skipped separation, cursor paging, invalid limits, guest denial and account B isolation. Dart service tests cover full pagination, fail-closed bound, JSON data minimization and stale async/account mismatch; widget tests cover lazy load, no synthetic grade, export consent and cross-account disposal. Initial CI exposed an invalid extra UUID group in the client validator, and a subsequent replacement operation corrupted the service source. Both were corrected and verified by the full third run; earlier failed runs are retained as audit evidence. The latest full suite passed.
- **Verified CI:** [Flutter CI #39541968383](https://github.com/RACCHUS/LearningApp/actions/runs/39541968383) **SUCCESS**, including Flutter analyzer/tests/web build, mainline migration history and incremental upgrade, clean-slate PostgreSQL+pgTAP (including the new 21-assertion progress suite), and post-ingestion taxonomy integrity. [Official Taxonomy Data #39541968392](https://github.com/RACCHUS/LearningApp/actions/runs/39541968392) **SUCCESS** on the same tested commit. The following Appendix A documentation commit does not change application or migration blobs.
- **Limitations and review gates:** This is a single-reference-edition, exact-manifest snapshot, NOT account-wide data portability. A multi-page export is cursor-consistent but not a single repeatable-read database transaction; concurrent deletion/new writes could affect the read. There is no offline export, direct native-file download or formal retention schedule in this slice. A privacy/security owner must approve the clipboard UX, 5,000-record limit, retention and disclosure rules before external pilot. Independent editorial 2027 real question authoring, held-out isolation, EXM final acceptance and deployment review remain outstanding. No hosted data or production migration was modified.

---

### A.13 — EXM-02B Current Context Progress integration (draft development; CI verified)

- **Code / scope:** October 21, 2026; branch `feature/exm-02b-context-progress-20261021`, stacked above draft PR #86. Only the existing **Progress → Current Context** screen is extended; the All Knowledge and canonical `user_concept_state` mastery calculations and issuer-readiness models remain completely untouched.
- **RLS and review scope:** The *unapplied* additive `supabase/migrations/20261027070000_exm_02b_context_progress.sql` introduces a `SECURITY INVOKER`, permanent-owner-only `exam_reference_drill_context_progress(p_target_version_id)` aggregate. It joins owner-RLS saved R1–R4 event observations and private server grade receipts to **currently published/approved** reference manifests belonging to one exact target-version ID, grouping by **manifest revision + exam part + drill step**. It returns counts for checked correct/incorrect responses, saved-but-unscored responses and skips separately, plus latest recorded time. No private reviewer data, answer tokens, physical-book claims or client-generated score enter the projection. A 100-group cap raises an explicit error instead of silently truncating, although a concurrent write between count and read remains an identified caveat.
- **Owner-keyed UI:** `lib/widgets/progress/reference_context_progress_card.dart` is loaded only for a permanently signed-in owner whose active LearningContext is a target with a pinned version and matching user ID. Its owner+context+target-version widget key isolates stale session state. Requests start on deliberate click, are checked again after every awaited request and cannot populate another account's Progress. Counts remain per exam part + approved edition; not blended into an exam score, concept mastery, global engagement metric or pass prediction. The existing Target Details exam-specific progress JSON remains the only edition export surface.
- **Tests:** Dedicated SQL pgTAP, Dart service and widget tests cover RPC grants and invoker RLS, account B and anonymous guest denial, wrong target-version exclusion, strict response-shape and score-count validation, skipped/unscored split, lazy loading and cross-account widget disposal. The dedicated SQL pgTAP and Flutter service/widget suites all passed as part of the verified integration CI.
- **Verification:** Code and test blobs were confirmed SHA-identical between focused PR #88 and integration PR #89. [Flutter CI #39543890944](https://github.com/RACCHUS/LearningApp/actions/runs/39543890944) **SUCCESS** and [Official Taxonomy Data #39543890865](https://github.com/RACCHUS/LearningApp/actions/runs/39543890865) **SUCCESS** on exact tested integration code commit `bb5cac14760449f282cdb1c26c0deb0e24128ac4`. CI includes Dart/Flutter analysis, unit and widget tests, web build, migration history guard, current-main incremental upgrade, clean-slate migrations and pgTAP, taxonomy ingestion and post-ingestion integrity. Following Appendix-only commits add verification references but do not change tested implementation files. Current-main comparison performed against `8581e5bd7338a8fa13ce36552cf8721be1955f1d` including the ECO-02 moderator migration. Independent owner/privacy/security review still outstanding.
- **Outstanding / evidence:** A retired manifest's older activity is not included in this *currently published* summary; no extra content is invented for missing references. A later reviewed retention/history policy must decide archived-edition visibility and deletion schedules before an external pilot. Whole-account portability, user-controlled file download, independent review of real regulator-specific original exercise material and full EXM acceptance remain separate blockers. No data deployment, migration repair, hosted SQL or production publication.

---

### A.14 — EXM-02B all-edition owner practice-data export (draft; CI verified)

- **Slice and predecessor:** October 21, 2026; `feature/exm-02b-account-practice-export-20261021`, stacked on draft #88. This provides complete **EXM R1–R4 reference-practice subsystem evidence** across the owner's original and historical/retired reference manifests. **It does not export or purport to cover the entire LearningApp account.** No automated record deletion, retention interval, account merge, exam content or reviewer metadata is added.
- **Single-read SQL:** Unapplied `supabase/migrations/20261027080000_exm_02b_account_practice_export.sql` adds `exam_reference_drill_account_export(p_max_records default 5000)`. It requires a permanent authenticated owner, is `STABLE SECURITY INVOKER`, and reads only the owner's `exam_reference_drill_events` and matching server-private `exam_reference_drill_grades` with existing two-table RLS/grants. A single bounded, materialized query snapshots the event rows and corresponding grades under one SQL statement (avoiding multi-request pagination races). It raises SQLSTATE `54000` for >5,000 owned event rows; no partial result is returned. It intentionally **does not join currently published reference manifests**, so superseded/retired saved evidence remains available without exposing protected old editorial records. No response token, private rubric, reviewer field or user-submitted correct answer is stored or returned. The invariant for activity is still `unverified`.
- **Strict Flutter boundary:** `exam_reference_drill_account_export_service.dart` enforces permanent session identity both before and after RPC, single-snapshot metadata, exact field allowlisting, total count, canonical original manifest/event UUIDs, descending event receipt order, duplicate prevention, well-formed server-only grade state and a 5,000-record cap. The locally prepared JSON serializes only that typed model. Export data includes exact provenance and self-report durations but distinguishes those from graded choice correctness. No current-edition eligibility claim or passing projection is made.
- **User interface:** `reference_practice_account_export_card.dart` is added under **Progress → All Knowledge**, owner-keyed and hidden from guests. The user clicks to prepare and reviews counts, then separately consents to **copy JSON to the system clipboard** with an explicit clipboard exposure warning; dismissal does not copy. The export is clearly titled *reference-practice history* rather than whole-account portability. An account switch discards old state and cannot copy old data when pending dialogs resolve. Copying is not a native file download, does not persist a remote export object, and is not a general LearningApp account archive.
- **Test coverage:** New pgTAP suite checks owner-RLS invoker/public restrictions, single-snapshot metadata, skipped/unscored/graded provenance, bounded fail-close, account B and anonymous guest isolation, data minimization, and successful retrieval after retiring the source manifest; Dart service tests cover all-edition records, invalid private fields, duplicates, bad counts and account switches; widget tests cover explicit preparation, cancelling vs consenting to clipboard copy, guest restrictions, asynchronous switch and server failures. Technical verification passed in the integrated current-main tree.
- **Verified integration CI:** [Flutter CI #39545949737](https://github.com/RACCHUS/LearningApp/actions/runs/39545949737) **SUCCESS**, including Flutter analysis and unit/widget tests, web build, migration governance, the latest-main incremental database upgrade, clean-slate migrations and all pgTAP (including 24 new all-edition export checks), and post-ingestion taxonomy integrity. [Official Taxonomy Data #39545949725](https://github.com/RACCHUS/LearningApp/actions/runs/39545949725) **SUCCESS**, on the exact tested cumulative commit `2d341353026b99618f37eb357ae361c4ed217a8b`. The eight feature-file blobs were transferred unchanged from the stacked development slice to that cumulative integration. The subsequent Appendix-only documentation commits do not change tested code or SQL. Both PRs remain drafts and must not be merged independently.
- **Remaining governance gates:** The product's **retention duration, automatic expiry/deletion schedule, right-to-export scope across non-EXM subsystems, downloaded-file packaging and authenticated deletion of all EXM activity** require approved product/legal/privacy decisions. Existing user-initiated attempt deletion still cascades to derived grade, and account deletion cascades to events where auth user deletion applies. No added server data or unpublished key leakage. Internal security/owner review, real independently reviewed 2027 original questions, EXM-02B acceptance and production rollout remain blocked until explicit approval.

---

### A.15 — EXM-02B explicit owner-directed practice erasure (draft; CI verified via cumulative integration)

- **Scope / branch:** October 21, 2026; `feature/exm-02b-owner-practice-erasure-20261021`, stacked above draft PR #90. This is **user-initiated deletion of EXM saved R1–R4 step observations across all reference editions**, including retired manifests; corresponding server-derived grade rows automatically cascade. It is **not** deletion of a whole LearningApp account, curricular content, publisher references, editorial scoring rubrics, exported clipboard JSON, system logs, database backups or other-app information. **No automatic retention/expiry timeline is set or approved by this feature.**
- **Privileged boundaries:** Additive, unapplied `supabase/migrations/20261028010000_exm_02b_owner_practice_erasure.sql` creates `SECURITY INVOKER` RPCs `exam_reference_drill_erasure_preview()` and `exam_reference_drill_erase_owned(expected_count,expected_fingerprint,confirmation)`. Both validate permanent Supabase Auth (explicitly excluding authenticated-role anonymous guests), use the existing owner-only SELECT/DELETE RLS and grants on `exam_reference_drill_events` and owner-only read of `exam_reference_drill_grades`; neither reads private scoring keys. Preview returns counts for steps, graded steps and distinct reference editions plus an MD5 fingerprint of the sorted exact owner-owned event IDs (this is an optimistic concurrency indicator, **not an authorization secret**). Erasure requires exact phrase `DELETE REFERENCE PRACTICE`, positive count up to 5,000, a matching preview count and fingerprint, and an ID-restricted SQL DELETE; it removes *only those selected IDs*, checks the actual deleted row count and rolls back the transaction on mismatch. There is deliberately no SELECT FOR UPDATE/SHARE because it would require granting UPDATE permission to learner roles. Grade FK `ON DELETE CASCADE` removes their dependent grade rows. Concurrent inserts are not swept into the selected list; post-delete remaining-count is reported so any new data is disclosed rather than a false blanket success. A lost network response cannot reliably confirm commit, so the client must refresh preview rather than blindly replay. Over-5,000-record accounts deliberately fail closed pending a separately reviewed large-account erasure path.
- **User interaction:** `reference_practice_erasure_card.dart` is placed after the existing all-edition JSON export in **Progress → All Knowledge**, owner-keyed and hidden from guests. User requests an explicit inventory, enters the exact confirmation phrase, then approves a second irreversible-action dialog. The UI discloses that exported copies/clipboard data survive erasure and that only reference practice and its derived scores are affected. On success it reports deleted and remaining counts; on failure or uncertain network completion it invalidates the preview and requires a fresh inventory. Account switching discards dialog and state. No silent, time-triggered or automatic deletion action is created.
- **Automated regression coverage:** `supabase/tests/exam_reference_drill_owner_erasure_test.sql` tests invoker permissions, guest/account B separation, forbidden phrase, stale count/fingerprint and concurrent inventory mismatch, historical-retired manifest removal, exact owner event erasure and dependent grade cascade. Dart service and widget tests verify owner/guest checks, strict response fields, asynchronous session races, confirmation and double opt-in, stale-preview reset and uncertain completion. Full CI passed on the cumulative current-main integration code commit `a50b2a5b67665707e757d64feb3d953ea7b54f74`; no production write occurred.
- **Verified checks (integration only):** [Flutter CI #39549159866](https://github.com/RACCHUS/LearningApp/actions/runs/39549159866) **SUCCESS**, including analyzer, unit/widget suites, web build, append-only migration governance, current-main incremental upgrade, clean-slate PostgreSQL/pgTAP with **32 new erasure assertions**, and official taxonomy ingestion/postflight integrity. [Official Taxonomy Data #39549159858](https://github.com/RACCHUS/LearningApp/actions/runs/39549159858) **SUCCESS**. Tested at cumulative code SHA `a50b2a5b67665707e757d64feb3d953ea7b54f74`; the focused branch's seven code/test/SQL blobs were verified byte-identical to the cumulative integration (migration renamed but content unchanged). The initial run failed migration governance because old unmerged EXM SQL names predated the newly merged ECO-02 migration. The integration renumbered *all nine unmerged EXM files* after the merged baseline with unchanged blobs, and full rerun passed. Independent owner and privacy/security review remains pending.
- **Non-goals and deployment gates:** Legal/privacy review must establish retention durations, production backup/log deletion and lawful preservation exceptions, full-account erase/export coverage, portability, account closure, high-volume deletion, current-snapshot race guarantees and UX accessibility. This phase cannot assert compliance with GDPR/CCPA solely by deleting these rows. Final EXM-02B acceptance still requires an independent security/owner review and real reviewed original exam exercises. No hosted SQL, migration application, merge or deployment.

---

### A.16 — Latest-main EXM migration-order reconciliation (integration-only; CI verified)

- **Why:** On October 21, 2026, `main` advanced to `88fd42564e1bbb1c9f12bd9496cf30c6f22af48d` and merged `20261028000000_eco_02_hardening.sql`. Earlier unmerged EXM revisions dated 20261027 were then **backdated** relative to the new mainline, as GitHub Actions correctly detected in its governance checks. There is no exception, repair, or migration-history bypass.
- **Integration-only filenames:** The cumulative integration PR #93 retains the exact same SQL blobs and dependency order as the narrow draft PR stack, but has renamed all **nine still-unmerged EXM migrations**, strictly *after* the latest `main` migration: EXM-01 manifest `20261028010000`; EXM-02A answer binding `20261028020000`; durable events `20261028030000`; private scoring `20261028040000`; reviewed practice delivery `20261028050000`; edition-scoped Progress export `20261028060000`; Current Context Progress `20261028070000`; all-edition owner export `20261028080000`; and explicit user-directed erasure `20261028090000`. All share their original descriptive suffixes. No merged ECO migration is edited. The focused stacked PR #92 retains its original still-unmerged migration name and is **not** independently merge-ready against current main.
- **Access/security correction:** First erasure iteration tried `SELECT ... FOR UPDATE`, which PostgreSQL requires `UPDATE` privilege to execute. That was removed **without granting UPDATE on append-only EXM events**. The invoker selects only owner-RLS event IDs, validates the preview fingerprint/count, runs `DELETE` on that explicit ID list (which takes its own necessary row locks), and aborts if deleted count differs. Concurrent new inserts are never swept into the selected set; remaining steps are returned. A later user request may still create further events, so deletion is not a permanent user-account block.
- **Acceptance:** Full rerun passed on code SHA `a50b2a5b67665707e757d64feb3d953ea7b54f74` (Flutter CI #39549159866, Official Taxonomy Data #39549159858); previous cancelled/failed CI remains distinct audit evidence. Append the exact green run SHA after verification. Both the cumulative and focused PRs remain drafts. Do not merge overlapping PRs separately or apply hosted migrations without explicit production authorization.

---

### A.17 — EXM-02B high-volume, explicit one-batch-at-a-time erasure (draft; CI verified)

- **Scope / branch:** October 21, 2026; `feature/exm-02b-batched-erasure-20261021` stacked above draft PR #93. **This is a supplemental high-volume path for saved EXM R1–R4 event observations**, not a change to retention duration, automated background deletion, all-account erasure, official readiness or published reference content. No production migration is applied.
- **Additive schema:** `supabase/migrations/20261028100000_exm_02b_batched_practice_erasure.sql` adds two `SECURITY INVOKER` functions with explicit execute grants only to authenticated: `exam_reference_drill_batch_erasure_preview(batch_limit default 1000)` and `exam_reference_drill_erase_batch(batch_limit,expected_count,expected_fingerprint,confirmation)`. Both enforce permanent Auth accounts and underlying saved-events/grade RLS. A fresh preview counts the **entire** saved event inventory but selects at most 1,000 deterministic owner-owned event IDs, reporting grade/edition counts only for that batch and an optimistic fingerprint of those IDs (not an authorization secret). The deletion requires exact phrase `DELETE NEXT BATCH`, matching first-N ID count/fingerprint and safe 1–1000 bounded limit, and deletes only the explicitly selected event IDs. Row-count mismatch rolls back the entire RPC. The existing grade FK automatically cascades derived grades, without granting UPDATE or DELETE on scoring keys.
- **Concurrency and honesty:** Newer concurrent inserts are never included in the already-selected ID list. An insert that changes the selected first-N ID set causes the preview fingerprint to fail closed. Concurrent removals can cause the deleted row-count assertion to abort. Post-deletion remaining counts are reported; an account with more than 5,000 records can repeatedly **opt in** to distinct batches, with explicit review and confirmation for each one. The operation is not one atomic whole-account purge and no unreviewed scheduling/retry loop is added. If a response is lost, the learner must preview again and **must not blindly repeat deletion**. Backend row-level policy cannot prohibit a user who continues practicing from creating later new data.
- **Flutter:** `exam_reference_practice_batch_erasure_service.dart` strictly validates owner/session both before/after RPC, exact safe fields, count bounds and per-batch receipt. `reference_practice_batch_erasure_card.dart` follows the existing full-set erasure card in Progress → All Knowledge and is explicitly labelled for large histories or smaller chunks. It loads data only on user request, needs the exact typed phrase plus a second irreversible-action dialog for **each** batch, clears the preview after success/failure and does not automatically preview or erase a subsequent batch. Keyed account sessions discard stale dialog state and late async results.
- **Regressions:** pgTAP `exam_reference_drill_batched_erasure_test.sql` constructs **5,001 synthetic approved R1–R4 step events**, proves prior 5,000 cap remains, verifies one 1,000-step deletion leaves 4,001 steps untouched, grade cascade, second separately previewed batch, stale/forged confirmation rejection, retired-edition eligibility for deletion, guest/account-B denial and no UPDATE grants. Dart service/widget tests cover malformed payload rejection, account-switch races, opt-in confirmation, no automatic repeat and uncertain completion. Full verification passed on the current-main integrated source SHA `7dae8bc42a2061b809b4d7962c39c9bdbd3b8dbc`.
- **Verification:** [Flutter CI #39552678157](https://github.com/RACCHUS/LearningApp/actions/runs/39552678157) **SUCCESS**, including Flutter analyzer, unit/widget tests, web release, append-only migration governance, current-main incremental upgrade, clean-slate migrations, **31 new batched-erasure pgTAP assertions** using the 5,001-step synthetic stress case, and post-ingestion taxonomy integrity. [Official Taxonomy Data #39552678149](https://github.com/RACCHUS/LearningApp/actions/runs/39552678149) **SUCCESS**. Exact tested cumulative code SHA `7dae8bc42a2061b809b4d7962c39c9bdbd3b8dbc`; source/SQL/test blobs are identical in focused and cumulative PRs, with the SQL migration filename re-sequenced only on cumulative branch. The final Flutter fix corrected adjacent widget text constructors, and the large-history UI explicitly warns that current all-edition JSON export cannot deliver more than 5,000 steps. Documentation-only evidence commits after the tested SHA do not change implementation.
- **Remaining governance:** This is still only an EXM subsystem privacy control; owners must approve backup/log retention, legal holds, erasure for other LearningApp subsystems, accessibility, observability and large-volume load limits before external release. A separate approved retention policy is needed for age-based or automated cleanup. Real independently reviewed exam items and end-to-end EXM acceptance remain blocked.
---

### A.18 — Current-main ECO-02 UGC integration and ten-EXM migration resequencing (tested; draft only)

- **Cause:** While implementing A.17, main advanced to `9615cd7bb972237c3bdcf68a9ed57e15dc8330b3`, introducing the merged `20261029000000_eco_02_ugc_gate_and_seed_stability.sql`. CI correctly rejected the ten earlier unmerged EXM migration timestamps; none of the existing merged ECO SQL files was modified, bypassed or repaired.
- **Reconciled integration:** Draft #96 was rebased using a guarded ref lease onto the latest main and preserved all newer ECO model/widget, SQL and test changes. The **ten unmerged EXM migration blobs** retain identical contents/dependency order but use strictly newer monotonic filenames `20261029010000`–`20261029100000`: EXM-01 manifest, EXM-02A binding, durable events, private scoring, reviewed practice delivery, edition progress, current-context progress, all-edition export, full-set owner deletion, and batch owner deletion. Focused #95 remains review-only with its original unmerged timestamp and must not be merged independently of the reconciled cumulative stack.
- **Verified outcome:** Earlier failed or cancelled CI runs were not treated as passing evidence. [Flutter CI #39552678157](https://github.com/RACCHUS/LearningApp/actions/runs/39552678157) and [Official Taxonomy Data #39552678149](https://github.com/RACCHUS/LearningApp/actions/runs/39552678149) both **SUCCESS** at `7dae8bc42a2061b809b4d7962c39c9bdbd3b8dbc`; code/test/migration blobs unchanged by Appendix-only commits. The large-history deletion warning explicitly states that current all-edition EXM JSON export is capped at 5,000 records. No hosted migration, production modification, merge, seed or external pilot authorization is implied.

---

### A.19 — EXM-02B extended owner evidence export beyond 5,000 saved steps (draft; CI verified)

- **Scope and predecessor:** October 21, 2026; draft branch `feature/exm-02b-verified-large-export-20261021` stacked on PR #96. This extends saved EXM R1–R4 history portability above the initial 5,000-record single-statement cap, while leaving the existing old API, retention schedule, original authoritative editorial records and user-directed deletion APIs unchanged. It does **not** represent a whole-LearningApp account archive, CSV/native file download, background exporter or publisher book-currentness guarantee.
- **Two owner-RLS APIs:** New unapplied, append-only `20261029110000_exm_02b_verified_large_export.sql` adds `exam_reference_drill_export_inventory()` and `exam_reference_drill_export_page(p_limit,p_before_recorded_at,p_before_event_id)`. Both use `STABLE SECURITY INVOKER`, explicit permanent Supabase Auth checks, underlying owner-only SELECT grants/RLS on saved EXM events and derived private server grades, explicit authenticated-only EXECUTE, and strict field allowlisting; no answer tokens, reviewer materials, protected source pages or `service_role` use. Inventory reports an exact count and deterministic MD5 fingerprint of event IDs + graded state/version/timestamp for **up to 50,000 records**. The fingerprint is a consistency indicator rather than an authorization credential. The keyset page returns at most 250 steps in descending `(recorded_at,id)` order. Both include retired historical reference editions.
- **Completeness contract:** New typed `exam_reference_verified_large_export_service.dart` first checks the owner and inventory, reads all 250-row-or-smaller pages with exact count/ordering/owner/manifest/grade/schema validation, then retrieves a **second inventory** and compares count + fingerprint. Any changed set or grade, missing/out-of-order/duplicated page, owner/account switch or malformed payload fails closed: no successful or incomplete JSON object is returned. Successful output labels `pre-and-post-inventory-verified-not-atomic`; it is **NOT one repeatable-read database snapshot across network requests**. The existing 5,000-record one-statement snapshot remains a separate, stronger atomic-read method for smaller histories. Edge cases involving changes followed by restoration (ABA) or digest collisions are not cryptographically excluded, and load/memory/duration limits for 50,000 events require final testing. No records are newly persisted or deleted.
- **Learner UI:** `reference_practice_account_export_card.dart` now offers an explicit `Prepare verified large history (up to 50,000 steps)` button next to existing small-history prepare. Preparation is opt-in and copy remains behind its **separate clipboard disclosure and confirmation dialog**. Loading/failure clears the previous export so a half-read set can never be labelled complete or copied. The owner-keyed card discards stale account data. Older editions remain clearly historical; physical book use, stopwatch values and official exam-passing probabilities are never verified by this feature. The large-history deletion warning is still valid for **over-50,000** records, and even smaller exported clipboard payloads may exceed third-party app limits.
- **Regressions:** New `exam_reference_drill_verified_large_export_test.sql` pgTAP tests use **5,001 synthetic events** plus owner/guest isolation, grant/invoker checks, 250-row cursor separation, protected field exclusion, retired manifest history, and a private-grade insertion changing the postflight digest without changing event count. Dart service tests verify all 5,001 events are read and exported only after two consistent inventories; they also reject changed fingerprints, missing/reordered/duplicated pages, mismatched owner, oversized inventory and asynchronous session changes. Widget tests verify explicit preparation, separate clipboard consent, failure and account-switch behavior. Full integrated CI passed at code SHA `68aad15a56cb81ffcf4e7b67f1dc3451a7b4116e`.
- **Verification:** [Flutter CI #39556006106](https://github.com/RACCHUS/LearningApp/actions/runs/39556006106) **SUCCESS** (Flutter analyzer, complete unit/widget suite, web release, migration governance, latest-main incremental upgrade, clean-slate PostgreSQL and all pgTAP including **33 new large-export assertions** with 5,001 synthetic saved steps, and taxonomy post-ingestion integrity). [Official Taxonomy Data #39556006272](https://github.com/RACCHUS/LearningApp/actions/runs/39556006272) **SUCCESS**. Both validated exact cumulative code SHA `68aad15a56cb81ffcf4e7b67f1dc3451a7b4116e`. Focused and cumulative PRs carry identical ten changed implementation/test/plan blobs. An initial Dart fixture default constant error was corrected before successful rerun; later the existing batch deletion warning was updated from its stale 5,000 limitation to the new 50,000 verified option. Documentation-only evidence commits after the tested code do not modify app or migration blobs.
- **Outstanding policy gates:** The export is EXM-only and up to 50,000; more complete LearningApp-account portability, native file downloads, reliable large-payload clipboard behavior, retention/deletion of backups/logs and explicit privacy/legal/owner acceptance require future review. Nothing merged, deployed, seeded, deleted or run against hosted Supabase.
---

### A.20 — EXM-02B confirmed browser JSON file download (draft; CI verified)

- **Current-main reconciliation first:** On October 21, 2026, `main` advanced to `f02006295b23bd383bb4833dda21c6bd22582492` containing the merged `20261030000000_harden_seed_pilot_matching.sql` (ECO). Draft compatibility PR #101 `feature/exm-current-main-reconciled-20261021` preserves this mainline change and carries the 77 EXM implementation blobs from draft #98, with the 11 still-unmerged EXM SQL migration contents unmodified but filenames strictly resequenced to `20261030010000`–`20261030110000`. Earlier EXM cumulative draft PR #98 is no longer independently mergeable against the current main. **Do not independently merge cumulative and overlapping focused PRs**. Migrations and policies are not deployed through this operation.
- **Native web file action:** The focused branch `feature/exm-02b-browser-json-download-20261021` adds `reference_practice_json_download.dart` with conditional browser implementation `reference_practice_json_download_web.dart` and non-web stub. The adapter constructs a Blob of UTF-8 JSON bytes, uses a short-lived browser object URL and an anchor with the `download` attribute to request a local `.json` file directly from the **final confirmation button's user activation**. The filename is `learningapp-exm-reference-practice-YYYYMMDDTHHMMSSZ.json`, with no user ID, account name, exam target or email. Object URLs are eventually revoked. This stores no Supabase export object or server copy. **The browser may suppress the request or the user may cancel the save; the app can report only that download was requested, never guarantee an actual saved file.**
- **UI / security:** The existing Progress → All Knowledge `reference_practice_account_export_card.dart` now displays *Download reference-practice JSON file* **only after** the existing owner-verified atomic (<=5,000 steps) or pre/post inventory-verified (<=50,000 steps) export has fully completed, and only if the platform adapter supports browser download. A separate confirmation dialog describes file privacy and EXM-only scope. The actual request is synchronous from the confirmation click. A keyed owner session plus an explicit live authProvider owner assertion blocks old-account confirmations after a switch, and an identity check blocks stale previously prepared objects. The original clipboard copying action remains available; on unsupported non-web targets the UI explains its fallback instead of misleadingly claiming to save an inaccessible app-private file. This enhancement does **not** convert the non-atomic 50k exporter into an atomic snapshot or expand the EXM-only data scope. Existing answers, private scoring rubrics and reviewer evidence remain omitted by the typed export serializer.
- **Regression coverage:** Service unit tests verify safe UTC filenames and that non-web VM builds refuse unsupported writes. Flutter widget tests verify no file action before the validated export, cancellation vs explicit second consent, payload/provenance, owner-changing while dialog open, fail-closed incomplete export, synchronous request failure and unsupported-platform clipboard fallback. The web build is the required compile validation of the conditional browser adapter. Automated tests do not themselves demonstrate that every browser/OS honors the download request.
- **CI baseline evidence:** Reconciliation-only draft #101, on `a6762cc5730f86998e2aef19c117e2dad3d5d8b0`, passed [Flutter CI #39612196769](https://github.com/RACCHUS/LearningApp/actions/runs/39612196769) and [Official Taxonomy Data #39612196768](https://github.com/RACCHUS/LearningApp/actions/runs/39612196768) against the October 30 mainline. This verifies the copied EXM stack and migration ordering, **not** the new browser download code. The latter must pass its own CI run.
- **Exact successful validation:** Code and test commit `b99ad526961e9bb4b5c0ecaf9740ff9e0b7aa16f` on cumulative draft #103 passed [Flutter CI #39613532870](https://github.com/RACCHUS/LearningApp/actions/runs/39613532870) (**SUCCESS**: Flutter analysis, complete tests including file-save consent and owner-switch cases, web build that compiles the conditional HTML adapter, migration governance, October 30 mainline incremental upgrade, clean-slate database migration+pgTAP and post-ingestion integrity) and [Official Taxonomy Data #39613532773](https://github.com/RACCHUS/LearningApp/actions/runs/39613532773) (**SUCCESS**). The initial draft test used an unsupported `doesNotContain` matcher; it was corrected to `isNot(contains(...))` on both branches before this successful full rerun. The following Appendix-only verification commits do not change tested implementation or test blobs. Both PR #102 and cumulative #103 remain unmerged drafts. Automated tests verify the request action and web compilation, **not** that individual browsers completed a physical download to disk.
- **Remaining gates / limitations:** Full Flutter CI and taxonomy verification on latest current-main compatibility code must pass before any technical acceptance claim. Large JSON still requires synchronous in-memory string/byte/Blob construction and could stall UI or exceed browser limits at 50,000 events; evaluate performance and consider chunked/streaming or immutable server-side export in a separately reviewed phase. Browser-only save is **not** native mobile/desktop file saving; those platforms retain clipboard fallback. Privacy/retention policy, account-wide portability beyond EXM, final independent security/owner approval and real reviewed exam content remain outstanding. No production deployment, SQL application, learner-data mutation or merge is authorized.
---

### A.21 — EXM-02B bounded browser JSON generation, progress and cancellation (draft; CI verified)

- **Purpose:** Follow-on development atop the October 30 latest-main compatible draft EXM integration #103. No new Supabase migration or privilege, no production read/write, no third-party transfer, no retention-policy change, and no real exam content publication. The relevant branch is `feature/exm-02b-chunked-browser-export-20261021`; user-facing test handoff lives at `docs/exm/EXM_02B_REFERENCE_EXPORT_ACCEPTANCE.md`.
- **Memory-bounded file generation:** `ReferencePracticeAccountExport.toJsonExportChunks()` emits allowlisted EXM export header and separately encoded per-event JSON fragments rather than allocating one additional full JSON string in Dart. `ReferencePracticeJsonChunker.encode` combines those into at most 64 KiB UTF-8 byte segments with an absolute 64 MiB combined-browser-file cap; size overflow or serialization failure throws **before** browser download begins. The web adapter builds the Blob from byte segments and requests a native download synchronously from the separate final user-consent click. This reduces the Dart-side peak temporary string memory but **does not make browser Blob size or total prepared events memory-free**. Clipboard JSON remains a separate full-string path for non-web and optional existing workflows; no new platform scaffolds were fabricated.
- **Data invariants:** Same exact owner verified events and `toExport()` allowlist, export metadata (scope, provenance, record_count, server correctness state, archived reference edition IDs), and no raw learner submitted responses, private answer keys, reviewer materials, protected book text or broader account data. The chunked result must parse into a JSON object semantically equal to the preexisting small/large `toJsonExport()`. A Unicode and size-limit unit suite exercises UTF-8 boundaries, empty/oversize rejection and byte-part limits. A separate opt-in stress fixture checks up to 50,000 synthetic records and prints byte size/timing without reading any real account.
- **User-controlled cancellation and progress:** `ExamReferenceVerifiedLargeExportService.loadComplete` now optionally accepts `onProgress(loaded,total)` and `shouldCancel()`. It checks cancellation before the inventory read, between each paginated RPC, after each page and after the final inventory; it throws `ReferencePracticeExportCancelled` rather than handing back any incomplete export. No further page request is started after the client cancellation is noticed; **already running server read requests can still complete**, and no persisted learner records are mutated. The Progress UI reports loaded/total and allows cancellation while a large export is being prepared. It keeps download/copy disabled until the final owner and inventory verification succeeds. Account switches still invalidate in-flight historical private data.
- **Final technical CI evidence:** Full [Flutter CI #39618001169](https://github.com/RACCHUS/LearningApp/actions/runs/39618001169) and [Official Taxonomy Data #39618001158](https://github.com/RACCHUS/LearningApp/actions/runs/39618001158) both **SUCCESS** on exact cumulative implementation/test SHA `5b12a78d01b44847319b264dfd28e1bceceaacba`. Flutter analyzer clean; complete Flutter tests (1,761 passing with one intentionally skipped default stress test), opt-in 50k synthetic probe separately passing, web release built, migration governance and incremental/clean-slate Supabase/pgTAP passing, post-ingestion taxonomy integrity passing. The stress fixture generated **37,550,615 UTF-8 bytes in 573 byte parts in 427 ms**, measured on GitHub Linux runner; this is not a device-level memory/performance promise. The first test attempt hit a malformed Dart adapter edit before any tests and was corrected; do **not** count that failed attempt as passing. Subsequent Appendix-only verification commits do not alter tested source, test or workflow files. Real browser acceptance is deferred to the documented final manual test matrix.
- **Verification and release gates:** Root Flutter CI adds an opt-in `EXM_STRESS` test invocation as a normal CI step before the web release build; nonstress unit/widget tests validate owner-switch, cancel-before-API, stop-after-first-page, stale preview, consent and payload fidelity. Engineering/real-browser matrix is recorded in the new QA document. Full CI verified on the current-main integration code SHA above; revalidate again on any later final merge baseline. Browser-save completion, 64 MiB browser support, memory performance on actual mobile browsers, native Android/iOS/macOS/Windows scaffolding, whole-app export, retention and privacy/legal review remain unapproved external gates. All PRs remain draft-only, and none may be merged/deployed solely on these test results.

 
### A.22 — EXM-03 local practice-clock correctness (draft, CI pending)

- **Scope and predecessor:** October 21, 2026. Draft `feature/exm-03-practice-timer-safety-20261021` is stacked on cumulative EXM #105, which itself awaits final newest-main reconciliation. The change does not merge, deploy, publish reference material or modify hosted Supabase.
- **Timer integrity:** `ExamSessionNotifier` now reads monotonic active duration from `StopwatchExamPracticeElapsedClock` rather than adding one second per periodic callback. The periodic callback is an observer; answer/flag/pause/submit paths also synchronize the deadline first. Expired local practice cannot accept further edits. Pause freezes active elapsed time and resume retains the same practice start and clock; this is *not* evidence of official permission to pause.
- **Submission state:** Repeated submit calls return no second diagnostic report; an expired practice submission retains its `expired` status rather than being relabeled `completed`. A fresh session resets elapsed state and the duplicate-submit guard. The deterministic clock test fixture covers tick throttling, elapsed drift, pause/resume, deadline checks, expiry and duplicate submission.
- **Outstanding scope:** The mock UI is still **practice-only**. The volatile clock does not implement reliable reload restoration, cross-device continuity, strict simulation timing, issuer navigation/break/accommodation rules, part-scoped readiness or validated scoring equivalence. Those remain EXM-03 gates. See `docs/exm/EXM_03_PRACTICE_TIMER_SAFETY.md` for final browser test cases. No official exam simulation claim or production pilot authorization follows from this patch.
- **Verification status:** Code and tests authored in draft branch; Flutter CI, newest-main integration and manual browser checks must be independently recorded once available. Do not infer this work was included in the previous EXM-02B green CI.

 
### A.23 — EXM-03 current-main ECO-02 integration and migration ledger repair (draft; CI pending)

- **Baseline:** October 21, 2026, `main@92f550c305e0f1a26d98e0c45f81f0df6df2275e` now includes merged ECO pull request #106 and `20261031000000_eco_02_author_feedback_and_internal_notes.sql`. Focused EXM timer draft #107 remains stacked on #105; cumulative draft #108 is the single newest-main integration candidate, copying its **90 EXM changed file blobs** onto the actual ECO-updated main tree without overwriting ECO changes.
- **First CI detection and remedy:** Initial #108 migration-history job correctly failed because eleven *unmerged* EXM SQL files were named `20261030010000`–`20261030110000`, before the new `20261031000000` main baseline. On cumulative #108 only, rename those eleven files in their original relative order to `20261031010000`–`20261031110000`. Each file uses the **identical pre-rename Git blob SHA** (SQL bytes unchanged), and the old filenames were removed from the draft tree. All merged main migrations remain untouched.
- **No misleading verification claim:** The original CI failed for a legitimate governance reason. A new Flutter/migration/taxonomy CI run on the resequenced cumulative SHA must succeed before this newest-main version can be called technically verified. The timer's actual-browser behavior and all existing pilot/retention/official-exam gates remain open. Do not merge/deploy any of the overlapping drafts without separate approval.

 
### A.24 — EXM-03 explicit part-scoped practice isolation (draft; CI pending)

- **Scope:** October 21, 2026. Focused draft `feature/exm-03-part-isolation-20261021` is stacked above the green cumulative current-main draft #108. It adds an existing-EXM-01-metadata-based, version-bound subtree resolver and scoped service APIs; no schema, RLS, publication or production data changes.
- **Fail-closed validation:** `ExamPartCurriculumScopeResolver` resolves only the selected `exam_part_key` from `ExamPreparationProfile` and verifies that its root and descendants belong to the requested target version. Unknown/missing/malformed parts, duplicate IDs, cycles and cross-version parents never degrade to target-wide selection. The legacy target-wide path is explicitly separate.
- **Consumers:** Mock blueprints carry the resolved part key/root, and selection retains whole-target ambiguity detection rather than borrowing shared or other-part questions. Conservative scoped diagnostics reject globally shared or mixed-part question mappings; read-only scoped readiness keeps legitimate shared concept *knowledge* evidence but excludes unrelated part nodes. Distinct provider keys include part identity. Mock practice reports preserve the selected part key, without claiming official simulation fidelity.
- **Verification and remaining risks:** New synthetic tests exercise Part A/B item/coverage isolation, missing/wrong roots, cyclic hierarchy, shared/mixed concepts, underfilled mocks, preloaded blueprint mismatch and target-versus-part readiness. CI, real-device testing and explicit part selection throughout UI, durable diagnostic report/session identity, Progress, NextAction and official profile/pilot review remain open gates. See `docs/exm/EXM_03_EXAM_PART_ISOLATION.md`. Never merge or deploy overlapping drafts without approval.

 
### A.25 — EXM-03 owner-keyed scoped diagnostic handoff (draft; automated CI pending)

- **Predecessor:** Building above cumulative EXM-03 part-scope draft #111 on October 21, 2026. This follow-up adds a selected `examPartKey` entry to the existing diagnostic screen without guessing from `LearningContext.activeFocusId`. The target-wide diagnostic remains backward compatible.
- **Canonical preflight:** `DiagnosticAssessmentService.evaluatePartDiagnosticSession` re-reads the published target/version/part candidate set, verifies selected item/question shape and concept bindings, and rejects stale, duplicate, mixed or unrelated questions before evidence recording. Evaluations score canonical data, not a caller's altered scoring payload. Historical item-version persistence and future official per-part simulation equivalence remain unsolved.
- **Owner and part isolation:** A separate auto-disposed session family is keyed by target ID, version ID, exam part and learner ID, guards mismatched owner submissions, blocks duplicate/in-flight resubmission and editing, and ignores results after disposal. Part key, resolved curriculum root, and learner identity are carried into the report and preserved by copy/remedial updates. The report UI hides old-account results after an identity change; the existing Start Curriculum action is labeled as **full curriculum** for part reports.
- **Verification and boundaries:** Added synthetic unit, state and widget regressions plus `docs/exm/EXM_03_SCOPED_DIAGNOSTIC_SESSIONS.md`. All technical CI on the latest mainline and final real-browser tests are required. This does not create part-specific persistent Progress or NextAction evidence, change official requirements, merge a PR, or modify hosted Supabase.

 
### A.26 — EXM-03 selected part Progress + separate NextAction (draft; CI pending)

- **UI contract:** The Current Context Progress section offers an *explicit* exam-part selector only for target contexts with an exact version-owned, published EXM-01 profile. It does not change All Knowledge, legacy whole-target Knowledge Readiness or the global Learn NextAction. Keyed view identity includes learner/context/version, so a switch cannot carry the prior part selection.
- **Projection:** `examPartProgressProvider` keys a read-only view by learner, target, version and part; revalidates actual version-owned part subtree and both knowledge-readiness and diagnostic availability. Shared global concept evidence can contribute to multiple relevant parts, but is never treated as historically scored part-specific exam attempts. Missing durable per-part attempt history is explicitly disclosed.
- **Secondary guidance:** Pure `ExamPartNextActionEngine` recommends mapping/study/reinforcement/practice from only scoped concepts and verified canonical diagnostic availability. Weaker concepts outrank more mock questions, and a diagnostic button is never offered for insufficient content. A launched diagnostic is pinned to exact selected part/version; the outline action is explicitly **full target** rather than falsely implying a part filter.
- **Tests and boundaries:** Pure precedence, version mismatch, owner target/version/part validation, A/B selection and account switch widgets. See `docs/exm/EXM_03_SELECTED_PART_PROGRESS.md`. No hosted SQL, saved attempt claims, official exam readiness claims or authorized merge/deploy; these are later gates.

 
### A.27 — EXM-03 durable saved R1–R4 part attempt history (draft; latest-main CI pending)

- **Data reuse:** Read-only `exam_reference_drill_part_attempt_history` groups the already immutable EXM-02B step records by verified owner, exact target version, exact part, client attempt, reviewed manifest edition and assessment item. Distinguishes 1–3 partial observations from all four recorded stages; only server-graded choices count as correct/incorrect. Four stages recorded never means certified pass, book use, verified elapsed time or official exam readiness. No separate history table, redundant retention rule or account export/erasure protocol is introduced.
- **Access boundaries:** New append-only migration after prior EXM timestamps creates an indexed permanent-account `SECURITY INVOKER` bounded paged RPC, using existing owner RLS; invalid owner/part/version/cursor, guest and private field/schema extensions fail closed. Client revalidates owner after awaits and before drawing private results. Progressive opt-in history card shows up to 20 per page, with bounded older-page loading and clear historic-retired-edition limits.
- **Tests/gates:** Existing pgTAP reference fixture extended for cross-account/part, guest, partial/four-stage completion and bounds; new Dart parser and widget tests for privacy and honest presentation. The EXM-02B owner export/erasure already includes all underlying events, including retired editions. See `docs/exm/EXM_03_DURABLE_PART_REFERENCE_HISTORY.md`. Real canonical diagnostic/mock history remains a separate future persistence design, not inferred from global concept states or these reference drills.
