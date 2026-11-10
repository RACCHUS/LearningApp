# Excel Software Learning Pilot Implementation Plan

**Tracking:** Checked items mean implemented and tested in repository source,
not deployed or approved. Unchecked operational items remain launch blockers.

**Goal:** Provide a usable guided Excel exercise that opens in the real software and securely verifies an independently completed workbook through the existing LearningApp evidence and skill architecture.

**Architecture:** Reuse existing content manifests, Library/Learn navigation, shared skills and ledger. A server-issued attempt owns exercise data and an immutable checker version. An isolated worker reads a tightly restricted .xlsx file, produces a safe structured snapshot, and runs a deterministic criterion checker. No Office clone or mandatory OAuth.

**Tech Stack:** Flutter 3.47.7 / Dart, Supabase PostgreSQL/RLS, append-only migrations, existing curriculum YAML, Python standard-library checker tests. The isolated worker hosting/runtime must be selected at Phase 0 exit; its design must enforce process and network isolation.

**Spec:** [Universal Software Learning Plan](../../../SOFTWARE_LEARNING_PLAN.md);
[Phase 0 audit](../../product/SOFTWARE_LEARNING_PHASE0_AUDIT_2026-11-07.md);
[current release gates](../../product/EXCEL_PILOT_SECURITY_RELEASE_GATES.md).

## PR #188 scope reconciliation (2026-11-10)

