# LearningApp Codebase Map (DRAFT — not active)

Status: Phase 1 draft for owner review. Proposed home on acceptance: `docs/engineering/CODEBASE_MAP.md`.
Pinned to `06221ed`. Read **one section**, not the whole file. Each section gives the owner, the contract that must not break, and the tests to run.
Machine-checked references are the `map-ref` comments only (grammar: `drafts/code_efficiency/VERIFY_CODEBASE_MAP_DESIGN.md`). Prose paths are not checked.

## How to use

1. Find the feature below. Open the owner at the listed lines, not the whole file.
2. Read the contract before editing. Run the listed tests plus `flutter analyze`.
3. Large root plans, `supabase/migrations/`, `content/`, `data/` and generated files are **not** default reading. Open them only when a section points to them or the task is in that domain.
4. If you move or rename an owner, update its section in the same PR.

## Navigation shell and destinations {#nav}

Three destinations (Learn, Library, Progress). Routes live in the router; the buttons live in `AppShell`.

<!-- map-ref path="lib/widgets/app_shell.dart" role="owner" lines="128-192" -->
- Owner: `lib/widgets/app_shell.dart` — NavigationRail (≥900dp) and NavigationBar destinations.
<!-- map-ref path="lib/providers/router_provider.dart" role="owner" -->
- Routes: `lib/providers/router_provider.dart` — GoRouter; `ShellRoute` wraps pages in `AppShell`. Not the place for destination UI.
<!-- map-ref path="UI_ARCHITECTURE_LOCKED.md" role="policy" lines="231-231" -->
- Rule: no badge/dot/count on a top-level destination; counts inside Library/Progress are fine (`UI_ARCHITECTURE_LOCKED.md` B3, lines 108, 231, 875).
<!-- map-ref path="test/widgets/direct_access_rule_test.dart" role="test" -->
- Tests: `test/widgets/direct_access_rule_test.dart` (ship gates incl. "no nav destination shows a badge"), `test/widgets/app_shell_sidebar_test.dart`.

## Learn and Next Action {#learn}

<!-- map-ref path="lib/screens/learn/learn_screen.dart" role="owner" -->
- Owner: `lib/screens/learn/learn_screen.dart`.
<!-- map-ref path="lib/services/next_action_engine.dart" role="contract" -->
- Contract: `lib/services/next_action_engine.dart` (content-neutral ranking), wired by `lib/providers/next_action_provider.dart`.
<!-- map-ref path="test/services/next_action_engine_test.dart" role="test" -->
- Tests: `test/services/next_action_engine_test.dart`, `test/providers/next_action_provider_test.dart`, `test/widgets/direct_access_rule_test.dart`.

## Library catalog and source filter {#library}

<!-- map-ref path="lib/screens/library/library_screen.dart" role="owner" lines="43-61" -->
- Owner: `lib/screens/library/library_screen.dart` — `_CatalogSource` (lines 43-61), source decision (145-162), picker (415-441).
<!-- map-ref path="lib/models/learning_target.dart" role="contract" lines="266-281" -->
- Contract: `LearningTarget.isTrustedPublic` / `sourceLabel`; server mirror is the `targets_read` RLS policy in `supabase/migrations/20261009000005_learning_target_catalog_provenance.sql` (lines 103-110).
<!-- map-ref path="test/widgets/library_create_chooser_test.dart" role="test" -->
- Tests: `test/widgets/library_create_chooser_test.dart`, `test/widgets/create_target_suggestions_test.dart`, `test/widgets/library_v2_test.dart`.
- Trap: the source filter does **not** use `scope_resolver.dart`. Known gap: no test checks what each source value shows.

## Learning contexts and scope {#scope}

<!-- map-ref path="lib/services/scope_resolver.dart" role="owner" -->
- Owner: `lib/services/scope_resolver.dart`; provider `lib/providers/scope_resolver_provider.dart`; contexts in `lib/providers/learning_context_provider.dart`.
<!-- map-ref path="test/services/scope_resolver_test.dart" role="test" -->
- Tests: `test/services/scope_resolver_test.dart`, `test/services/scope_resolver_rpc_test.dart`, `test/services/learning_context_sync_service_test.dart`.

