# Simulation framework: Phase 0 design note

- **Status:** Owner authorized implementation on a review branch; review is
  still required before merge, feature enablement, or deployment.
- **Repository baseline:** `34b97d8` on `main`, November 7, 2026. Discovery
  began at `7472eec`; subsequent updates added catalog content and did not
  change the simulation or evidence paths reviewed here.
- **Proposal:** [Simulation and virtual learning framework, v0.11](SIMULATION_VIRTUAL_LEARNING_FRAMEWORK.md).

The owner asked for the proposal to be implemented on the feature branch
before review. Work therefore proceeds against its documented conservative
defaults; this does not approve a merge, production enablement, or deployment.
The note records findings and open verification limits rather than implying
that a live database or production host was inspected.

## Conclusions for the seven stop-condition areas

| Area | Initial conclusion |
| --- | --- |
| Existing simulator | Start with the existing [currency and ATM widget](../../lib/widgets/literacy/currency_atm_widget.dart). It already has a discrete withdrawal-completion action and is mounted in [life domains](../../lib/screens/literacy/life_domains_screen.dart). A completion callback can be added without changing its existing callers. It does not need a new engine or navigation destination. |
| Completion telemetry | Use **memory only**, for every learner, in the first prototype. Do not send simulation events through `record_events`, the outbox, analytics, or a new RPC. Authenticated server persistence remains a separate, reviewed change. |
| Activity contract | Start with immutable activity identity and capabilities, a small lifecycle, and typed completion-only events. No score, learner identity, credentials, raw input, or arbitrary event metadata is part of this prototype. |
| Lesson integration | The opt-in native slice now adds a `simulation` lesson block and a deferred full-screen route, with Help, explicit exit, Escape, load-failure return, and lesson-content fallback. Launch remains disabled by default and requires a registered ID/version. The route and block still need owner review and a reviewed amendment to [the locked UI baseline](../../UI_ARCHITECTURE_LOCKED.md) before enablement. |
| Evidence architecture | The current client writers and the `arch_04` server projection are not equivalent. A real authenticated database check and a user-facing regression investigation remain open; simulation evidence must not depend on either path. |
| Attempt handling | The prototype has an ephemeral local session, **not** a server attempt. Any future persisted attempt must be server-issued, version-pinned, owner-bound, and idempotent. |
| Native networking PoC | A native networking practice now presents the router topology, structured diagnosis/repair/reason choices, hints, narration, and explanatory review without a score. Focused widget tests cover the interaction; screen-reader, keyboard-only, reduced-motion, contrast, and WCAG 2.2 AA validation remain outstanding. |

## Evidence boundary investigation

### Existing writers and readers

1. [SpacedRepetitionService](../../lib/services/spaced_repetition_service.dart)
   records a `review` event and separately invokes
   `ConceptEvidenceService.recordEvidence` without awaiting it. That service
   resolves item-to-concept mappings and weights, then upserts
   `user_concept_state` directly. Its errors are logged, but this path does not
   report a failed concept update to the learner. The review event constructed
   here has no `concept_id` in its top-level fields or metadata, so the
   `arch_04` concept projection does not itself resolve its mapped concepts.
2. [DiagnosticAssessmentService](../../lib/services/assessment/diagnostic_assessment_service.dart)
   calls `recordAssessmentItemEvidence`, which also performs direct
   concept-state upserts. The method catches failures and returns `false`; the
   [diagnostic report](../../lib/screens/assessment/diagnostic_report_screen.dart)
   displays a warning when evidence was not persisted.
3. [TargetReadinessService](../../lib/services/target_readiness_service.dart),
   its provider, and the [Progress screen](../../lib/screens/progress/progress_screen.dart)
   read concept state; they are not additional direct upsert callers. Readiness
   can prefer `get_target_readiness_v2`, while the Progress retention summary
   uses stored retrieval bands.

The [client evidence service](../../lib/services/concept_evidence_service.dart)
computes per-mapping weighted totals, retrieval bands, and confidence before
its upsert. The
[`arch_04` migration](../../supabase/migrations/20261107050000_arch_04_learning_events_strict_rules.sql)
revokes authenticated `INSERT`, `UPDATE`, and `DELETE` on
`user_concept_state`. Its `record_events` projection updates counts and
weighted totals only when the submitted payload includes a concept ID; it
increments the total by `1.0`, accepts the client score and concept ID, and
does not calculate the old service's per-concept weights, retrieval band, or
confidence. The
[`get_target_readiness_v2` implementation](../../supabase/migrations/20261106000000_arch_02_item_analytics_and_readiness_v2.sql)
uses weighted accuracy and count for its score but also reports distributions
from the stored retrieval bands. A stale band can therefore affect the band
distribution and Progress display even when some weighted totals change.

