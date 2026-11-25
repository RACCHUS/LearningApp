# LearningApp Codebase Map

Read **one section**, not the whole file. Each section gives the owner, the contract that must not break, and the tests to run. Line numbers were verified at `06221ed`; if they have drifted, search for the named symbol and fix the section.

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

<!-- map-ref path="lib/screens/library/catalog_source.dart" role="owner" -->
- Owner: `lib/screens/library/catalog_source.dart` (`CatalogSource.shows`); picker `library_sections/category_chips.dart`.
<!-- map-ref path="lib/models/learning_target.dart" role="contract" lines="266-281" -->
- Contract: `LearningTarget.isTrustedPublic` / `sourceLabel`; server mirror is the `targets_read` RLS policy in `supabase/migrations/20261009000005_learning_target_catalog_provenance.sql` (lines 103-110).
<!-- map-ref path="test/screens/library/catalog_source_test.dart" role="test" -->
- Tests: that file, `test/widgets/library_source_filter_test.dart`, `library_create_chooser_test.dart`, `library_v2_test.dart`.
- Trap: the source filter does **not** use `scope_resolver.dart`.

## Learning contexts and scope {#scope}

<!-- map-ref path="lib/services/scope_resolver.dart" role="owner" -->
- Owner: `lib/services/scope_resolver.dart`; provider `lib/providers/scope_resolver_provider.dart`; contexts in `lib/providers/learning_context_provider.dart`; retired lessons: `retired_lesson_context_provider.dart`.
<!-- map-ref path="test/services/scope_resolver_test.dart" role="test" -->
- Tests: `test/services/scope_resolver_test.dart`, `test/services/scope_resolver_rpc_test.dart`, `test/services/learning_context_sync_service_test.dart`, `test/providers/retired_lesson_context_test.dart`.

## TEL Fast strategy and offline CAS sync {#fast}

Protected: CAS conflict semantics, replay idempotency, account separation. Independent review required for changes.

<!-- map-ref path="lib/services/fast_preference_store.dart" role="owner" lines="371-554" -->
- Owner: store/CAS/queue `lib/services/fast_preference_store.dart` (371-554); notifier replay in `learning_strategy_provider.dart` (178-208).
<!-- map-ref path="lib/services/learning_context_sync_service.dart" role="contract" lines="177-226" -->
- Contract: `update_context_fast_preferences` RPC client (`learning_context_sync_service.dart` 177-226); server function in `supabase/migrations/20261111030000_tel_01b_context_fast_preferences.sql` (54-346).
<!-- map-ref path="test/providers/learning_strategy_provider_test.dart" role="test" -->
- Tests: `test/providers/learning_strategy_provider_test.dart`, `supabase/tests/tel_01b_context_fast_preferences_test.sql`.

## Assessment rendering and server grading {#assessment}

Protected: hidden answer keys never reach the client.

<!-- map-ref path="lib/widgets/assessment/assessment_item_renderer.dart" role="owner" lines="245-409" -->
- Owner: `assessment_item_renderer.dart`: answer state, submit and grading (245-409), view wiring (706-818). Views (display only): `assessment_answer_views.dart`.
<!-- map-ref path="lib/services/assessment/assessment_grading_service.dart" role="contract" -->
- Contract: `lib/services/assessment/assessment_grading_service.dart` (server grading for hidden-key items).
<!-- map-ref path="test/widgets/assessment_item_server_grading_test.dart" role="test" -->
- Tests: `assessment_item_server_grading_test.dart`, `assessment_item_renderer_test.dart`, `assessment_item_renderer_exam_mode_test.dart`.

## CLEP simulation {#simulation}

<!-- map-ref path="lib/services/assessment/clep_simulation_service.dart" role="owner" -->
- Owner: `lib/services/assessment/clep_simulation_service.dart`; screen `lib/screens/simulation/simulation_screen.dart`.
<!-- map-ref path="test/services/clep_simulation_service_test.dart" role="test" -->
- Tests: `test/services/clep_simulation_service_test.dart`, `test/widgets/simulation_exam_launch_card_test.dart`. Item privacy and eligibility are enforced in SQL (`*clep_simulation*` migrations); read them for eligibility changes.

## Excel software learning {#excel}

Two Budget rubrics that differ **on purpose**: do not make them identical. Neither awards skills; both return `unverified_checker_only`. Policy: `docs/product/EXCEL_PILOT_SECURITY_RELEASE_GATES.md` (lines 27-35).