## TEL Fast strategy and offline CAS sync {#fast}

Protected: CAS conflict semantics, replay idempotency, account separation. Independent review required for changes.

<!-- map-ref path="lib/providers/learning_strategy_provider.dart" role="owner" lines="376-559" -->
- Owner: `lib/providers/learning_strategy_provider.dart` — store/CAS/queue (376-559), notifier replay (815-845).
<!-- map-ref path="lib/services/learning_context_sync_service.dart" role="contract" lines="177-226" -->
- Contract: `update_context_fast_preferences` RPC client (`learning_context_sync_service.dart` 177-226); server function in `supabase/migrations/20261111030000_tel_01b_context_fast_preferences.sql` (54-346).
<!-- map-ref path="test/providers/learning_strategy_provider_test.dart" role="test" -->
- Tests: `test/providers/learning_strategy_provider_test.dart`, `supabase/tests/tel_01b_context_fast_preferences_test.sql`.

## Assessment rendering and server grading {#assessment}

Protected: hidden answer keys never reach the client.

<!-- map-ref path="lib/widgets/assessment/assessment_item_renderer.dart" role="owner" lines="702-863" -->
- Owner: `lib/widgets/assessment/assessment_item_renderer.dart` — interaction dispatch and single choice (702-863); submit/grade path (242-310).
<!-- map-ref path="lib/services/assessment/assessment_grading_service.dart" role="contract" -->
- Contract: `lib/services/assessment/assessment_grading_service.dart` (server grading for hidden-key items).
<!-- map-ref path="test/widgets/assessment_item_server_grading_test.dart" role="test" -->
- Tests: `test/widgets/assessment_item_server_grading_test.dart`, `test/widgets/assessment_item_renderer_test.dart`.

## CLEP simulation {#simulation}

<!-- map-ref path="lib/services/assessment/clep_simulation_service.dart" role="owner" -->
- Owner: `lib/services/assessment/clep_simulation_service.dart`; screen `lib/screens/simulation/simulation_screen.dart`.
<!-- map-ref path="test/services/clep_simulation_service_test.dart" role="test" -->
- Tests: `test/services/clep_simulation_service_test.dart`, `test/widgets/simulation_exam_launch_card_test.dart`. Item privacy and eligibility are enforced in SQL (`*clep_simulation*` migrations); read them for eligibility changes.

## Excel software learning {#excel}

Two rubric copies with different trust: change both together.

<!-- map-ref path="tool/software_learning/excel_budget_total.py" role="owner" -->
- Authoritative rubric: `tool/software_learning/excel_budget_total.py` (isolated worker; `xlsx_worker.py`, sealed upload `brokered_upload.py`).
<!-- map-ref path="lib/widgets/software_learning/excel_upload_card.dart" role="owner" lines="13-294" -->
- Client unverified checker: `SoftwareLearningWorkbookEvaluator` in `lib/widgets/software_learning/excel_upload_card.dart` (13-294); result must stay `unverified_checker_only`.
<!-- map-ref path="lib/services/software_learning/demo_workbook_reader.dart" role="contract" -->
- Contract: `lib/services/software_learning/demo_workbook_reader.dart` is a restricted **preview** reader, never authoritative.
<!-- map-ref path="tool/tests/test_software_learning_excel_checker.py" role="test" -->
- Tests: `tool/tests/test_software_learning_excel_checker.py`, `tool/tests/test_xlsx_worker.py`, `tool/tests/test_brokered_upload.py`, `test/services/software_learning/demo_workbook_evaluator_test.dart`. Known gap: no test checks the two rubrics agree.

## Community Q&A {#qa}

