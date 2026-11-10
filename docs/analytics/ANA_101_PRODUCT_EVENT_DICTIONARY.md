# ANA-101/102 — Product event dictionary and disabled capture contract

**Status:** Interface only, no data collection or deployment. The service defaults to disabled and its default sink is a no-op. This file is the authoring contract for Phase 1 of [the analytics plan](../../LEARNINGAPP_ANALYTICS_IMPLEMENTATION_PLAN.md).

## Why product events are separate

- `public.learning_events` records verified learning evidence/FSRS actions and is RPC-only; do **not** contaminate it with clicks or arbitrary user activity.
- `private.learner_progress_events` and `public.learner_activity_progress` represent learner progress and bounded active-study intervals; they are **not** general product analytics.
- `public.usage_events` represents API and quota consumption, not distinct active learners.
- Until the new analytics ingestion is implemented and deployed, dashboards must say **Not measured** for product event KPIs, rather than borrowing counts from the three unrelated sources.

## Version-1 event dictionary

| Event | Allowed categorical dimensions | Notes |
|---|---|---|
| `app_session_started` | `surface` | Requires session design/idle boundary before emitting |
| `surface_viewed` | `surface` | Learn, Library, Progress etc.; not raw route query strings |
| `goal_selected` | `goal_type` | Confirm successful save; do not transmit user-entered goal text |
| `resource_search_submitted` | `source_type`, `query_category` | NEVER capture raw query or result titles |
| `resource_opened` | `resource_id`, `resource_type`, `source_tier` | Only catalog IDs, no URLs |
| `external_resource_clicked` | `resource_id`, `provider_category`, `referral_id` | A click is not evidence of watching/learning |
| `lesson_engaged` | `resource_id`, `mode` | Explicit interaction; not lesson mount or score |
| `feature_error_observed` | `error_category`, `feature` | No full stack, input, email, token or raw response |

The client JSON envelope has `event_id`, `session_id`, `event_name`, `schema_version=1`, `occurred_at_client`, and `properties`. The **server** must attach `user_id` from JWT, receipt time, trust/eligibility and ingestion status. Unknown event names, dimensions or versions must be rejected, not silently accepted. Do not store user metadata that a client can edit as a permission source.

## Privacy + release gates (not yet satisfied)

1. Document and approve minor/school-managed/guest eligibility; anonymous Supabase users are still `authenticated`, so server checks **trusted** `auth.users.is_anonymous` instead of role alone.
2. Design consent capture and withdrawal, disclosures, export/erasure and retention (proposed raw events 90 days) with user privacy owner.
3. Add a dedicated **non-exposed** `analytics` schema and validated `public.record_product_events(jsonb[])` RPC with strict table grants, auth/consent/eligibility checks, UTC timestamp bounds, property allowlists, 25-event batch limit, unique ids and retry ACK.
4. Add client-only **bounded and account-isolated** outbox with retry/TTL (proposed 7-day cap), strict opt-out deletion and no study-performance impact.
5. Add trusted aggregation and `is_admin()`-gated read RPCs with non-admin and anonymous guest negative pgTAP tests. Four dashboard surfaces only once metrics are truly available.
6. Instrument high-value routes with minimal capture, preferably at **confirmed actions** rather than every render. Keep the default feature flag **OFF** until the entire server and privacy gate is verified.
7. Prevent expensive synchronous writes and user-visible error behavior. Never add a vendor SDK or incur spend without the user's approval.

## Verification

`test/services/product_analytics_service_test.dart` proves disabled-by-default behavior, required three client gates (feature, eligibility, consent), bounded event properties, rejection of raw query/URL dimensions and analytics sink errors not interrupting learning.

**Limitations:** Client booleans are not an authorization boundary, and no event storage, real DAU/MAU, payments, or dashboards are created by this PR.
