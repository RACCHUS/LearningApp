# Software Learning — Phase 0 Repository Audit (in progress)

**Date:** 2026-11-07  
**Baseline:** `main` at `126c4e15a819cd2e9e50e58d0b621035b05387cc`  
**Feature branch:** `feature/software-learning-excel-mvp-20261107`  
**Plan:** [SOFTWARE_LEARNING_PLAN.md](../../SOFTWARE_LEARNING_PLAN.md) (v1.2)  
**Status:** **Partially audited. NOT a release or architecture sign-off.**

## Verified repository facts

1. **Navigation is locked:** `UI_ARCHITECTURE_LOCKED.md` specifies Learn, Library, Progress and a learner-controlled context. No new top-level Software tab is permitted. Use Library for discovery and Learn for active study. A product/software goal must fit the existing goals model or require an explicitly approved architecture amendment.
2. **Reuse curriculum infrastructure:** `content/schema/curriculum_manifest.schema.json`, `content/*.yaml`, `tool/lint_manifest.dart`, and `tool/ingest_curriculum.dart` already support content manifests, lesson blocks and assessments. The pilot uses `content/excel_fundamentals.yaml` rather than a new learning engine. Ingestion remains draft/review/publish gated; this branch has not published anything.
3. **No new skill scale:** `lib/models/skill.dart` models `Skill` by shared slug; `UserSkillStats.level` is **0–100**, with an `isVerified` flag. `supabase/migrations/20261101200000_eco_06_port_legacy_skills_and_missing_schema.sql` creates `skills`, `course_skills`, `user_skill_stats` and related tables. The v1.2 illustrative 0–5 labels must **not** be added as a parallel database scale. Existing shared concept slugs may be transferable; existing skill-slug collisions still require review before writing any skill records.
4. **Ledger corrective work is merged in source:** PR [#169](https://github.com/RACCHUS/LearningApp/pull/169), merged 2026-11-07, added `supabase/migrations/20261107050000_arch_04_learning_events_strict_rules.sql` and `supabase/tests/learning_events_strict_rules_test.sql`. The migration tightens `public.record_events` idempotency, canonical digests and the server-owned `user_concept_state` projection. **Production migration deployment, support for this workbook-assessment event type, and the trust of skill-stat updates are not established.** A merged ledger PR by itself does not authorize verified workbook skill awards.
5. **Simulation evidence is not implemented:** PR [#187](https://github.com/RACCHUS/LearningApp/pull/187) was merged into main on 2026-11-07; it contains an opt-in simulation preview with in-memory completion only, **no scoring or persisted evidence**. Do not create a competing evidence system. Propose one shared contract for both source types before implementation.
6. **File ingress is unresolved:** Repository search found existing taxonomy XLSX ingestion utilities, but no confirmed isolated learner-workbook ingestion worker or user-submission policy. Those developer utilities are **not** evidence of safe handling of arbitrary learner uploads. No upload endpoint is enabled in this branch.
7. **Testing and migration governance exist:** `.github/workflows/flutter-ci.yml` runs curriculum linting, dry-run ingestion, Flutter tests, schema checks, and other validations. `AGENTS.md` requires append-only migrations and guarded deployment. This branch introduces **no database migrations or production deployment**.

## Keep / extend / build decisions

| Capability | Decision | Specific repo surface | Current action |
|---|---|---|---|
| Library discovery and Learn context | **Keep** | `lib/screens/library/library_screen.dart`, `lib/screens/learn/learn_screen.dart`, `UI_ARCHITECTURE_LOCKED.md` | Do not add navigation |
| Curriculum, lesson blocks, provenance | **Extend** | `content/`, `tool/lint_manifest.dart`, `tool/ingest_curriculum.dart` | Draft one Excel course |
| Skills and competency | **Keep/extend after review** | `lib/models/skill.dart`, `public.skills`, `public.user_skill_stats` | No new skill scale or award |
| Shared evidence | **Extend after contract audit** | `public.learning_events`, `public.record_events`, PR #169; draft PR #187 | Contract proposal below; no event writes |
| Excel checker | **Build narrowly** | `tool/software_learning/excel_budget_total.py` | Pure deterministic core and tests only |
| Uploaded XLSX isolation | **Build after threat review** | no suitable learner-upload worker established | **Blocking** |
| User file retention and deletion | **Design and test before uploads** | storage and privacy architecture to verify | **Blocking** |
| Microsoft/Google OAuth | **Defer** | provider approvals and scopes not evaluated | Not part of Excel pilot |

## Proposed shared evidence envelope (not an API yet)

The software checker and eventual simulation runtime should both emit the **same server-validated evidence envelope**, not their own skill counters:

```json
{
  "schema_version": "proposal-1",
  "attempt_id": "server-issued-uuid",
  "learner_id": "authenticated-user-id",
  "activity_id": "excel-budget-total-v1",
  "activity_version": 1,
  "source_kind": "file_assessment",
  "software_context": "microsoft-excel",
  "skill_slug": "spreadsheet-range-summation",
  "assistance_mode": "independent",
  "result": "pass",
  "trust": "server_verified",
  "checker_version": 1,
  "artifact_digest": "sha256-of-approved-artifact",
  "recorded_at": "server-timestamp"
}
```

For a simulation, `source_kind` would change to `simulation`, while identifiers, outcome, assistance, provenance and trust policy remain consistent. **This JSON is illustrative only.** Reconcile with the actual `record_events` 13-field canonical payload, allowable `event_type` values and existing evidence projections before designing a migration or RPC.

The checked-in pure Excel checker currently returns `unverified_checker_only`, even for a passing formula. That is deliberate: it does not accept raw files, authorize the learner, issue attempts, write events, or award skills.

## Excel pilot security boundary

**Already drafted, not released:** a proprietary-software-free curriculum, synthetic CSV starter data, a versioned declarative criterion description, and a bounded formula checker that checks one `Budget!C10` sum.

**Must be added before a file upload route:**

- An isolated parser worker with no privileges or outbound internet; use ephemeral storage and strict time/resource limits.
- Signed, authenticated, single-user and single-attempt upload authorization.
- Enforce 10 MiB maximum *before* ingestion; allow only genuine .xlsx with file signatures and ZIP structure validation.
- Reject .xlsm, embedded macros/objects, formulas with external references, external workbook relationships, suspicious archive structures, decompression bombs, encrypted files and unsupported features.
- Never execute uploaded formulas or trust their cached results; only validate supported expression classes against a server-issued synthetic dataset.
- Define retention and deletion by policy, storage region, accessible user controls, and response to account erasure.
- Require clear opt-in before transmitting submitted files or extracted content to any AI service. Initial deterministic grading must **not** send data to AI.
- Include malformed/hostile fixture tests, retry/idempotency tests, cross-tenant checks, user deletion tests, and privacy disclosures.

**Integrity limitation:** The static CSV starter and public checker code demonstrate correctness of a workbook, **not proof of which person authored it**. To support high-level independent competency, use versioned server-issued attempt data and additional independent evidence safeguards; do not claim anti-cheating guarantees from a formula check alone.

## Audit exit checklist

- [x] Dated source audit with concrete files, merged PR #169 and open draft PR #187 identified.
- [x] Initial keep/extend/build map and no-new-navigation decision.
- [x] Existing `Skill` and 0–100 `UserSkillStats` model documented.
- [x] Ledger source status recorded; deployment and new assessment event eligibility explicitly unverified.
- [x] Reusable target evidence envelope **proposed**, not finalized.
- [ ] Verify existing transferable skill slugs and complete concept/skill mapping (no duplication).
- [ ] Reconcile proposed evidence envelope with `record_events` and simulation PR #187.
- [ ] Review and approve isolated parser, storage, cost, and lifecycle proposal.
- [ ] Complete Excel checker threat model, synthetic attempt issuance and acceptance matrix.
- [ ] Confirm locked-UI compliance in an actual desktop/mobile Flutter flow.
- [ ] Assign and approve implementation tickets and independent owners/reviewers.
- [ ] Receive owner sign-off on Phase 0 exit.

Until the open items are completed, the branch is **implementation work in progress**, **not deployable**, and must not be merged as a released Excel feature.


## Implementation progress — restricted workbook pipeline (same branch, 2026-11-07)

The following **prototype** components are now committed:

- `tool/software_learning/xlsx_snapshot.py` — strictly bounded ZIP/OOXML admission, one Budget worksheet, safe typed values, no formula execution or cached-value trust.
- `tool/tests/test_xlsx_snapshot.py` — malformed/macro/external/ZIP-abuse regression tests, plus UTF-16 entity/DTD bypass prevention (the test failed before the parser was patched).
- `tool/software_learning/xlsx_worker.py` — separate stdin/stdout worker protocol, provisional tagged values only; rejects without echoing potentially sensitive document contents.
- `tool/tests/test_xlsx_worker.py` — independent subprocess/CLI contract and negative tests.
- `deploy/software-learning/Dockerfile` and `deploy/software-learning/README.md` — unprivileged image and explicitly restrictive sample sandbox flags; no services or uploads exposed.
- `tool/software_learning/pilot_pipeline.py` and `tool/tests/test_excel_pilot_pipeline.py` — unverified worker-output adapter to the existing deterministic criterion checker, with negative tests against forged trust and inconsistent values.
- CI tests the Python parser, worker, and provisional checker. A Docker smoke step exercises the worker with no network access, a read-only filesystem, no extra capabilities, and resource limits. This validates the example CI invocation but **not** a future production orchestration platform.

**Trust boundary remains unchanged:** The parser and local checker are NOT evidence authority. There is still no authenticated issuance, upload endpoint, private storage, file retention/deletion pipeline, `record_events` integration, trusted skill award, or learner-facing submission button. Phase 0 is still **open**, and owner/security review is still required before enabling any learner file upload.

**Compatibility note:** This reader deliberately rejects many legitimate complex XLSX files (other sheets, embedded objects, unsupported features) rather than relaxing the whitelist. Broader Excel compatibility should be assessed only after the security and evidence gates.

## 2026-11-07 continuation — authenticated attempt issuance (repository only)

The feature branch has been synchronized with main including the merged simulation PR #187. The new migration `20261108150000_software_learning_excel_attempt_issuance.sql` provides a deliberately limited, non-deployed backend foundation:

- `public.software_learning_attempts` — RLS owner-only SELECT, immutable-to-clients synthetic attempt metadata with short expiry; clients cannot create, alter, or delete rows directly.
- `software_learning_private.excel_attempt_inputs` — restricted synthetic per-attempt inputs, inaccessible through public RLS/role grants.
- `public.sl_issue_excel_budget_attempt()` — permanent authenticated live-session verification, issued session binding, two active-attempt maximum, a 12-in-24-hour issuance limit, server-owned transaction numbers and pinned checker version.
- `software_learning_private.excel_issuance_log` — separate private count ledger so erasing an attempt cannot bypass issuance limits. This contains only an account identifier and issuance time; account deletion cascades. **Scheduled age-based pruning still needs implementation and policy approval before activation.**
- `public.sl_delete_excel_budget_attempt(uuid)` — authenticated owner erasure, cascading to private synthetic values; foreign/unknown attempt IDs produce the same false result.
- `supabase/tests/software_learning_attempts_test.sql` — pgTAP covers authentication/session checks, permissions, quotas, cross-tenant visibility, and erasure.

**No upload bucket, signing operation, learner file processing endpoint, persistent score, verification claim, learner UI, evidence projection, or production migration deployment is enabled.** The connected hosted project's recorded migrations are behind the repo and must be reconciled only through the guarded deployment governance; do not auto-apply this branch.

Next secure milestones: design the private bucket and immutable owner/attempt upload grant; implement isolated worker orchestration, strict TTL erasure (raw files and quota metadata), per-attempt attachment integrity, owner-facing delete/export, and only then map server-verified results into the shared `record_events` evidence contract.

## 2026-11-07 — Private Storage gate and cleanup prototype

**Repository-only implementation (never deployed):**

- Migration `20261108160000_software_learning_excel_private_upload_gate.sql` adds a dedicated **private** Storage bucket with a 10 MiB and XLSX MIME admission limit, while `software_learning_attempts.upload_enabled` defaults **false**. Existing attempts remain upload-disabled.
- The authenticated Storage `INSERT` RLS check accepts only `<owner_uuid>/<attempt_uuid>/workbook.xlsx` for a server-enabled attempt whose JWT user and **live original Auth session** match. A restrictive policy prevents broad existing INSERT rules from overriding this boundary.
- Restrictive RLS denies anonymous and authenticated user `SELECT`, `UPDATE`, and `DELETE` in this bucket; future trusted service processing uses the Storage API with narrowly scoped credentials.
- A database trigger refuses deletion of attempt metadata while its workbook is still present in Storage, preventing silent SQL-only deletion of bytes' references.
- `supabase/tests/software_learning_storage_gate_test.sql` checks default-deny behavior, private-bucket limits, policy/trigger presence, exact object paths, owner/session isolation, anonymous sessions and expiry.
- `tool/software_learning/storage_retention.py` and `tool/tests/test_storage_retention.py` implement and test a **host adapter contract**, not a running cleanup service. Its order is freeze upload -> remove bytes **using Storage API** -> verify absence -> delete metadata. Failures preserve a retryable record. All responses are bounded status strings without file data.
- The generated self-host SQL bundle now includes **95 migrations** and its contents are checked by the self-host tests.

**Unresolved before enabling upload:** a deployed service with verified privileged adapters and rate/concurrency limits; protection against in-flight uploads and reusable signed upload tokens; server-held workbook ingest/assessment handoff to the network-disabled container worker; private Storage deletion and retries on account erasure/expiry; scheduled retention of raw files and private issuance log; threat review, cost controls, and a learner-facing privacy notice. Do not set `upload_enabled=true` in production until those checks pass.

**Evidence remains unverified:** there is no skill award, persisted result, or new `record_events` contract in this increment. The existing simulation and software activities must eventually share that ledger before competency verification.

## 2026-11-07 continuation — one-time trusted-host processing boundary (source only)

**New migration and backend code:** `20261108170000_software_learning_excel_processing_lease.sql` adds an atomic private service-role processing claim, a unique processing lease, upload closure, checksum-pinned provisional receipt, and final failure transition. It does **not** add a verified evidence writer or permit learners to upload by default. The consolidated self-host bundle now contains **96 migrations**.

The supporting Python code and tests define a full *trust contract* between a server-authenticated request, the live session/owner-bound database claim, the exact private Storage path, a digest-pinned no-network Docker parser, and server-only deterministic feedback. `DbApiAttemptRepository` uses parameterized SQL and rolls back a malformed lease response; `DockerXlsxWorker` uses a fixed subprocess argument vector with memory/CPU/PID/time limits. Attempt replay, cross-account access, forged trust, worker timeout and changing Storage revision all fail closed in the unit contract.

**Verified in local/prototype tests only:** The database test executes trusted SQL functions against a disposable CI database, and the Python tests use injected session/storage collaborators. These tests demonstrate the contracts and checks, **not** deployed Auth/Storage adapters, end-to-end race freedom, or finished learner functionality.

**Unresolved production work:** Host service deployment; server-side validation of Supabase bearer identity and active session; controlled private Storage API download and object-version pinning; crash/retry and idempotency; concurrent/in-flight uploads and signed URLs; object retention, account erasure and issuance-log pruning; metrics, privacy copy, user UI and unified simulation/software evidence. Production `upload_enabled` must remain **false**. No `record_events` writes, competency awards or AI-file transfer are permitted until trust review and implementation.

## 2026-11-07 continuation — reviewed API adapter boundaries (not deployed)

Two additional host-only, network-capable source adapters are checked in:

- `supabase_auth_gateway.py`: contacts the official Auth server for a fresh user record before using the bearer JWT's subject/session claims. Rejects anonymous accounts, mismatched identity, malformed JWTs, invalid project origins, redirects and oversize responses. The database claim still independently verifies a live session.
- `supabase_private_storage.py`: fixed `learningapp-excel-private` bucket and canonical UUID/UUID/`workbook.xlsx` key, bounded authenticated object-info and XLSX download, metadata/version checks, no redirects, and idempotent Storage API removal. Server-side secret is never passed to the parser. Its tests use mock HTTPS responses, not a live project.

**Still blocked:** a hosted handler/queue that validates caller tokens and invokes these adapters with dedicated secret management, a real pinned Docker image deployment and container runtime enforcement, durable lease/retry/retention scheduling, Storage object revision race validation, client upload UI and user-visible privacy/deletion controls, and eventual unified trusted skill evidence. Current static capabilities must not be represented as a complete service. No production deployment, data mutation or learner file intake occurred.