**Verification limit:** the permission failure is expected from the SQL
privilege revocation, and the existing
[pgTAP suite](../../supabase/tests/learning_events_strict_rules_test.sql)
contains authenticated-role denial tests, but neither a live database nor the
real Flutter-to-database flow was exercised in this workspace. Docker's engine
was unavailable. The existing
[diagnostic service test](../../test/services/assessment/diagnostic_assessment_service_test.dart)
uses a fake Supabase client and does not prove actual role permissions.
Whether deployed learners have experienced a regression remains unverified.

This is a broader existing-architecture issue. Investigate and correct it in
separate work rather than quietly changing concept evidence inside the
simulation project. Before any simulation result affects mastery, readiness,
or scheduling, the server must compute the evidence value, validate the
activity-to-concept mapping, and update the existing authoritative projection.
`arch_04`'s idempotency and server-side write boundary alone do not satisfy
those requirements. The existing
[measurement roadmap](../learning_science/06_MEASUREMENT_AND_SCHEDULING.md)
and [platform plan](../product/PLATFORM_VISION_AND_EXECUTION_PLAN.md) should govern
that work; do not create a second simulation-specific mastery system.

## Local prototype contract

Simulation launch requires a registered ID/version and an explicitly enabled
`ENABLE_SIMULATION_PREVIEW` flag. That flag is off by default. Every launch
boundary — the lesson block's launch button, the simulation screen, and
`SimulationSession` — calls `isSimulationPreviewAllowed`, which returns false
when `kReleaseMode` is true, regardless of any explicit `previewEnabled` or
`enabled` constructor override. Debug-mode tests may pass those overrides. The
flag is not an approval to expose the preview route: the owner, accessibility,
fallback, and privacy gates below still apply.

The `atm-withdrawal` activity opens `CurrencyAtmWidget` with
`initialSection: CurrencyActivitySection.atmSimulator`; other callers keep the
default coins-and-bills section.

An activity configuration contains a host-provided simulation ID and immutable
version plus declared capabilities. It is not a content manifest or a learner
record. The prototype supports:

| Operation | Local behavior |
| --- | --- |
| Start | A disabled session fails explicitly. An enabled, not-yet-started session emits one `launched` event and becomes running. |
| Pause/resume | Available only when declared as a paired capability. Unsupported or invalid operations fail explicitly. They do not generate completion telemetry. |
| Complete | A running session emits one `completed` event. Completion is not a score, a pass, or evidence of learning. |
| Terminate | A running or paused session emits one `terminated` event with an allowlisted learner, host, or runtime reason. |
| Fail | A running or paused session emits one `failed` event with an allowlisted coarse category. It means a runtime failure, not a failed assessment. The prototype allows at most one such event per session. |
| Late events | Once completed, terminated, or failed, later terminal reports are ignored and return `false`; they do not change the result. A missing completion remains unknown, not failure. |
| Dispose | Clear the in-memory event list and reject subsequent operations. No retry queue or storage is created. |

The events have no free-text metadata or raw action trace. The ATM callback
signals completion only; it must never transmit the practice PIN, withdrawal
amount, or other entered values. When this prototype eventually gains a host,
it must tell learners not to enter a real PIN. No server attempt ID is invented
for this local session.

The existing canonical taxonomy must remain authoritative. The
[learning-science taxonomy](../learning_science/02_LEARNING_TASK_TAXONOMY.md)
defines facets, operations, channels, reference policy, and assessment policy.
The existing [Dart `LearningTaskProfile`](../../packages/learning_core/lib/src/models/learning_task_profile.dart)
has a different, smaller track-and-timing shape. Reconcile those existing
representations before adding simulation metadata; do not assume they are
already interchangeable or create a competing taxonomy in this prototype.

## Privacy and telemetry

The prototype has no persistence or network dependency, for both signed-in and
anonymous practice. In particular:

- No simulation event enters `LearningEventOutbox`, `learning_events`,
  analytics, crash-report metadata, local preferences, or a later sync queue.
