# Excel Pilot — Hosted Processing, Retention, and Evidence Release Gates

**Status:** Proposal for owner, privacy, and security review; NOT approved or deployed.  
**Scope:** Excel-only guided external-app practice, private XLSX submission, deterministic provisional feedback.  
**References:** [Software Learning Plan](../../SOFTWARE_LEARNING_PLAN.md), [Phase 0 Audit](SOFTWARE_LEARNING_PHASE0_AUDIT_2026-11-07.md), [Simulation Phase 0](../design/SIMULATION_PHASE_0_DESIGN.md), [Measurement and Scheduling](../learning_science/06_MEASUREMENT_AND_SCHEDULING.md).

## Implemented, but disabled

- Private Storage bucket and default-false upload eligibility; 45-minute owner/session-bound synthetic attempts.
- Single-use processing lease with provisional result only. No learning-event or skill-stat writes.
- Privileged Storage client, isolated container parser, bounded host composition and disabled-by-default internal ASGI handler. **These are review-branch components, not a deployed service.**
- Bounded DB cleanup and dry-run-first expiry sweep; candidate cleanup after attempt expiry. Processing claims are reclaimed only after both attempt expiry and claim time are older than 30 minutes.
- Shared, nonpersistent evidence-envelope adapter for file assessment and simulation preview. The current Flutter simulation does not emit it; it remains in-memory only.

**Not implemented:** live hosted private gateway/worker broker, learner upload flow, signed-upload immunity tested against the live Storage provider, no-late-write object immutability guarantee, scheduled cleanup, completed account-erasure orchestration, trusted skill awards.

## Proposed retention policy (approval required)

| Data category | Proposed limit and method |
|---|---|
| Attempt validity | 45 minutes after server issuance; no new uploads after expiry or claim |
| Raw workbook | Purge target within 24 hours after attempt expiry; hourly cleanup with retries and delay alerts; delete bytes using Storage API before metadata |
| Provisional score/digest | Delete with attempt metadata after workbook bytes are confirmed absent; no permanent practice mastery evidence |
| Account deletion | Revoke sessions and ingress first, remove all Excel Storage objects/attempts **before** Auth-user deletion; do not claim completion if Storage cleanup fails |
| Private issuance timestamp log | Prune entries older than 48 hours, preserving complete 24-hour issuance quota; batched private SQL |
| Diagnostics | Aggregate counts only; never log learner bearer, workbook bytes, file names, extracted cells, private expected values or secret keys |

The 24-hour purge and hourly scan are **proposed operating targets**, not guarantees from an active scheduler. A retention service, background retry controls, erasure proof and user-visible policy must be approved before enabling uploads. Do not assume learners will only submit synthetic data.

## Concurrent upload and immutable file gate

- This feature must **never issue signed upload tokens**. No learner upsert, overwrite or update permissions.
- Exactly one canonical owner/attempt workbook path. Gate access by the original live session and owner; server claim atomically disables future uploads.
- Double-checking object version before and after download does **not** establish atomic immutability. An upload already in flight or a previously signed token could land after a claim or after cleanup.
- Before enabling direct-to-Storage uploads, independently prove provider-level single-insert semantics and test late writes, claim/cleanup races, and object resurrection on the actual hosting platform.
- If those guarantees cannot be demonstrated, **replace direct upload with an authenticated server-brokered upload** that produces a sealed immutable object and avoids shared signed tokens.
- Failure to freeze, validate or delete an object must leave a retryable record rather than granting a grade or claiming deletion.

## Host and secret boundary

- Internal gateway: TLS, no public reachability, no browser CORS, trusted internal capability, independently verified learner bearer, rate/body limits and private routing.
- The internal ASGI entrypoint defaults off and validates fixed route, host and request shape. Backend composition opens a fresh DB connection per request and limits per-process concurrency. Neither alone proves a production-safe hosting topology.
- **Never expose a Docker socket or privileged DB/Storage credentials to a public HTTP process.** Use a separate authenticated broker/worker tier; keep credentials and file bytes out of browser and parser container.
- The private Storage adapter now denies disallowed HTTP methods in each host: upload host **GET/POST only**, grading host **GET only**. This is a fail-closed code-level defense against accidental cross-service operations, **not** independent secret or infrastructure isolation; live host IAM, routing and permission separation still require staging review.
- Keep the parser's network disabled, filesystem read-only, and CPU, memory, PID, runtime and output sizes bounded. Pin the worker image and review dependency provenance.
- No file or extracted contents are transmitted to AI; any future AI transfer requires prior informed learner consent.

## One evidence schema, no competing mastery pipeline

The simulation preview currently records lifecycle events **in memory only**. The strict learning-event RPC has a canonical 13-field digest and idempotency guards, but a client-provided correct-answer or simulation-completion claim is not authoritative workbook or skill evidence.

