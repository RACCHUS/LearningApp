# AI Context Benchmark — deterministic MVCS baseline (T1–T9)

**Pin:** `06221ed6f9ef617113f76d0ddd072c20a0042250`. **Manifest:** `data/task_manifest.json` (frozen 2026-11-14; T9 owner-approved before measurement). **Results:** `data/mvcs_baseline.json`. **Script:** `scripts/measure_mvcs.py`.
**Bytes (primary):** raw Git blob bytes; every whole-file figure was cross-checked against `git cat-file -s`. **Tokens (secondary):** `tiktoken` 0.9.0, `o200k_base`, ranks SHA-256 `11ab290e…3bef36` (an OpenAI-family proxy, not Claude/Gemini tokens). **Live model calls:** 0.
**Conditions measured:** baseline (current instructions, no map) in §§1–2; draft-map condition in §3.

## 1. MVCS footprints

| Task | Kind | Files | Whole-file bytes | Bounded-range bytes | Range / whole | Range tokens |
|---|---|---:|---:|---:|---:|---:|
| T1 Library source filter | refactor-sensitive | 5 | 87,102 | 7,428 | 8.5% | 1,551 |
| T2 Q&A review message | refactor-sensitive | 3 | 178,919 | 9,638 | 5.4% | 2,166 |
| T3 Excel Budget rubric | refactor-sensitive | 10 | 123,937 | 47,007 | 37.9% | 10,843 |
| T4 Single-choice presentation | refactor-sensitive | 5 | 84,202 | 20,344 | 24.2% | 4,365 |
| T5 Fast CAS replay | refactor-sensitive | 5 | 104,655 | 41,999 | 40.1% | 9,811 |
| T6 Ingestion contracts | navigation | 8 | 161,241 | 20,697 | 12.8% | 5,152 |
| T7 Pre-reader route/audio | navigation | 11 | 149,023 | 24,986 | 16.8% | 5,389 |
| T8 Feature gate | navigation | 7 | 40,327 | 8,183 | 20.3% | 1,795 |
| T9 Nav badge rule | navigation + excluded doc | 4 | 125,956 | 5,404 | 4.3% | 1,148 |

Reading the table: the gap between whole-file and bounded-range bytes is what an agent saves by **reading ranges instead of whole files**, given it already knows where to look. It is largest for the two biggest files (T2: Q&A sheet 100,717 B, of which the review handlers are ~2.9 KB; T9: `UI_ARCHITECTURE_LOCKED.md` 79,012 B, of which three rule lines are 920 B). T3 and T5 are dense: much of the owner file is genuinely needed.

## 2. Scripted baseline routing (no map)

Route rule: follow the v0.5 §7.2 starting probe as whole-file reads; when it misses the owner, one grep for the task's key identifier, then the hit. Avoidable bytes = bytes read before the first correct owner that are outside the MVCS ranges.

| Task | Hops to owner | File reads | Route bytes | Avoidable before owner | False-owner candidates |
|---|---:|---:|---:|---:|---|
| T1 | 1 | 1 | 50,609 | 0 | `scope_resolver.dart`, `scope_resolver_provider.dart` (37,825 B named by the probe, not needed) |
| T2 | 1 | 1 | 100,717 | 0 | — |
| T3 | 4 | 3 | 58,699 | **39,787** | treating the two rubrics as copies that must match |
| T4 | 1 | 1 | 49,617 | 0 | — |
| T5 | 1 | 1 | 43,442 | 0 | — |
| T6 | 1 | 1 | 59,126 | 0 | — |
| T7 | 2 | 5 | 80,715 | **50,262** | — (probe incomplete: misses the auto-speak consumer) |
| T8 | 5 | 4 | 25,744 | **12,544** | `site_feature_service.dart` |
| T9 | 2 | 3 | 115,809 | **29,108** | `router_provider.dart` as destination owner |

## 3. Map-sufficiency rubric (baseline vs draft map)

Map condition: read one section of `drafts/code_efficiency/CODEBASE_MAP.md` plus its "How to use" block (441 B), then follow the section. Same route rules as §2. Data: `data/map_condition.json`. Scored by the plan author; the independent reconciliation is in §6.

| Task | Hops to owner (base → map) | Avoidable bytes (base → map) | Map section cost | Map: owner / contract / tests | False owners (base → map) |
|---|---|---|---:|---|---|
| T6 | 1 → 2 | 0 → 0 | 753 B | yes / yes / yes | 0 → 0 |
| T7 | 2 → 2 | **50,262 → 0** | 986 B | yes / yes / yes | 0 → 0 |
| T8 | 5 → 4 | **12,544 → 0** | 938 B | partial / yes / partial | 1 → 0 |
| T9 | 2 → 2 | **29,108 → 0** | 1,000 B | yes / yes / yes | 1 → 0 |
| T1 (refactor-sensitive) | 1 → 2 | 0 → 0 | 917 B | yes / yes / partial | 2 → 0 |
| T3 (refactor-sensitive) | 4 → 2 | **39,787 → 0** | 1,174 B | yes / yes / yes | 1 → 0 |

T8 is `partial` because the section gives a rule ("grep the key in `supabase/migrations/`") rather than the specific migration; this is deliberate, since the section serves every feature key. T1 tests are `partial` because the known test gap is stated rather than filled. These are the author's draft scores; the independently reconciled scores for T3, T7, T8 and T9 are in §6. The map adds one hop when the probe already started at the owner (T1, T6); it costs under 1.7 KB per task including "How to use".

