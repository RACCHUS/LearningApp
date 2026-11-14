# AI Context Benchmark — deterministic MVCS baseline (T1–T9)

**Pin:** `06221ed6f9ef617113f76d0ddd072c20a0042250`. **Manifest:** `data/task_manifest.json` (frozen 2026-11-14; T9 owner-approved before measurement). **Results:** `data/mvcs_baseline.json`. **Script:** `scripts/measure_mvcs.py`.
**Bytes (primary):** raw Git blob bytes; every whole-file figure was cross-checked against `git cat-file -s`. **Tokens (secondary):** `tiktoken` 0.9.0, `o200k_base`, ranks SHA-256 `11ab290e…3bef36` (an OpenAI-family proxy, not Claude/Gemini tokens). **Live model calls:** 0.
**Condition measured:** baseline only (current instructions, no codebase map). The map condition is `not_measured` until the Phase 1 map draft exists.

## 1. MVCS footprints

| Task | Kind | Files | Whole-file bytes | Bounded-range bytes | Range / whole | Range tokens |
|---|---|---:|---:|---:|---:|---:|
| T1 Library source filter | refactor-sensitive | 5 | 87,102 | 7,428 | 8.5% | 1,551 |
| T2 Q&A review message | refactor-sensitive | 3 | 178,919 | 9,638 | 5.4% | 2,166 |
| T3 Excel Budget rubric | refactor-sensitive | 6 | 76,098 | 36,311 | 47.7% | 8,516 |
| T4 Single-choice presentation | refactor-sensitive | 5 | 84,202 | 20,344 | 24.2% | 4,365 |
| T5 Fast CAS replay | refactor-sensitive | 5 | 104,655 | 41,999 | 40.1% | 9,811 |
| T6 Ingestion contracts | navigation | 8 | 161,241 | 20,697 | 12.8% | 5,152 |
| T7 Pre-reader route/audio | navigation | 8 | 103,611 | 20,856 | 20.1% | 4,442 |
| T8 Feature gate | navigation | 7 | 40,327 | 8,183 | 20.3% | 1,795 |
| T9 Nav badge rule | navigation + excluded doc | 4 | 125,956 | 5,404 | 4.3% | 1,148 |

Reading the table: the gap between whole-file and bounded-range bytes is what an agent saves by **reading ranges instead of whole files**, given it already knows where to look. It is largest for the two biggest files (T2: Q&A sheet 100,717 B, of which the review handlers are ~2.9 KB; T9: `UI_ARCHITECTURE_LOCKED.md` 79,012 B, of which three rule lines are 920 B). T3 and T5 are dense: much of the owner file is genuinely needed.

## 2. Scripted baseline routing (no map)

Route rule: follow the v0.5 §7.2 starting probe as whole-file reads; when it misses the owner, one grep for the task's key identifier, then the hit. Avoidable bytes = bytes read before the first correct owner that are outside the MVCS ranges.

| Task | Hops to owner | File reads | Route bytes | Avoidable before owner | False-owner candidates |
|---|---:|---:|---:|---:|---|
| T1 | 1 | 1 | 50,609 | 0 | `scope_resolver.dart`, `scope_resolver_provider.dart` (37,825 B named by the probe, not needed) |
| T2 | 1 | 1 | 100,717 | 0 | — |
| T3 | 4 | 3 | 58,699 | **39,787** | `excel_upload_card.dart` treated as the sole rubric owner |
| T4 | 1 | 1 | 49,617 | 0 | — |
| T5 | 1 | 1 | 43,442 | 0 | — |
| T6 | 1 | 1 | 59,126 | 0 | — |
| T7 | 2 | 5 | 80,715 | **50,262** | — (probe incomplete: misses the auto-speak consumer) |
| T8 | 5 | 4 | 25,744 | **12,544** | `site_feature_service.dart` |
| T9 | 2 | 3 | 115,809 | **29,108** | `router_provider.dart` as destination owner |

## 3. Map-sufficiency rubric (navigation controls)

| Task | (a) hops | (b) avoidable B | (c) map: owner / contract / tests | (d) false owners |
|---|---:|---:|---|---|
| T6 | 1 | 0 | not_measured | 0 |
| T7 | 2 | 50,262 | not_measured | 0 |
| T8 | 5 | 12,544 | not_measured | 1 |
| T9 | 2 | 29,108 | not_measured | 1 |

Column (c) is filled when the Phase 1 map draft is scored under the same rules.

## 4. Findings (verified at the pin)

1. **Four of nine v0.5 starting probes pointed at a wrong or partial owner** (T1, T3, T8, T9). These are the cases a map fixes directly; none needs a code move.
2. **T3 trust twin:** the authoritative Budget rubric is Python (`tool/software_learning/excel_budget_total.py`, 113 lines); the Dart evaluator is an unverified client copy. No test checks the two agree. This strengthens Pilot B's "do not merge" rule and is a map entry, not a refactor.
3. **T7:** the Library picture grid never reads `autoSpeakScreens`; routed screens do. A map entry would say so in one line.
4. **Test gaps found while freezing** (documented, not fixed): T1 has no test of what each source value shows; T2 has no test of the review message text; T6's ingestion transport has no direct test.
5. **Range reads matter more than file splits** for T1, T2 and T9: bounded ranges are 4–9% of whole-file bytes with no code change.

## 5. Limits

- Ranges are frozen by one author; the plan's second-reviewer check of T3 and T7 is **pending** and may add or remove ranges (additions are recorded, never hidden).
- Scripted routes are deterministic stand-ins, not observed agent behaviour.
- Tokens are a proxy; bytes are the comparison metric.
