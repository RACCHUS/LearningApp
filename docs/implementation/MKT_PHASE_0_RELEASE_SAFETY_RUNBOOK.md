# Marketing plan v1.6 — Phase 0 implementation evidence

**Branch:** `feat/marketing-foundation-feature-controls-20261110`
**Plan:** `/LEARNINGAPP_MARKETING_ADVERTISING_FINANCIAL_SUSTAINABILITY_MASTER_PLAN.md`

## Owner decisions preserved

- TEL Fast stays available. A low-key "Fast · Experimental" disclosure signals unverified learning-outcome maturity without disabling it.
- BYOK must not be usable until key custody, provider compatibility, privacy and CSP remediation are independently tested and the owner explicitly approves activation.
- Existing unreplaced learning features must remain available. No legacy feature is removed by this slice.
- No paid services, billing credentials, analytics collection or production deployments are authorized by this branch.

## BYOK emergency latch (MKT-002 / FLAG-015)

`ByokReleaseGate.enabled` is hard-coded `false`, independently of any later admin configuration. The settings dialog offers only an unavailable explanation and opt-in **local key deletion**, without loading credentials into text fields. `ByokStorageService.saveConfig`, `LlmClient.create`, both direct provider-client calls and curriculum generation reject before any network request. Existing local data is not automatically erased or silently uploaded. Users with formerly exposed keys should consider rotating them.

**Important:** Until the changed web bundle is deployed, BYOK may remain reachable on the currently deployed site. A successful PR or migration is not proof of production shutdown.

## Future BYOK unlock conditions

Require reviewed key storage/handling; approved provider/endpoint policy; no API key in query URLs, URLs, logs, analytics or exception messages; CSP and real browser compatibility; secret-leak/off-path tests; privacy claims consistent with the architecture; and separate owner approval. Never infer approval from a toggled server flag.

## Rollout acceptance

- Verify the provider direct-call tests have zero HTTP requests.
- Verify no new key persistence is permitted.
- Verify mock-backed non-BYOK evaluations and core lessons remain usable.
- Confirm BYOK dialog is unavailable without mounting or reading existing key fields.
- Run Flutter analysis/tests, check release bundle changes, then separately check the live deployment.

## Feature registry bootstrap and admin panel (FLAG-001..005)

An additive migration `supabase/migrations/20261110220000_marketing_feature_control_foundation.sql` seeds the approved Fast/Overview ON defaults, default-OFF unready features, `private.site_feature_enabled` for future server admission, anonymous public snapshot, privileged admin RPCs, optimistic revisions and immutable audit rows. The `/admin/features` route is linked from Cost & Observability and inaccessible to non-admins by server enforcement. Entries marked **Planned; not yet connected** do not assert that a live feature is disabled.

**Bootstrap is intentionally dark.** `SITE_FEATURE_RPC_READY` defaults to `false`, so ordinary learners make zero calls to the not-yet-deployed RPC. Apply the migration only through `dart run tool/guarded_supabase_deploy.dart` after full owner-approved preflight and backup review; do not apply it because this PR is merged. After deployment, test admin RPC authorization, direct bypass, concurrent edits and default Fast/Overview parity. Then enable `SITE_FEATURE_RPC_READY=true` in a separately reviewed web build. Subsequent ready-feature switches take effect without deployment.

The registry is a source-of-truth **only for the surfaces actually wired to it**. Existing simulations, community, legacy `FeatureFlagsCore`, advertising and MCP remain outside generic controls until feature-specific backend enforcement is complete and tested. Never describe an unwired flag as an operational kill switch.

## Additional BYOK key-hardening changes (still unavailable)

- `ByokConfig.toJson` now emits nonsecret preferences only; `ByokConfig.fromJson` intentionally discards any legacy `apiKey` property. Old browser records are not deleted without user action. Re-entering a key is required after a reviewed future enablement.
- The new session key is scoped to a `ByokStorageService` instance, not written to persistent storage; it is erased by `clearConfig`.
- Credential-bearing HTTP clients reject custom endpoint URLs. Gemini uses the provider key header rather than query parameters; provider error bodies are not echoed in UI exceptions.
- These fixes **do not authorize reactivation**: browser CSP, supported provider models, legal/consent language, compatibility and cross-session UX still need review.

## Lifecycle refresh and future-feature CI contract

`SiteFeatureRefreshObserver` wraps only the production router's `AppShell` and leaves the reusable legacy `AppShell` untouched. While `SITE_FEATURE_RPC_READY` is false it registers no lifecycle observer and makes no new feature RPC. Once the reviewed bootstrap is activated, it refreshes cached presentation flags on app resume with a two-minute minimum interval; the owner panel also invalidates its local snapshot after a successful change. Neither behavior substitutes for backend admission checks for remote, privacy or paid operations.

`tool/verify_feature_registry.py` is now a required no-network Flutter CI step with regression tests. Its contract aligns all 18 `SiteFeatureKeys` entries to additive SQL seed keys and rejects risky enabled-by-default entries. It cannot automatically prove that a new application feature is wired to its flag, so `AGENTS.md`, the pull request checklist, code review, explicit server-guard tests and the disabled-state contract remain mandatory.

### Emergency OFF and registry failure semantics

Before the production feature registry is activated, TEL Fast and Overview use their owner-approved existing defaults (ON). After `SITE_FEATURE_RPC_READY=true` is enabled in a separate reviewed release, an unavailable or malformed registry snapshot disables optional TEL Fast/Overview presentation instead of silently reviving an emergency-killed feature; Standard learning stays available. A successful snapshot explicitly set ON restores Fast/Overview. This avoids bypassing kill switches when the network or database fails, and is covered by deterministic tests.
