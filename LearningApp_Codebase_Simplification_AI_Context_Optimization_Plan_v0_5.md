# LearningApp — Codebase Simplification & AI Context Optimization Plan

**Status:** **OWNER CONDITIONALLY APPROVED: Phase 0 audit + Phase 1 drafts only. Phase 2 NOT AUTHORIZED.**
**Version:** **0.6** (November 14, 2026) — execution-time re-pin and drift corrections on top of v0.5 (Gemini Argon, Grok, Z.ai, Qwen reviews). See §2.1b and §13 "v0.6 disposition". The filename keeps `v0_5` so existing links resolve; move to the canonical home below on acceptance.  
**Prepared:** November 12, 2026; revised November 14, 2026.  
**Phase 0 execution pin (v0.6):** `06221ed6f9ef617113f76d0ddd072c20a0042250` (committer time 2026-11-14T14:54:13Z; PR #270 merge). Audit branch `chore/code-efficiency-audit-baseline` was created from this SHA.  
**Repository:** [RACCHUS/LearningApp](https://github.com/RACCHUS/LearningApp).  
**Historical inventory/plan baseline:** `a458b4138719811e441dd75268bd354d0125d302` (CI/test-quality plan v4, PR #240). **Latest `main` observed during v0.5 review:** `1e6757678b8311dfc7f4814e4e17699498c28792` (November 12, 2026, 19:53:02 UTC; PR #244 merge). **Neither commit is a frozen Phase 0 execution baseline. Re-pin `main` when the audit branch is actually created.** See §2.1a for the checked delta.  
**Authorization boundary:** A future Phase 0 execution may establish the dedicated audit branch and commit **audit evidence only**. Phase 1 may prepare **reviewable draft documents and proposed diffs**; applying agent instructions, activating a validator, changing CI, or merging Phase 1 work requires a fresh owner decision. No Phase 2 code movement, refactoring, file deletion, or production/migration action is authorized.  
**Review inputs:** Gemini Argon, Grok, the user-supplied Z.ai independent-review DOCX, and Qwen’s written v0.4 review. Z.ai reports 120+ checks from a pinned clone; those counts are reviewer-reported, not independently rerun by this plan author. Specific T7, B3, T6, and instruction claims were spot-checked; the v0.5 `main` SHA, comparison, fresh tree totals and CI file were checked through the GitHub connector. Qwen’s assertions are independently qualified below.
**Proposed canonical home on owner acceptance:** `docs/engineering/LearningApp_Codebase_Simplification_AI_Context_Optimization_Plan.md`. This downloadable v0.5 is **not** a repository change.

---

## 1. Executive summary

LearningApp has grown into a substantial Flutter/Dart, Python, SQL, and content repository. Its size is not automatically evidence of waste: the application contains real features, security rules, tests, curriculum, and operational documentation. Nevertheless, direct inspection of `main` identified **concrete refactoring candidates**: exceptionally large multi-purpose UI/state files, tightly coupled logic, repeated workflow structures, and a large set of documents that can add unnecessary reading overhead for coding agents.

The primary goal is **less work to understand, change, and safely test a feature**. Reducing source lines or repository bytes is secondary. The initiative should make AI development cheaper in context tokens, more reliable, and easier to review without losing functionality or changing protected behavioral contracts.

**Authorized planning approach:** establish a scoped, reproducible baseline; measure deterministic minimum viable context for eight already-approved tasks (plus one separately proposed documentation-exception control); prepare a validated feature map and minimal agent navigation rules; evaluate whether any code pilot is justified at all; only if separately approved, run high-value, low-hop pilots and coordinate later CI checks. Do **not** perform a wholesale rewrite or set arbitrary percentage-reduction targets before measuring.

### Core principles

1. **Preserve behavior and product capabilities first.** Functional legacy capabilities remain until replacement parity or explicit owner approval for obsolescence is demonstrated.
2. **Optimize for *cognitive load*, not minimum line count.** Straightforward code is preferable to compressed one-liners and clever general-purpose abstractions.
3. **Keep safe duplication when warranted.** Independent security checks, cross-boundary validation, and explicit failure handling can be intentional.
4. **Avoid new abstraction debt.** Do not replace five simple methods with a difficult, highly parameterized framework unless the benefit is demonstrated.
5. **Prefer narrow, testable PRs.** Refactoring must be observable, reversible, and separable from product behavior changes.
6. **Treat AI context as an explicit engineering resource.** Repository navigability, bounded file retrieval, concise contracts, and dependency maps are deliverables, not incidental documentation.
7. **Make claims evidence-based.** Report measured duplication and context savings; do not present estimates as results.
8. **Enforce a cohesion-and-hop-count rule.** Splitting a module only counts as successful when typical sub-feature work can be understood and verified with a narrow contract and **less total relevant context**, not a growing chain of parent/child/provider reads.
9. **Reserve scarce AI quota for high-value validation.** All eight tasks use deterministic measurements. **Live discovery traces are not authorized by this approval**; budget and permission must be requested separately.
10. **Stop when navigation alone solves the problem.** If a small, accurate map and existing instructions already identify owner, contract and tests without excess reads, recommend **no pilot** rather than manufacturing code churn.

---

## 2. What was actually inspected

This initial review used GitHub's repository tree and selected source files in `main`, including `AGENTS.md`, `analysis_options.yaml`, `pubspec.yaml`, `.github/workflows/flutter-ci.yml`, and the files in the table below. It was **not** a full local clone, test run, semantic clone scan, static dependency analysis, runtime performance study, or end-to-end feature parity review.

### 2.1 Initial repository inventory — historical `a458b41` snapshot

**Versioning discipline:** Figures and source line references in §§2.1–2.3 are the **reproducible historical v0.3/v0.4 snapshot**, not automatically the inventory at audit execution time. The execution-time top-25 file list, source classifications, task ranges and tests must be revalidated on the actual branch-parent SHA. The newer observation is summarized separately in §2.1a.

| Measure | Observed inventory | Interpretation |
|---|---:|---|
| Dart files in repository | ~1,140 | Includes application, packages, and tests; not 1,140 production Dart files |
| Dart files inside `lib/` | 691 | Main Flutter application source footprint |
| Dart source bytes inside `lib/` | **6,217,786 bytes** | Raw source size, **not** compiled bundle size or AI token count |
| Dart files in `test/` | 373 | Tests must generally be retained; tests are not code bloat by default |
| Python files in `tool/` | 112 | Scripts, generation tools, and checks |
| Root-level Markdown files | **13 files / 1,175,608 bytes** | Several large plans share the repository root |
| Distinct byte-identical file groups | **2** | MCP config pair (168 bytes each) and two empty Dart files. **Not** a meaningful duplication-rate estimate |

The GitHub tree inventory returned **1,926 entries, not truncated**, including directories. All **112 repository Python files** are under `tool/`. The following are large *review candidates*, **not confirmed waste**:

| File | Inspected size | Why review it |
|---|---:|---|
| [`lib/widgets/community/in_context_qa_sheet.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/widgets/community/in_context_qa_sheet.dart) | 2,612 lines | Q&A, answers, drafts, review queues, moderation actions, bookmarks, audit logs, dialogs, and UI within one file |
| [`lib/widgets/assessment/assessment_item_renderer.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/widgets/assessment/assessment_item_renderer.dart) | 1,337 lines | Several interaction types plus UI, local response management, and grading-related presentation |
| [`lib/widgets/software_learning/excel_upload_card.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/widgets/software_learning/excel_upload_card.dart) | 1,270 lines | Sample OOXML workbook generation, workbook evaluation, and upload UI live together |
| [`lib/providers/learning_strategy_provider.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/providers/learning_strategy_provider.dart) | 1,226 lines | Storage, offline queue, conflict handling, sync, and Riverpod state management |
| [`lib/screens/library/library_screen.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/screens/library/library_screen.dart) | 1,193 lines | Filtering, search, active learning-context scope, provider selection, and large UI composition |
| [`lib/screens/lessons/guided_generation_screen.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/screens/lessons/guided_generation_screen.dart) | 1,257 lines | Session restoration, multi-step generation flow, validation and import UI |
| [`lib/services/taxonomy/taxonomy_crosswalk_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/taxonomy/taxonomy_crosswalk_service.dart) | 1,091 lines | Several taxonomy operations plus a substantial fallback-data region |
| [`tool/ingest_curriculum.dart`](https://github.com/RACCHUS/LearningApp/blob/main/tool/ingest_curriculum.dart) | 1,393 lines | CLI, manifest validation, transport, transformation, and ingestion orchestration |

**Concrete repeated-structure example, not an automatic DRY recommendation:** `in_context_qa_sheet.dart` has `_handleReviewQuestion()` and `_handleReviewAnswer()` with almost identical notification-refresh-error scaffolding (around lines 766–817), but **distinct domain calls**. Keep these domain paths separate unless tests establish matching permission, audit, and UI semantics. If consolidation is beneficial, prefer a small closure-based orchestration helper that preserves explicit `reviewQuestion` and `reviewAnswer` calls; first characterize the existing large build flow and avoid extracting dialogs that are **already separate classes** near the file bottom.

**Zero-byte file evidence from Z.ai (reviewer-reported):** `lib/services/audio_lesson/audio_lesson_controller.dart` and `lib/widgets/progress/recent_activity_list.dart` are zero-byte and unreferenced in `lib/`, `test/`, and `tool/` at the pinned baseline. Its sampled history found the audio controller empty since 2025-07-25 and an audio subsystem rebuild on 2025-08-29; this suggests a remnant, not an active controller. Phase 0 should **attach the supplied history findings**, perform only a quick reproducibility spot-check if necessary, and close the research item. **No deletion, placeholder annotation, or other code change** without separate owner approval. `git log -- <path>` is the relevant history command; `git log -S` is not a meaningful way to establish empty-file provenance.

### 2.1a Qwen verification: `main` moved before Phase 0 execution

**Verified by the plan author on November 12, 2026, using GitHub:** `main` is now `1e6757678b8311dfc7f4814e4e17699498c28792`; its latest merge is PR #244, *ID-keyed independent oracles for shipped College Algebra*. The [comparison against historical `a458b41`](https://github.com/RACCHUS/LearningApp/compare/a458b4138719811e441dd75268bd354d0125d302...1e6757678b8311dfc7f4814e4e17699498c28792) reports **10 commits ahead**, **0 behind**, and **23 changed paths**. This is a **review-time observation**, *not* an audit that has already started.

| Snapshot metric | Historical `a458b41` | Newly observed `1e67576` | Scope of change |
|---|---:|---:|---|
| Recursive Git tree entries (files + directories) | 1,926 | **1,937** | +11, both trees nontruncated |
| All Dart files | 1,140 | **1,141** | +1 test Dart file |
| Dart files in `lib/` | 691 | **691** | unchanged |
| Dart bytes in `lib/` | 6,217,786 | **6,217,786** | unchanged |
| Dart files in `test/` | 373 | **374** | +1 |
| Python files in repository | 112 | **120** | +8 |
| Root Markdown files | 13 | **13** | unchanged file count |
| Root Markdown bytes | 1,175,608 | **1,184,126** | +8,518 bytes, chiefly CI plan evolution |

**Qualitative delta relevant to this initiative:** `.github/workflows/flutter-ci.yml` has changed (+40/−5 lines), retains named `verify` and `verify-database` jobs in the checked file, and now includes test-inventory and College Algebra parity/accuracy steps. `tool/ingest_curriculum.dart`, `tool/lint_manifest.dart`, algebra curriculum generation/tests, and `content/schema/curriculum_manifest.schema.json` have changed or gained tests. **Do not infer that the entire separate CI v4 restructuring or required-check-name decisions are finished merely because CI PRs landed.** Before proposing any later CI integration, verify that plan’s current state and check-name stability.

### 2.1b Phase 0 execution re-pin — `06221ed` (v0.6, measured)

**Executed November 14, 2026** with `phase0_inventory.py` (on the audit branch under `docs/engineering/audits/code_efficiency/scripts/`), reading **Git blob sizes at the pin**, not the working tree. `main` is **67 commits** past `1e67576`; `a458b41..06221ed` changes **145 files (+15,177/−2,766)**.

| Snapshot metric | `1e67576` (v0.5) | **`06221ed` (pin)** |
|---|---:|---:|
| Recursive Git tree entries | 1,937 | **1,995** |
| All Dart files | 1,141 | **1,162** |
| Dart files / bytes in `lib/` | 691 / 6,217,786 | **697 / 6,284,136** |
| Dart files in `test/` | 374 | **389** |
| Python files (all under `tool/`) | 120 | **141** |
| Root Markdown files / bytes | 13 / 1,184,126 | **14 / 1,282,238** |
| Always-on/agent instruction surface (6 files) | not measured | **16,834 bytes** (`AGENTS.md` 7,263 B / 90 lines) |

**Drift that changes this plan:**

1. **The CI/test-quality v4 plan has landed** (PR-1..PR-9, #241–#261). The required check is now the fail-closed gate job **`Analyze, test, and build`** (`required-gate` in `flutter-ci.yml`, behind `verify` and `web-builds`); `early-feedback` and `browser-smoke` are advisory; `verify-database` remains. Policy lives in `docs/testing/TEST_QUALITY_POLICY.md`, which forbids renaming required checks and sets a 30-run/14-day stability bar before an advisory job becomes required. The CI hold in §§2.2, 6 and 12 is therefore **no longer blocked on v4**; it is blocked only on owner approval plus that policy.
2. **Measurement hygiene:** the owner's Windows checkout has `core.autocrlf=true`, so working-tree bytes are inflated (e.g. `excel_upload_card.dart` 46,277 B on disk vs **45,008 B** blob). **All byte metrics must come from Git objects at the pin** (`git ls-tree -l`, `git cat-file -s`, `git show <pin>:<path>`).
3. **This plan is itself a root mega-plan** (84,082 B), which is why root Markdown grew by one file. Moving it under `docs/engineering/` on acceptance is now a concrete §2.2 action, not a nicety.
4. **Top-25 changed** (recomputed; see `top25_size.csv`): `tool/tests/clep_algebra_oracles.py` (47,046 B, class `test`) entered; `tool/ingest_official_taxonomies.dart` dropped out; `tool/ingest_curriculum.dart` grew to 59,126 B. All §5/§7.2 pilot line anchors were re-checked and still hold (`excel_upload_card.dart:13` and `:309`; `in_context_qa_sheet.dart:766`, `:793`, `:1005`, dialogs at `:2298`/`:2386`).
5. **Churn finding not anticipated by v0.5:** by the frozen §2.4 method (window 2026-08-16T14:54:13Z → 2026-11-14T14:54:13Z), the highest-churn eligible file is **`lib/providers/router_provider.dart`** (31 commits, 3,091 changed lines), ahead of Library (19) and Q&A (14). It is a navigation owner, not a pilot candidate; record it as a **map priority** (it is also T9's owner).
6. Both zero-byte Dart files are still present and still empty at the pin.

**Execution gate (v0.5 text, now satisfied by §2.1b):** from an up-to-date local checkout, record `git rev-parse origin/main` (or `git rev-parse HEAD` after fast-forwarding a clean local `main`), `git diff --stat a458b4138719811e441dd75268bd354d0125d302..HEAD`, the new top-25 inventory, and any source/test/instruction deltas affecting T1–T8. Do not silently reuse the historical line ranges, top-25 order or T6 coverage assumptions. Any new drift between this reviewed `1e67576` snapshot and audit execution must also be reported. The proposed branch remains `chore/code-efficiency-audit-baseline`; creating it is **not** part of drafting v0.5.

---

### 2.2 AI-context and documentation observations

- The **13 root Markdown files total 1,175,608 bytes**. The major default-exclusion candidates include `LEARNINGAPP_CONTENT_INTELLIGENCE_AND_GAP_RESCUE_MASTER_PLAN_V2_6_2026-11-11.md` (**405,303 bytes**), `LEARNINGAPP_MARKETING_ADVERTISING_FINANCIAL_SUSTAINABILITY_MASTER_PLAN.md` (**165,380 bytes**), and `LearningApp_CI_Test_Quality_Optimization_Plan.md` (**109,177 bytes**). This is **potential retrieval overhead**, not measured always-loaded context; agents may read only a subset.
- `AGENTS.md` is approximately **7.3 KB**, already covering migration, flag, legacy parity, BYOK, and TEL Fast rules. **Do not rewrite or mirror it wholesale.** Keep the proposed retrieval guidance to **~40 or fewer touched lines and no more than +20 net lines** in `AGENTS.md` (prefer near-zero net growth), linking to the map rather than repeating architecture rules. Measure the **existing `AGENTS.md` and applicable always-on instruction surface** in the Phase 0 baseline; do not presume an agent actually loaded every instruction without evidence.
- Existing instruction surface is broader than `AGENTS.md`: `.agents/rules/mcp-tooling.md`; `.github/instructions/Main.instructions.md` (**`applyTo: '**'`**); `.github/agents/lesson-generator.agent.md`; `.github/prompts/generate-lesson.prompt.md`; and `.github/pull_request_template.md` with feature-preservation checkboxes. Phase 0 must inventory overlaps and precedence without copying these into another megadocument.
- **Verified instruction conflict:** `.github/instructions/Main.instructions.md` currently says to suggest modularizing when a file exceeds **400 lines** and extract helpers when a function exceeds **50 lines**. These blanket triggers conflict with this plan's cohesion/hop-count rule. **Phase 1 must draft a replacement** (see §6); it is not permission to edit the active instruction file yet.
- Existing disabled lint entries in `analysis_options.yaml` are largely style rules; `use_build_context_synchronously` is already an error. No broad lint re-enable/format sweep is justified by this audit.
- `.github/workflows/flutter-ci.yml` is an established required workflow. The **CI/test-quality v4 restructure has landed** (§2.1b); any eventual validator step must follow `docs/testing/TEST_QUALITY_POLICY.md` (start advisory, never rename `Analyze, test, and build`, add to the gate's `needs:` only after the stability bar). **No CI modification in Phase 0 or Phase 1 drafts.**
- `UI_ARCHITECTURE_LOCKED.md` (**79,012 bytes**) is a required exception for certain UI tasks. **B3 prohibits badges/dots/counts on top-level `NavigationBar`/`NavigationRail` destinations**, while allowing informational counts *inside* Library/Progress (§3 and the line-108 erratum). Taxonomy/learning architecture documents may be required for their domains. **Retrieval exclusions are defaults, never bans**. Historical migrations can also be necessary for schema or security changes. Every exclusion requires task-specific override rules.
- Large migrations, self-host schema snapshots, generated mocks, content manifests, data-shaped model files and official-source catalogs must be separately classified, not counted as unnecessary production duplication.

### 2.3 Published provisional top-25 size list (Phase 0 input)

**Method:** top 25 GitHub blobs by raw byte size under `lib/` or `tool/` at the **historical** `a458b41` snapshot. On the newly observed `1e67576` tree, several large algebra generator/tool files increased in size; **recompute and publish the top 25 using the actual Phase 0 SHA before measuring**. This is **size-ranked, not churn-ranked**; Phase 0 computes a separate churn ranking using the **precommitted method in §2.4**, not an after-the-fact choice of window. Classification is provisional and can change after inspection. `data-in-lib` and `curriculum-as-code` do **not** enter the authored-logic clone-rate denominator.

| Rank | File | Bytes | Initial classification / permitted Phase 0 action |
|---:|---|---:|---|
| 1 | `lib/widgets/community/in_context_qa_sheet.dart` | 100,717 | Authored UI; characterize only; Pilot A held |
| 2 | `tool/curriculum_clep_algebra/domain_03_functions_and_properties.py` | 86,015 | Curriculum-as-code; inventory, exclude from clone denominator |
| 3 | `tool/curriculum_clep_algebra/domain_02_equations_and_inequalities.py` | 74,672 | Curriculum-as-code; inventory only |
| 4 | `tool/curriculum_clep_algebra/domain_01_algebraic_operations.py` | 71,255 | Curriculum-as-code; inventory only |
| 5 | `tool/curriculum_clep_algebra/domain_04_number_systems_and_operations.py` | 56,810 | Curriculum-as-code; inventory only |
| 6 | `tool/ingest_curriculum.dart` | 55,727 | **Protected ingestion — read, no refactor proposal** |
| 7 | `lib/screens/library/library_screen.dart` | 50,485 | Authored UI; Pilot C conditional on T1 evidence |
| 8 | `lib/widgets/assessment/assessment_item_renderer.dart` | 49,617 | Grading-adjacent; read, high-risk hold |
| 9 | `lib/screens/lessons/guided_generation_screen.dart` | 46,218 | Authored UI; characterize |
| 10 | `lib/widgets/software_learning/excel_upload_card.dart` | 45,008 | Authored UI + separate evaluator class; Pilot B conditional |
| 11 | `lib/providers/learning_strategy_provider.dart` | 43,442 | CAS/sync; read and characterize, no Phase 2 authorization |
| 12 | `lib/services/taxonomy/taxonomy_crosswalk_service.dart` | 42,740 | Taxonomy service/fallback; characterize carefully |
| 13 | `lib/services/governance/guarded_deployment_manager.dart` | 41,443 | **Protected deployment — read, no refactor proposal** |
| 14 | `tool/curriculum_clep_psychology/formative_lesson_questions.py` | 41,377 | Curriculum-as-code; inventory only |
| 15 | `lib/data/seed_faqs_catalog.dart` | 39,612 | **Data-in-lib**; exclude from clone denominator |
| 16 | `tool/curriculum_clep_psychology/domain_01_history_methods.py` | 38,821 | Curriculum-as-code; inventory only |
| 17 | `lib/services/taxonomy/official_taxonomy_sources.dart` | 38,293 | **Data-in-lib / official authority**; no dedup proposals |
| 18 | `lib/models/overview_outline.dart` | 37,478 | **Data/model-shaped mixed**; classify before scoring |
| 19 | `lib/services/scope_resolver.dart` | 37,076 | Scope/privacy-related; **read for T1, do not split in Pilot C** |
| 20 | `lib/widgets/enhanced_json_import_widget.dart` | 35,800 | Authored UI; characterize |
| 21 | `tool/curriculum_clep_psychology/domain_06_cognition.py` | 35,059 | Curriculum-as-code; inventory only |
| 22 | `tool/curriculum_clep_psychology/domain_12_social.py` | 34,815 | Curriculum-as-code; inventory only |
| 23 | `tool/curriculum_clep_psychology/domain_02_biological.py` | 34,814 | Curriculum-as-code; inventory only |
| 24 | `lib/screens/taxonomy/taxonomy_explorer_screen.dart` | 34,634 | Authored UI; characterize |
| 25 | `tool/ingest_official_taxonomies.dart` | 33,144 | **Protected official ingestion — read, no refactor proposal** |

**Explicit Phase 0 non-refactor denylist:** deployment and reset code (`lib/services/governance/guarded_deployment_manager.dart`, `lib/services/reset_service.dart`); official or authoritative ingestion (`tool/ingest_curriculum.dart`, `tool/ingest_official_taxonomies.dart`); verification utilities (`tool/verify_*.dart`, `tool/verify_*.py`, including `tool/verify_eco02_pilot.dart`); and migrations, RLS, grading, auth/consent, and protected CAS/sync logic. These may be **read to document contracts or navigation**, but **Phase 0 must not generate suggested edits/refactors for them**. Any eventual reconsideration requires a separate security/owner decision; broad wildcard exclusions from refactoring do **not** imply ignoring them when validating feature behavior.

**Classification schema:** `authored-application`, `authored-support-tool`, `data-in-lib`, `curriculum-as-code`, `generated`, `test`, `migration`, `documentation`, `protected-operations`. Report clone counts and denominators by class; never divide confirmed application-code clones by the bytes/lines of data catalogs, manifests or generated source. Save churn scores separately; do not relabel this table as highest-churn evidence.

### 2.4 Frozen churn method and external spot-check evidence

**Precommitted before measurement:** define the time window as exactly **90 × 24 hours preceding the pinned baseline commit committer timestamp in UTC**, not the later audit execution date. Use `git show -s --format=%cI <pin>` to record the endpoint; report both (1) **distinct non-merge commit count** touching a path and (2) **added + deleted lines from `--numstat`** over that window. Use `git log --no-merges --follow --since=<start_utc> --until=<end_utc> --numstat -- <single_path>` for each eligible path; record the exact script/Git version and how renames/binary files are handled. This definition is for the **formal authored-code churn ranking**, not retrospective comparison to a different Git command. A churn score is a signal, not proof of duplication, quality, or future-change probability.

**Scope:** authored application and support-tool files; do not mix `data-in-lib`, `curriculum-as-code`, generated files, docs, migrations, or protected operations into the *eligible refactor-priority ranking*. Those categories may still be inventoried separately. Save raw per-path values, allow reproducibility, and report the size ranking separately from churn.

**Z.ai spot check (not the formal ranking):** for three pilot candidates, it reports 14/14 lifetime/recent commits in Community Q&A, 18/18 in Library, and 4/4 in the Excel widget under its own `--since=2026-08-12` procedure. These reviewer-reported counts are **not directly comparable** to the method above (different window and merge handling). They justify inspecting churn but do not predetermine a pilot.

## 3. What "efficient" means for LearningApp

Evaluate every candidate along five axes:

| Axis | Better outcome | Common false optimization |
|---|---|---|
| **Behavioral** | Identical user-visible outcomes, permissions, persistence, data contracts | Deleting edge cases or legacy capabilities |
| **Maintainability** | Clear ownership, smaller change surface, readable boundaries | Splitting into many one-function files |
| **Duplication** | One sensible implementation of repeated domain policy | Abstracting unrelated actions just because they look similar |
| **AI context** | Fewer relevant tokens/files to retrieve, less ambiguity | Hiding essential logic behind many indirect layers |
| **Runtime/build** | Improved performance/bundle size when measured | Assuming fewer lines means faster runtime |

**Important:** Source-code size, compiled application size, repository storage, AI context, and runtime performance are different metrics. A refactor can improve one while making another worse. Measure independently.

### Decision rule for refactors

Prioritize changes when the same behavior can be maintained while reducing **at least one** of: repeated reasoning, change-surface area, unnecessary coupling, retrieval tokens, or defect risk—**without materially worsening another**. If the benefit is unclear, leave the working code alone.

---

## 4. Audit workstreams

### A. Real code duplication (semantic and structural)

Search for:

- Repeated business rules, validation chains, status transitions, and error handling across different files.
- Copy/paste widgets or similarly shaped screens with only text/labels changing.
- Repeated Supabase query construction, auth/ownership handling, request retries, JSON parsing, and data mapping.
- Multiple competing implementations of the same canonical process (e.g., readiness, scope, grading, taxonomy, content ingestion).
- Inconsistent domain naming concealing equivalent behavior.

**Method:** first detect probable clones (exact/near text and token-based), then manually inspect semantics. Record common inputs, outputs, side effects, permissions, and differences. Extract only where the common concept is stable.

**Output:** ranked clone clusters with file paths, line ranges, approximate duplicated lines, risk level, recommended action, and rationale. Include 'keep separate' decisions.

### B. Dead code, obsolete paths, and dependency usage

Classify:

1. **Clearly unreachable/unreferenced** source after accounting for reflection, routing, registries, code generation, and conditional feature availability.
2. **Retired but capability-bearing** features that still lack a replacement.
3. **Feature-disabled** code intentionally preserved for reactivation or rollback.
4. **Generated** artifacts and migrations retained for reproducibility/history.
5. **Potentially redundant** packages or helper libraries, after verifying imports, runtime usage, transitive requirements, and tooling needs.

**Never auto-delete categories 2–4.** Require explicit inventory evidence, feature-owner review, and behavioral tests for all removals.

### C. Oversized and mixed-responsibility modules

Inspect **dependency cohesion**, not just length. The best boundary allows agents to understand a sub-feature from **one focused module plus a narrow interface/contract**. Splitting a widget that still needs 10–15 parent state variables and callbacks can make AI retrieval *worse*.

**Mandatory Cohesion & Hop-Count Rule (Phase 2 gate):**

1. Record a representative sub-feature task, the **Minimum Viable Context Set (MVCS)**, and its imported dependencies **before** proposing a split.
2. Favor extraction when the child owns a coherent behavior and the parent calls it through a small, stable, well-tested contract. Independent pure domain logic is a stronger candidate than closely coupled Riverpod/widget state.
3. Reject or redesign any split where a typical task must read **both the whole parent and whole child**, shuttle across many constructors/providers, or load **more total required context/hops** than before. A narrow parent call site or typed contract is acceptable; the requirement is *not* zero knowledge of the caller.
4. Record before/after **minimum required files**, **navigation hops**, **contract breadth**, **cross-boundary parameters/callbacks**, and **MVCS tokens**. Token savings do not excuse behavior or security regressions.
5. Avoid global generic helpers when a local, readable implementation is cheaper to understand. Stable domain-local abstractions beat aesthetic micro-file splitting.

Review signals (not automatic violations): files above ~700–1,000 lines, methods/build blocks above ~100–150 lines, UI mixed with parsing/persistence/network decisions, and provider/controller interfaces with heavy prop drilling. Keep large files when splitting offers no measurable benefit.

---

**Refinement (Grok):** only propose a split if essential parent + child + contract + tests **combined** require less context and fewer/higher-value hops for the same task. Reject state/callback prop drilling, especially in Riverpod widgets. Count package/project imports only when actually needed to understand or validate the edit. The absence of a 400-line or 50-line threshold is intentional.

### D. AI-specific context navigation

**Phase 1 target:** `docs/engineering/CODEBASE_MAP.md`, not a sprawling second architecture manual. It should have short, navigable **feature → entry point → authoritative contract → test** records, links to full plans, and task-specific examples. Limit redundancy with `AGENTS.md` and any feature-flag registry.

**Map freshness cannot rely on prose review alone.** Design `tool/verify_codebase_map.py` to validate machine-readable references (an explicit checked section, structured entries, or restricted link syntax) for:

- Repository-relative **file paths**: normalized, confined within the repository, present on disk, and not stale; optional line anchors must be in range.
- Named **symbols and routes**: check through an appropriate bounded mechanism (e.g., targeted symbol lookup, analyzer/generated route registry, or a documented, testable text check); distinguish structural checks from actual semantic ownership.
- No broken links to required tests/contracts and no unreviewed new authoritative copies of security/feature policies.

**Caveat:** indiscriminately parsing **every backticked span** in Markdown is incorrect—backticks also enclose code snippets, identifiers, paths not meant to be live, and examples. Validate a deliberately structured reference list. A file can still exist while the documented ownership has changed; require map review on relevant PRs and periodic human semantic checks. Do **not** claim that existence checks fully prevent map drift.

Add a **short, portable retrieval rule** to `AGENTS.md`: begin with the map and relevant contracts; read bounded file ranges; do not automatically grep/preload huge master plans, historical migrations, generated code, or curriculum manifests unless the task needs that domain. A `.aiignore` may be added for tools that support it, but cannot be the sole enforcement: not all coding agents honor the same ignore configuration. Neither suppression nor exclusions may prevent intentionally targeted security/migration/content work.

---

### E. Documentation and developer-tool duplication

- Do not preload the ~405 KB root content-intelligence master plan (`LEARNINGAPP_CONTENT_INTELLIGENCE_AND_GAP_RESCUE_MASTER_PLAN_V2_6_2026-11-11.md`) during unrelated coding tasks. Apply the same default exclusion principle to large marketing/architecture plans, archival docs, historical SQL migrations, generated mocks, and curriculum data.
- **Preserve and link** these resources; do not delete them, hide them from explicit retrieval, or duplicate their authoritative requirements in a new summary.
- Put the compact map at `docs/engineering/CODEBASE_MAP.md`, with only a small pointer and retrieval rules in `AGENTS.md`.
- Coordinate with `LearningApp_CI_Test_Quality_Optimization_Plan.md`. In Phase 0–2, run heavy clone/complexity reports **locally or as non-blocking artifacts**, never in required hot-path PR checks. The proposed path/reference validator may later join the fast static stage after testing runtime and false-positive behavior; **sub-second execution is a goal to measure**, not a guarantee.

---

### F. Tests and safety-critical code

Test code is not expendable simply because it is repetitive. Prefer fixtures/builders/shared setup **only when failures remain understandable**. Do not hide assertions or make one generic test replace meaningful independent cases.

**Test-sharding alignment:** When genuine pure filtering/evaluation logic moves out of a widget, migrate the corresponding **logic and edge-case assertions** into fast pure Dart unit tests wherever feasible. Retain a small number of widget/integration tests proving wiring, UI states, permissions, and end-to-end behavior. Do not move UI-specific assertions into inappropriate unit tests or change production logic solely to optimize test runners.

Assess whether refactors touch protected paths such as server-side grading, answer-key confidentiality, auth/RLS, private analytics consent/erasure, content provenance, lesson import/session recovery, offline sync, feature latches, or production migration integrity. Those paths require stronger pre/post evidence.

---

## 5. Priority candidates and suggested treatment

**Rank as navigation problems first; Phase 2 remains unauthorized.** The top-25 list in §2.3 is the Phase 0 inventory; the shortlist below is **not an instruction to refactor**.

| Priority | Candidate | Evidence already present | Proposed next step / prohibition |
|---|---|---|---|
| **P0** | AI retrieval + instruction conflicts | ~1.18 MB root Markdown; Copilot `400`/`50` triggers apply globally | Draft concise map, retrieval defaults and replacement instruction diff; no activation |
| **P0** | Scoped baseline / eight MVCS tasks | Large mixed-purpose files; no actual token savings measured | Rank, classify and establish fixed tasks/estimator |
| **P1 / Pilot B conditional** | Excel evaluator **move** | `SoftwareLearningWorkbookEvaluator` at `excel_upload_card.dart:13`; `ExcelUploadCard` starts ~309 | Diff existing evaluator against `DemoWorkbookReader`; preserve distinct trust roles; do not design a new worker |
| **P1 / Pilot C conditional** | Library filters | `_CatalogSource` private in screen; scope and pre-reader dependencies | T1 first; pure extraction only if independent of scope, privacy, pre-reader and Riverpod state; no `scope_resolver.dart` split |
| **P2 / Pilot A conditional** | Community Q&A | 2,612-line file, `build` begins near 1005; dialogs already separate classes | Characterization first, only cohesive subviews; **do not** unify moderation domain calls or alter silent catches |
| **Hold** | Assessment/answer keys, Fast CAS/sync | Sensitive invariants and mixed responsibilities | Map/test contracts; independent approval for any sensitive edits |
| **Denylist** | Deployment/reset/official ingestion/`verify_*`/migrations | Safety-critical or operational functions | Read to understand; **no Phase 0 refactor proposals** |
| **Classify, not shrink** | `data-in-lib`, content generators, generated artifacts | Size is not code-clone evidence | Exclude from authored-code clone denominator |
| **Housekeeping inquiry** | Two 0-byte Dart files | Exact empty blobs | Brief history/reference check; **no deletion/comment in Phase 0** |

**Evidence-based global stop condition:** for each navigation/control task, record scripted hops to owner, extraneous bytes *in the scripted retrieval set* before correct identification, whether map section alone identifies owner/contract/tests, and false-owner candidates. If the compact map and instruction draft resolve navigation without material ambiguity or unnecessary reads, recommend **no Pilot B/C/A**. Pilot order is a fallback shortlist, never an automatic work queue.

## 6. Proposed phases and deliverables

### Phase 0 — Scoped, reproducible read-only baseline **(owner conditionally approved)**

**Goal:** establish measured inefficiency without AI quota waste or behavioral changes.

1. **At execution time, re-query `main` HEAD and record the exact SHA used as the parent of `chore/code-efficiency-audit-baseline`.** Qwen-reported drift from `a458b41` to `1e67576` has already been independently checked (§2.1a), but the audit must **re-pin again when it starts**; do not use a review-time SHA as a promise of execution-time HEAD. Use `git fetch origin main`, then (on a clean updated local checkout) `git rev-parse HEAD` and `git diff --stat a458b4138719811e441dd75268bd354d0125d302..HEAD`, and record commit dates, changed files, inventory changes, test/CI/instruction impact and benchmark implications. Never overwrite or silently compare against a moving baseline. If the named audit branch already exists, inspect its parent/HEAD rather than resetting it.
2. Create/use the dedicated audit branch **only for read-only baseline artifacts**. Do not change production Dart/Python code, Supabase migrations, active agent instructions, validator activation or CI workflows in Phase 0.
3. Run cheap broad automated inventory **on the newly re-pinned execution SHA**; save §2.3's exact **25 size-ranked files** as the provisional review set, plus a separately measured recent-churn ranking computed using §2.4's **locked 90-day UTC, non-merge, per-path commit/line-change method**. Limit targeted human/AI source reading to high-value eligible candidates, root-document overhead and necessary contracts. The protected-operational denylist and `data-in-lib`/curriculum classification are mandatory.
4. Run bounded local clone detection where permitted. Store raw candidate matches, eligibility denominator, manual confirmation and **false-positive class**. Do not propose edits to deployment, reset, official ingestion or `verify_*` tools. Do not mistake identical empty files for useful clone evidence.
5. **Freeze corrected T7 and all eight authorized tasks** before first measurement (§7.2), reconciling any new source/test changes shown by the re-pin delta. Resolve the proposed T9 documentation-exception task by **separate owner sign-off** before including it in measurements; no silent expansion of approved task scope. Freeze written MVCS inclusion/exclusion rules, required test lists (particularly T6), instruction-surface footprint and token estimator. Compute deterministic whole-file/bounded-range **MVCS bytes as primary**, annotated token estimates as secondary, and scripted retrieval overhead. No LLM execution or live traces under this approval.
6. Compare the instruction surface and root docs with actual code ownership. Measure the current `AGENTS.md` and applicable global instructions as a **separate baseline instruction cost**; record global Copilot instructions, agent/prompt files, `.agents` rules and PR template without duplicating content or assuming agent-side auto-loading.
7. Carry forward Z.ai's sampled-history and zero-reference evidence for both empty Dart files (§2.1). Spot-check attribution if needed, mark housekeeping as evidence-only, and **do not edit them**.
8. Publish a **bounded report**, preferably an executive audit of <= 250 lines / ~20 KB plus machine-readable top-25/MVCS tables. Store audit reports **on the audit branch** until owner acceptance; do **not** add a root mega-plan.

**Deliverables (audit branch only):** fact/evidence reports under `docs/engineering/audits/code_efficiency/` (bounded `CODE_EFFICIENCY_BASELINE.md`, `AI_CONTEXT_BENCHMARK.md`, compact `data/code_efficiency_metrics.json`, task/contract inclusion manifest and source/denylist inventory); distinguish those from Phase 1 proposals under `docs/engineering/drafts/code_efficiency/`. Store measured evidence and drafts separately until owner acceptance. The accepted canonical plan belongs under `docs/engineering/`, never repository root. Report size caps apply to human-readable summaries, not necessary raw machine-readable evidence.

**Exit gate:** reproducible baseline, real commit pin, frozen tasks, verified risk classifications and zero production/CI/agent-rule mutations. **No Phase 2 authorization.**

### Phase 1 — Navigation and context improvements **(DRAFTS ONLY; owner conditionally approved)**

**Goal:** prepare minimal, reviewable navigation changes; **no automatic application, merges or CI activation**.

1. Draft `docs/engineering/CODEBASE_MAP.md`, **maximum ~250 lines and 20 KB**, organized as **one canonical anchor per feature** with owner path, narrow contract, test entry and outbound links. No prose-heavy dependency duplication; section-level reads must be possible. A map is an index, not an always-loaded manual. Keep the current root/agent instruction baseline visible in the scorecard; the map must be **read by relevant section**, not preloaded wholesale.
2. Draft **at most ~40 touched lines and +20 net lines maximum** (target near-zero growth) of retrieval guidance for `AGENTS.md`. Include measured before/after instruction bytes and net line change. Point to the map and distinguish: (a) compact always-on rules, (b) normally excluded large root plans/migrations/manifests/generated outputs, and (c) mandatory exceptions when a task is in that domain. Preserve existing migration/FLAG/BYOK/Fast/legacy rules verbatim or in effect.
3. **Draft the critical global Copilot instruction fix** in `.github/instructions/Main.instructions.md` (`applyTo: '**'`): remove the 400-line file and 50-line function triggers. Replace with a concise cohesion/hop-count and behavior-preservation rule (proposed minimal diff below). **Do not apply during Phase 1 draft authorization.**
4. Design a lightweight `tool/verify_codebase_map.py` **without activating it**. **Freeze one explicit reference grammar in the draft**, e.g. an HTML comment per *authoritative index link*, `<!-- map-ref path="lib/screens/library/library_screen.dart" role="owner" -->` (and `role="contract"` / `role="test"` as applicable). Parse **only `map-ref` annotations**, never arbitrary backticked Markdown, fenced examples, or casual prose. Check normalized repository-relative paths, existence, path escape/symlink safety and optionally validated line anchors; a separate optional symbol/route check may be designed but must not pretend to establish semantic ownership. Include examples of valid/invalid references and a tiny false-positive fixture design. This is **a design and draft only**: no production tool file, execution in required CI, or CI change is authorized. Benchmark runtime only when permitted (sub-second is an aspiration); retain human semantic ownership review.
5. Inventory existing `.agents`, `.github/agents`, `.github/prompts`, PR template and the CI v4 plan. Draft map freshness instructions for future ownership-changing PRs; avoid contradictory copy-pasted guidelines.
6. **Do not edit `.github/workflows/flutter-ci.yml` now.** Propose any eventual fast static step **only after** the CI/test-quality v4 reshape and check-name preservation have landed or have been explicitly deferred. No new heavy required clone scanner.
7. **No live agent discovery traces** until owner separately approves a credit budget and exact subset. Deterministic MVCS is sufficient to complete Phase 0 and review drafts.
8. Keep Phase 1 drafts and their proposed diffs in `docs/engineering/drafts/code_efficiency/` on the audit branch or attached to the audit report for review; keep Phase 0 evidence in its separate `audits/code_efficiency/` directory. **Do not merge** active instruction edits or documentation into `main` unless explicitly authorized; accepted artifacts should reside under `docs/engineering/` rather than as root-level mega-plans.

**Proposed `Main.instructions.md` diff for review only:**

```diff
-- **Modularize:** Suggest breaking a file into separate modules if it exceeds 400 lines or starts handling multiple distinct responsibilities.
-- **Function Focus:** Keep functions focused. If a function exceeds 50 lines, suggest extracting helper functions.
+- **Cohesion over line count:** Split only when responsibilities are independently owned and a representative edit needs less total parent/child/contract/test context. Count navigation hops and state/callback coupling; do not split solely because a file or function crosses a numeric line threshold.
+- **Preserve behavior:** For proposed extraction, document contracts and required tests. Avoid unrelated abstractions and keep privacy, grading, feature-gate, and persistence boundaries intact.
```

**Exit gate:** compact map and proposed diffs satisfy caps (**AGENTS.md net growth <=20 lines**); path validator design passes review; instruction contradiction has a clear proposed fix; baseline instruction bytes and map-only decision rubric are reviewable; CI activation remains held. Owner separately approves any Phase 1 commit/CI change. **No Phase 2 refactoring.**

### Phase 2 — Controlled code simplification pilots **(NOT AUTHORIZED — briefs only)**

**None of the following is approval to move files or change behavior.** Before any pilot, Phase 0 must demonstrate that the map/instruction change alone is insufficient and that representative MVCS/hop-count measurements justify editing code. No automatic promotion from Phase 0/1 to Phase 2.

**Pilot B — first candidate, a narrow move (Excel):**

- **What exists:** `SoftwareLearningWorkbookEvaluator` is a separate class **at line 13 of** `lib/widgets/software_learning/excel_upload_card.dart`. It already contains sample OOXML generation and `evaluateWorkbook`; `ExcelUploadCard` begins around **line 309**. `lib/services/software_learning/demo_workbook_reader.dart` is already a **restricted preview reader, not the authoritative isolated upload worker**. The evaluator imports it.
- **Phase 0 prerequisite:** compare evaluator responsibilities, imports, callers and trust semantics with `DemoWorkbookReader` and the worker envelope. **Do not merge the evaluator into `DemoWorkbookReader`, create a competing reader, or relabel preview as authoritative** because both concern OOXML.
- **Possible future action only after approval:** *move* the existing evaluator class to an appropriately named UI-independent Dart service under `lib/services/software_learning/` without changing semantics. Avoid a speculative rubric rewrite, new parser, extra framework abstraction, or churn for a line-count target. Preserve an intentionally narrow public import/caller interface and verify import updates.
- **Regression net:** current Excel jobs for checker, XLSX snapshot reader, worker envelope, provisional grade/pipeline, sealed upload, retention and erasure, plus caller imports, affected unit tests and any surviving widget/integration tests. Assert existing rubric/test behavior, malformed archive limits, evidence classification and trust boundaries.
- **Measurement honesty:** removing approximately the evaluator prefix will leave a still-large UI widget; T3 gains may be **modest**. Justify any move by separating rubric/trust reasoning from unrelated UI edits, not by promising a fixed line or token reduction.

**Pilot C — second candidate, conditional on T1 (Library):**

- `LibraryScreen` is `ConsumerStatefulWidget`; trusted/official/reviewed/mine is a private `_CatalogSource` enum; category filtering and scope-sensitive selection are in its state/build logic. The screen depends on `scope_resolver_provider`, `pre_reader_provider` and `pre_reader_picture_grid_widget`; `lib/services/scope_resolver.dart` is itself large (~37 KB).
- Phase 0 T1 must prove a **pure, deterministic subproblem can be isolated** without pulling privacy, scoped learnability, provider state or pre-reader routing into a new dependency web. If not proven, **drop or redesign Pilot C**.
- No splitting `scope_resolver.dart` as part of Pilot C. Any future approved extraction must keep trusted/private visibility, context-scoping, accessibility, and navigation contracts intact. Use fast pure tests for extracted predicate logic **and preserve** widget/provider boundary tests.

**Pilot A — third candidate, Q&A characterization first:**

- Shared scaffolding in `_handleReviewQuestion` and `_handleReviewAnswer` (around lines **766–817**) is real but small, and both already use `_handleReviewError` with distinct `targetType`; **do not make a closure helper the pilot** or combine their domain calls.
- `_RejectionDialog` and `_AnswerRevisionDialog` are **already separate classes** near the bottom. The real mass is the large `build`/subview region beginning around **line 1005**. Characterize moderation permissions, audit logs, auth switching and dialog lifecycle first; consider coherent subviews only if parent and child do not have to be co-read and hop-count falls.
- **Do not "clean up" the empty `catch (_) {}` in `_handleAcceptAnswer` under this initiative.** It is a separate behavioral/error-handling issue requiring its own ticket and tests.

**Pilot gate if ever authorized:** same-task before/after whole-file and bounded-range MVCS, file-hops, state/callback width, test mix, retained boundary behavior, code-review independence for sensitive changes and required CI. A clean map outcome or ambiguous benefit means **stop**, not continue to the next pilot.

### Phase 3 — Higher-risk domain boundaries

Proceed only after Phase 2 evidence and separate owner approval. Candidate domains: assessment renderer/grading presentation, Fast preference persistence/CAS sync, taxonomy crosswalk, content ingestion. Build state/contract tests first. Any PR touching **RLS, server grading/answer-key confidentiality, auth/consent, or Fast sync semantics** requires independent reviewer sign-off; a second model such as Claude may assist but does not replace mandatory tests or a qualified human reviewer.

### Phase 4 — Sustainable prevention

1. Keep heavy clone and complexity scans local or advisory/non-blocking until stable and cheap.
2. Add PR checklist items for duplication, dependency hops, deterministic MVCS, unit-test migration and map updates.
3. Ratchet thresholds only after observing false-positive rates and coordinating with `LearningApp_CI_Test_Quality_Optimization_Plan.md`; do not duplicate test matrices.
4. Periodically review empty/orphan files and architecture-map **semantic** accuracy, not only file existence.
5. Maintain optional AI retrieval-ignore profiles across tools, anchored by portable `AGENTS.md` instructions.

**Exit gate:** repeatable savings and safe maintenance, without significant new required-CI latency or agent context overhead.

---

## 7. Metrics and AI benchmark design

### 7.1 Baseline metrics (no invented results)

| Metric | Definition | Interpretation |
|---|---|---|
| Production logical LOC | Nonblank, noncomment lines in hand-maintained source by language | Size indicator, not the main success criterion |
| Validated clone percentage | Confirmed duplicate logical lines / eligible hand-maintained logical lines | Exclude generated, migrations and intentional security checks |
| File cohesion and fan-out | Responsibilities and meaningful dependencies of a module | Detects fragmentation and cross-cutting effects |
| **MVCS context bytes (primary), estimated tokens (secondary)** | UTF-8 bytes for exact files **and bounded ranges** required to safely understand/verify an edit; tokenizer estimate with fixed encoding | **Primary deterministic context-efficiency measure**; tokens are annotated cross-model proxies |
| **Scripted navigation hop-count** | Distinct deterministic route/file/contract transitions to locate owner and verify task (not an observed live agent trace) | Detects potential file-hopping; label scripted vs actually observed |
| **Contract width** | Parameters/callbacks and other parent state dependencies crossed after splitting | Detects prop-drilling disguised as modularity |
| Live discovery trace | File reads, actually loaded tokens, irrelevant context, navigation calls and discovery time | Secondary validation on 3–4 tasks, only if approved |
| Behavioral safety | Targeted and required CI tests; permissions, data and state invariants | Hard pass/fail, not traded for token savings |
| Runtime / test cost | Fast pure unit runs, retained widget/integration tests, CI time, bundle size where relevant | Avoid shifting work into slower or riskier surfaces |

**Byte source (v0.6):** every byte figure is the **Git blob size at the pin**, never a working-tree size; bounded-range bytes are the raw bytes of the selected lines from `git show <pin>:<path>`, each with its stored line ending (a few blobs, e.g. `tool/ingest_curriculum.dart`, are committed with CRLF; no normalisation).

**Counting protocol:** Pin the **actual execution** repository SHA and committer time (not a review-time observation); task statement; written MVCS inclusion rules; actual files, line ranges, tests/fixtures and contracts; instruction surfaces; source classification; and the exact measurement scripts before the first reading. Use **UTF-8 bytes as primary**. For an optional reproducible token proxy use Python `tiktoken` **`o200k_base` encoding** (an OpenAI-family approximation, **not** a universal Gemini/Claude tokenizer), recording its installed library version and hashes before measurement; if unavailable, report tokens as `not_measured` rather than fabricate them. Use the **same estimator and encoding** before/after. Report whole-file and bounded-range footprints separately. Pin source-line convention as Python `splitlines()` (logical text lines; explain difference from `wc -l`'s newline count). Do not count unused on-disk documentation as consumed model context. Include an independently measured **instruction baseline** (`AGENTS.md` and applicable instructions) plus increment from map sections.

**Written Minimum Viable Context Set (MVCS) inclusion rule, frozen pre-measurement:** include (1) the minimum code/callsite required to identify the actual edit owner; (2) each direct data/permission/trust/side-effect contract needed to safely validate the task, including protected §8 invariants; (3) the named tests **and necessary fixtures** that exercise the relevant boundary; and (4) required authoritative policy text—even in an otherwise excluded large document—only for tasks that need it. Exclude unrelated imports, whole plans, generated artifacts and historical migrations **only where no task invariant depends on them**. For every file or bounded range, record *why required*, *why range sufficient*, and notable excluded candidates. A second reviewer should independently check T3 and T7 (or two other risk-diverse tasks) before freeze; record reconciled disagreements. Do not shrink the post-change MVCS by pretending a newly necessary dependency is irrelevant.

### 7.2 Eight approved tasks to freeze + one proposed exception probe

**Freeze before measuring.** T1–T8 are the owner-approved deterministic benchmark scope, but their manifest is **not yet frozen by execution**. The v0.5 review-time SHA `1e67576` does not itself freeze the benchmark; verify the actual execution SHA first. Freeze the corrected T7 and every task/test inclusion rationale before collecting the first context metric. T9 is a **proposed extra** to test default-exclusion exceptions and is **not authorized for measurement** unless the owner expands the deterministic benchmark before freeze. The baseline pin is refreshed at execution (§6). Task semantics must remain unchanged later; a newly required dependency is added, never hidden.

| ID | Fixed representative task | Pinned starting entry point / minimum contract probe | Treatment |
|---|---|---|---|
| **T1** | Locate and safely change **one Library trusted/official/reviewed/mine source filter decision** | `lib/screens/library/library_screen.dart`; `lib/providers/scope_resolver_provider.dart`; `lib/services/scope_resolver.dart`; Library filter and privacy tests | **Refactor-sensitive**; Pilot C feasibility gate |
| **T2** | Locate the **question-versus-answer moderation review message** without changing domain action semantics | `lib/widgets/community/in_context_qa_sheet.dart`; Q&A service and moderation/audit tests | **Refactor-sensitive**; Pilot A characterization |
| **T3** | Locate the **Excel Budget workbook rubric evaluation rule**, with untrusted preview/worker boundary unchanged | `lib/widgets/software_learning/excel_upload_card.dart` **and** `lib/services/software_learning/demo_workbook_reader.dart`; Excel checker/worker/sealed-upload tests | **Refactor-sensitive**; Pilot B gate |
| **T4** | Identify the source of a **single-choice assessment interaction presentation** without changing grading | `lib/widgets/assessment/assessment_item_renderer.dart`; server-grading service and hidden-answer-key tests | **Refactor-sensitive**; protected control |
| **T5** | Trace **offline Fast preference CAS conflict replay** without changing strategy behavior | `lib/providers/learning_strategy_provider.dart`; persistence/sync contracts and tests | **Refactor-sensitive**; protected control |
| **T6** | Locate curriculum-ingestion **test and authority contracts**, with no source modifications | `tool/ingest_curriculum.dart`; `tool/lint_manifest.dart`, `content/schema/curriculum_manifest.schema.json` as contracts; **actual candidate tests** `test/services/curriculum_manifest_test.dart` and `test/tool/curriculum_stable_ids_test.dart` (latter imports ingestion CLI), plus relevant source/SQL checks only if required. **Freeze exact test set and coverage limitations.** | **Navigation/map control**; protected ingestion, no edits |
| **T7** | Trace the **pre-reader picture-grid route, auto-speak preference state, and audio playback entry** from Library; **not global narration controls** | `lib/screens/library/library_screen.dart` → `lib/widgets/literacy/pre_reader_picture_grid_widget.dart` → `lib/providers/pre_reader_provider.dart` → **`lib/services/pre_reader_audio_service.dart`**; `test/services/pre_reader_audio_service_test.dart` and `test/widgets/pre_reader_home_navigation_test.dart` | **Navigation/map control**; corrected pre-freeze to cover actual state and service |
| **T8** | Locate **feature-control owner and server enforcement gate** for a named feature (and BYOK/Fast exclusions) | `AGENTS.md`; `lib/models/governance/site_feature_keys.dart`; `lib/services/governance/site_feature_service.dart`; registry/flag tests and production effect gate as warranted | **Navigation/map control** |

**v0.6 freeze (November 14, 2026):** the owner **approved T9** before measurement, so the benchmark is **T1–T9**. The frozen manifest (`docs/engineering/audits/code_efficiency/data/task_manifest.json`) corrects four starting probes from the table above, because tracing the code showed them to be wrong or incomplete:

- **T1:** `scope_resolver.dart` / `scope_resolver_provider.dart` are **not** used by the source filter (a pure switch on `LearningTarget.isTrustedPublic`/`isOfficial`/`createdBy` and the auth user); the server contract is the `targets_read` RLS policy (`20261009000005_…provenance.sql:103-110`).
- **T3:** the probe misses the **upload checker** `tool/software_learning/excel_budget_total.py` and its trust gate `pilot_pipeline.py`. It and the Dart browser rubric differ on purpose (cached total vs server inputs, per `docs/product/EXCEL_PILOT_SECURITY_RELEASE_GATES.md`), and neither awards skills. Both belong in the MVCS; neither is a copy of the other. (Corrected after the independent review.)
- **T8:** frozen named feature is **`content.refresh_proposals`**; its server gate is SQL (`private.site_feature_enabled` in `propose_contribution_refresh` / `decide_refresh_proposal`), not `site_feature_service.dart`.
- **T9:** destination controls are owned by **`lib/widgets/app_shell.dart`**; `router_provider.dart` only wraps pages in `AppShell`. Test: `direct_access_rule_test.dart` "no nav destination shows a badge".

T7 additionally needs the routed consumer of auto-speak (`life_milestones_screen.dart`) and `pre_reader_literacy_test.dart`. The original v0.5 T9 text follows for the record.

**T9 — (v0.5 text; approved in v0.6):** "Determine whether a badge or count may appear on the **top-level Library navigation destination**, and locate the binding UI architecture rule, distinguishing it from informational counts inside Library." Expected exception-read path: `lib/providers/router_provider.dart` (navigation owner), and **normally excluded** `UI_ARCHITECTURE_LOCKED.md` (B3 erratum around line 108 and prohibition around lines 231 and 875), with any targeted navigation test located at freeze. Expected answer: **no top-level navigation badge; informational in-Library counts are distinct**. T9 is an **excluded-but-required document-path control**. Obtain explicit owner permission to expand from eight to nine *before* taking baseline measurements, or record this unmeasured as a pending coverage gap; never silently call T9 part of the original approved eight.

**Required zero-cost protocol, T1–T8:**

1. Store fixed task prompt, pinned owner entry, exact minimal files **and line ranges**, written §7.1 inclusion/exclusion reasons, direct security/logic contracts, linked tests/fixtures and justification. The table is a **starting probe**, not falsely declared a completed MVCS. In particular, T6's tests are **not absent**; verify whether each candidate tests the relevant authority/ingestion boundary before freeze.
2. Measure **two distinct footprints** before/after any later approved change: (a) full-file context when an agent cannot safely use line reads; (b) bounded-range MVCS including necessary contracts, tests/fixtures and call sites. **Bytes are primary**; compute token approximations only with the pinned tokenizer. Record additional initial `AGENTS.md`/instruction bytes and section-only map cost instead of assuming the entire map is always loaded.
3. Separately calculate **avoidable bytes in a deterministic scripted retrieval set**: unnecessary root plans, irrelevant migrations/fixtures, unrelated UI/providers and repeated instructions. Do **not** call this "actual model-consumed irrelevant tokens" absent approved live traces. Distinguish file existence, default-exclusion *rules*, and evidence of true automatic instruction loading.
4. T1–T5 are **refactor-sensitive**; T6–T8 are **navigation controls** expected to benefit from map/retrieval guidance, **not Pilot B**. If approved, T9 is a separate documentation-exception control. Do not demand Pilot B improvements on navigation controls or cherry-pick a post-move task definition.
5. Capture all required parent/child/provider hops, shared contracts and test ownership; do not quote savings from just the moved evaluator file.
6. Baseline requires **zero live-model calls**. Discovery traces are outside current authorization; later requests require model/tool/budget/trace selection and a separate owner decision.
7. **Map-sufficiency rubric for each navigation/control task (T6–T8 and T9 only if approved):** report (a) scripted hops to first correct owner; (b) avoidable bytes in the scripted retrieval set **before** first correct owner identification; (c) `yes / partial / no` for map-section-only identification of **owner, contract and tests** separately; (d) count and path of any **false-owner candidates**, plus explanation. Record `not_measured` for any real agent field. Compare baseline routing and proposed map/instruction routing under identical task and measurement definitions.
8. **Stop decision:** recommend **no Phase 2 pilot** if map/instruction guidance resolves owner/contract/test identification without false-owner paths, avoids unnecessary broad doc reads, and retains essential exceptions. Escalate unresolved ambiguity or trust-boundary context only with concrete task evidence. No invented percentage threshold; publish per-task data and a written owner-reviewable rationale.

### 7.3 Success thresholds and decision criteria

- Navigation improvement target: **25–40% less irrelevant context** is a **hypothesis only**, not a measured result, promise or approval threshold. Keep absolute bytes/tokens visible and compare the map-only condition before committing to any code move.
- **No file split passes on LOC reduction alone.** It must improve (or at least not worsen) representative task MVCS and hop-count, with clear cohesive ownership; any exception requires explicit rationale and owner sign-off.
- For pure extraction pilots, assess unit-test timing and coverage alongside retained widget/integration coverage; do not infer CI gains without timing.
- Zero accepted regressions in feature parity, privacy, grading, access, persistence and safety-critical policies.
- Never add required CI steps during this audit/draft authorization. Any later CI change depends on the CI v4 restructure being landed or explicitly deferred, with check-name preservation verified.

---

## 8. Hard safety boundaries and preservation rules

These are non-negotiable and align with the existing [`AGENTS.md`](https://github.com/RACCHUS/LearningApp/blob/main/AGENTS.md):

- **No production database changes as part of audit.** Existing merged Supabase migrations are **append-only**; never rewrite, squash, rename, or silently repair history. Any future migration must use the guarded deployment workflow and separate authorization.
- **No weakening of RLS, auth, role checks, privacy consent/erasure, or server-side grading.** Client conveniences cannot replace enforcement at protected boundaries.
- **Answer-key confidentiality and simulation eligibility remain protected.** Do not simplify logic by revealing restricted scoring content or bypassing review gates.
- **Legacy parity:** functional existing features cannot be removed solely because their path looks old. Require an equivalent replacement or explicit approved obsolescence.
- **Feature controls:** retain the `site_feature_controls` and stable feature-key regime; actual server-side effect gates matter more than registry names. BYOK remains independently hard-disabled until reviewed; Fast remains available with appropriate Experimental designation until its separate release criteria are met.
- **Excel:** preserve file trust distinctions, upload/retention controls, rubric accuracy, recovery paths, and any disabled-by-default capability. Moving rubric logic into a pure service must not make untrusted previews authoritative or bypass protected grading boundaries.
- **Offline/remote state:** preserve CAS conflict semantics, replay protection, account separation, durability, and recovery behavior.
- **Curriculum:** preserve official blueprint integrity, provenance, content rights, item privacy, and grading invariants.
- **Do not delete historical documents, migrations, generated files, curriculum, or tests merely to reduce repository bytes.** They can often be excluded from AI retrieval without being removed.
- **No blanket formatter or lint-fix sweep bundled with feature refactors.** Such changes obscure meaningful diffs and make regressions harder to review.
- **Independent review for sensitive changes:** require a review independent of the implementing agent for PRs touching RLS, protected grading, auth/consent or Fast sync/CAS semantics. A second AI opinion alone does not constitute security verification.
- **Test-layer preservation:** extracting pure logic calls for moving deterministic edge-case tests to fast unit scope, not deleting meaningful widget/integration boundary checks.

---

## 9. Recommended implementation workflow once approved

**Branching and authorization:** the owner has **conditionally authorized a Phase 0 baseline and Phase 1 drafts**. At execution, re-pin `main` and create/use `chore/code-efficiency-audit-baseline` for audit artifacts and review diffs only; no direct writes to `main`. Separate approval is needed before applying Phase 1 edits, editing CI or commencing any Phase 2 pilot. For any later authorized PR, rebase to current `main` and re-verify.

**Each refactor PR should contain:**

1. **Problem statement** with paths/line references, verified duplication or coupling evidence.
2. **Before/after behavior contract** including edge cases, authorization, persistence, and UI states.
3. **Measured impact**: exact before/after MVCS whole-file and bounded-range bytes/tokens, navigation hops, contract width, duplicated lines removed (if applicable), changed-file surface and complexity; distinguish evidence from estimates.
4. **Verification**: characterization tests first, new fast pure unit tests where logic was extracted, retained widget/integration assertions, `flutter analyze`, required CI, and feature-specific database/security tests when touched.
5. **Reversibility**: small diff, documented rollback, no production activation side effects.
6. **Decision log**: why a shared abstraction is simpler, or why the candidate was deliberately left alone.

### Suggested developer/agent task protocol

```text
1. Read applicable existing instructions, then only the relevant codebase-map section (once approved/committed), not the whole map by default.
2. Identify the feature owner, authoritative contracts, dependencies, and exact tests.
3. Read only relevant file ranges; expand scope for direct dependencies and security contracts. Default-ignore large root plans, migrations, generated outputs and curriculum data; read them when UI spec, taxonomy, CI, curriculum, migration or security task requires them.
4. Confirm what must not change before editing.
5. Prefer the smallest coherent change; avoid unrelated cleanup.
6. Run targeted tests, analyzer, and required PR checks.
7. Report behavior parity, measured MVCS and hop-count changes, remaining risk,
   and whether the feature map and required test lanes need an update.
```

**What not to do:** “Reduce 30% of lines across the repo,” “delete all unused-looking files,” “replace all duplication with one utility,” or “split everything above 500 lines.” These encourage false savings and regressions.

---

## 10. Risks, trade-offs, and mitigations

| Risk | Why it matters | Mitigation |
|---|---|---|
| Under-abstraction | Many copies drift over time | Extract true repeated policy behind a clear interface |
| Over-abstraction | AI must chase helpers and generics across more files | Count navigation hops; prefer shallow, domain-local abstractions |
| Feature loss | Legacy code can still hold unique capabilities | Behavior parity matrix, caller/route inventory, owner approval |
| Test masking | Simplified fixtures may reduce coverage or clarity | Keep independent failure assertions; characterization tests |
| Security changes disguised as cleanup | Different checks can be intentionally redundant | Formal invariant list, security reviews, regression tests |
| Agent map gets stale | Paths may exist but ownership/authority changes | Structured reference validation plus human semantic review and PR-linked updates; never claim automated semantic proof |
| Noisy CI | False-positive lint/clone reports become ignored | Advisory mode and ratchet from stable baseline |
| Merge conflicts | Ongoing LearningApp development is active | Small PRs, rebase/recheck at time of merge |
| Misleading metrics | Deleting docs, shortening identifiers or measuring only extracted files may fake savings | Count essential callers/contracts/tests, both full-file and bounded-range MVCS; judge task correctness |
| Over-optimistic validator | Parsing all Markdown backticks creates false failures and misses semantic drift | Check structured refs only; benchmark runtime; document validator limits |
| AI quota waste | Many live agents are expensive and noisy | Eight approved zero-LLM MVCS tasks only (T9 pending); separate owner budget required for any future live traces |
| Global instruction contradiction | Copilot `400`/`50` line triggers cause fragmentation despite the new plan | Draft the `Main.instructions.md` correction; apply only after owner sign-off |
| “Trust twin” mistaken for duplication | Excel preview parser resembles evaluator but has a distinct authority boundary | Map both, compare call sites, do not merge with worker or reader |
| Denominator contamination | Seed catalogs and curriculum-as-code inflate duplication estimates | Classify `data-in-lib`/curriculum before duplicate-rate calculation |
| Premature CI step | CI v4 restructuring may alter required check names and latency | Hold validator CI integration until v4 landed or deferred |
| Test mis-sharding | Moving tests solely for speed can lose integration assurances | Move only pure logic cases; preserve boundary/widget tests and coverage |

---

## 11. Suggested audit report format

For each finding, provide:

```yaml
id: EFF-001
category: duplicated-workflow | mixed-responsibility | dead-code |
          dependency | ai-context | documentation
files:
  - path: lib/widgets/community/in_context_qa_sheet.dart
    ranges: ["766-817"]
status: candidate | verified | rejected | approved | implemented
problem: "Repeated question/answer review handling structure"
evidence: "Specific matching control-flow stages; distinct domain calls retained"
impact:
  code_lines: not_measured
  mvcs_full_file_bytes_before: not_measured
  mvcs_range_bytes_before: not_measured
  mvcs_full_file_tokens_secondary: not_measured
  mvcs_range_tokens_secondary: not_measured
  instruction_bytes_baseline: not_measured
  map_section_bytes: not_measured
  scripted_hops_before: not_measured
  scripted_hops_after: not_measured
  avoidable_bytes_before_owner: not_measured
  map_owner_identified: not_measured
  map_contract_identified: not_measured
  map_tests_identified: not_measured
  false_owner_candidates: not_measured
  contract_width_delta: not_measured
  behavior_risk: medium
proposal: "Prefer independent Q&A subviews; only consider closure-based shared scaffold if semantics and hop count justify it"
invariants:
  - "Review permissions unchanged"
  - "Question and answer audit records remain distinct"
tests: []
priority: P2
decision_owner: repository_owner
```

Deliver a human-readable report plus a machine-readable findings inventory. The first audit must explicitly distinguish **verified** findings from **suspicions**.

---

## 12. Owner authorization and approval checkpoints

This table records **actual conditional authorization from the owner** and the Grok review, rather than merely an AI recommendation.

| Gate | Current decision | Restrictions / separate next approval |
|---|---|---|
| **Phase 0 audit** | **Approved with conditions** | Branch `chore/code-efficiency-audit-baseline`, re-pin, top-25 list + denylist, no production/CI/active-instruction changes, small reports |
| **Deterministic MVCS** | **Approved for T1–T8** | Correct T7 *before* freeze, lock inclusion criteria, T6 tests and estimator; T1–T5 refactor-sensitive vs T6–T8 controls; zero live-agent calls |
| **Phase 1 documentation/map/instruction/validator drafts** | **Approved as drafts only** | Map <=250 lines/~20 KB, `AGENTS.md` <=40 touched / <=+20 net lines, Copilot threshold replacement, structured validator design; no merge/activation |
| **Phase 1 applied changes** | **Approved by owner (November 14, 2026)** | Applied in PR #273 (map, `AGENTS.md`, `Main.instructions.md`); merge remains the owner's call |
| **CI edits** | **Not approved** | CI v4 has landed (§2.1b), so the remaining blockers are owner approval and `docs/testing/TEST_QUALITY_POLICY.md` (advisory first; never rename `Analyze, test, and build`) |
| **Pilot B then C then A** | **NOT AUTHORIZED** | First demonstrate map-only insufficiency; B requires trust-twin map; C requires T1 proof; A requires characterization |
| **Legacy, RLS, grading, auth, CAS, migrations, BYOK/Fast** | **No change authorized** | Continue existing hard invariants; independent review on any future relevant PR |
| **Live LLM discovery traces** | **Not approved / no budget** | Separate explicit credit and task authorization needed |
| **T9 excluded-document exception probe** | **Approved by owner (November 14, 2026), before first measurement** | Measured with T1–T8 under the same frozen rules |

### Draft-only execution directive

1. Re-read `main` and record execution-date SHA; do not rely silently on `a458b41` if it changed. Establish an evidence-only audit branch when executing Phase 0.
2. Produce the §2.3 top-25 ranking and classification plus a **separate real churn ranking**, protected denylist and `data-in-lib` exclusion; no proposal to refactor operational/official-ingestion/verification tools.
3. Correct/freeze T7 with the audio service; record T6's actual test set; freeze §7.1 MVCS inclusion rules, churn method, estimator and instruction footprint; measure whole-file/range context **bytes first**. Request a decision on proposed T9 *before* measuring it; do not silently expand the eight authorized tasks.
4. Draft the <=250-line/20-KB codebase map, <=40 touched / <=+20 net `AGENTS.md` guidance, `Main.instructions.md` numeric-threshold replacement and `tool/verify_codebase_map.py` design; **do not apply or activate**.
5. Separate Phase 0 evidence (`docs/engineering/audits/code_efficiency/`) from Phase 1 drafts (`docs/engineering/drafts/code_efficiency/`) on the audit branch until the owner accepts exact diffs. Accepted documents move to `docs/engineering/`, not root. No new CI workflow step, no live-model traces and no Phase 2 changes.
6. Report whether **navigation-only intervention is sufficient**. If yes, recommend stopping code refactoring. Otherwise submit Pilot B/C/A briefs for **new owner sign-off**; do not start them.

**Current session status (v0.6):** Phase 0 has **started** on `chore/code-efficiency-audit-baseline` at pin `06221ed`: re-pin, delta, inventory, top-25, frozen-method churn ranking and instruction-surface bytes are recorded under `docs/engineering/audits/code_efficiency/`. T1–T9 are frozen and measured (`data/mvcs_baseline.json`); the bounded clone scan and a dead-code candidate scan are recorded; **Phase 1 drafts** are in `docs/engineering/drafts/code_efficiency/` (map 188 lines / 14.4 KB; `AGENTS.md` diff 7 touched / +7 net; `Main.instructions.md` cohesion diff; validator design; instruction inventory). Scored against the baseline, the draft map removes every false-owner path and all avoidable whole-file reads in T3, T7, T8 and T9. **Phase 0/1 recommendation: no Phase 2 pilot** (`AI_CONTEXT_BENCHMARK.md` §4). An independent reviewer checked T3/T7 and the map scoring; its additions and corrections are reconciled (§6 of that report). With owner approval, the map and instruction diffs (corrected) are in PR #273, and two missing tests are in PR #274. **Owner decision (2026-11-14):** the recommendations were accepted, with targeted refactoring allowed where it makes sense. #273 and #274 are merged. Follow-ups are open: #275 (pre-reader voice-track fix), #276 (removal of 36 retired unreachable files) and #277 (Q&A audit-log widget extraction). See `AI_CONTEXT_BENCHMARK.md` §4. Still open for the owner: validator/CI activation, the PR-template checkbox, and the 15 unreachable files kept in #276. No CI or migration change has been made.

## 13. Consolidated Gemini Argon + Grok + Z.ai + Qwen review disposition

**Overall decision:** retain the owner’s conditional approval and accept Z.ai’s pre-freeze benchmark corrections and Qwen’s execution controls, except that T9 is a **proposed scope expansion**, not silently approved, and Z.ai’s claim of no T6-related named tests is corrected using repository evidence. Qwen’s “ready for conditional execution” is a reviewer recommendation, **not a new authorization to implement Phase 1 diffs, start Phase 2, or run live agent traces**. The original goal remains **fewer irrelevant tokens, clearer feature ownership, lower edit risk, preserved functionality**—not raw line-count reduction.

**Accepted from Gemini Argon:** cohesion and file-hopping measurements; deterministic zero-LLM MVCS as primary metric; structured map and validator; staged Pilot B → C → A; pure logic unit tests while preserving widget/integration coverage; security, grading, legacy and migration protections.

**Accepted and corrected from Grok:**

- Actual execution SHA must be re-pinned; size-ranked 25 are now published; churn is separate, not fabricated.
- `data-in-lib` and curriculum-as-code are excluded from authored-code clone metrics; operational reset, guarded deployment, official ingestion and `verify_*` are **read-only/no-proposal** domains in Phase 0.
- Always-on context is bounded: ~40 lines of added/changed `AGENTS.md` guidance and **<=250 lines/~20 KB** for the map, read by feature section rather than universally loaded.
- Global Copilot guidance has a real **400/50 line-threshold contradiction**. Phase 1 drafts must propose replacing it with a cohesion/context rule.
- No validator CI step until CI v4 restructuring is settled; no live AI trace budget is assumed.
- T7 now has a **corrected path through `pre_reader_audio_service.dart`**, and its task specifically targets auto-speak/playback entry rather than unrelated global narration UI; T1–T5 and T6–T8 remain separately interpreted.
- Pilot B is a **narrow move of an existing evaluator**, not an extraction from entangled widget code and not a merger with the restricted reader or worker.
- Pilot C can be dropped if scope/private/pre-reader behavior cannot be separated cleanly. Pilot A focuses on build/subview coupling, not small moderation wrappers or already-separated dialog classes.
- The map-only improvement has an explicit **stop condition**: if navigation becomes efficient, avoid premature pilot refactoring.

**Z.ai finding disposition (F1–F8):**

| Finding | v0.4 decision | Concrete change |
|---|---|---|
| **F1 — T7 mismatch** | **Accepted; required** | Fix task text and include playback service and relevant tests before freeze. |
| **F2 — excluded-but-required document** | **Accepted as proposed T9, pending owner authorization** | UI B3 prohibition exercise with explicit retrieval exception; not counted in the eight approved tasks. |
| **F3 — `AGENTS.md` growth** | **Accepted** | <=40 touched lines, <=+20 net; measure instruction baseline. |
| **F4 — churn definition** | **Accepted** | Freeze 90×24h UTC, non-merge commit count and numstat changed lines, with class boundaries. |
| **F5 — MVCS inclusion rules** | **Accepted** | Precommit inclusion/exclusion and review two risk-diverse tasks before freeze. |
| **F6 — map stop evidence** | **Accepted** | Four evidence fields for navigation controls; distinguish scripted from actual agent loads. |
| **F7 — token estimator** | **Accepted with qualification** | UTF-8 bytes primary; optional pinned `tiktoken/o200k_base` proxy, not universal model tokens. |
| **F8 — hygiene** | **Accepted with one correction** | Fix line convention/canonical path/report layout; source links already present in v0.3; **T6-related tests do exist**, though exact coverage remains to be verified. |

**T6 correction to Z.ai:** `test/services/curriculum_manifest_test.dart` imports `tool/lint_manifest.dart`; `test/tool/curriculum_stable_ids_test.dart` imports **both** `tool/ingest_curriculum.dart` and `tool/lint_manifest.dart`; `tool/tests/test_check_algebra_manifest_parity.py` covers a generator-to-manifest parity boundary. These are *candidate contract tests*, not proof of complete ingestion-path coverage. The Phase 0 manifest must freeze which are required, which CI jobs execute them, and any documented gaps.

**Reviewer-reported supporting evidence:** Z.ai says it checked 80 quantitative claims and roughly 40 structural/history checks; its observed empty-file provenance and 14/18/4 pilot churn spot counts are recorded in §§2.1/2.4. No Flutter/Python test runs, real agent context traces, or branch protection configuration were demonstrated by that review. Avoid recasting those reports as author-run verification.

**Qwen review disposition (v0.5):**

| Qwen observation | Decision | Concrete plan treatment |
|---|---|---|
| `main` advanced to `1e67576` | **Verified; important** | §2.1a records 10 commits, 23 files and new inventory; Phase 0 must still re-pin and compare at actual execution time |
| 400/50-line Copilot instruction conflict persists | **Verified; retain** | Preserve the Phase 1 **proposed** cohesion/hop-count diff; do not edit the instruction file under draft-only approval |
| Pilot B trust twin; pilot A/C coupling | **Verified existing constraints** | Keep pilots held; no evaluator/reader merge, filter extraction or subview split without owner gate |
| T9 remains unmeasured until owner authorizes ninth task | **Accepted literally** | Keep T9 separate and explicitly `not_measured`; T1–T8 only |
| Validator must ignore arbitrary Markdown backticks | **Accepted and made concrete** | Draft `map-ref` grammar only; no validator code or CI activation |
| If `tiktoken/o200k_base` is unavailable, do not substitute estimators | **Already in v0.4; reaffirmed** | UTF-8 bytes primary, optional pinned token proxy, otherwise `not_measured` |
| Proceed with Phase 0/Phase 1 drafts and halt for owner | **Within existing conditional authorization, but not executed by this review** | Branch, scripts, map draft and analysis are future authorized work only; no work starts merely because a review recommends it |

**Review-time CI nuance:** PRs #241–#244 introduce CI and algebra checks, but the checked workflow still has the named `verify` and `verify-database` jobs. That observation does **not** establish branch-protection requirements or completion of every CI v4 initiative. The “no CI edits” restriction remains absolute for this phase.

**Qualified rather than accepted literally:** path validation is not semantic ownership validation; sub-second validator runtime requires measurement; `git log -S` only finds meaningful string additions/removals, not an empty file's provenance; even a clean extraction may require several files to understand critical privacy/trust contracts; no second AI model replaces tests or qualified independent review.

**Next action after reviewing v0.5:** at authorized execution, re-pin `main` (review-time `1e67576` may already be stale), report the reviewed `a458b41` → current `HEAD` delta, fix/freeze T7 and written MVCS/churn/estimator rules, and request an owner decision on T9. Then execute only the already conditionally approved **Phase 0 evidence-gathering and Phase 1 draft preparation**, returning findings and drafts for a new owner decision. **Do not automatically move into Phase 2**.

**v0.6 disposition (execution re-pin, November 14, 2026):**

| Change | Reason |
|---|---|
| Pin `06221ed`; §2.1b delta table | v0.5's `1e67576` was 67 commits stale at execution |
| CI hold re-based on `TEST_QUALITY_POLICY.md` | CI v4 (PR-1..PR-9) has landed; required check is now the `Analyze, test, and build` gate job |
| Git-blob bytes mandated (§7.1) | `core.autocrlf=true` inflates working-tree bytes on the owner's checkout |
| `router_provider.dart` recorded as map priority | Highest frozen-method churn; absent from v0.5 candidate lists |
| Plan file itself flagged for relocation | It is now the 5th-largest root Markdown file |
| Stale "v0.4 revision" status line replaced | Text drift |

| T9 approved; nine tasks frozen and measured; four probes corrected (§7.2) | Owner decision; code tracing showed false-owner probes in T1, T3, T8, T9 |

Unchanged: Phase 2 remains unauthorized; no live traces.

---

### Source links for reviewers

- [Historical baseline commit `a458b41`](https://github.com/RACCHUS/LearningApp/commit/a458b4138719811e441dd75268bd354d0125d302)
- [Qwen-review-time `main` commit `1e67576`](https://github.com/RACCHUS/LearningApp/commit/1e6757678b8311dfc7f4814e4e17699498c28792)
- [Exact `a458b41...1e67576` change comparison](https://github.com/RACCHUS/LearningApp/compare/a458b4138719811e441dd75268bd354d0125d302...1e6757678b8311dfc7f4814e4e17699498c28792)

- [Repository main](https://github.com/RACCHUS/LearningApp/tree/main)
- [Agent/developer rules](https://github.com/RACCHUS/LearningApp/blob/main/AGENTS.md)
- [Current Flutter analysis options](https://github.com/RACCHUS/LearningApp/blob/main/analysis_options.yaml)
- [Current Flutter CI](https://github.com/RACCHUS/LearningApp/blob/main/.github/workflows/flutter-ci.yml)
- [Existing CI efficiency plan v4](https://github.com/RACCHUS/LearningApp/blob/main/LearningApp_CI_Test_Quality_Optimization_Plan.md)
- [Global Copilot instructions with line-count triggers](https://github.com/RACCHUS/LearningApp/blob/main/.github/instructions/Main.instructions.md)
- [Restricted preview Excel reader](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/software_learning/demo_workbook_reader.dart)
- [PR template: feature-preservation controls](https://github.com/RACCHUS/LearningApp/blob/main/.github/pull_request_template.md)

*End of v0.6 — conditional-approval plan with Phase 0 execution started. No live-agent traces, CI edits or Phase 2 implementation performed.*