<!-- map-ref path="tool/software_learning/excel_budget_total.py" role="owner" -->
- Upload checker (real uploads): `tool/software_learning/excel_budget_total.py` `check_budget_total`. It ignores cached totals and uses server-issued inputs; spec `data/software_learning/excel_budget_total_v1.json`.
<!-- map-ref path="tool/software_learning/pilot_pipeline.py" role="contract" -->
- Its only caller and trust gate: `tool/software_learning/pilot_pipeline.py` `grade_parsed_snapshot` (requires the `xlsx_worker.py` envelope `parsed_unverified`, `can_award_skill` false).
<!-- map-ref path="lib/services/software_learning/software_learning_workbook_evaluator.dart" role="owner" -->
- Browser preview rubric: `SoftwareLearningWorkbookEvaluator` in `lib/services/software_learning/software_learning_workbook_evaluator.dart`. It checks a cached total against fixed demo inputs, via `demo_workbook_reader.dart`. The UI card's trust guard is `_submitWorkbook` in `lib/widgets/software_learning/excel_upload_card.dart` (145-226).
<!-- map-ref path="tool/tests/test_software_learning_excel_checker.py" role="test" -->
- Tests: `tool/tests/test_software_learning_excel_checker.py` (incl. spec parity), `tool/tests/test_excel_pilot_pipeline.py`, `tool/tests/test_xlsx_worker.py`, `test/services/software_learning/demo_workbook_evaluator_test.dart`, `test/widgets/software_learning/excel_upload_card_test.dart` (trust binding).

## Community Q&A {#qa}

<!-- map-ref path="lib/widgets/community/in_context_qa_sheet.dart" role="owner" lines="703-795" -->
- Owner: `in_context_qa_sheet.dart`: review handlers 703-795, build 953. Tabs `qa_sheet/`; dialogs `qa_review_dialogs.dart`.
<!-- map-ref path="lib/widgets/community/qa_audit_log_list.dart" role="owner" -->
- Audit log: `lib/widgets/community/qa_audit_log_list.dart` (shows internal notes: moderator queue only).
<!-- map-ref path="lib/services/community/community_qa_service.dart" role="contract" lines="505-553" -->
- Contract: `reviewQuestion` / `reviewAnswer` RPCs (505-553). Keep question and answer paths separate.
<!-- map-ref path="lib/widgets/community/answer_revisions_dialog.dart" role="owner" -->
- Answer history (`learning.answer_revisions`): `answer_revisions_dialog.dart`; RPCs in migration `20261115050000`. Author and moderators only; never internal notes.
<!-- map-ref path="test/widgets/community/in_context_qa_sheet_test.dart" role="test" -->
- Tests: `in_context_qa_sheet_test.dart`, `qa_audit_log_list_test.dart`, `community_qa_service_test.dart`, `community_answer_revisions_service_test.dart`, pgTAP `community_answer_revisions_test.sql`.

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
- **Server gate is SQL**: each gated RPC calls `if not private.site_feature_enabled('<key>')`. Grep `site_feature_enabled('<key>')` in `supabase/migrations/` for a feature's enforcement points (e.g. `20261113020000_content_refresh_proposals.sql` lines 135, 192). The helper itself is defined in `20261110220000_marketing_feature_control_foundation.sql`. `lib/services/governance/site_feature_service.dart` only fetches snapshots.
<!-- map-ref path="tool/tests/test_verify_feature_registry.py" role="test" -->
- Tests: `tool/tests/test_verify_feature_registry.py` (`python3 tool/verify_feature_registry.py`); the per-feature refused-while-OFF pgTAP is in `supabase/tests/<feature>_test.sql` (e.g. `content_refresh_proposals_test.sql`).

## XP and achievements {#xp}

Gate `learning.xp_achievements` (default OFF). Shown only in Progress §4 and session summaries (`UI_ARCHITECTURE_LOCKED.md` §9).

<!-- map-ref path="supabase/migrations/20261115000000_learning_xp_achievements.sql" role="contract" -->
- Contract: `claim_activity_xp` (server fixes amounts and limits) and `private.evaluate_user_achievements` in that migration.
<!-- map-ref path="lib/services/xp_service.dart" role="owner" -->
- Owner: `xp_service.dart`; gate + `ActivityXpRecorder` in `xp_achievements_provider.dart`; `models/achievement.dart` mirrors the SQL CHECK.
- UI: `motivation_xp_rows.dart`; claims fire from `ReviewSessionNotifier` and `LessonScreen._onLessonComplete`.
<!-- map-ref path="supabase/tests/learning_xp_achievements_test.sql" role="test" -->
- Tests: that pgTAP file, `test/services/xp_service_test.dart`, `test/widgets/progress/`.
- Trap: `record_xp_award` is service-role only; browsers must never call it.