The shared activity envelope contains source kind, activity ID/version, owner/attempt when legitimately bound, transferable skill slug, result, assistance, artifact digest when present, and explicit **trust = unverified / can_award_skill = false**. The file-assessment and simulation-preview envelopes have the same keys.

Before awarding competency, reconcile the shared event model with the existing learning_events ledger and user_skill_stats **0–100** model; do not add a parallel 0–5 scale. Require a single server-owned, idempotent, ownership-checked projection path with replay and forged-trust tests, reused by future verified simulations and real-app submissions. A correct Excel workbook establishes only that a file meets the criterion, **not** independent learner competence.

## Release checklist

- [ ] Internal gateway and isolated worker-broker topology deployed only to staging and independently reviewed; no Docker socket or privileged database credentials in a public process.
- [ ] Live Storage race tests show uploads cannot replace or resurrect committed/removed objects, or implement sealed server-brokered upload instead.
- [ ] Scheduled expiry, account erasure and quota-log cleanup proved with retries, alarms and deletion evidence; retention policy approved and disclosed.
- [ ] Mobile/desktop accessible Excel practice, secure upload and feedback, privacy notice, no AI by default.
- [ ] Unified trust contract reviewed against actual ledger and simulation, including cross-account, replay, assistance and forged skill evidence tests.
- [ ] Clean/incremental Supabase migrations, complete Flutter/Python checks, hostile-file tests, costs and governance reviewed.
- [ ] Owner confirms protected rollout and deployment plan.

**Until release gates pass:** leave upload eligibility off, PR #188 draft, and all file/simulation competency claims unverified.

## Server-brokered upload continuation (source only; not deployed)

The review branch now includes a sealed server-brokered workbook upload prototype. The broker verifies a permanent user session, holds an exclusive owner/session-bound PostgreSQL row lock while uploading one canonical workbook, uses a create-only fixed-MIME Storage REST request, reads the bytes back, and commits the SHA-256 and object revision in the same database transaction. On failure it rejects without awarding any competency. It deliberately does **not** delete an ambiguous object inline: an unversioned Storage DELETE after a stale negative lookup, timeout-after-write or lost database-commit acknowledgement could destroy an existing or legitimately sealed workbook. The attempt record is retained for Storage-first expiry/account-erasure recovery; a rejected upload may require a newly issued attempt.

The append-only migration 20261108180000_software_learning_excel_brokered_upload_seal.sql disallows direct learner Storage INSERT even if upload_enabled is later set, stores a server-attested SHA-256 / revision / commit timestamp, and requires the exact digest for any processing lease and provisional completion. The associated self-host SQL bundle includes 100 migrations.

The private upload host and binary ASGI ingress are **separate from the Docker parser host**. The ingress requires a fixed private HTTPS host, a server-held internal key, one canonical attempt ID, exact XLSX MIME, declared Content-Length no greater than 10 MiB, bounded concurrent in-memory requests, and no cookies or browser Origin. It is **disabled by default** and is not an exposed or running service.

Account erasure now has a service-only, revoked-session-gated, bounded, dry-run-first owner cleanup. It cannot claim global erasure: an authoritative Storage-prefix enumeration is still required to detect orphaned objects.

### Required real-host staging tests, not yet passed

1. Race two uploads to the same attempt and upload against an assessment claim; verify only one committed SHA and no overwrites or late writes.
2. Revoke the original Auth session during an upload and before a claim; reject replay, other-account IDs, and expired attempts.
3. Inject Storage POST timeout-after-commit, stale negative object metadata, create-only conflicts, lost DB commit acknowledgements, deletion errors, signed-token attempts and retries. Verify the upload broker never issues an unversioned cleanup DELETE, and expiry/account-erasure recovery handles orphans without falsely reporting success.
4. Confirm the deployed Storage provider actually honors create-only object semantics, blocks client insert/upsert under restrictive RLS, and cannot resurrect objects after cleanup.
5. Validate separate private gateways, zero public reachability, no Docker socket in the upload host, secret isolation, resource limits, and redacted logs.
6. Complete a Storage-prefix inventory for account erasure, activate an audited private retention schedule, and approve the raw-file deletion policy.
7. Review signed-upload token handling, worker ownership, idempotent shared evidence, user privacy notice, mobile UX and skill progression with no self-verified awards.

These unit-tested components do not satisfy the hosting, provider-concurrency, privacy approval or deployment gates. Leave the upload entrypoint disabled and PR #188 draft until independent security review.

### Failure recovery boundary (not activated)

The retention DB adapter now performs a terminal state transition when freezing an **issued** workbook attempt: `upload_enabled=false` **and** `status='failed'`, committed before Storage deletion. This prevents a new broker from locking an unsealed attempt after cleanup has begun. For processed, failed, or expired-and-grace-cleared processing attempts, cleanup retains the appropriate status. DB/pgTAP regression tests cover the original live session's rejection after the transition. The provider-level lock/write race and distributed cleanup behavior still require live staging tests.

