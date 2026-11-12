# 00 — Baseline and Compatibility Audit (P0)

Deliverable for master plan v2.6 §16 **P0.1** (`LEARNINGAPP_CONTENT_INTELLIGENCE_AND_GAP_RESCUE_MASTER_PLAN_V2_6_2026-11-11.md`).
The plan requires **P0-light** (repository/source) and **P0-hosted** (live database, deployment and GitHub settings) sections to be labeled separately. This revision completes **P0-light only**. Every hosted fact is marked **UNKNOWN — not verified** until someone with authorized access produces fresh evidence.

| Field | Value |
|---|---|
| Audit date | 2026-11-12 |
| Repository baseline | `main` @ `b748d552abe16872b3836ebc907d0da981ac64cf` (PR #225, 2026-11-11 22:43 −05:00) |
| Method | Read-only source inspection of the checked-out repository, plus local `flutter analyze` / `flutter test` runs on the PR-0a/PR-0b branches |
| Not performed | No hosted database query, no Supabase CLI against production, no deployment, no migration repair, no GitHub branch-protection/ruleset read |
| Related open PRs | PR-0a answer/scoring integrity (#226); PR-0b creation-path compatibility (#227, stacked on #226) |

---

## Part A — P0-light (source and contract audit)

### A.1 Five source dialects and their status

| Dialect | Producer | Shape at baseline | Status at baseline | After #226/#227 |
|---|---|---|---|---|
| **P** flat personal | Hand-written / exported JSON → `LessonImportService` | top-level `title`, `terms`, `concepts`, `questions[]`, integer `correct_answer` | Imports, but `int.tryParse(...) ?? 0` invents answer A; invalid items dropped silently | Whole-payload preflight, per-item errors, no invented key |
| **G** guided assembled | `GenerationSession.assemble()` | P plus `_needs_review` / `_review_reason` | Unmatched text → `correct_answer: 0`; substring matching (`"10"` matched `"100%"`); Import still enabled | Unique exact match only; `_answer_error` blocks Import |
| **C** curriculum manifest | `content/**` → `tool/ingest_curriculum.dart` → privileged RPC | target/version/domains, `scoring_spec.correct_index` | Separate privileged path; dry-run validator bounds-checks; intermediate export used `?? 0` | Intermediate export refuses guesses; personal importer refuses manifests (`privileged_manifest`) |
| **B** Builder / JSON Import | `LessonBuilderWidget`, `EnhancedJsonImportWidget` | `{lesson:{title,…}, content:[…]}`, integer `correctIndex` | **Broken**: importer reads top-level `title` → "Lesson title is required" | Normalized to P by `LessonDialectNormalizer` |
| **Q** Quick Generate | `AiPromptService.generateLessonCreationPrompt` response | `{lesson, content}`, term `title`/`content`, MCQ **text** `correct_answer` | **Broken**: validator requires `correctIndex`; importer requires top-level `title` | Normalized; text resolved by unique exact match |

Fields that personal lessons cannot store (`estimated_duration_minutes`, `difficulty_level`, per-item `emoji`/`tags`) are now reported as **not saved** in the import preview. Persisting them would need a schema decision (see A.8), which is out of scope for this zero-SQL work.

### A.2 Answer-key default inventory (`?? 0` and equivalents)

| Location | Kind | Status |
|---|---|---|
| `lib/models/generation_session.dart` `_assembleMcqs` / `_resolveCorrectIndex` | writer | Fixed in #226 |
| `lib/services/lesson/lesson_import_service.dart` (both `questions` and `content` paths) | writer | Fixed in #226 |
| `lib/providers/lesson_provider.dart`, `available_lessons_provider.dart`, `services/lesson/content_loading_service.dart`, `lesson_crud_service.dart` | readers | Fixed in #226 (invalid → unscorable sentinel `-1`) |
| `lib/models/question.dart` `Question.fromJson` | model | Fixed in #226 |
| `lib/providers/lesson_editor_provider.dart`, `widgets/editors/question_editor_sheet.dart` | editor | Fixed in #226 |
| `lib/widgets/lesson_builder_widget.dart` (default `0`, blank-option index shift) | editor | Fixed in #227 |
| `lib/services/assessment/short_answer_grader.dart` | scorer | Fixed in #226 |
| `tool/ingest_curriculum.dart` intermediate export | tool | Fixed in #226 |
| **`tool/import_lesson.dart:181`** `q['correct_answer'] ?? q['correctIndex'] ?? 0` | dev tool writer | **OPEN — new finding** |
| **`tool/import_lesson.dart:403`** `raw['correctIndex'] ?? 0` | dev tool writer | **OPEN — new finding** |
| **`lib/services/ai/generated_content_models.dart:66`** `GeneratedAssessmentItem.correctIndex ?? 0` | AI item parser (BYOK path, latch OFF) | **OPEN — new finding**; reachable only with AI generation enabled |
| **`lib/models/community/family_abe_pilot.dart:267`** `DiagnosticQuestion.correctIndex ?? 0` | pilot model | **OPEN — new finding** |
| **SQL** curriculum-ingest RPC: `coalesce((coalesce(correct_answer, correct_index))::int, 0)`; latest redefinition in `20261108140000_clep_simulation_bank_and_item_privacy.sql` (earlier copies in 8 prior migrations) | privileged server writer | **OPEN — requires a new append-only migration** via the guarded deploy after P0-hosted. The client-side dry run rejects missing keys first, but the RPC itself does not. |

Recommendation: a small **PR-0a addendum** for the three Dart items (no SQL). Separately, a reviewed migration that redefines the ingest RPC to raise on a missing or out-of-range key, gated on Part B.

### A.3 Renderer and scorer ownership (personal-lesson questions)

| Renderer | Routed from | Scoring rule after #226 |
|---|---|---|
| `widgets/lesson_content_renderer.dart` → `McqQuestionWidget` / `TrueFalseQuestionWidget` / `ShortAnswerQuestionWidget` | `screens/study/lesson_mode_screen.dart` | Label-based true/false; "not scored" notice for invalid keys |
| `widgets/content_renderers/question_content_renderer.dart` (same child widgets) | `widgets/audio_aware_lesson_renderer.dart` | Same; previously used the **opposite** true/false convention (0 = True) |
| `screens/study/mcq_screen.dart` (uses `Question`) | Study MCQ mode | `selected == correctAnswer` fails closed for `-1`, but shows no "not scored" notice. **Follow-up.** |
| `screens/study/mixed_mode_screen.dart`, `lesson_content_pager.dart`, `audio_enhanced_lesson_screen.dart`, `lesson_mode_dialog.dart` | Convert `Question` → `QuestionContent` | Inherit the reader sentinel; not individually re-tested |
| `screens/study/session_results_screen.dart` | End of session | Bounds-checks both indices (#226) |
| `widgets/assessment/assessment_item_renderer.dart` | `rich_lesson_reader`, adaptive practice, diagnostic, mock exam | **Protected assessment items** — separate server scoring; out of PR-0 scope by design |

### A.4 V1 generation session (local storage)

- Key: SharedPreferences `generation_session_v1`; no `schema_version` field.
- Hard-cast required fields in `GenerationSession.fromJson`: `id` (String), `created_at` (ISO String), `subject`, `target_audience`, `difficulty`, `content_focus` (String), `duration_minutes` (**int**). A wrong type throws.
- Optional: `lesson_plan`, `terms`, `concepts`, `mcqs`, `review_result`. An unknown `current_phase` falls back to `planning`.
- Phases: `planning, generatingTerms, generatingConcepts, generatingMcqs, reviewing, complete`. Batch limits are 8 terms / 4 concepts / 5 MCQs.
- Since #226, an unreadable session is copied raw to `generation_session_v1_unreadable_raw` before anything overwrites it. **PR-A1** still needs to add a version discriminator, recoverable export UI and per-field fixtures.

### A.5 Feature control and AI boundaries

- `SITE_FEATURE_RPC_READY` is a compile-time define (`lib/services/governance/site_feature_service.dart`), default `false`.
- The registry migration `20261110220000_marketing_feature_control_foundation.sql` exists in the repository. Its hosted application status is **UNKNOWN** (see B.1).
- The BYOK release latch (`lib/services/ai/byok_release_gate.dart`) is independently hard-OFF. Nothing in #226/#227 touches it.
- No new feature keys were introduced by PR-0a/PR-0b (correctness repairs to existing capabilities).

### A.6 CI (workflow definitions only)

| Workflow file | Job name |
|---|---|
| `.github/workflows/flutter-ci.yml` | `Analyze, test, and build` (job `verify`) |
| `.github/workflows/flutter-ci.yml` | `Verify clean Supabase migrations and complete official taxonomy ingestion` |
| `.github/workflows/taxonomy-official-data.yml` | `Validate official taxonomy sources` |

Other workflows: analytics guarded preflight/deploy/retention, catalog/taxonomy imports, hosted catalog coverage audit, Supabase keep-alive. `dart format` is **not** enforced by CI. Whether any job is a **required** status check is **UNKNOWN** (B.3).

Local evidence on the PR branches: `flutter analyze` (lib, tool, test) reported no issues. `flutter test`: #226 had 2,576 passed / 4 skipped / 0 failed; #226 + #227 had 2,594 passed / 4 skipped / 0 failed. Hosted CI results are pending on the PRs.

### A.7 Local migration inventory

- 111 migration files; the latest is `20261111030000_tel_01b_context_fast_preferences.sql`.
- The historical ledger `supabase/rehearsal/production_applied_versions.txt` (2026-11-07 snapshot) lists 93 versions.
- **23 local versions are absent from that snapshot**:
  - `20261106030000`, `20261107025537`, `20261107041341`, `20261107045000`, `20261107050000`, `20261107060000`, `20261107100000`, `20261107110000`, `20261108000000`, `20261108140000`
  - `20261110000000`, `20261110150000`, `20261110170000`, `20261110180000`, `20261110190000`, `20261110200000`, `20261110210000`, `20261110220000`, `20261110230000`
  - `20261111000000`, `20261111010000`, `20261111020000`, `20261111030000`

  Some may have been applied after the snapshot; the 2026-11-10 guarded preflight (run `42892752312`) is the newer evidence. **No conclusion about what production currently has is drawn here.**

### A.8 Logical-to-physical storage

PR-0a, PR-0b and the planned PR-A1/A2/A3 are **zero-SQL**. No new table, column or RLS policy is proposed in this revision. The plan's reuse/view/JSONB/extend/new comparison is therefore deferred to the first PR that actually proposes storage (earliest: PR-B or the lesson-metadata fields in A.1), and must be completed with Part B evidence before that PR.

### A.9 Owner decisions and release blockers

| # | Item | Needed from |
|---|---|---|
| 1 | Approve/merge #226 then #227 (retarget #227 to `main` after #226) | Owner review + CI |
| 2 | PR-0a addendum for the three open Dart defaults (A.2) | Engineering |
| 3 | New migration to remove the server-side `coalesce(..., 0)` in the curriculum ingest RPC | Engineering + owner; guarded deploy only, after Part B |
| 4 | Whether to persist `estimated_duration_minutes` / `difficulty_level` / item emoji for personal lessons (schema change) | Owner |
| 5 | Optional read-only data check for already-stored personal questions with invalid keys (now shown as "not scored") | Owner; authorized access only |
| 6 | Part B hosted audit before any SQL or hosted release change | Someone with authorized hosted access |

---

## Part B — P0-hosted (live state) — **partly verified 2026-11-12**

The evidence below comes from read-only checks on 2026-11-12, with owner authorization: the guarded deploy tool, aggregate `SELECT` queries and the GitHub API. Items still marked **UNKNOWN** must be verified before any change that depends on them. Do not infer them from merged code.

| # | Question | Status | How to obtain (authorized operator) |
|---|---|---|---|
| B.1 | Which of the 23 versions in A.7 are applied in production; any version mismatch | **VERIFIED** | Guarded dry run from `main` @ `b748d55`: 111 local and 111 applied, 0 pending, no mismatch. After deploying `20261112010000` and `20261112020000` with the guarded tool, the post-deploy check confirmed **113/113** parity. No `migration repair` was used. |
| B.2 | Live definition of the curriculum ingest RPC (does it still `coalesce(..., 0)`?) | **FIXED and VERIFIED** | It did. `20261112010000_manifest_answer_key_integrity` (#234) replaced the default with `private.manifest_question_correct_index`. A read-only `pg_get_functiondef` check confirms the live function calls the validator. |
| B.3 | Required status checks / branch rulesets on `main` | **VERIFIED** | Strict branch protection: PRs must be up to date. The three required checks are "Analyze, test, and build", "Verify clean Supabase migrations and complete official taxonomy ingestion" and "Validate official taxonomy sources". No required reviews. Repository auto-merge was enabled on 2026-11-12 with owner approval. |
| B.4 | `private.site_feature_controls` present and seeded; `release_ready` / `enabled` per key; server admission active | **PARTLY VERIFIED** | The table is present, and `learning.quick_rescue` is seeded `enabled=false`, `release_ready=false`, `experimental`. The other keys and server admission paths have not been rechecked. |
| B.5 | Production build sets `SITE_FEATURE_RPC_READY` | UNKNOWN | Release build configuration |
| B.6 | Count of stored personal `questions` rows with out-of-range / duplicated-key options | **VERIFIED: none** | Aggregate counts only, no rows exported. All 43 `questions` rows belong to personal lessons. All 43 have a key inside their option range, none uses key `0`, none is short-answer, and none has duplicate options. Production has 0 curriculum lessons, 0 `assessment_items` and 0 `assessment_questions`. **No stored answer key was fabricated, so no data repair is needed.** |
| B.7 | Deployed tables/types relevant to the logical entities in plan §12.0 | UNKNOWN | Schema read with authorized access |

---

## Change log

- 2026-11-12 — P0-light completed from repository `main` @ `b748d55`. Part B intentionally left UNKNOWN.
- 2026-11-12 — Part B: B.1, B.2, B.3 and B.6 verified; B.4 partly verified; B.5 and B.7 still UNKNOWN. The server answer-key default was fixed and deployed (#234), and the quick_rescue registry row was deployed (#233).