<!-- map-ref path="lib/widgets/community/in_context_qa_sheet.dart" role="owner" lines="766-858" -->
- Owner: `lib/widgets/community/in_context_qa_sheet.dart` — moderation review handlers (766-858); main build from line 1005; dialogs at 2298 and 2386.
<!-- map-ref path="lib/services/community/community_qa_service.dart" role="contract" lines="504-552" -->
- Contract: `reviewQuestion` / `reviewAnswer` RPCs (`community_qa_service.dart` 504-552). Keep question and answer paths separate.
<!-- map-ref path="test/widgets/community/in_context_qa_sheet_test.dart" role="test" -->
- Tests: `test/widgets/community/in_context_qa_sheet_test.dart`, `test/services/community/community_qa_service_test.dart`.

## Community lessons and refresh proposals {#contributions}

<!-- map-ref path="lib/services/community/lesson_contribution_service.dart" role="owner" -->
- Owner: `lib/services/community/lesson_contribution_service.dart`; gates in `lib/providers/lesson_contribution_provider.dart`; review UI `lib/screens/governance/contribution_review_screen.dart`.
<!-- map-ref path="test/widgets/refresh_proposals_test.dart" role="test" -->
- Tests: `test/widgets/refresh_proposals_test.dart`, `test/widgets/contribution_review_screen_test.dart`, `supabase/tests/content_refresh_proposals_test.sql`.

## Feature controls {#flags}

<!-- map-ref path="AGENTS.md" role="policy" lines="83-90" -->
- Policy: `AGENTS.md` FLAG-010/016 (BYOK hard-off latch; TEL Fast stays Experimental).
<!-- map-ref path="lib/models/governance/site_feature_keys.dart" role="owner" -->
- Keys: `lib/models/governance/site_feature_keys.dart`; client check `isSiteFeatureEnabled` in `lib/providers/site_feature_provider.dart`.
- **Server gate is SQL**: `private.site_feature_enabled(...)` called inside each RPC (defined in `supabase/migrations/20261110220000_marketing_feature_control_foundation.sql`); grep the feature key in `supabase/migrations/` to find its gates. `lib/services/governance/site_feature_service.dart` only fetches snapshots.
<!-- map-ref path="tool/tests/test_verify_feature_registry.py" role="test" -->
- Tests: `tool/tests/test_verify_feature_registry.py` (`python3 tool/verify_feature_registry.py`), per-feature pgTAP in `supabase/tests/`.

## Pre-reader and literacy {#prereader}

<!-- map-ref path="lib/widgets/literacy/pre_reader_picture_grid_widget.dart" role="owner" -->
- Library entry: `lib/widgets/literacy/pre_reader_picture_grid_widget.dart` (tap-only narration; tiles route to `/milestones`, `/domains`).
<!-- map-ref path="lib/providers/pre_reader_provider.dart" role="owner" -->
- State: `lib/providers/pre_reader_provider.dart` (`autoSpeakScreens` persisted); playback `lib/services/pre_reader_audio_service.dart`.
<!-- map-ref path="lib/screens/literacy/life_milestones_screen.dart" role="owner" lines="40-61" -->
- Auto-speak is consumed by routed screens (`life_milestones_screen.dart`, `life_domains_screen.dart`, `foundational_literacy_screen.dart`), not by the grid.
<!-- map-ref path="test/widgets/pre_reader_literacy_test.dart" role="test" -->
- Tests: `test/widgets/pre_reader_literacy_test.dart`, `test/services/pre_reader_audio_service_test.dart`, `test/widgets/pre_reader_home_navigation_test.dart`.

## Help {#help}

<!-- map-ref path="lib/widgets/help/help_center_sheet.dart" role="owner" -->
- Owner: `lib/widgets/help/help_center_sheet.dart`; search `lib/services/help_search_service.dart`. Help must stay reachable top-right and never carries a badge.
<!-- map-ref path="test/widgets/help_center_test.dart" role="test" -->
- Tests: `test/widgets/help_center_test.dart`, `test/services/help_search_service_test.dart`.

