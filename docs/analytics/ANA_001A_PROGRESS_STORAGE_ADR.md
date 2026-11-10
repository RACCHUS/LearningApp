# ANA-001A — Canonical learner progress storage contract

**Status:** Proposed architecture decision; RED contract test pending ANA-001B implementation  
**Owner issue:** [#202](https://github.com/RACCHUS/LearningApp/issues/202)  
**Plan:** [LearningApp Analytics Implementation Plan](../../LEARNINGAPP_ANALYTICS_IMPLEMENTATION_PLAN.md)  
**Evidence snapshot:** `main` at `54c861640d90366b51e0f691c4a1958d177081e8`, read-only hosted schema inspection on 2026-11-09

## Decision

Prefer a **narrow, typed, version-aware new learner-progress projection** backed by an **idempotent server-controlled event ledger** and an authenticated RPC. Keep the legacy `public.user_progress` table as a compatibility boundary until all callers have been migrated and verified. Do not add old UI/local-cache fields to the legacy table merely to make malformed `toJson()` payloads accepted. This decision does not authorize a production migration.

## Why the legacy table is not a safe universal store

1. The normal `lib/providers/lesson_provider.dart` route fetches `public.lessons` by `lessonId` and its DB identifiers are UUIDs.
2. `lib/providers/available_lessons_provider.dart::_parseAssetLesson` explicitly derives bundled lesson IDs from filename stems, e.g., `prog_01_variables`, `prog_02_control_flow`, `prog_03_functions`. Those IDs reach `LessonScreen._onLessonComplete` via `widget.lessonId`; they cannot satisfy the `user_progress.lesson_id UUID REFERENCES public.lessons(id)` constraint.
3. `public.user_progress.user_id` references `public.users(id)`, not `auth.users(id)`. Read-only hosted inspection found 7/24 `auth.users` accounts without `public.users` rows, including two non-anonymous accounts.
4. `StudyNotifier.markLessonAsCompleted` and `toggleLessonCompletion` submit fields absent from the hosted schema. `ProgressSyncService` serializes local `UserProgress` including `content_id`, `study_mode`, `last_position`, `is_synced`, `metadata`, and a synthetic non-UUID primary key. `ProgressNotifier.startLesson` filters on an absent remote `study_mode`.
5. `lib/models/user_progress.dart` and `lib/models/lesson_progress.dart` duplicate the same `UserProgress` and `StudyMode` definitions. ANA-001B must consolidate them without breaking Hive deserialization.
6. `offline_provider.syncProgress` merges by learner + lesson + local day, then upserts without a conflict target; this can collide with `UNIQUE(user_id,lesson_id,date)` or overwrite accumulated totals after retries.
7. `CourseService.getCourseProgress` does genuine database reads and inserts, whereas `ProgressService` uses mock data. ANA-002, not this storage ADR, owns the production mock replacement.
8. The hosted `user_progress` table contains zero rows at the snapshot; no legacy rows need migration today, but local Hive records and additional learning/assessment sources still require inventory before cutover.

## Chosen logical contract (ANA-001B must validate with a concrete migration)

### Authoritative event ledger

Propose `private.learner_progress_events` (or another unexposed schema), written **only** by a vetted server-side `public.record_learner_progress(jsonb[])` RPC:

- `user_id` is always server-derived `auth.uid()`, FK to `auth.users(id)`. Client `user_id`, payment status, admin role, and verified assessment scores are ignored.
- Each event has immutable `event_id` / `idempotency_key`, user+key uniqueness, canonical payload digest, server receipt timestamp, and bounded accepted client timestamp.
- Event kinds distinguish `lesson_completed` from `active_study_interval`. Completion is a learner progress action; it is **not** a verified assessment outcome.
- A retry with the same event/key/digest is a no-op; with a mismatched digest it is rejected. Do not add duration twice when the same request is replayed.
- Preserve course/lesson provenance and version, with a non-null `version_key` (explicit sentinel for legacy unversioned content). Null unique-key components are not acceptable for deduplication.
- Server validates elapsed active intervals and overlap/replay behavior; the product-analytics pipeline remains separate from this progress source of truth.

### Read projection

Propose `public.learner_activity_progress`, with one row per **(`user_id`, `content_kind`, `content_id`, `version_key`, `reporting_date_utc`)**:

- `user_id UUID NOT NULL REFERENCES auth.users(id)`.
- `content_kind TEXT NOT NULL` with an explicit allowlist: initially `legacy_lesson`, `bundled_asset_lesson`, and `curriculum_node_lesson`.
- `content_id TEXT NOT NULL`: UUID string for legacy lessons and exact stable filename ID for bundled assets; never cast arbitrary content IDs to UUID.
- `version_key TEXT NOT NULL` and `reporting_date_utc DATE NOT NULL`; the full five-column key is unique.
- `completed BOOLEAN NOT NULL DEFAULT false`, `active_seconds INTEGER` with `NULL` meaning not measured, and last activity metadata.
- Server projects accepted events transactionally: completion is monotone within a key; unique accepted intervals are merged/deduplicated, not replaced by a stale device's snapshot. Historical corrections use audited event logic.
- An explicit, owner-scoped SELECT RLS policy is needed. No direct browser INSERT/UPDATE/DELETE. Admin metrics use approved aggregate RPCs, not global raw-row reads.

### Day, identity, and guest semantics

- **UTC reporting day** is derived separately from the **learner-local goal day**; a local-day view must use an explicit learner timezone (IANA zone), not silently mix device-local strings with UTC retention definitions.
- Anonymous sign-ins still have `authenticated` role and `auth.uid()`. Keep guest **product telemetry off** by default; that does not mean local learning progress should be lost. Decide guest progress sync/upgrade treatment independently with the privacy and UX owners.
- Offline local records retain local-only IDs and metadata. Use separate, allowlisted remote serializers. Only a confirmed item-level server ACK marks a local event synced; cross-account queues must never mix.
- Learner records must follow documented export/erasure rules, including reidentifiable user-day projections.

## Rejected options

- **Add every missing field to `user_progress`:** does not fix the legacy UUID FK, synthetic non-UUID IDs, replay overwrites, or duplicate model ownership.
- **Store all progress only in `learning_events`:** would contaminate validated learning evidence and potentially the mastery/scheduler trust boundary. It is an assessment/review evidence stream, not a general UI-click or lesson-timer store.
- **Make all progress a single row by `content_id`:** omits user identity, content kind/version and day or attempt grain, causing collisions and invalid reporting.

## Implementation / validation sequence

1. **ANA-001A (this draft):** capture route-ID evidence and check the existing schema; add an intentionally **RED** pgTAP schema-contract test. Do not merge failing tests into `main`.
2. **ANA-001B:** create the reviewed additive schema/RPC migration via repository tooling, consolidate duplicated `UserProgress` models, separate Hive/server JSON contracts, and migrate *all* writers/readers (including `offline_provider`, `ProgressSyncService`, `StudyNotifier`, `toggleLessonCompletion`, and `ProgressNotifier`).
3. Prove local migration-chain and RLS tests with synthetic users, a missing `public.users` profile, legacy UUID and `prog_01_variables`, same-day repeat, two-device replay, non-overlapping/overlapping intervals, sync error and recovery, guest account switch, and UTC-vs-local DST boundaries.
4. Verify `CourseService` course-level math against the new source without altering server-authoritative assessment and FSRS evidence.
5. Run clean and incremental Supabase migrations plus full protected CI. Deploy only via `AGENTS.md`'s guarded owner-controlled path; account for pending CLEP migration drift separately.

## Explicit remaining questions before ANA-001B merge

- Should version grouping use a curriculum publication UUID, asset hash, or an immutable content revision ID? Confirm against active versioned target tables before schema freeze.
- Are completion events reversals allowed? If manual toggle-off must work, use an explicit audited reversal event instead of monotone `false` overwrite.
- For active-time measurement, how does accessibility-safe long reading and hands-free audio prove activity without inflating duration?
- Which existing local Hive records need a one-time migration to new event IDs, and how should they be de-duplicated if previously synced elsewhere?

**This document is a design artifact, not a verified deployed schema or permission to apply production DDL.**
