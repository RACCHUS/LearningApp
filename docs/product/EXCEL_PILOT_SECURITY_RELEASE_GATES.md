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
