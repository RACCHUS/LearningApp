# Excel Software Learning Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a usable guided Excel exercise that opens in the real software and securely verifies an independently completed workbook through the existing LearningApp evidence and skill architecture.

**Architecture:** Reuse existing content manifests, Library/Learn navigation, shared skills and ledger. A server-issued attempt owns exercise data and an immutable checker version. An isolated worker reads a tightly restricted .xlsx file, produces a safe structured snapshot, and runs a deterministic criterion checker. No Office clone or mandatory OAuth.

**Tech Stack:** Flutter 3.47.7 / Dart, Supabase PostgreSQL/RLS, append-only migrations, existing curriculum YAML, Python standard-library checker tests. The isolated worker hosting/runtime must be selected at Phase 0 exit; its design must enforce process and network isolation.

**Spec:** `SOFTWARE_LEARNING_PLAN.md`; repo-specific findings: `docs/product/SOFTWARE_LEARNING_PHASE0_AUDIT_2026-11-07.md`.

## Global Constraints

- No new top-level navigation; Browse Software remains within Library, active study in Learn.
- Do not create a second curriculum, goal, concept, competency or evidence ledger.
- Existing `UserSkillStats.level` is 0–100; do not add a 0–5 skill scale.
- Client completion is unverified; no skill advancement until trusted server checks and accepted shared evidence.
- Only .xlsx is proposed for the initial pilot; max 10 MiB, no .xlsm, macros, external links, encrypted files or unsafe archives.
- No untrusted file parsing in the main backend or client; use a resource-limited worker without outbound network.
- No content of uploaded workbooks goes to AI by default.
- Supabase migrations are append-only; do not deploy except through the guarded path, with explicit owner approval.
- Keep all content on the branch/draft PR until Phase 0 and release acceptance are satisfied.

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
- [ ] Run `dart run tool/lint_manifest.dart --dir content/` and fix errors.
- [ ] Run `dart run tool/ingest_curriculum.dart --dir content/ --dry-run`.
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
- [ ] Enforce signed per-user/per-attempt upload authorization, immutable attempt version and retention TTL.
- [ ] Implement sandboxed parser with network disabled, bounded CPU/memory/expanded ZIP bytes and no privileged secrets.
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
- [ ] Integrate checker with isolated worker; use server-owned per-attempt expected inputs.
- [ ] Add independent calibration fixtures and ensure unsupported formulas remain inconclusive.

**Deliverable:** Deterministic results from safely parsed server-owned attempts, with no arbitrary formula execution.

### Task 5 — Server-issued attempts and submission lifecycle

**Files:** To be selected after Phase 0 backend/storage audit; append-only migration only if existing tables cannot support it.

- [ ] Write failure tests for anonymous upload, cross-learner file, stale attempt, tampered spec and replay.
- [ ] Implement authenticated server issuance of a randomized synthetic dataset and checker version.
- [ ] Bind upload, storage object, criterion result and attempt owner on the server.
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
- [ ] Keep learner-controlled next actions and existing 3-tab navigation.
- [ ] Test narrow phone and desktop layouts; no implicit software-clone controls.

**Deliverable:** Safe Learn/Library experience for Excel's real-software workflow.

### Task 8 — Release verification and expansion decision

- [ ] Pass Flutter analysis/tests/build, manifest linter/dry-run, worker test suite and Supabase pgTAP in CI.
- [ ] Independently verify security threats, data deletion, privacy copy and mobile accessibility.
- [ ] Verify server-issued attempt and one trusted evidence write with no duplicate awards.
- [ ] Confirm owner sign-off on guarded migration deployment and content publication.
- [ ] Expand to Word/PowerPoint/Sheets only after the complete Excel slice is demonstrably usable.

**Deliverable:** Gated Excel pilot readiness; future integrations and software catalogs stay aspirational.
