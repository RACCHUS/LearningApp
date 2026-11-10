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