[PR #188](https://github.com/RACCHUS/LearningApp/pull/188) is a source-only,
disabled foundation increment, not the completed production MVP. The owner
selected this merge boundary during follow-up review. Exact-head green CI and
review are required before removing draft status. No merge or deployment is
authorized by completing this checklist.

### Owner-approved one-time migration renumbering (2026-11-10)

`main` merged `20261110200000_ana_102…`, `20261110210000_ana_103…` and
`20261110220000_marketing_feature_control_foundation.sql`, colliding with this
branch's unmerged Excel migrations. The owner approved a one-time rename of
the four **unmerged, never-applied** Excel files to versions strictly after
main's newest migration, preserving SQL content (byte-identical) and order:

| Previous (unmerged) | Renumbered | Migration |
|---|---|---|
| 20261110200000 | 20261110230000 | attempt issuance |
| 20261110210000 | 20261111000000 | private upload gate |
| 20261110220000 | 20261111010000 | processing lease |
| 20261110230000 | 20261111020000 | brokered upload seal |

Evidence the previous versions were never applied: the only guarded
deployment record (2026-11-07, commit `df059a2`) ends at `20261108000000`;
both guarded deploy workflows on `main` have no runs; deploys diff against
`origin/main`, which never contained these files. No aliases, repair,
check bypass, merged-migration edits or production changes were made. The
self-host bundle was regenerated (110 migrations) and its tests derive counts
from the migration directory.

| Task | Implemented source and evidence | Remaining acceptance / dependency |
|---|---|---|
| 1: audit | Dated audit, locked 3-tab navigation, existing 0-100 skill scale, provisional shared envelope | Deployed ledger compatibility, approved skill mapping, worker costs/topology, privacy and Phase 0 owner sign-off |
| 2: curriculum | Draft manifest and synthetic CSV; existing manifest lint/dry-run and editorial workflow | Real starter-file download action and reviewed goal/catalog publication; do not publish before intake/evidence readiness |
| 3: safe intake | `xlsx_snapshot.py`, `xlsx_worker.py`, resource-limited `container_worker_runner.py`; hostile-file tests, CI Docker smoke, Storage-first erasure collaborators | Hosted network/IAM isolation, late-write/crash/retry proof, actual deletion verification and independent operational threat review |
| 4: checker | Versioned JSON, pure bounded SUM/direct-addition checker, isolated-worker pipeline with server expected inputs; wrong/altered/unsupported cases tested | Independently reviewed calibration corpus and formula-subset sign-off; never treat cached workbook values as server evidence |
| 5: attempts | Four append-only migrations; authenticated session-bound issuance, pinned checker, NOWAIT sealed upload, replay/owner tests; local DB/Storage broker probe | Real browser picker, deployed private broker, accessible consent/cancel/retry UX and expiry/account-deletion operations |
| 6: evidence | `shared_evidence.py` has one nonpersistent file/simulation envelope and forged-trust tests; Flutter preview never calls completion on callback passes | Deployed `record_events` audit, idempotent trusted projection and verified simulation integration; no skill awards until reviewed |
| 7: Flutter | Opt-in gated sample route/card; phone/desktop route tests, timer/reset races, real ZIP fixtures, bounded typed XML/relationship checks, honest privacy notices | Real-app starter-file actions, resume/checklist/focus/reading-help end-to-end acceptance and protected upload UX after Tasks 3/5 |
| 8: release | CI includes Flutter analysis/tests/default and opted-in web builds, content lint/dry-run, Python tests, isolated-worker smoke and pgTAP/local broker races | Hosted staging, reviewed privacy/retention, one trusted evidence write, guarded deployment/publication approval; expansion remains deferred |

### Full specification acceptance matrix disposition

Every row of the root plan's section 13 remains accounted for:

| Requirement | Source coverage / release disposition |
|---|---|
| No application replicas | Real-Excel instructions and sample rubric only; no spreadsheet clone or OAuth |
| Reusable catalog | Existing curriculum manifest; published Library discovery still gated |
| UI architecture | Existing Learn/Library/Progress and preview feature flag; no new primary navigation |
| Excel correctness | Python server-input checker and Flutter regression fixtures; broader compatibility unsupported |
| Determinism | Immutable checker version, bounded expressions and repeatable fixtures; deployed environment not certified |
| Checker safety | Hostile ZIP/XML tests plus no-network resource-limited worker invocation in CI; hosted isolation still required |
| Trusted evidence | Forged-trust/replay/owner defenses for provisional work; authoritative ledger write not implemented |
| Competency cap | All outcomes unverified, no skill-stat writes and no callback-triggered completion |
| Shared evidence | Same provisional envelope keys tested for file/simulation; actual Flutter-to-ledger integration deferred |
| Cross-software skills | Transferable `spreadsheet-range-summation` key tested; actual registry mapping requires approval |
| Mobile usability | Gated route layout/timer/reset tests; real app switching, resume and file transfer not accepted yet |
| Accessibility | Text-first instructions and route/widget semantics; complete keyboard/focus/reading-help acceptance remains open |
| Content governance | Source/rights metadata and independently authored draft; publication, owner/staleness and legal review remain gated |
| Privacy | Proposed-only retention copy, no AI transfer, Storage-first retryable cleanup tests; scheduler/alarms/deletion proof not deployed |
| Provider connections | None added; future OAuth scopes/cost/consent/fallback require separate review |
| Regression safety | Exact-head CI is the merge gate; production clean/upgrade rollout remains guarded and owner-approved |

### Follow-up local validation

- `flutter analyze` passed with no issues.
- `flutter test test/widgets/software_learning/excel_upload_card_test.dart test/services/software_learning/demo_workbook_evaluator_test.dart test/widgets/simulation test/services/simulation --reporter compact` passed: **84 tests**.
- `python -m unittest discover -s tool/tests -v` passed: **358 tests** with
  `PYTHONUTF8=1` on Windows (the initial Windows console-encoding failure was
  resolved without changing application code).
- `dart run tool/lint_manifest.dart --dir content` passed.
- `dart run tool/ingest_curriculum.dart --dir content --dry-run` passed; no
  content was published.
- `flutter build web --release --dart-define=ENABLE_SIMULATION_PREVIEW=true`
  passed. Browser smoke displayed the sample rubric pass and disabled-upload
  notice; hot reload succeeded. A prior debugger hot-restart request failed;
  this is not represented as a successful restart.
- The previous head `b1ff11f` passed all GitHub checks; a new follow-up head
  must independently pass CI before being marked ready. Local validation
  does not replace the clean/incremental database and isolated-worker CI jobs.
- After the renumbering and sync with `main`:
  `dart run tool/verify_migration_history.dart --base-ref origin/main` passed
  (4 pending, append-only); `python -m unittest discover -s tool/tests`
  passed **362 tests**; `flutter test test/services/governance
  test/services/self_host_infrastructure_test.dart test/services/software_learning
  test/widgets/software_learning` passed **129 tests**.

## Global Constraints

- No new top-level navigation; Browse Software remains within Library, active study in Learn.
- Do not create a second curriculum, goal, concept, competency or evidence ledger.
- Existing `UserSkillStats.level` is 0–100; do not add a 0–5 skill scale.
- Client completion is unverified; no skill advancement until trusted server checks and accepted shared evidence.
- Only .xlsx is proposed for the initial pilot; max 10 MiB, no .xlsm, macros, external links, encrypted files or unsafe archives.
- No untrusted file parsing in the main backend or client; use a resource-limited worker without outbound network.
- No content of uploaded workbooks goes to AI by default.
- Supabase migrations are append-only; do not deploy except through the guarded path, with explicit owner approval.
- Source may merge as a disabled foundation after exact-head CI/review. Keep course publication, ingress, upload eligibility and verified awards disabled until Phase 0 and release acceptance are satisfied.

## Review Focus

1. A renamed .xlsm file or dangerous ZIP payload must be rejected before workbook parsing (Task 3).
2. A correct-looking Excel cached result with a wrong formula must not pass (Task 4).
3. A valid workbook from a different user/attempt must not produce a trusted result for the current learner (Tasks 5–6).
4. A repeated or reordered submission must not double-award competency (Task 6).
5. A phone-only learner must retain lesson place, obtain instructions accessibly and upload only when supported (Task 7).

---

### Task 1 — Audit and gating decisions

**Files:**
- Root spec: `SOFTWARE_LEARNING_PLAN.md`
- Audit: `docs/product/SOFTWARE_LEARNING_PHASE0_AUDIT_2026-11-07.md`

- [x] Check main branch architecture, current skill model and event migrations.
- [x] Identify PR #169 merged in source and PR #187 still draft/no persisted evidence.
- [ ] Confirm actual deployed `record_events` version and compatible event type.
- [ ] Confirm reusable skill slug mapping and simulation evidence contract.
- [ ] Review isolated worker runtime, cost, data retention, deletion and privacy policy.
- [ ] Obtain owner approval of Phase 0 exit, worker boundary and tasks before release.

**Deliverable:** Audited keep/extend/build decision and documented release blockers.

### Task 2 — Course foundation through existing curriculum

**Files:**
- `content/excel_fundamentals.yaml`
- `assets/lessons/excel_budget_transactions.csv`
- `content/schema/curriculum_manifest.schema.json` (read-only unless approved)

- [x] Author a small Excel lesson using the existing manifest format.
- [x] Supply synthetic transactions only; do not use real learner/business data.
- [x] Run `dart run tool/lint_manifest.dart --dir content/` and fix errors (CI).
- [x] Run `dart run tool/ingest_curriculum.dart --dir content/ --dry-run` (CI).
- [ ] Validate course targeting/mapping against existing goals and publishing workflow.
- [ ] Only after security/evidence readiness, publish via the existing editorial gates.

**Deliverable:** Reviewed, valid Excel lesson content without new navigation or a second catalog.

### Task 3 — Safe workbook intake and isolated parser

**Files (exact runtime/location to be selected at Phase 0 exit):**
- New isolated worker package for XLSX admission and snapshot extraction
- Security tests and malicious fixtures
- New storage/retention policy and user deletion controls

- [ ] Write failing security tests: over-limit, truncated, renamed .xlsm, macro parts, linked workbooks, encrypted file, ZIP slip, decompression bombs and resource exhaustion.
- [ ] Demonstrate each rejection before implementing parser acceptance.
- [x] Implement owner/session/attempt-bound sealed broker authorization and immutable checker version in source (never signed upload tokens); enforce attempt expiry.
- [x] Implement sandboxed parser invocation with network disabled, bounded CPU/memory/expanded ZIP bytes and no privileged secrets; exercised in CI, not a deployed host.
- [ ] Prove hosted retention TTL, isolation and immutable Storage behavior with operator evidence.
- [ ] Confirm real file deletion and account erasure, including failed and incomplete attempts.
- [ ] Run worker security tests and independent threat review.

**Deliverable:** Safe, isolated structured `Budget` worksheet snapshots; no learner-visible upload before this passes.

### Task 4 — Declarative deterministic criteria

**Files:**
- `data/software_learning/excel_budget_total_v1.json`
- `tool/software_learning/excel_budget_total.py`
- `tool/tests/test_software_learning_excel_checker.py`

- [x] Commit test-first acceptance cases for SUM range, equivalent addition, wrong range, altered rows, missing rows, external links, unsupported expression, and hidden-feedback policy.
- [x] Implement a bounded pure structured-snapshot criterion checker.
- [x] Add an explicit versioned criterion specification without expected answers in client-visible content.
- [ ] Verify tests green in GitHub CI and review Formula AST limitations.
- [x] Integrate checker with isolated worker; use server-owned per-attempt expected inputs (`pilot_pipeline.py`, `private_assessment.py` and tests).
- [ ] Add independent calibration fixtures and ensure unsupported formulas remain inconclusive.

**Deliverable:** Deterministic results from safely parsed server-owned attempts, with no arbitrary formula execution.

### Task 5 — Server-issued attempts and submission lifecycle

**Files:** To be selected after Phase 0 backend/storage audit; append-only migration only if existing tables cannot support it.

- [x] Write failure tests for anonymous upload, cross-learner file, stale attempt, tampered spec and replay (Python/pgTAP).
- [x] Implement authenticated server issuance of a randomized synthetic dataset and checker version in source.
- [x] Bind upload, storage object, provisional criterion result and attempt owner on the server in source.
- [ ] Enforce upload retention/deletion and user-visible privacy/consent controls.
- [ ] Expose only bounded hint-safe feedback and retry rules.

**Deliverable:** Authenticated provisional assessment with deterministic outcome, no automatic skill awards.

### Task 6 — One evidence and skill projection gate

**Files:** Existing event/skill model and new migrations/tests only if truly required.

- [ ] Verify `public.record_events` release status and define a compatible software/simulation evidence envelope.
- [ ] Write negative tests for client-created trust, cross-user evidence, duplicate/replayed outcomes and outdated checker versions.
- [ ] Reuse the existing skill slug and 0–100 stats, with software context on evidence.
- [ ] Require server-verified checker result before setting `is_verified` or allowing advanced claims.
- [ ] Ensure the future simulation uses this *same* envelope.

**Deliverable:** One trusted skill-evidence path, not separate software and simulation scoring systems.

### Task 7 — Flutter practice workflow and accessibility

**Files:** Existing Learn/Library screens and lesson renderers (exact edit locations determined after route audit), plus Flutter widget tests.

- [ ] Write widget tests for the Excel lesson's mobile checklist, Help, focus restoration and resume behavior.
- [ ] Present real-software instructions and available starter-file actions.
- [ ] Enable protected upload only after Task 3 and Task 5 pass.
- [ ] Support low literacy through screen-reader labels, captions/transcripts for future video, and audio/reading help.
- [x] Keep learner-controlled next actions and existing 3-tab navigation.
- [x] Test narrow phone and desktop preview layouts; no implicit software-clone controls.

**Deliverable:** Safe Learn/Library experience for Excel's real-software workflow.

### Task 8 — Release verification and expansion decision

- [ ] Pass Flutter analysis/tests/build, manifest linter/dry-run, worker test suite and Supabase pgTAP in CI.
- [ ] Independently verify security threats, data deletion, privacy copy and mobile accessibility.
- [ ] Verify server-issued attempt and one trusted evidence write with no duplicate awards.
- [ ] Confirm owner sign-off on guarded migration deployment and content publication.
- [ ] Expand to Word/PowerPoint/Sheets only after the complete Excel slice is demonstrably usable.

**Deliverable:** Gated Excel pilot readiness; future integrations and software catalogs stay aspirational.
