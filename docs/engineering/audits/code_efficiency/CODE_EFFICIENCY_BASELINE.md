# Code Efficiency Baseline — Phase 0 (in progress)

**Plan:** `LearningApp_Codebase_Simplification_AI_Context_Optimization_Plan_v0_5.md` (v0.6 content).
**Pin:** `06221ed6f9ef617113f76d0ddd072c20a0042250`, committer time 2026-11-14T14:54:13Z (PR #270 merge).
**Branch:** `chore/code-efficiency-audit-baseline` (evidence only).
**Tooling:** git 2.x (exact version in `data/inventory.json`), Python 3.13.4; `scripts/phase0_inventory.py`.
**Byte source:** Git blob sizes at the pin. Working-tree sizes are not used (`core.autocrlf=true`).
**Status:** inventory, top-25, churn, instruction surface and the **T1–T9 deterministic MVCS baseline measured** (see `AI_CONTEXT_BENCHMARK.md`). Clone scan, dead-code candidate scan, Phase 1 drafts and the map-condition score are done. Second-reviewer check of T3/T7 and owner decisions pending. Zero live-model calls.

## 1. Re-pin delta

| From | To | Result |
|---|---|---|
| `a458b41` (historical v0.3/v0.4) | `06221ed` | 145 files changed, +15,177 / −2,766 |
| `1e67576` (v0.5 review) | `06221ed` | 67 commits |

Largest relevant changes since v0.5: CI/test-quality PR-1..PR-9 merged (required check is now the `Analyze, test, and build` gate job); PR-H community slices; PR-C generation slices; scope-resolver and sync test coverage; action SHA pinning.

## 2. Inventory at the pin

| Measure | Value |
|---|---:|
| Git tree entries (files + dirs) | 1,995 |
| Dart files (all) | 1,162 |
| Dart files / bytes in `lib/` | 697 / 6,284,136 |
| Dart files in `test/` | 389 |
| Python files (all in `tool/`) | 141 |
| Root Markdown | 14 files / 1,282,238 B |

`lib/` + `tool/` by class (files / bytes):

| Class | Files | Bytes |
|---|---:|---:|
| authored-application | 681 | 6,038,640 |
| authored-support-tool | 81 | 611,150 |
| curriculum-as-code | 21 | 768,851 |
| protected-operations | 12 | 275,667 |
| data-in-lib | 5 | 143,008 |
| test (`tool/tests`) | 63 | 396,983 |
| generated | 9 | 27,610 |
| documentation | 2 | 13,886 |

Classification rules are code in `scripts/phase0_inventory.py` (`classify`). `lib/models/overview_outline.dart` is **provisionally** `data-in-lib` pending manual review.

## 3. Top-25 by size (lib/ + tool/)

Full table: `data/top25_size.csv`. Changes versus the v0.5 published list:

- **Entered:** `tool/tests/clep_algebra_oracles.py` (#9, 47,046 B, `test`).
- **Left:** `tool/ingest_official_taxonomies.dart` (33,144 B; still denylisted).
- **Grew:** `tool/ingest_curriculum.dart` 55,727 → 59,126 B; algebra domain generators +1.1–1.3 KB each; `library_screen.dart` 50,485 → 50,609 B.
- **Shrank:** `scope_resolver.dart` 37,076 → 36,840 B.
- Unchanged: `in_context_qa_sheet.dart` 100,717 B (#1), `excel_upload_card.dart` 45,008 B, `assessment_item_renderer.dart` 49,617 B.

Of the 25: 10 authored-application, 9 curriculum-as-code, 2 protected-operations, 3 data-in-lib, 1 test.

## 4. Churn ranking (frozen §2.4 method)

Window 2026-08-16T14:54:13Z → 2026-11-14T14:54:13Z; `git log <pin> --no-merges --follow --numstat` per path; 755 eligible authored files, 621 with any churn. Full table: `data/churn_eligible.csv`.

| Rank | Path | Commits | ± lines |
|---:|---|---:|---:|
| 1 | `lib/providers/router_provider.dart` | 31 | 3,091 |
| 2 | `lib/screens/library/library_screen.dart` | 19 | 2,024 |
| 3 | `lib/widgets/community/in_context_qa_sheet.dart` | 14 | 3,841 |
| 4 | `lib/services/learning_target_service.dart` | 14 | 665 |
| 5 | `lib/providers/next_action_provider.dart` | 13 | 2,560 |
| 8 | `lib/services/scope_resolver.dart` | 11 | 1,324 |
| 11 | `lib/widgets/assessment/assessment_item_renderer.dart` | 9 | 3,480 |
| 17 | `lib/screens/lessons/guided_generation_screen.dart` | 8 | 4,666 |

**Finding (verified, not a refactor proposal):** `router_provider.dart` is the highest-churn file and is absent from the v0.5 candidate lists. It owns navigation (and T9's question). Treat it as a **codebase-map priority**. Size × churn overlap confirms Library and Q&A as the busiest large files; Excel (`excel_upload_card.dart`) is not in the top 25 by churn.

## 5. Instruction surface (separate baseline cost)

| File | Bytes | Lines |
|---|---:|---:|
| `AGENTS.md` | 7,263 | 90 |
| `.github/agents/lesson-generator.agent.md` | 4,653 | 106 |
| `.github/pull_request_template.md` | 1,987 | 29 |
| `.agents/rules/mcp-tooling.md` | 1,409 | 20 |
| `.github/instructions/Main.instructions.md` (`applyTo: '**'`) | 1,138 | 12 |
| `.github/prompts/generate-lesson.prompt.md` | 384 | 11 |
| **Total** | **16,834** | 268 |

Which files a given agent auto-loads is **not measured**; the total is a ceiling, not observed load. The 400-line / 50-line triggers are still present at `Main.instructions.md:7-8`.

## 6. Housekeeping (evidence only, no edits)

Both zero-byte files remain zero bytes at the pin: `lib/services/audio_lesson/audio_lesson_controller.dart`, `lib/widgets/progress/recent_activity_list.dart`. No other empty blob exists under `lib/`, `tool/` or `test/`. Z.ai's history evidence is carried forward unchanged; no deletion proposed.

## 7. Task freeze (frozen 2026-11-14, T1–T9)

T9 was approved by the owner before measurement. Frozen manifest: `data/task_manifest.json`; results and findings: `AI_CONTEXT_BENCHMARK.md`. Probes corrected at freeze: T1, T3, T8, T9 (false owners) and T7 (missing auto-speak consumer). Notes made during preparation:

- **T6:** candidate tests confirmed. `test/tool/curriculum_stable_ids_test.dart` imports `tool/ingest_curriculum.dart` and `tool/lint_manifest.dart`; `test/services/curriculum_manifest_test.dart` imports `tool/lint_manifest.dart`; both run in the full `flutter test` step of the `verify` job. `tool/tests/test_check_algebra_manifest_parity.py` and `tool/ci/check_algebra_manifest_parity.py` run in `verify` (`flutter-ci.yml:298-299`). Coverage of the ingestion transport path itself is not established.
- **T7:** call path confirmed: `library_screen.dart:446` renders `PreReaderPictureGridWidget` when `preReaderProvider.enabled`; `pre_reader_provider.dart` imports `pre_reader_audio_service.dart`. Corrected task text stands.
- **T9:** approved and measured; owner is `lib/widgets/app_shell.dart`, rule at `UI_ARCHITECTURE_LOCKED.md:108,231,875`.

## 8. Clone candidates (bounded scan)

`scripts/clone_scan.py`, window 8 normalised logical lines (blank, comment, import and lone-brace lines dropped), authored-application + authored-support-tool only (755 files, 129,461 logical lines). **607 candidate runs; 6,369 logical lines (4.9%) in any run — unconfirmed.** Raw: `data/clone_candidates.json`. Manual review of the largest clusters:

| Cluster | Size | Status | Decision |
|---|---:|---|---|
| `widgets/shimmer_loading.dart:418-666` copies `widgets/empty_state.dart:116-381` (illustration painter) | ~249 lines | **Verified**: 23 differing diff lines, comments and class name only | Duplicate; its only consumer is unimported (§9). Housekeeping candidate |
| `tool/catalog_p2{i,j,k,l}_*_pathways.py` (URL validation, label logic, SQL render) | 25–52 lines × 4 | **Verified** repeated structure | Keep separate for now: each is a reviewed one-batch import with its own test; extract a helper only if more batches follow |
| `in_context_qa_sheet.dart` question vs answer card subviews (1578/1699, 1624/1748, 1878/2006) | 21–33 lines | Candidate | Pilot A territory; held |
| `life_domains_screen.dart` vs `life_milestones_screen.dart` app bar | 31 lines | Candidate | Low value |
| `question_content_renderer.dart` vs `lesson_content_renderer.dart` state setup | 22–24 lines | Candidate, semantics not inspected | Inspect before any action |
| `audio_playback_provider.dart` vs `audio_provider.dart` speak wrappers | 20 lines | Candidate, semantics not inspected | Two providers wrap one `AudioService`; check for competing implementations |
| `scope_resolver.dart:395-422` vs `528-555` | 23 lines | Candidate | Scope/privacy logic; keep unless tests prove equivalence |

## 9. Dead-code candidates (evidence only)

36 `lib/` Dart files (242,023 B) are named by **no** import/export/part URI (including conditional-import alternatives) in any tracked Dart file, tests included: `data/unimported_lib_files.json`. Dart has no reflection-based loading, so these are unreachable from `lib/main.dart` unless built by another entry point; files imported only by other candidates are not counted, so the true set may be larger. Notable: `screens/careers/` (4 files, 48.8 KB), `screens/home/home_lessons_list.dart` and `home_study_sets_section.dart`, `widgets/dashboard_skill_widgets.dart` (23 KB), `widgets/desktop_sidebar.dart`, `widgets/whiteboard/whiteboard_widget.dart`, `screens/test/notification_test_screen.dart`, and both empty files. **No deletion proposed.** Per the legacy-parity rule each needs a capability check (is there a replacement?) and owner approval.

## 10. Next steps

1. Second-reviewer check of the T3 and T7 ranges and of the map scoring (human or independent reviewer).
2. Owner decision on Phase 1 drafts in `docs/engineering/drafts/code_efficiency/` (map, `AGENTS.md` and `Main.instructions.md` diffs, validator design, PR-template checkbox).
3. Owner decision on the stop recommendation (`AI_CONTEXT_BENCHMARK.md` §6) and on the housekeeping/test follow-ups.