## 4. Stop decision (plan §7.2 step 8)

The draft map resolves owner, contract and tests for all four navigation controls with **no false-owner path** and no avoidable whole-file reads, and it also removes the false owners found in two refactor-sensitive tasks (T1, T3). The remaining context cost in T2–T5 is in genuinely needed code that range reads already handle.

**Recommendation: no Phase 2 code pilot.** Pilot B (Excel move) would not fix T3's real problem, which is navigation: two rubrics whose difference is intentional. Pilot C's predicate is pure but has no test; a test, not a split, is the next step. Pilot A has no task evidence that a split would cut context. Separate, owner-decided follow-ups instead: apply the map and instruction diffs; add the missing tests (two done in PR #274); review the dead-code candidates in `CODE_EFFICIENCY_BASELINE.md` §9.

**Owner decision and outcome (2026-11-14).** The owner accepted the recommendations and allowed targeted refactoring where it makes sense, rather than a strict no-refactor rule. Follow-ups:

| PR | Change | Status at writing |
|---|---|---|
| #273 | Codebase map, `AGENTS.md` guidance, cohesion rule in `Main.instructions.md` | Merged |
| #274 | Tests: Library source filtering; Q&A review confirmations | Merged |
| #275 | Fix: Library pre-reader grid narrates in the learner's track and rate | Merged |
| #276 | Remove 36 retired Dart files unreachable from the app (224 KB); 15 other unreachable files kept for an owner decision | Open |
| #277 | Refactor: Q&A moderation audit log extracted into `QaAuditLogList` (pure move, three read-only inputs) | Merged |
| #278 | `tool/verify_codebase_map.py` (advisory CI step) and PR-template map checkbox | Open |

The one refactor done (#277) is the piece of the Q&A sheet that passes the cohesion rule: no callbacks, no `setState`, three inputs. The sheet's other tabs share loading, auth-switch and dialog state, so they were left in place. No pilots B or C.

## 5. Findings (verified at the pin)

1. **Four of nine v0.5 starting probes pointed at a wrong or partial owner** (T1, T3, T8, T9). These are the cases a map fixes directly; none needs a code move.
2. **T3 two rubrics, on purpose** (corrected by the second review, §6): the browser preview rubric (`excel_upload_card.dart`, cached total vs fixed demo inputs) and the upload checker (`tool/software_learning/excel_budget_total.py`, called only via `pilot_pipeline.py`; ignores the cache, uses server inputs) differ deliberately per `docs/product/EXCEL_PILOT_SECURITY_RELEASE_GATES.md`. Neither awards skills. The v0.5 probe misses the upload checker entirely. This is a map entry, not a refactor, and it strengthens Pilot B's "do not merge" rule.
3. **T7:** the Library picture grid never reads `autoSpeakScreens`; routed screens do. The second review also found the grid calls `speak()` without the learner's track, so it always uses the default adult track and rate (`pre_reader_picture_grid_widget.dart` 156, 240). This is a possible bug, recorded here and not fixed.
4. **Test gaps found while freezing:** T1 had no test of what each source value shows, and T2 had no test of the review message text; both are now covered in PR #274. T6's ingestion transport has no direct test (still open).
5. **Range reads matter more than file splits** for T1, T2 and T9: bounded ranges are 4–9% of whole-file bytes with no code change.

## 6. Independent second review (T3, T7, map scoring)

A separate reviewer agent derived T3 and T7 from the task text alone, then compared its answer with the manifest and scored the draft map. Raw scores: `data/map_condition.json` (`reconciled_draft`).

- **T3:** accepted additions `pilot_pipeline.py` (the checker's only caller and trust gate), the spec `data/software_learning/excel_budget_total_v1.json`, policy lines 27-35 of the release-gates doc, and the card's trust-binding tests. Accepted the correction that the two rubrics differ on purpose. MVCS grows from 36,311 to 47,007 range bytes.
- **T7:** accepted additions of the full tile range (29-110, including `/literacy`), the `preReaderProvider` definition, the profile default, router query parsing, `life_domains_screen.dart` and `phase_5_pwa_ux_test.dart`. Removed `pre_reader_home_navigation_test.dart`, which tests Learn, not the Library grid. MVCS grows from 20,856 to 24,986 range bytes.
- **Draft map scores, reconciled:**

| Task | Owner | Contract | Tests | False-owner leads |
|---|---|---|---|---|
| T3 | yes | partial | partial | 1 ("change both together") |
| T7 | partial | yes | partial | 0 |
| T8 | yes | partial | partial | 0 |
| T9 | yes | yes | yes | 0 |

  T9 caveat: its test only checks `find.byType(Badge)`.
- **Corrections applied** to the map in PR #273 (Excel, feature-gate and pre-reader sections). The author re-scores the corrected map yes/yes/yes for T3, T7 and T8; that re-score has not been re-reviewed.
- **Dropped:** the proposed Dart/Python Excel parity test. Its premise was wrong.

The stop decision (§4) is unchanged. The review found map omissions, not cases needing code moves.

## 7. Limits

- T3 and T7 ranges were checked by an independent reviewer (§6). The other seven tasks were frozen by one author.
- Scripted routes are deterministic stand-ins, not observed agent behaviour.
- Tokens are a proxy; bytes are the comparison metric.