- An anonymous Supabase guest can have a non-null `currentUser` and is
  identified by `user.isAnonymous`; a non-null user ID alone is **not**
  sufficient to permit authenticated telemetry. See
  [AuthNotifier](../../lib/providers/auth_provider.dart).
- Guest identity linking can preserve the same user ID. Never attach an
  anonymous simulation session or its local progress to a later account.
  Sessions are ephemeral by default and discarded on disposal.
- Existing error reporting currently contains example integrations and local
  logging rather than an active Sentry/Crashlytics integration, but an
  end-to-end audit is still required before the simulation route is enabled.
- The [outbox](../../lib/services/offline/learning_event_outbox.dart) supports
  both anonymous and account-scoped queues and can flush account queues. It is
  therefore not an acceptable anonymous-simulation boundary merely because it
  is local first.

The current tests exercise the local session, ATM callback, and native
networking/route flow, not a complete authentication, account-switching,
browser-storage, analytics, or network audit. Those checks remain required
before a learner-facing release.

## Future authenticated attempt and completion path

No persisted path is implemented here. If authenticated completion telemetry
is approved, prefer a dedicated completion-only server API rather than
expanding `record_events`. It must derive the learner from authentication,
exclude anonymous guests, allowlist event types and metadata, reject scores,
ratings and scheduler state, enforce ownership, use server timestamps, and
have no mastery, readiness, or scheduling side effects.

For each persisted attempt, the server must create the ID and pin simulation,
scenario, rubric where applicable, and contract versions. Use independent
database enforcement for:

1. One server-issued ID per attempt.
2. At most one accepted completion per attempt.
3. A request-idempotency key scoped to learner and operation, with a canonical
   payload digest and atomic result creation.

The server returns the original result for the same key and payload; rejects a
reused key with a different payload; does not accept a second completion with a
new key; prevents cross-user access; and rejects version mismatches. Creation
retries must not create additional attempts. Define the precise transaction
and response contract before implementation. Existing `learning_events` IDs
are globally keyed and may be client-supplied; a future simulation endpoint must
not let a client-supplied event ID shadow another learner's record or reveal
whether it exists.

Persisted `launched`, `completed`, and `terminated` events are each at most
once per attempt; `failed` is bounded. Only allowlisted termination reasons and
coarse failure categories are permitted. Late events cannot reopen an attempt.
The current local-only slice discards activity on exit and has no offline retry.
Any later authenticated retry design must reuse the original idempotency key
for a bounded period and must not use the anonymous outbox.

## Lesson, fallback, navigation, and accessibility

[`LessonBlockType.fromString`](../../lib/models/lesson_block.dart) turns an
unknown type into `markdown`; the
[markdown renderer](../../lib/widgets/lesson/blocks/markdown_block_widget.dart)
then reads `body`, `text`, or `markdown`, or renders nothing if all are absent.
Accordingly, each `simulation` block must include non-empty `body` content;
the migration enforces this so older clients always render the fallback. The
new renderer uses that same `body` before any optional fallback aliases. The
focused tests cover the fallback path, but an older-client build has not been
run against a simulation lesson. A non-simulation alternative must let the
learner demonstrate the same objective, not merely describe the activity.

The database block-type CHECK is extended by the append-only
[`simulation lesson-block migration`](../../supabase/migrations/20261107100000_simulation_lesson_blocks.sql).
The consolidated self-host bundle was regenerated from migrations with
`dart run tool/self_host_bootstrap.dart --generate-bundle deploy/self-host/init-scripts/01-full-schema.sql`
([self-host documentation](../SELF_HOSTING.md)). Neither the migration nor any
production database has been applied or changed; production deployment remains
subject to the repository's guarded migration workflow.

The implemented route has visible Help, an explicit exit, Escape and system
back handling, and a tested fallback on disabled or unknown activity and
deferred-load failure. State-preserving return and unsupported pause behavior
still need validation before enablement. Check keyboard, touch, screen-reader
semantics, narration, reduced motion, contrast, and adjustable pace against the
WCAG 2.2 AA target. Neither the networking practice nor the ATM widget has been
certified against that target.

## Networking proof and measurement

PoC A can use native Flutter widgets or `CustomPaint` for a simple network
schematic, with semantic controls and an equivalent structured action list.
The task is to connect devices, diagnose a deliberately broken connection,
choose a repair, and select or order the reason it works. Keep explanations
structured rather than free text. A scoring replay, if built, is test-only and
must not write events, concept state, readiness, or production endpoints.