## Lesson import and generation {#lessons}

<!-- map-ref path="lib/services/lesson/lesson_import_service.dart" role="owner" -->
- Import: `lib/services/lesson/lesson_import_service.dart`. Guided generation: `lib/screens/lessons/guided_generation_screen.dart` (session recovery).
<!-- map-ref path="test/services/lesson_import_service_test.dart" role="test" -->
- Tests: `test/services/lesson_import_service_test.dart`, `test/integration/lesson_import_local_supabase_test.dart` (database job), `test/widgets/guided_session_recovery_test.dart`.

## Auth {#auth}

<!-- map-ref path="lib/providers/auth_provider.dart" role="owner" -->
- Owner: `lib/providers/auth_provider.dart` (`AuthNotifier`).
<!-- map-ref path="test/providers/auth_notifier_test.dart" role="test" -->
- Tests: `test/providers/auth_notifier_test.dart`, `test/auth_provider_test.dart`. RLS changes need independent review.

## Product analytics and privacy {#analytics}

<!-- map-ref path="lib/services/analytics/product_analytics_privacy_service.dart" role="owner" -->
- Consent/erasure: `lib/services/analytics/product_analytics_privacy_service.dart`; events `product_analytics_service.dart`, outbox `product_event_outbox.dart`.
<!-- map-ref path="test/services/product_analytics_privacy_service_test.dart" role="test" -->
- Tests: `test/services/product_analytics_privacy_service_test.dart`, `test/widgets/product_analytics_privacy_screen_test.dart`.

## Taxonomy {#taxonomy}

<!-- map-ref path="lib/services/taxonomy/taxonomy_crosswalk_service.dart" role="owner" -->
- Owner: `lib/services/taxonomy/taxonomy_crosswalk_service.dart`; official sources (data) `lib/services/taxonomy/official_taxonomy_sources.dart`. Read `CANONICAL_TAXONOMY_ARCHITECTURE.md` for taxonomy policy.
<!-- map-ref path="test/services/taxonomy_crosswalk_service_test.dart" role="test" -->
- Tests: `test/services/taxonomy_crosswalk_service_test.dart`, `test/services/official_taxonomy_sources_test.dart`.

## Curriculum ingestion (protected) {#ingestion}

Read to understand; no refactor proposals.

<!-- map-ref path="tool/ingest_curriculum.dart" role="owner" lines="1-56" -->
- Owner: `tool/ingest_curriculum.dart` (pipeline doc 1-56; schema validation 128-145).
<!-- map-ref path="tool/lint_manifest.dart" role="contract" -->
- Contracts: `tool/lint_manifest.dart` (stable item IDs), `content/schema/curriculum_manifest.schema.json`, `tool/ci/check_algebra_manifest_parity.py`.
<!-- map-ref path="test/tool/curriculum_stable_ids_test.dart" role="test" -->
- Tests: `test/tool/curriculum_stable_ids_test.dart`, `test/services/curriculum_manifest_test.dart`, `tool/tests/test_check_algebra_manifest_parity.py`. Known gap: REST transport has no direct test.

## Database and deployment (protected) {#database}

<!-- map-ref path="tool/guarded_supabase_deploy.dart" role="owner" -->
- Deploy only via `tool/guarded_supabase_deploy.dart` (`AGENTS.md`). Migrations are append-only; never repair versions.
<!-- map-ref path="test/services/governance/guarded_supabase_deploy_test.dart" role="test" -->
- Tests: `test/services/governance/guarded_supabase_deploy_test.dart`, `supabase/tests/` (pgTAP, `verify-database` job).

## CI and test policy {#ci}

<!-- map-ref path="docs/testing/TEST_QUALITY_POLICY.md" role="policy" -->
- Policy: `docs/testing/TEST_QUALITY_POLICY.md`. Required check `Analyze, test, and build` (gate job in `.github/workflows/flutter-ci.yml`); never rename it.
