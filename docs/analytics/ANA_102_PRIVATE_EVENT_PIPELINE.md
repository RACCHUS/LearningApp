# ANA-102 / ANA-105 / ANA-108 — Private product events and first admin overview

**Status:** Migration and UI implementation in PR #212; not deployed, not collecting events.  
**Prerequisite:** ANA-101's disabled client dictionary and separate learner-progress and scored-evidence streams.

## Trust boundary and minimal collection

- Raw product events live in the **non-exposed** `analytics.product_events` table. The `analytics` schema grants no usage to `anon` or `authenticated`, and its raw tables grant no browser DML/SELECT. RLS is enabled as defense in depth.
- Only `public.record_product_events(jsonb[])` ingests events. The server attaches identity from `auth.uid()`, not client identity fields. No service key appears in Flutter.
- **Eligibility is default-deny:** `auth.users.is_anonymous IS FALSE` AND trusted `auth.users.raw_app_meta_data.product_analytics_eligible = true`. This metadata may be provisioned only by privileged server-side processes **after an independently approved adult/minor, school-account and privacy review**. Browser-controlled `raw_user_meta_data` is ignored. The current implementation does not decide a person's age or make a user eligible.
- Even an eligible user must explicitly opt in through `public.set_product_analytics_consent(true)`; a row in `analytics.product_consents` is checked and locked during ingestion. No opt-in UI is enabled or implicit from login.
- `set_product_analytics_consent(false)` works for any authenticated user and immediately erases their raw events. Deleting their Auth user cascades to consent and raw events. `export_my_product_events` returns at most 100 of the caller's own events per request; pagination/verified full-volume export is a later requirement.
- Strict versioned event dictionary and property allowlist, maximum 25 items per RPC, 60 items per user/minute, 7-day offline event age, 5-minute future tolerance, 2 KiB JSON envelope, 512-byte property cap and 64-character ASCII categorical values. Raw search strings, URLs, answers and free-form user notes do not have valid fields.
- Event IDs are per-user unique; identical replays acknowledge `duplicate_noop`; changed payloads return `idempotency_payload_mismatch`. The optional client transport verifies each ACK, but **no durable outbox exists yet**. The default `ProductAnalyticsService` remains disabled and uses a no-op sink.

## First admin view

- `public.get_product_analytics_overview(p_days)` is a SECURITY DEFINER aggregate with fixed empty search path and **server-side** `public.is_admin()` gate, plus an explicit anonymous-account denial.
- Rolling windows: 1, 7, or 30 days, based on *received_at* (not the client clock). Returns `as_of`, coverage `opted_in_eligible_accounts_only`, and counts of distinct user IDs with events, received events, session-start actions, resource opens and external clicks. It is not a census of all platform activity, revenue, or verified learning.
- **Zero received eligible events => `not_measured` with null counts**, never fabricated platform zero. Between one and four distinct eligible users => `small_cohort_suppressed` with null counts. For five or more eligible users, the server returns counts, not raw rows.
- The first Flutter view at `/admin/analytics` is deferred/lazy and linked from the existing admin Cost & Observability console. Client-side `isAdmin` is only UX; the RPC enforces authorization.

## Retention, deployment, and outstanding gates

- Proposed raw retention is 90 days. `analytics.purge_expired_product_events()` is a **privileged manual maintenance function**. No scheduler is installed or activated by this PR. Until an approved scheduled job or operational manual runbook is in place, this policy is **not automatically enforced**.
- This PR makes an additive migration and synthetic pgTAP and Flutter tests. It does **not** deploy it. Hosted migration ledger must first pass owner-controlled `dart run tool/guarded_supabase_deploy.dart --dry-run`; there are earlier unapplied migrations in the repository.
- Collection activation is blocked until: documented age/school eligibility policy, trusted provisioning, explicit accessible user consent and withdrawal interface, retention execution and erasure/export audit, account-isolated durable client outbox with backpressure/TTL and confirmed retry, coverage/small-cohort validation, and a final privacy/security review.
- No external analytics SaaS or paid service is required; public user-facing widgets and study flows must not wait on analytics.
- Test corpus: `supabase/tests/ana_102_product_event_security_test.sql`, `test/services/product_event_rpc_sink_test.dart`, `test/services/product_analytics_overview_service_test.dart`, `test/widgets/product_analytics_overview_screen_test.dart`.

## Definitions and exclusions

| Displayed metric | Verified numerator | What it does **not** measure |
|---|---|---|
| Opt-in active users | Distinct accepted product-event user IDs in selected rolling window | All registered or active users, daily DAU, unique people across devices |
| Events | Accepted, deduplicated raw event records | Page views without explicit captured event or all product activity |
| Session starts | `app_session_started` event records | Exact user sessions without complete client session lifecycle |
| Resource opens | `resource_opened` event records | Reading/comprehension or external watch time |
| External clicks | `external_resource_clicked` event records | Partner conversions, affiliate revenue or course completion |

All metrics will remain unavailable in production until the guarded migration has been applied, explicit consent and eligibility decisions are made, and approved collection is activated.
