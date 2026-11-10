# LearningApp — Universal Software Learning & Development Plan

**Version:** 1.2 (reviewed and revised)  
**Date:** November 7, 2026  
**Project:** RACCHUS/LearningApp  
**Status:** Proposed design — **not approved for implementation until Phase 0 audit exits**  
**Scope of this revision:** Document-level review only. The GitHub repository, live database, `record_events` corrective PR, and architecture lock have **not** been verified as part of this revision.

### Implementation status and PR #188 merge boundary (2026-11-10)

This v1.2 specification remains the full product target, **not a statement that
the MVP is finished**. [PR #188](https://github.com/RACCHUS/LearningApp/pull/188)
is a disabled foundation increment. Merging its reviewed source does not approve
Phase 0 exit, publish the course, deploy migrations, enable uploads, or authorize
skill awards. This narrows the earlier draft-only constraint for source merge
review only; all launch gates below remain mandatory.

The [implementation checklist](docs/superpowers/plans/2026-11-07-excel-software-learning.md)
accounts for all eight tasks and distinguishes tested source from operational
acceptance. The [release gates](docs/product/EXCEL_PILOT_SECURITY_RELEASE_GATES.md)
are authoritative for hosting, retention, privacy and activation blockers.
The [Phase 0 audit](docs/product/SOFTWARE_LEARNING_PHASE0_AUDIT_2026-11-07.md)
records source findings, not production verification.

| Phase | Current disposition |
|---|---|
| 0: audit and approval | Repository audit and default-off design implemented; owner, privacy, cost, hosting, deployed ledger and skill-mapping approvals remain open |
| 1: usable Excel slice | Draft course, bounded isolated worker, provisional backend and opt-in sample rubric UI implemented in source; real picker, protected learner workflow, staging and deletion operations not released |
| 2: trusted evidence | Shared provisional envelope tested; no trusted ledger projection, verified skill award or completed MVP |
| 3: course expansion | Deferred until Phase 2 exit; no other software course promised |
| 4+: integrations | Aspirational and out of scope |

## 1. Executive decision

LearningApp will **teach people to use existing software**; it will **not recreate Word, Excel, PowerPoint, VS Code, QuickBooks, AutoCAD, or other applications**. Learners should practice in the real application wherever feasible. LearningApp supplies instruction, practice tasks, starter materials, feedback, and **trustworthy assessment of the work produced**.

**Smallest useful release:** one Excel catalog entry → guided real-Excel exercises → an `.xlsx` submission → deterministic, server-side checks → verified skill evidence. **Do not launch additional software courses, general OAuth integrations, or professional-level competency claims before this vertical slice works.**

### Non-negotiable design rules

1. Reuse the existing LearningApp course, goal, skill, progress, assessment, and security architecture; do not introduce a parallel platform.
2. Follow `UI_ARCHITECTURE_LOCKED.md`. Any conflict requires a documented and approved amendment **before** implementation.
3. A verified skill claim must be backed by trusted, server-validated evidence—not self-reported completion or client-side scoring.
4. Use real applications and ordinary file import/export first. Full replicas, mandatory remote desktops, and unnecessary simulation runtimes are out of scope.
5. Treat uploaded files and external tool outputs as untrusted input.
6. Prefer accessible, low-bandwidth instruction that works on phones as well as desktop, while clearly communicating when the actual software requires desktop access.
7. Treat the later integrations and industry expansion roadmap as **aspirational**, not committed functionality.

## 2. One learning model, four distinct concepts

The earlier plan used multiple overlapping sets of “levels.” Keep the concepts separate and name them consistently:

| Concept | Name | What it measures | Examples |
|---|---|---|---|
| Learning progression | **Learning Stages** | Where the learner is in an activity | Learn → Watch → Practice → Demonstrate → Review |
| Software support | **Integration Tiers** | What LearningApp can technically do with the external software | Teach only; guided real-app work; authorized API; verified output |
| Instruction intensity | **Assistance Modes** | How much help the learner receives | Guided; Assisted; Independent |
| Skill attainment | **Existing Competency Scale** | What reliable evidence demonstrates | Existing LearningApp skill model; no duplicate scale |

```text
SOFTWARE GOAL (existing multi-goal model)
    ↓
COURSE / LESSON (existing Learn system)
    ↓
Learning Stages: Learn → Watch → Practice → Demonstrate → Review
    │                  │                    │
    │                  └─ Assistance Mode ──┘  Guided / Assisted / Independent
    │
    └─ Integration Tier chosen per activity
       (instruction → real-app guidance → optional API → validated work)
                                    ↓
                           ONE SHARED EVIDENCE SCHEMA
                                    ↓
                     EXISTING SKILL / COMPETENCY MODEL
                         (trusted verification required)
```

**Learning Stages:** LearningApp explains the task, demonstrates it, guides practice in the real application, requests evidence, then gives feedback and re-practice. “Master” is an *outcome*, not an automatic stage awarded for viewing lessons.

**Integration Tiers (capabilities, not proficiency):**

- **Tier A — Instruction:** Lessons, screenshots, captions, transcripts, examples, and knowledge checks. No external account required.
- **Tier B — Guided real-app practice:** Learner works in their own licensed/available software; LearningApp supplies checklists and starter files. No direct control assumed.
- **Tier C — Authorized connection:** Optional official APIs, OAuth, file import/export, or compatible tools for specific supported operations. Connection never implies full application control.
- **Tier D — Validated work:** Trusted checking of a submitted artifact or authorized project state. This may be achieved by file upload **without** Tier C account integration.

**Assistance Modes:** Guided (step-by-step), Assisted (hints on request), Independent (task objective only). All modes may produce evidence, but the mode must be recorded and considered by the existing competency rules.

**Competency:** Reconcile to LearningApp’s current scale during Phase 0. **Do not create a new software-specific 0–5 scale.** If the existing scale uses 0–5 with equivalent semantics, unverified/self-reported work must not raise achievement above **level 2**. Levels 3–5 (or the equivalent independent/professional bands in the existing model) require trusted verified evidence. An imported file alone is not “verified”; a successful trusted evaluation is.

## 3. Navigation and goal-model fit

Respect the locked information architecture:

- **Library:** Browse Software, software catalog, categories, and discoverable curricula.
- **Learn:** My Software Courses, current lessons, active practice, and course progress.
- **Goals:** Software mastery and careers are **goals in the existing multi-goal system**. A goal may include Excel, Word, communication, or coding skills without introducing a new top-level tab or separate goal engine.
- **Skills:** Reuse the current skill and evidence graph; software is context attached to skills, not an independent skill system.
- **AI instructor:** May explain, suggest prerequisites, and recommend next lessons. **The learner makes the choice**; recommendations must not silently change goals, enrollments, or navigation.

All proposed screens, routing, terminology, lesson blocks, and goal relationships must be reconciled against `UI_ARCHITECTURE_LOCKED.md` in Phase 0. Conflicts become explicit amendment proposals; they are not implemented speculatively.

## 4. Skill identity: software-independent, evidence contextual

**Skill keys describe transferable capabilities, not product names.** Avoid multiplying the skill graph with separate nodes for the same concept in Excel and Sheets.

Examples of proposed concepts (final key names depend on the existing registry):

| Shared skill concept | Excel evidence context | Google Sheets evidence context |
|---|---|---|
| Spreadsheet cell references | `.xlsx` formula references | Sheet formula references |
| Sum a numeric range | Excel `SUM` task | Google Sheets `SUM` task |
| Sort tabular data | Sort a workbook table | Sort a Sheet range |
| Create and interpret charts | Excel chart requirement | Sheets chart requirement |

Proposed conceptual record:

```yaml
skill_key: spreadsheet.aggregate.sum  # illustrative; audit existing keys first
software_context:
  product: microsoft-excel
  edition: desktop-or-web
  version: covered-by-course
assessment_context:
  task_id: excel-budget-sum-01
  assistance_mode: independent
```

A shared skill key **does not automatically prove proficiency in every application**. Record which software produced the evidence. Cross-application transfer can be suggested or evaluated with a follow-up task, not blindly assumed. If the existing skill ontology already solves this, reuse it.

## 5. Excel-only MVP: one end-to-end vertical slice

The first deliverable is **one demonstrably useful Excel learning experience**, not a shallow four-application catalog.

### Learner journey

1. **Discover:** Open Library → Software → Excel; add an Excel-related goal using the current multi-goal model if desired.
2. **Learn:** See a concise lesson explaining spreadsheets, ranges, and `SUM`, with accessible screenshots/video and a downloadable sample workbook.
3. **Practice:** Open the real Excel application (web or desktop, as appropriate); follow a mobile-friendly checklist or desktop instructions.
4. **Demonstrate:** Independently calculate totals for a supplied sample budget in an `.xlsx` workbook; upload the workbook.
5. **Verify:** A restricted worker parses the file, evaluates trusted criteria, and returns useful feedback without exposing hidden answers.
6. **Record:** The trusted evidence pipeline records the checker outcome against the shared skill key and software context. Existing competency rules decide whether a level can increase.
7. **Review:** Learner sees result, next practice option, submission deletion controls, and the choice to continue.

### MVP scope

**In scope:** One catalog entry; one small Excel course/module; several guided exercises; one independent project; starter `.xlsx` file; upload/validation; one deterministic assessment checker; bounded feedback; trusted evidence; resume support; accessibility and mobile workflow; tests and telemetry.

**Out of scope:** Other software courses; Microsoft or Google OAuth; account-based editing; arbitrary desktop control; remote desktop; Excel clone; general formula interpreter; macro support; AI grading of the submitted workbook; automatic skill award from self-report; broad certification claims.

### Pilot exercise example

**Task:** Enter transactions in `C2:C9` and compute their total in `C10`. Provide a saved `.xlsx` file. The dataset and expected output are controlled by the exercise specification; use synthetic amounts.

**Pass criteria:** A valid formula in `C10` produces the expected total, references the required data in an acceptable way, and does not rely on an external workbook. Do not require a single literal formula string when multiple legitimate solutions exist.

## 6. Declarative checker contract

A checker should be **server-owned, versioned, deterministic, and declarative** for supported tasks. Content authors specify *what must be true*; parsers and evaluators implement the limited supported checks. The client cannot submit or modify the authoritative checker specification.

Illustrative specification **(design example, not a final schema)**:

```yaml
spec_version: 1
checker_id: excel-budget-total
checker_version: 1
artifact:
  allowed_extensions: [".xlsx"]
  max_bytes: 10485760  # proposed pilot limit: 10 MiB
worksheet: "Budget"
checks:
  - id: total-c10
    target_cell: "C10"
    rule: "aggregate_sum_of_range"
    source_range: "C2:C9"
    required_operation: "sum"
    allow_equivalent_formulas: true
    expected_result_ref: "server_held_budget_total"
    numeric_tolerance: 0.000001
    weight: 1
feedback:
  public_success: "Your budget total is calculated correctly."
  public_failure: "Check how your total includes the transaction rows."
  reveal_hidden_answer: false
```

**Checker design obligations:**

- Parse files only in an isolated worker with outbound network disabled.
- Inspect cell types, formulas, references, cached values, and workbook structure using a narrowly supported evaluation model. **Never run macros, workbook scripts, embedded binaries, or arbitrary formulas as code.**
- Prefer meaning and resulting behavior over literal string matching. Define supported equivalence classes (for example, `SUM(C2:C9)` and appropriate additive expressions), not an unrestricted formula engine.
- Validate results independently; do not trust cached workbook values alone because they can be forged or stale.
- Permit multiple valid solutions only where the checker can verify them reliably. Unsupported constructs yield **inconclusive / needs review**, not a confident pass.
- Bind evaluation to the server-controlled assignment version, approved dataset, and applicable learner/attempt context. Prevent submitting another learner's completed file as sufficient evidence of personal mastery; define integrity safeguards and their limits in Phase 0.
- Give a bounded result: `pass`, `fail`, `inconclusive`, or `rejected`, with criterion IDs, safe learner-facing hints, and retry guidance.
- Keep expected answers, grading thresholds, and any hidden variants server-side. Use recall-before-reveal in feedback; do not leak exact solutions on first failure.
- Version checker specs and implementations so past results remain interpretable after content changes.

For the first pilot, do **not** claim reliable evaluation of all Excel functionality. Publish supported formula/feature coverage explicitly. Expand checker coverage only with regression fixtures.

## 7. Shared trusted evidence and competency gate

Software learning and the existing **Simulation & Virtual Learning Framework** must emit **one compatible evidence contract**. No second software-only evidence table, awarding path, or skill-level system should be introduced without an audit finding that justifies it.

### Illustrative shared evidence fields

- Schema and source versions.
- Learner ID and authorized attempt/session ID.
- Goal / course / lesson / task IDs.
- Canonical **skill key** and software context (if applicable).
- Source type (`file_checker`, `simulation`, `external_integration`, `self_report`, etc.).
- Assistance mode and task conditions.
- Artifact reference or integrity hash (when relevant), never private file contents in public logs.
- Checker ID/version and **trusted server-generated outcome**.
- Verification status, timestamp, and provenance.
- Idempotency key and trusted event reference.
- Retention/erasure handling and access policy.

The exact fields and storage location must be resolved against existing contracts during Phase 0.

### Required dependency: `record_events` corrective PR

The review identifies a **`record_events` corrective PR** as a blocker for trusted skill updates. Its **merge status, contents, tests, and scope are not verified in this document review**.

**Release rule:** Do not enable competencies above the existing unverified cap until repository review confirms that the corrective change is merged, deployed where applicable, passes required checks, and prevents client-fabricated verified evidence. If it is not ready, ship instruction/practice only or keep outcomes explicitly **unverified**; do not silently fall back to client assertions.

**Trust boundaries:**

1. Client reports intent, submissions, and UI events—not trusted completion.
2. Worker evaluates artifact against server-authoritative checker spec.
3. Trusted backend validates worker identity, task ownership, result authenticity, and event idempotency.
4. Existing evidence/competency processor updates attainment only under verified-evidence policy.
5. Failed, missing, inconclusive, forged, or unverifiable evidence cannot promote level 3–5 (or equivalent).

Audit direct writes, replays, duplicate events, cross-learner submissions, stale spec versions, and forged `verified=true` flags. The event pipeline must fail closed when trust guarantees cannot be met.

## 8. Uploaded-file security, privacy, and lifecycle

Assume every learner-uploaded workbook is hostile, even if named `.xlsx`. Provide synthetic practice datasets by default and discourage submission of sensitive or real business data.

### Mandatory ingestion controls

- Allowlist only `.xlsx` for MVP and verify format by content as well as extension/MIME signals.
- **Reject macro-enabled formats** such as `.xlsm`, `.xltm`, `.xlsb` for this pilot; reject OLE/embedded executables and unsupported active content.
- Use a signed/authorized upload flow to isolated storage with learner-specific access controls; quarantine uploads until checked.
- Enforce limits on compressed size, expanded size, archive entry count, nesting, XML entities, CPU time, memory, and parsing wall time. Proposed pilot defaults: **10 MiB compressed, 50 MiB expanded**; finalize operational limits after benchmark tests.
- Detect and reject zip bombs, suspicious archive structures, path traversal, external workbook links and remote references. **Do not fetch external links** during parsing or grading.
- Parse in a **sandboxed isolated worker**, not the main Supabase/Flutter backend; no network egress or production secrets, least-privilege storage access, and strict execution timeouts.
- Sanitize filenames, log only safe metadata, enforce per-learner rate limits, and audit suspicious submissions without exposing file contents.
- Never open submitted spreadsheets with a full privileged office application or enable macro/script execution in production grading.
- Implement safe error handling: malicious/unsupported files are **rejected**, not awarded partial trusted credit.

### Retention, deletion, and AI consent

- Define raw upload retention **before launch**. Proposed default: remove raw submission files **30 days after final assessment**, unless the learner chooses earlier deletion or an explicit, justified retention workflow applies. Make the effective policy visible; final durations require privacy/security approval.
- Provide learner-initiated deletion for raw files, with documented consequences for re-review. Define how removal affects derivative feedback, hashes, evidence, and legal/operational records; minimize retained personal data.
- Support automatic cleanup of abandoned/quarantined uploads and orphaned artifacts.
- Do not send uploaded files to AI services by default. If optional AI review is introduced, **disclose which data leaves LearningApp, the purpose, provider, and retention behavior, and collect specific informed consent first**. Offer a non-AI route when feasible.
- Encrypt in transit and at rest, validate authorization on every access, and prevent cross-learner access.
- Include deletion, retention, access-control, and security-abuse tests in release criteria.

## 9. Mobile, accessibility, and literacy-first experience

Working in one app while reading instructions in another is difficult on a phone. **Do not assume split-screen or multiple monitors.**

### Mobile-first pattern

- Present one bite-sized task at a time with a clear **Open app / Mark step / Hint / Resume / Upload result** flow.
- Preserve checklist position when users switch applications or the device pauses the browser.
- Offer a compact printable/downloadable checklist or shareable instructions when an activity is easier on desktop.
- Support file upload from the phone's files/share interface where technically available, without implying the learner can edit all desktop-only formats on mobile.
- Explain required software, licensing, platform, and whether the task is feasible on phone, browser, or desktop **before** starting.
- Provide an honest alternative or postponement path when a task needs a desktop application.

### Accessibility and literacy

- Caption videos and provide usable transcripts.
- Provide optional spoken/audio instructions and accessible text equivalents.
- Use alt text for instructional images and keyboard/screen-reader-friendly checklists.
- Break instructions into short clear steps, define jargon, and provide illustrations when useful.
- Provide playback speed and repeat-step support where applicable.
- Test narrow-screen layouts, keyboard access, focus order, and screen reader announcements.

This must align with the existing literacy work and should not create a separate accessibility stack.

## 10. Content ownership, accuracy, and legal review

Every software course must have:

- Identified **content owner** and accountable reviewer.
- Product, version, platform, and edition applicability.
- Official/authorized source references where available.
- **Last verified** date, planned review cadence, and actionable staleness status.
- Review notes when interface changes affect a lesson.
- Licensing/trademark/screenshot usage review, including attribution where needed.

Show a **staleness warning in the UI** for lessons that are no longer verified against a supported version. A date field alone is insufficient. Proposed initial rule: recheck critical walkthroughs when a major UI version changes and on an owner-defined schedule (default quarterly for active high-change software); finalize during content governance review.

Do not imply official vendor affiliation, copy proprietary course materials without permission, or rebuild protected application interfaces.

## 11. Catalog, curriculum, and integration expansion

### Software catalog metadata

- Stable product/provider identifier and category.
- Supported platform/edition/version.
- Reused course and learning-path IDs.
- Canonical skill mappings.
- Supported Integration Tiers, prerequisites, license requirements.
- Content owner, verification date, staleness status.
- Verification capability and limitations.

A new title should primarily be **seed/configuration plus authored course content**—not new engine code—unless genuinely new file formats or integration capabilities are needed.

### Example future categories

- Office: Word, Excel, PowerPoint, Outlook, Google Docs/Sheets/Slides.
- Development: VS Code, Git, GitHub, Android Studio, databases, APIs, Supabase.
- Business: QuickBooks, Xero, Salesforce, CRM and payroll tools.
- Design: Figma, Photoshop, Blender, Canva.
- Engineering/construction: AutoCAD, Revit, SketchUp, estimating systems.
- Analytics and AI: Power BI, Tableau, Jupyter, automation tools.

### Integration feasibility gate

**Do not commit Microsoft 365 / Google Workspace OAuth as automatic Priority 1 work.** Before choosing any provider, record:

1. Educational value beyond ordinary file upload/export.
2. Developer registration and app verification requirements.
3. Required scopes and least-privilege alternatives.
4. Admin consent / enterprise restrictions.
5. Pricing, usage quotas, and support burden.
6. Terms, security review, and data retention implications.
7. Availability of a no-connection path.
8. Testing, monitoring, and outage handling.

Use a file-first pilot; add OAuth only where it materially improves learning and passes the gate. Likewise, programming learning should use real IDEs, authorized GitHub projects, or isolated sandboxes—not an in-app VS Code clone.

## 12. Roadmap with blocking gates

Phases below describe **dependencies**, not promises of release dates. A later phase does not start merely because a calendar date arrives.

### Phase 0 — Repository and architecture audit (**mandatory first**)

Review the current main branch and relevant PRs, focusing on:

- `UI_ARCHITECTURE_LOCKED.md`, goal/navigation restrictions, and any approved amendments.
- Existing Learn, Library, goal, course/lesson, skill, and competency models.
- Existing Simulation & Virtual Learning Framework and evidence event schema.
- `record_events` corrective PR and real trusted-evidence boundaries.
- Supabase RLS, storage policies, worker architecture, migrations, and CI.
- Existing file upload, assessment, content validation, and accessibility capabilities.
- Existing skill-key registry to prevent duplication.

**Phase 0 exit criteria (all required):**

- [ ] A dated audit cites concrete files, schema objects, and PR/commit references.
- [ ] A keep/extend/build decision exists for each proposed component.
- [ ] Any conflict with the locked UI architecture is resolved via approved amendment or scope change.
- [ ] Existing skill keys and evidence contracts are documented; one shared target evidence shape is proposed.
- [ ] `record_events` status and the exact trusted-evidence release dependency are recorded.
- [ ] Safe isolated file-parsing approach, costs, limits, and storage/retention proposal are reviewed.
- [ ] Excel pilot scope, checker features, threat model, and acceptance test matrix are signed off.
- [ ] Required changes are broken into independently reviewable issues with owners and dependencies.
- [ ] Nothing is described as “locked” or implemented solely on the assumptions in this plan.

**Deliverable:** Approved repository-specific design and small-ticket implementation sequence.

### Phase 1 — Excel vertical slice: catalog + guided activity + deterministic checker

Build the **smallest complete** path, not a catalog-only release:

- Excel entry in Library, active course in Learn, existing goal association.
- A short lesson, accessible demonstration, starter workbook, and guided checklist.
- One independent synthetic-data task and `.xlsx` upload.
- Isolated upload quarantine/parse/check flow with at least one declarative checker spec.
- Useful feedback and retries that do not reveal hidden answers.
- Trusted server-issued assessment results with provisional/unverified status until Phase 2 gate, as needed.

**Phase 1 exit criteria:**

- [ ] A learner can finish the full Excel task without OAuth or any rebuilt spreadsheet interface.
- [ ] Valid equivalent formulas pass; wrong, stale-cached, altered, malformed, and unsupported submissions do not falsely pass.
- [ ] Macro-enabled, external-link, zip-bomb, and over-limit files are rejected in tests.
- [ ] Parsing happens outside the main application, with no outbound network or privileged secrets.
- [ ] Mobile switching/resume, captions/transcripts, screen readers, and upload guidance are tested.
- [ ] User-visible retention, deletion, and non-AI handling are implemented.

**Deliverable:** Usable Excel course with deterministic project validation—not merely instructional content.

### Phase 2 — Trusted evidence + competency release gate

- Reconcile simulation evidence and software assessment into **one schema**.
- Verify `record_events` corrective PR and server trust boundaries are merged/active, with passing CI and negative security tests.
- Enforce authoritative event recording, replay protection, and existing skill policies.
- Ensure self-report/unverified exercises cannot award level 3–5 (or equivalents).
- Validate competency behavior across retakes, retries, and software contexts.

**Phase 2 exit criteria:**

- [ ] Client-forged verification, cross-learner evidence, duplicate/replayed events, and stale checker versions fail securely.
- [ ] A valid independently completed Excel task produces exactly one trusted evidence outcome.
- [ ] Skill improvement is derived through the existing competency model, not a second software-specific counter.
- [ ] The same contract accepts appropriate evidence from the Simulation Framework.
- [ ] If the corrective PR is not ready, higher-level competency remains blocked without exception.

**Deliverable:** A credible Excel mastery claim backed by verified evidence. **The MVP is not complete until this gate passes.**

### Phase 3 — Controlled course expansion

Only after Phase 2:

- Add Word, then PowerPoint, then Google Sheets as **separate small slices**, each with a justified validation strategy.
- Reuse shared skills and lesson architecture; create new file-format checkers only if secure and maintainable.
- For difficult-to-verify formats, use transparent rubric/instructor review with appropriately limited trust claims. Do not pretend every format can be auto-graded.
- Prove new catalog titles and courses can be added without engine code changes.

**Phase 3 exit criteria:**

- [ ] A new software title can be added via approved seed/config/content changes and **zero changes to the shared learning engine**.
- [ ] No duplicate skill nodes are created merely because an equivalent skill appears in another software product.
- [ ] Every competency claim can be traced to accepted evidence and an identified assessment method.

**Deliverable:** A repeatable software-learning authoring and assessment pattern.

### Phase 4+ — Aspirational, independently justified work

- **Provider integrations:** Microsoft, Google, GitHub, Supabase, Figma, or others, only after provider feasibility and privacy/security gates.
- **Development pathways:** VS Code, Git, SQL, APIs, and programming assignments using real tools and sandboxed execution where needed.
- **Industry software:** Accounting, real estate, construction, design, healthcare administration, and analytics based on demand and validation feasibility.
- **Advanced AI instructor:** Context-aware assistance, adaptive practice, and optional consented feedback; AI recommendations remain learner-controlled and cannot award authoritative competence without verified evidence.

These are possibilities, **not scope committed by the Excel MVP**.

## 13. Measurable release acceptance matrix

| Area | Concrete proof required |
|---|---|
| No application replicas | Excel course opens/uses real Excel and contains no newly built Excel clone or mandatory virtual desktop |
| Reusable catalog | A new software record loads in Library using seed/config/content with no shared engine changes |
| UI architecture | Library/Learn/Goals routes follow `UI_ARCHITECTURE_LOCKED.md` or a documented approved amendment |
| Excel correctness | Passing workbook, equivalent valid formula, incorrect reference, missing formula, and forged cached value fixtures are all classified correctly |
| Determinism | Same artifact + same checker/spec version yields the same result under controlled conditions |
| Checker safety | Macro formats, external links, zip bombs, malformed XML, size-limit breaches, and unsupported features cannot cause code execution/network access or a false pass |
| Trusted evidence | Forged client pass, replay, unauthorized attempt, and mismatched skill/task tests fail; exactly one authoritative outcome recorded per accepted attempt |
| Competency cap | Unverified/self-report evidence cannot raise a skill above level 2 or the existing model's equivalent trust boundary |
| Shared evidence | Software checker and simulation evidence both validate against one contract without separate awarding logic |
| Cross-software skills | Excel `SUM` and Sheets `SUM` map to a canonical shared skill, with software context retained |
| Mobile usability | User can leave/reopen the lesson, preserve checklist position, and submit or transfer work without requiring two windows |
| Accessibility | Captions, transcript, meaningful alt text, screen-reader labels, keyboard navigation, and hint controls pass targeted tests |
| Content governance | Each lesson has an owner, verified date, staleness policy, and screenshot/trademark review status |
| Privacy | User sees retention and AI-sharing policy; raw file deletion and scheduled cleanup are covered by tests |
| Provider connections | No OAuth provider is added without documented scopes, app-review/consent implications, costs, and fallback |
| Regression safety | Relevant Flutter, Supabase/RLS, backend, checker, and CI suites pass before merge/deploy |

## 14. Risks and explicit unknowns

| Unknown/risk | Required Phase 0 decision |
|---|---|
| Actual `record_events` implementation and corrective PR status | Verify commit/merge/CI/deployment and whether verified evidence can be forged |
| Exact skill scale and ontology | Reuse its canonical keys and level/evidence semantics; amend examples as needed |
| Actual UI/navigation constraints | Read locked document and produce amendment only if necessary |
| File worker hosting and operational cost | Select the simplest isolated runtime with enforceable limits and monitoring |
| Workbook formula evaluation coverage | Define a small trustworthy supported subset, not a blanket “Excel checker” claim |
| Artifact provenance and learner authorship | Decide reasonable integrity requirements and avoid false certainty about who created a file |
| Privacy requirements and retention durations | Review against current legal/privacy policy before finalizing defaults |
| Client/platform file handling | Test Flutter web/PWA and phone workflows before marking supported |
| Simulation evidence compatibility | Confirm shared schema and plan any migration before a new awarding path appears |
| Trademark, licensing, and content rights | Approve screenshot and demonstration sourcing guidelines |

## 15. Development handoff instructions

The implementing agent/team must:

1. **Audit first.** Read current repository state, relevant docs, schemas, CI workflows, and PRs. This document is a proposed target, not proof that those components already exist.
2. Produce a **gap analysis**, architecture decisions, issue dependencies, and measurable tests before coding.
3. Respect the existing locked UI, multi-goal model, learner-choice policy, and skill/evidence architecture.
4. Build **Excel only** as the first end-to-end demonstration, including its deterministic checker and safe file lifecycle.
5. Block trusted higher-level skill claims until the `record_events` corrective dependency and evidence threat tests pass.
6. Keep upload handling server-isolated, network-restricted, resource-limited, and privacy-conscious.
7. Keep authoring declarative and separate answers/checker secrets from client lesson payloads.
8. Do not add OAuth, speculative infrastructure, or other software courses before the Excel vertical slice passes its gates.
9. Prefer small independently reviewable PRs, append-only migrations as required by repository conventions, test coverage, and passing CI.
10. Record actual limitations and unresolved risks without marking work as complete prematurely.

## 16. Definition of success

A learner who knows little about Excel can discover a course in Library, follow a clear lesson in Learn, practice using **actual Excel**, submit a safe sample workbook, receive accurate feedback from a deterministic checker, and obtain **trusted, traceable skill evidence** through LearningApp's existing competency model—without a cloned spreadsheet, without mandatory OAuth, and without the app accepting a self-reported “I did it” as proof of independent mastery.

Once that vertical slice passes security, accessibility, architecture, and evidence gates, the system can expand responsibly to Word, PowerPoint, Google Sheets, development tools, and eventually broader professional software.

---

## Appendix A — Revision notes (v1.1 → v1.2)

1. Reordered rollout to **Excel with checker first**, broader courses later.
2. Added blocking `record_events` trust prerequisite and self-report competency cap.
3. Defined isolated-worker upload security, format restrictions, archive/links protections, retention/deletion, and consent rules.
4. Added declarative, versioned, server-side checker sample with equivalent-solution and no-answer-leak requirements.
5. Replaced ambiguous “levels” with four named concepts and a relationship diagram.
6. Aligned Library, Learn, and Goals placement with the stated locked architecture, subject to repository verification.
7. Made shared skill keys cross-product with software-specific evidence context; deferred exact scale to audit.
8. Added mobile single-screen workflow and literacy/accessibility requirements.
9. Added OAuth feasibility gates, content ownership/staleness, and legal review.
10. Required one evidence schema across software checkers and simulations.
11. Converted acceptance items to testable checks and defined Phase 0 exit criteria.
12. Marked future integrations, development environments, and industry expansion as aspirational.

**Review provenance:** This revision incorporates the review supplied in conversation. It does not independently validate the repository or external service capabilities.