## Study reminders (web push) {#reminders}

Gate `learning.study_reminders` (default OFF). Owner setup: `docs/deployment/STUDY_REMINDERS_WEB_PUSH.md`.

<!-- map-ref path="supabase/migrations/20261115010000_study_reminders_web_push.sql" role="contract" -->
- Contract: gated save/register RPCs and service-role `claim_due_study_reminders` / `record_push_delivery`. Legacy `public.reminders` is unused.
<!-- map-ref path="lib/screens/settings/study_reminders_screen.dart" role="owner" -->
- Owner: that screen; data in `study_reminder_service.dart`; interop `notifications/web_push_web.dart`; handler `web/push_sw.js`; sender `supabase/functions/send-study-reminders/`.
<!-- map-ref path="supabase/tests/study_reminders_web_push_test.sql" role="test" -->
- Tests: that pgTAP file, `dispatch_test.ts`, `study_reminders_screen_test.dart`, `study_reminder_service_test.dart`.

## Question scratchpad {#scratchpad}

Gate `learning.scratchpad` (OFF) plus a Settings opt-in. One blank pad per question, nothing stored (§5.6).
<!-- map-ref path="lib/widgets/whiteboard/question_scratchpad.dart" role="owner" -->
- Owner: that file (in `McqScreen`, `AssessmentItemRenderer`); canvas `whiteboard_widget.dart`; gate in `scratchpad_provider.dart`.
<!-- map-ref path="test/widgets/whiteboard/question_scratchpad_test.dart" role="test" -->
- Tests: that file, `settings_scratchpad_switch_test.dart`, `mcq_screen_test.dart`.
- Trap: keep the canvas's eager pan recognizer, or touch strokes scroll the page.

## Progress reinforcement list {#reinforce}

Gate `learning.reinforcement_suggestions` (OFF, read-only): the §5.5 list in Retention.
<!-- map-ref path="lib/services/progress/reinforcement_suggestion_service.dart" role="owner" -->
- Owner: that service; UI `widgets/progress/reinforcement_suggestions_list.dart`; gate and hiding in its provider.
<!-- map-ref path="test/widgets/progress/reinforcement_suggestions_list_test.dart" role="test" -->
- Tests: that file and `reinforcement_suggestion_service_test.dart`.
- Trap: `/review?concepts=` takes review-item ids, not concept ids. No percentages or "mastery" in its copy (§6.1).

## Pre-reader and literacy {#prereader}

<!-- map-ref path="lib/screens/library/library_screen.dart" role="owner" lines="350-351" -->
- Library inserts the grid when `preReaderProvider.enabled` (`library_screen.dart` 107, 350-351).
<!-- map-ref path="lib/widgets/literacy/pre_reader_picture_grid_widget.dart" role="owner" -->
- Grid: `lib/widgets/literacy/pre_reader_picture_grid_widget.dart`: 8 tiles routing to `/milestones?…`, `/domains?…` and `/literacy` (query parsing in `router_provider.dart`). Narration is tap-only and calls `preReaderAudioServiceProvider` directly with the default track.
<!-- map-ref path="lib/providers/pre_reader_provider.dart" role="owner" -->
- State: `lib/providers/pre_reader_provider.dart` (`autoSpeakScreens` persisted, defaults to true in `lib/models/pre_reader_profile.dart`); playback `lib/services/pre_reader_audio_service.dart`.
<!-- map-ref path="lib/screens/literacy/life_milestones_screen.dart" role="owner" lines="40-61" -->
- Auto-speak is consumed by the routed screens (`life_milestones_screen.dart`, `life_domains_screen.dart` 40-60, `foundational_literacy_screen.dart`), not by the grid.
<!-- map-ref path="test/widgets/pre_reader_literacy_test.dart" role="test" -->
- Tests: `test/widgets/phase_5_pwa_ux_test.dart` (grid tiles and speakers), `test/widgets/pre_reader_literacy_test.dart` (auto-speak toggle), `test/services/pre_reader_audio_service_test.dart`.

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
- Owner: `lib/services/taxonomy/taxonomy_crosswalk_service.dart` (offline samples: `taxonomy_crosswalk_fallbacks.dart`); official sources `official_taxonomy_sources.dart`. Read `CANONICAL_TAXONOMY_ARCHITECTURE.md` for taxonomy policy.
<!-- map-ref path="test/services/taxonomy_crosswalk_service_test.dart" role="test" -->
- Tests: `test/services/taxonomy_crosswalk_service_test.dart`, `test/services/official_taxonomy_sources_test.dart`.