A rejected broker call may leave an unsealed object after Storage accepted a write, or may correspond to a sealed object if the database commit acknowledgment was lost. The hot upload path must never delete either case. The server-side attempt remains available to the existing expiry/account-erasure coordinator, which freezes uploads, deletes through the private Storage API, confirms absence, and only then erases metadata. Reusing the same attempt path or treating an upload error as proof that no object exists is forbidden. These are code-level invariants; retention scheduling, orphan inventory, provider race tests, and alarms are **not** live and still block rollout.


### Read-only account Storage inventory prototype (disabled)

A separate, server-only \`SupabaseExcelOwnerInventory\` makes one bounded
\`POST /object/list/{bucket}\` query under a canonical owner UUID prefix,
using the reserved Excel bucket only. A folder or file entry is enough to
block account erasure. It cannot read workbook bytes, issue signed tokens,
delete objects, or reveal object names in its returned status.

The diagnostic wrapper requires externally confirmed Auth-session revocation,
and reports only \`objects_visible\`, \`empty_observed\`, or \`unavailable\`.
**Every result has \`account_erasure_confirmed=false\`: an empty provider
listing can be stale and is not authoritative deletion proof.** The actual
retention scheduler, retries/alerts, independent database/object consistency,
multi-pass erasure proof, and Auth deletion controller remain unimplemented
and require staging + privacy review. New tests are synthetic only.


### 2026-11-08 local-provider create-only regression

The new disposable local Supabase Storage race probe initially produced **three HTTP 200** responses for three concurrent uploads to one path when the client sent `x-upsert: false`. Therefore treating that header value as a denial of overwrite is **unsafe** on the tested provider. The production adapter and local probe now **omit the `x-upsert` header entirely** for create-only requests. A fresh local-provider concurrent race run must pass with exactly one accepted write and unchanged SHA/revision before this gate can advance; hosted staging behavior is still unverified.


### 2026-11-08 provider diagnostic clarification

The local Supabase Storage API returned **HTTP 200 for all three simultaneous privileged POST requests**, both with `x-upsert: false` and after removing the upsert header. Therefore the header alone is *not proven* to cause the concurrency behavior, and raw provider write exclusivity is **not established**. The CI probe now distinguishes a mandatory **sequential create-only and SHA/revision consistency check** from a nonblocking, explicitly warned **raw concurrent privileged-write diagnostic**. The latter bypasses the actual broker database lock by design. Multiple accepted concurrent privileged writes must remain a **hosted staging security blocker**, not be represented as a green immutability proof. Only the trusted broker with an exclusive row lock may write an Excel object, and all direct learner writes remain forbidden.


### 2026-11-08 local Storage metadata compatibility

The loopback provider returns a canonical private object name, bucket, and a string revision, but the object-info JSON's `metadata` may **omit `size`**. The private Storage adapter now treats a missing or null size as optional, while rejecting malformed or over-limit sizes whenever supplied. This is not a relaxation of file-content bounds: the HTTP client rejects large `Content-Length` and reads at most the configured limit plus one byte, the upload broker checks the original workbook length and SHA-256 readback, and the private bucket has a 10 MiB limit. The synthetic local-provider test checks the same behavior. This needs fresh CI; hosted verification remains pending.

Note: the earlier concurrency-gate text above was superseded by the separate strict sequential and warned raw concurrent diagnostic; simultaneous raw service-role writes are not considered a verified single-writer guarantee.


### One-shot retention service composition (source only)

`private_retention_job.run_retention_once` now combines the existing
owner-bound expiration sweep and private issuance-log pruning into one
bounded, **dry-run-by-default** invocation. Destructive execution requires
an explicit privileged authorization flag and a fresh exclusive,
non-autocommit connection; results expose only aggregate counts and
`retry_required` or `unavailable` status, without workbook content or
account identifiers. The module neither schedules itself nor deletes Auth
accounts, and never declares account erasure complete. The CI suite tests
authorization denial, cleanup failures, pruning order, connection closure,
invalid configurations, and redaction.

This is not an approved operational scheduler: live provider staging,
separate cleanup credentials, an authenticated private runner, durable retry
queue, monitoring/alerts, retention consent/disclosure and independent
security review are still required. Do not enable execution in production.


### Retention sweep completion semantics

The isolated one-shot retention job now returns **preview_only** for all dry
runs; **retry_required** when any deletion failed; and **more_pending** when
either candidate cleanup or 48-hour issuance pruning hits its batch cap.
Only a short, retry-free authorized execution returns **complete**, which
means that *single sweep* completed, **not** that every account or workbook
has been erased. Malformed prune counts fail closed. This is tested in CI;
no scheduler or production worker is activated.
