# ANA-003 — Active study-time measurement (client v1)

**Scope:** Measured study-time intervals in Flutter lesson reader mode only. This is *not* time-on-page, a verified learning outcome, an assessment score, or third-party video/course watch time.

## Contract

- Entry: rendered `RichLessonReader` or `LessonContentPager`. Study-mode selection, loading screens, dashboards, external resources, and other app surfaces do not count.
- Start: visible foreground lesson **plus an actual learner input** (pointer down, scroll/wheel/trackpad, dragging or keyboard key-down). Merely opening a lesson or bringing a background tab forward earns zero.
- Idle: after 60 seconds without input, no further time is credited. This is an intentionally conservative proxy for reading; long passive reading, hands-free audio and accessibility interactions may be **undercounted**, not falsely estimated.
- Visibility: Flutter's `WidgetsBindingObserver.didChangeAppLifecycleState` pauses for `inactive`, `hidden`, `paused` and `detached`. The lesson's `ModalRoute.isCurrent` pauses when a modal or route overlays the content. On resume, a fresh interaction is required.
- Scheduling: sample foreground elapsed time every 10 seconds, reject gaps over 20 seconds and reversed clocks, and emit at most 60-second events (stricter than the 120-second server cap).
- Offline: locally persist each interval as an immutable Hive progress action with a unique idempotency key and typed content ID. A separate allowlisted serializer excludes all Hive-only identity, study-mode and score counters. Reuse ANA-001B `record_learner_progress(jsonb[])` and verify per-event ACK before marking synced. An offline or un-deployed backend leaves events retryable.
- Identity: intervals capture the **learner ID at observation time**, and old-account rows cannot sync under a new account. Anonymous Supabase sign-ins have their own learner ID. This is learner progress, *not* product telemetry.
- Server: existing private ledger enforces authenticated `auth.uid()`, event shape, 25-event batch, timestamp/interval bounds, exact replay digest and UTC-day union. No client direct DML or score claims.

## Daily goal semantics

The goal widget now uses **this device's measured local Hive intervals**. It clips to the learner's device-local calendar day (constructs next calendar midnight rather than adding 24 hours), unions overlapping/tab-replayed intervals, and excludes other users and downloaded UTC daily projections. It displays a positive duration of less than a minute as `<1m` and displays *unavailable* instead of zero when no measured interval exists.

**Limitation:** This is a precise *this-device* lower bound, not a synced cross-device total. Do not silently add UTC aggregate records to a local day. A future server-side local-day query or interval endpoint should be designed to support cross-device days and IANA timezone preferences before making overall daily-goal claims.

## Limitations / follow-ups

1. Time is a behavioral **estimate**, not proof of learning. A user can deliberately interact without reading. Use scores and verified evidence for outcomes.
2. Long passive reading, screen readers, global voice controls and audio playback need explicit, accessible engagement signals. Do not count audio playing in a background tab by default.
3. Device-local time depends on the device time zone; a persisted IANA learner preference and DST/account-switch integration tests are a follow-up.
4. Multiple tabs/devices can submit overlapping windows. The server's event ledger and UTC interval union are authoritative; the client local-day display uses its own union.
5. Offline queues should be monitored and eventually bounded with visible partial-state accounting. Never silently report missing/dropped time as zero.
6. Hosted Supabase has pending migrations. The new RPC cannot accept events until the guarded owner-controlled deployment applies ANA-001B. All events remain locally queued until then.
7. Do not enable product-level anonymous telemetry as a side effect of this learner-progress feature.

## Verification

- Unit tests: `test/services/active_study_tracker_test.dart`, `test/services/local_study_day_test.dart`, `test/models/progress_server_event_test.dart` and `test/providers/daily_goal_progress_accuracy_test.dart`.
- Integration: ANA-001B's `supabase/tests/ana_001b_learner_progress_rpc_test.sql` already tests ACL, idempotency, interval union, replay and UTC midnight.
- Deployment: merge only after Flutter analyze/tests/web build and clean-slate/incremental Supabase CI pass; production changes remain a separate guarded workflow.

Relevant references: [Flutter lifecycle state](https://docs.flutter.dev/release/breaking-changes/add-applifecyclestate-hidden) and [MDN Page Visibility API](https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API).