## Curriculum ingestion (protected) {#ingestion}

Read to understand; no refactor proposals.

<!-- map-ref path="tool/ingest_curriculum.dart" role="owner" lines="1-56" -->
- Owner: `tool/ingest_curriculum.dart` (pipeline doc 1-56; schema validation 132-149).
<!-- map-ref path="tool/lint_manifest.dart" role="contract" -->
- Contracts: `tool/lint_manifest.dart` (stable item IDs), `content/schema/curriculum_manifest.schema.json`, `tool/ci/check_algebra_manifest_parity.py`.
<!-- map-ref path="test/tool/curriculum_stable_ids_test.dart" role="test" -->
- Tests: `test/tool/curriculum_stable_ids_test.dart`, `test/services/curriculum_manifest_test.dart`, `tool/tests/test_check_algebra_manifest_parity.py`. Known gap: REST transport has no direct test.

## Outside-resource companion {#companion}

Gates `content.learner_resources`, `content.companion_capture` (`add_resource_screen.dart`). Plan: `LEARNINGAPP_EXTERNAL_RESOURCE_COMPANION_PLAN_V1_0_2026-11-25.md`. "Studied" is self-report, never readiness.
<!-- map-ref path="lib/screens/companion/learner_resource_screen.dart" role="owner" -->
- Owner: that screen; gaps `goal_gaps_screen.dart` (model `goal_coverage.dart`); outline `resource_outline_screen.dart` + `outline_mapper.dart`; steps `companion_screen.dart`; card `learner_resources_card.dart`; `outside_study_widgets.dart`; storage `learner_resource_store.dart`; bundled: `learning_support/`.
<!-- map-ref path="supabase/migrations/20261125030000_learner_external_resources.sql" role="contract" -->
- Contract: gated write RPCs there, `…050000` (outline), `…060000` (progress); catalog checker `tool/verify_external_resources.py`.
<!-- map-ref path="supabase/tests/learner_external_resources_test.sql" role="test" -->
- Tests: that pgTAP file and `learner_resource_sections_test.sql` (isolation), `test/widgets/learner_resources_flow_test.dart`, `resource_outline_flow_test.dart`, `companion_flow_test.dart`.

## Database and deployment (protected) {#database}

<!-- map-ref path="tool/guarded_supabase_deploy.dart" role="owner" -->
- Deploy only via `tool/guarded_supabase_deploy.dart` (`AGENTS.md`). Migrations are append-only; never repair versions.
<!-- map-ref path="test/services/governance/guarded_supabase_deploy_test.dart" role="test" -->
- Tests: `test/services/governance/guarded_supabase_deploy_test.dart`, `supabase/tests/` (pgTAP, `verify-database` job).

## CI and test policy {#ci}

<!-- map-ref path="docs/testing/TEST_QUALITY_POLICY.md" role="policy" -->
- Policy: `docs/testing/TEST_QUALITY_POLICY.md`. Required check `Analyze, test, and build` (gate job in `.github/workflows/flutter-ci.yml`); never rename it.
<!-- map-ref path="tool/tests/test_check_required_results.py" role="test" -->
- Tests: `tool/tests/test_check_required_results.py` (fail-closed gate), `tool/tests/test_check_test_inventory.py` (every suite runs in CI).
- This map is checked by `tool/verify_codebase_map.py` (paths and line ranges only, advisory `early-feedback` job). It cannot tell whether an owner is still the owner: update the section when you move one.

## Device-local avatar {#avatar}

Browser-only, per account; nothing uploaded. Gate `learning.avatar_customizer` (OFF).
<!-- map-ref path="lib/providers/device_avatar_provider.dart" role="owner" -->
- Gate and user-scoped lifecycle: `lib/providers/device_avatar_provider.dart`.
<!-- map-ref path="lib/services/avatar/avatar_persistence_service.dart" role="contract" -->
- Persistence: `lib/services/avatar/avatar_persistence_service.dart` (never the legacy unscoped key for accounts).
<!-- map-ref path="lib/widgets/avatar/avatar_customizer_sheet.dart" role="owner" -->
- Editor: `lib/widgets/avatar/avatar_customizer_sheet.dart`; entry point `lib/screens/profile_screen.dart`, header preview `lib/widgets/account_actions.dart`.
<!-- map-ref path="test/services/avatar/avatar_persistence_service_test.dart" role="test" -->
- Tests: that service's test, `profile_display_name_test.dart`, `account_header_test.dart`.