Define the learning outcome and independently reviewed baseline and equivalent
post items before piloting. Include delayed retention and a comparison or
alternative-explanation analysis where practical. Record sample size and
uncertainty; a small pilot can expose usability and measurement problems but
cannot establish causal effectiveness.

## Review and implementation gates

- [ ] Owner reviews this note and the original proposal; resolve the live
      `ConceptEvidenceService` permission and user-impact investigation.
- [ ] Decide the existing task-profile reconciliation and a compatible
      supported-client/older-client lesson fallback.
- [ ] Approve the locked-UI amendment and demonstrate equivalent, accessible
      alternatives and failure/exit behavior.
- [ ] Audit guest, signed-out, authenticated, account-switch, network,
      analytics, crash-reporting, outbox, and local-storage boundaries.
- [ ] If persistence is needed, approve the completion-only RPC, attempt
      identity, versioning, idempotency, retention, and pgTAP/RLS tests.
- [ ] Before evidence processing, land server-authoritative scoring and
      concept mapping through the shared evidence architecture.
- [ ] Before T1/T2 work, confirm the production host and separately review
      isolation, CSP, framing, network egress, caching, and performance.

## Implementation and verification status

- `flutter test test/widgets/simulation/ test/services/simulation/`
  passed: 22 tests. These include a gate test bound to the compile-time
  `kReleaseMode` constant (`isSimulationPreviewAllowed` has no caller-supplied
  release-mode parameter), ATM direct entry with the
  unchanged default section, and a route-level deferred-load failure test that
  exercises the real `buildSimulationRoute` error view, Help, and the
  "Return to lesson" pop back to the launching page. A temporary copy of the
  placeholder `.env.example` was needed because the asset bundle requires `.env`.
  All three exit paths (screen exit/Escape/disabled return, deferred-load
  failure return, and network-practice finish) use `leaveSimulation`: they pop
  to the originating lesson when one exists and otherwise go to `/learn`, so a
  direct link opened in a new tab cannot strand the learner. Four direct-link
  tests start on the simulation route and verify each path reaches `/learn`;
  the simulation suite is now 26 tests.
  Widget tests run in debug mode, so release behavior is verified by the gate
  unit test plus the compile-time `kReleaseMode` constant, not by launching a
  release build end to end.
- `flutter analyze` passed with no issues using the same temporary `.env`.
- `flutter build web --release --dart-define=ENABLE_SIMULATION_PREVIEW=true`
  compiled successfully (existing `flutter_tts` WebAssembly dry-run warnings
  only). This confirms the gated code compiles for release; it was not served
  or exercised in a browser.
- After merging `origin/main` (`126c4e1`), the full `flutter test` suite passed
  (2,261 passed, 1 skipped), and `dart run tool/verify_migration_history.dart --base-ref origin/main`
  verified append-only, monotonic history. The self-host test's latest-version
  assertion now expects `20261107100000`.
- `dart run tool/self_host_bootstrap.dart --generate-bundle deploy/self-host/init-scripts/01-full-schema.sql`
  regenerated the bundle against the combined history: 93 migrations, with
  `20261107060000_performance_library_search_trigram_indexes` followed by
  `20261107100000_simulation_lesson_blocks`. It was not deployed. The
  migration also requires the backward-compatible `body` fallback.
- [The pgTAP suite](../../supabase/tests/simulation_lesson_blocks_test.sql)
  now inserts real rows. It accepts a simulation block with a body; rejects a
  missing, empty, or whitespace-only body and an unknown block type
  (`23514`); and accepts all eight existing block types without a simulation
  body. It runs in a rolled-back transaction.
- Hot restart was attempted, but no running Flutter app was connected to this
  workspace.
- pgTAP could **not** run locally because the Docker engine was unavailable. It
  must pass in the PR's `verify-database` CI job, which runs `supabase test db`
  against both incremental and clean local databases. No hosted or production
  database was started, deployed, or modified.
- Feature-enablement gates (not merge gates for preview-disabled code): a
  release browser must refuse both block and direct-route launches even with
  `ENABLE_SIMULATION_PREVIEW=true`, and WCAG 2.2 AA review plus the equivalent
  learning alternative must be verified.
