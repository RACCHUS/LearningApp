# LearningApp — CI Efficiency and Test-Quality Improvement Plan (v4.1, Argon + Grok + Qwen + local re-verification)

**Document status:** Reviewed implementation plan; **PR-1 to PR-9 implemented** (see §0C.3 status tracker; open follow-ups listed there). Current policy lives in `docs/testing/TEST_QUALITY_POLICY.md`. No production systems are touched by any phase.  
**Reviews incorporated:** Gemini Argon, Grok, and Qwen technical reviews; relevant findings checked against `main` on 2026-11-12; decisions in §0, §0A and §0B; **local checkout re-verification and implementation decisions in §0C**.  
**Baseline date:** 2026-11-12  
**Last reviewed GitHub branch:** `main` at `a458b41` (local checkout re-verification, 2026-11-12)  
**Repository:** [`RACCHUS/LearningApp`](https://github.com/RACCHUS/LearningApp)  
**Implementation branch:** `chore/ci-test-quality-optimization`  
**Scope:** GitHub Actions, Flutter/Dart tests, Python/tooling tests, Supabase/pgTAP tests, integration and browser tests, test observability, branch-check compatibility, and safe CI cost/performance optimizations.  
**Out of scope:** Production database deployment; changing application behavior solely to make tests green; lowering security/privacy/assessment controls; enabling BYOK or other unreleased features; removing still-needed functionality.

---

## 0. Argon review: incorporated decisions and corrections (2026-11-12)

**Verdict:** Adopt the high-value repository-specific adjustments, but do not carry forward several unverified assumptions or treat aggressive performance claims as guarantees. This document is the consolidated plan; the original requirements remain in force unless explicitly superseded below.

| Argon point | Decision | Reason / explicit implementation rule |
|---|---|---|
| Preserve the three branch-required check names | **Adopt as a hard compatibility constraint; protection configuration not independently readable** | GitHub workflow files now confirm **all three job-name strings**, including the taxonomy job in `.github/workflows/taxonomy-official-data.yml`. The GitHub App returns **403** for `branches/main/protection`; direct confirmation of the selected required-check settings was not available. Treat names as fixed and verify through a real test PR before merge. |
| Private repository / paid runner-minutes | **Correct** | GitHub repository metadata currently says `visibility=public` / `private=false`. Standard hosted GitHub Actions runners in public repositories are **free** per GitHub policy; larger runners/storage and any later switch to private have different economics. Efficiency is still desirable. |
| Parallel job overhead / shard cost | **Adopt the measurement principle, not the asserted 45–75-second or doubled-consumption numbers** | Cold-start/cache tax varies. Compare actual elapsed and aggregate job-runtime metrics; never infer a cost multiplier from estimates. |
| `flutter test --concurrency` experiment first | **Adopt** | Check current 3.47.7 defaults with `flutter test --help` and run controlled benchmarks (e.g. 2/4/6/8 subject to runner CPU/memory). Avoid assuming concurrency is currently off. |
| 50k synthetic export probe is the full-suite bottleneck | **Reject this diagnosis** | Workflow runs it in a **separate** `flutter test --dart-define=EXM_STRESS=true` step. In sampled logs it takes about **9 seconds**; the full suite had already taken 3m24s–4m19s. Maintain the separate stress gate. |
| Algebra tests must verify the actual shipped content | **Adopt and elevate to P0** | Load an authoritative versioned manifest/derived release artifact and use stable item IDs; do not compute only independent hardcoded mathematical examples. |
| Add pytest/SymPy inside existing Python/Flutter job | **Adopt as initial topology** | Avoid new VM while repairing discovery; benchmark actual package installation/runtime. Keep pinned dependency versions. |
| Reuse existing Supabase job for live Dart↔DB integration | **Adopt** | Supabase starts in the DB job, not the Flutter analyze/test job. No second Docker stack for PR-3; add Dart/Flutter deps only as required on the existing DB runner. |
| Run simultaneous `flutter build web` with `-o` paths | **Partially adopt / correct** | Different `-o` paths protect `build/web`, but the build may also write shared `.dart_tool`/other mutable state. **Do not execute concurrent builds in the same checkout** unless all relevant mutable paths are isolated and proven race-free. Separate jobs/worktrees or keep sequential. |
| Automatically skip one web build on draft PRs | **Conditional only** | Early draft feedback may be lighter, but before a PR becomes mergeable, **both** variants must be verified for the exact reviewed SHA under the existing required-check policy. No false green. |
| Replace Supabase reset with `CREATE DATABASE ... TEMPLATE` in ~2 seconds | **Reject as an immediate fix** | Unverified timing and **not automatically equivalent** to full Supabase local rebuild, roles, extensions, storage, seed, migration ledger, and historical upgrade paths. Treat snapshots as isolated R&D only after rigorous equivalence proof. |
| Flutter web requires accessibility semantics for Playwright locators | **Adopt** | Flutter docs specify opt-in accessibility via the invisible **Enable accessibility** control or `SemanticsBinding.instance.ensureSemantics()`. Verify on Flutter 3.47.7; avoid hardcoding a brittle internal shadow-DOM selector as the primary contract. |
| Keep PR browser suite to 2–3 journeys | **Adopt** | Cover guest navigation/pre-reader routing, lesson create/readback in disposable backend, and simulated assessment safety. Expand only when deterministic. |
| Use GitHub Job Summary + JSON test reporting | **Adopt** | Prefer `$GITHUB_STEP_SUMMARY` and `flutter test --file-reporter=json:<path>` once verified against pinned Flutter. No dashboard or recurring artifact hoard as a prerequisite. |

**Exact check names to preserve (current job names verified; branch-protection configuration reported but not directly readable):**

1. `Validate official taxonomy sources`
2. `Analyze, test, and build`
3. `Verify clean Supabase migrations and complete official taxonomy ingestion`

The **second and third** names are in `.github/workflows/flutter-ci.yml`; **the first, `Validate official taxonomy sources`, is confirmed in `.github/workflows/taxonomy-official-data.yml`** under job `official-taxonomy`. This confirms job names, **not** the protected branch's selected required-check list.

**Required fan-in rule if/when jobs are split:** the single final status-check job **must** be named `Analyze, test, and build`, must depend on **every required child check**, must execute after upstream failures/skips (`if: ${{ always() }}`), and must **fail** unless all required `needs.*.result` values are exactly `success`. A cancelled or skipped required job is **not** acceptable, even though GitHub branch protection can treat a skipped check as satisfied. The DB and taxonomy check names must remain distinct and unchanged. Do not introduce multiple jobs with the same check name across workflows.

**Public-repository cost guardrail:** prefer free standard `ubuntu-latest` runners; do not silently switch to paid larger runners or paid third-party CI. Still measure aggregate runner-seconds, artifact/cache storage, concurrency limit, rerun waste, and future private-repository portability. If visibility changes, re-evaluate billable Actions usage **before** applying matrix expansions.

**Primary implementation recommendation:** proceed in small PRs beginning with **PR-1 (lean measurement)** and **PR-2 (activate actual-content math oracle + enforce test inventory)**. PR-2 may precede the broader instrumentation work if a clean baseline is already available. Do not start with sharding.

---

## 0A. Grok review: repository-verified corrections and PR-2 implementation contract (2026-11-12)

**Decision:** **Adopt.** Grok identifies the most important remaining correctness issue: merely enabling the existing College Algebra `pytest` file does **not** establish mathematical accuracy of the actual shipped curriculum. The source modules, YAML generator, manifest, Dart mapper, schema, and database ingestion must form one verified contract. These requirements supersede any looser wording elsewhere in this document.

### 0A.1 Findings checked against current `main`

| Finding | Verified outcome | Implementation consequence |
|---|---|---|
| The CI workflow explicitly enumerates Python tests | 44 `tool/tests/test_*.py` files; 43 named in the CI steps; only `test_clep_algebra_math_accuracy.py` omitted | PR-2 must collect and **execute** the missing suite and install its pinned dependencies; inventory guard prevents future orphaned suites |
| Algebra pytest currently reads Python authoring objects | Imports the four `DOMAIN_0*` modules plus `FORMATIVE_QUESTIONS_BY_LESSON` | Its passing result cannot independently guarantee `content/clep_college_algebra.yaml` is correct |
| Existing algebra test is order-dependent | Uses `items[22]`, `items[7]`, etc., and hardcoded SymPy expressions | Replace positional identity with stable authored IDs and bind expected mathematics to the **actual** selected manifest option |
| No CI generator↔manifest parity gate | CI runs `tool/clep_content_pipeline.py --manifest content/clep_college_algebra.yaml --require-simulation`, but does not compare the YAML against a freshly generated result | Add a read-only deterministic generator check that fails on canonical data drift |
| IDs cannot just be added to both item types | `content/schema/curriculum_manifest.schema.json` defines both `AssessmentItem` and `LegacyQuestion` with `additionalProperties: false`, and neither permits `id` | Explicitly extend **both** definitions and their validation/test contracts |
| Top-level IDs can be lost during ingestion | `tool/ingest_curriculum.dart` builds an explicit item map without copying `item['id']`; SQL `assessment_items` ingestion copies `metadata`, not a top-level `id`; legacy `questions` ingestion does not persist a source ID | Specify *where* source IDs survive. For simulation items, intentionally map ID into metadata or another approved field; for formative items, decide whether IDs remain manifest-only or need an additive persistence contract, and test the chosen design |
| CI dependencies for math suite are not pinned | No repo-managed pytest/SymPy test lock/requirements file was identified in the reviewed paths; CI currently installs `PyYAML>=6.0` | Add reproducible, pinned test dependencies; **replace** the floating PyYAML install in the affected CI step rather than relying on the preinstalled image |
| Database workload is substantial | `verify-database` timeout is 20 minutes; **four** `supabase test db` invocations (incremental upgrade, historical backfill, clean reset, post-ingestion); `supabase/tests` contained **67** SQL files at Grok review time and **68** on 2026-11-12 re-check | Do not add a second database stack; instrument headroom and protect all four invocations before PR-3 |
| Existing runners and check names | Flutter `3.47.7`, Supabase CLI `2.67.1`; required-looking job names unchanged | PR-1 and PR-2 add steps to existing jobs and do not rename required checks |
| Repository visibility | GitHub reports `visibility=public` | Standard hosted runner compute is currently free; aggregate runner-seconds and storage still matter, especially if visibility changes |

The historical **2,585 Flutter passes, 4 skips, 1,709 pgTAP assertions, and 66 pgTAP files** are **sample-run observations**, not immutable current totals. The *current* directory contains 67 SQL test files. Do not replace those prior log measurements with current file counts without recording both contexts.

### 0A.2 Mandatory PR-2 dependency chain (one reviewable PR; no sharding)

1. **Define a stable source identity contract:** Give each of the 60 simulation items and 40 formative questions a meaningful, immutable `id`/`source_item_id` based on course and semantic intent, not array position, current answer index, prompt hash, or a generated UUID that changes between builds. Define a uniqueness scope (course + target version + item type); IDs survive harmless reordering and editorial changes. Use deliberate versioning/retirement on semantic replacement.
2. **Author IDs where content is actually authored:** Add IDs to the four Algebra domain modules and formative-question authoring source, then let the generator preserve them in YAML. **Never add IDs only to generated YAML**, which a later generator run would delete.
3. **Extend both JSON Schema definitions:** Add an explicit, **optional** nonempty string `id` to the `properties` of `AssessmentItem` and `LegacyQuestion`, preserving `additionalProperties: false`; **do not** add `id` to their global `required` lists. Enforce well-formed, unique IDs **only for College Algebra** in target-aware `tool/lint_manifest.dart` and generator checks while Psychology and other unmigrated manifests remain compatible. Test invalid/duplicate IDs and unrelated manifests without IDs.
4. **Specify ingestion propagation:** Validate `tool/lint_manifest.dart` and `tool/ingest_curriculum.dart --dry-run` accept and validate IDs. The Dart mapper currently reconstructs assessment items and drops top-level IDs; map the stable ID into a deliberate, nonsecret metadata field when appropriate and add assertions on the outgoing payload. For formative questions the current DB write does not preserve a source ID; if persistence is required, design and test an additive database change in a separately reviewed migration. **Do not mistake schema acceptance or a green dry run for persistent identity.**
5. **Add read-only generator parity:** Refactor or wrap `tool/generate_clep_algebra_course.py` with a deterministic `--check`/`--output <temporary-path>` capability; do **not** overwrite `content/clep_college_algebra.yaml` as a side effect of CI. In an isolated generator process, generate a temporary YAML file, `yaml.safe_load` both it and the committed YAML, then compare the resulting objects (`generated == committed`). Ignore only nonsemantic formatting and mapping key order; **array ordering, options, answer keys, IDs, data types and values must match exactly**. Byte equality is a supplemental diagnostic, not the primary gate. Run generation twice or in isolated interpreters to detect nondeterminism or shared-object mutations.
6. **Build independent oracle metadata keyed by ID:** For each authored item, bind the **current YAML prompt, answer options, domain assumptions, and canonical answer** to an independently reviewed math/logic oracle. For symbolic forms use SymPy equivalence under explicit domains; for numeric/word/conceptual questions use independently derived expected outcomes and appropriate unit/rounding/exclusion checks. Do **not** calculate the expected answer from the item's own `correct_index`.
7. **Protect against prompt drift:** Where prompts are not reliably machine-parseable, maintain an independently reviewed prompt-contract fingerprint, structured semantic parameters, or human-reviewed specification. Any changed meaning must fail or trigger mandatory oracle review. A hardcoded SymPy computation unrelated to the text must not count as passing this requirement.
8. **Check actual selected options and distractors:** Resolve `selected = yaml_item['response_spec']['options'][correct_index]` (or formative `options[correct_answer]`) and prove equivalence to the independent oracle. Also check relevant incorrect options are not accidentally equivalent and explanations are consistent; separate automatable checks from human-reviewed content.
9. **Run real targeted mutations:** On temporary in-memory/generated fixtures, independently corrupt one item key, selected option, prompt, domain restriction, content ID, and generator/YAML parity. Each mutation must reliably trip an appropriate gate. No changes to production data, GitHub main, or hosted databases.
10. **Install reproducible Python test tooling once in the existing Flutter CI job:** Add root `requirements-ci-tests.txt` with exact versions for `pytest`, `sympy`, and `PyYAML`, **selected after an isolated compatibility run**; Qwen's example pins are not automatically approved. Constrain/hash-pin transitive packages where practical, run `python3 -m pip check`, log interpreter/dependency versions, and invoke from repository root:

   ```bash
   PYTHONPATH=. python3 -m pytest tool/tests/test_clep_algebra_math_accuracy.py -q
   ```

   This invocation must be a real required step, not `continue-on-error`. The exact pin versions are selected by an isolated compatibility test, not invented in the plan.
11. **Switch PR-1's `check_test_inventory.py` to blocking mode in PR-2:** PR-1 creates and reports the inventory without blocking the known Algebra omission. PR-2 ensures every `tool/tests/test_*.py` maps to an actual framework runner, detects zero-collected cases, missed pytest suites, duplicates and accidentally excluded files, and fails on any gap. Do not assume `unittest discover` will execute pytest-style function tests.
12. **Decide key-position policy separately from proof:** The existing pytest enforces **20–30% per option position** across 60 simulation items; the generator uses an active **maximum 40%**, and the broader pipeline has a **maximum 45%** heuristic. **Plan decision:** keep existing active generator/pipeline policy gates; report the 20–30% band as an *advisory content-policy metric*, not part of the independent mathematical-correctness oracle, until the product owner explicitly ratifies a single hard threshold. If retained as a stricter blocking gate, label it clearly as a reviewed content-balance rule, document its rationale, and test it separately. Do not silently relax an already active gate.

**PR-2 is incomplete unless all of these are demonstrated:** a newly generated manifest matches the committed artifact; IDs in both item types are unique and stable under reordering; the schema and mapper's chosen ID propagation work; the pytest suite is executed; the answer oracle fails on real YAML mutations; zero Python suites silently disappear; and the required GitHub check names remain unchanged.

### 0A.3 Guardrails for PR-1, PR-3, and later CI optimization

- **PR-1 remains lean:** use `$GITHUB_STEP_SUMMARY` plus pinned-Flutter-supported JSON file reporting, no dashboard, no new runners, no new long-lived metrics database. Measure the real default Flutter test concurrency; absent `--concurrency` does **not** mean concurrency is disabled.
- **PR-3 stays in the existing Supabase job:** existing Docker stack, synthetic users only, local-only host checks, fail-closed setup/cleanup, explicit budget under the 20-minute job cap. Refactor/replace the skipped legacy script; do not merely remove `skip: true`, because its name prevents ordinary `flutter test` collection and early `return` paths may falsely pass.
- **Four DB pgTAP runs are intentionally distinct:** incremental upgrade, historical backfill rehearsal, clean-slate reset, and post-ingestion; preserve each and its pgTAP run until a proven-equivalent refactor exists.
- **No near-term job sharding:** experiment with existing runner `flutter test --concurrency` **against its actual default**, using measurements at identical commit and cache conditions. Two sequential web builds remain default, since changing output directories alone cannot isolate `.dart_tool` and other shared state.
- **Branch-check compatibility:** preserve all three current names. If later splitting, the sole fan-in job named `Analyze, test, and build` must use `if: always()` and explicitly reject any missing/failed/skipped/cancelled child. A disposable PR and an authorized branch-protection review are required before merge.
- **Action SHA pinning is separate:** `actions/checkout@v5`, `subosito/flutter-action@v2`, `actions/cache@v4`, and `supabase/setup-cli@v1` use moving tags. Make a distinct supply-chain upgrade PR rather than conflating pinning with runtime comparisons. Investigate Node 20 deprecation warnings; never suppress them just to get green logs.
- **Existing cancellation behavior:** `concurrency: flutter-ci-${{ github.ref }}` and `cancel-in-progress: true` can cancel obsolete runs on the same ref, including `main`. A required gate must complete successfully for the *actual review/merge SHA*; cancelled predecessors do not establish that status.
- **Browser smoke stays bounded:** two or three real journeys per PR, safe local backend and Flutter Web semantics enabled; expansion belongs to release/nightly after deterministic results.

**Risk rule:** If stable ID propagation or independent-oracle coverage exposes a larger content/database change than can be safely reviewed in PR-2, stop and split the implementation *within the same correctness phase*: one gated schema/generator/id parity PR, then one pytest/oracle activation PR. Do not mark Q-01/Q-03 closed until both are merged and the CI evidence shows the shipped YAML is verified. This is a sequencing safety valve, **not** permission to merge a false-green placeholder.

---

## 0B. Qwen review: safe schema evolution, semantic parity, and reporting-only inventory (2026-11-12)

**Decision:** **Adopt with two refinements.** Qwen's schema and semantic-diff recommendations remove implementation friction. The inventory script may be *introduced* in PR-1 without gating but **cannot become a blocking test until PR-2 activates the missing suite**. Example library versions must be tested and locked, not blindly copied.

| Qwen recommendation | Decision | Precise implementation rule |
|---|---|---|
| Add `id` to both `AssessmentItem` and `LegacyQuestion` | **Adopt as optional base-schema field** | Preserve `additionalProperties: false` and do **not** add `id` to global `required`. Define a meaningful nonempty stable ID format and verify compatibility of existing manifests, including Psychology and other courses. |
| Require Algebra IDs in Dart linter | **Adopt with robust scoping** | Identify College Algebra by the manifest's authoritative target slug (`clep-college-algebra`), **not only by filename**; for this target, require and check unique IDs for all 60 simulation plus 40 formative items, with tests for renamed file and unrelated manifests. |
| Compare generated and committed YAML semantically | **Adopt as primary parity gate** | Run generator in an isolated process, redirect output to a temporary file, `yaml.safe_load` both YAML documents and compare parsed values (`generated == committed`). Dictionary key order, quoting and whitespace are ignored; **list order, option order, data values and missing/extra fields remain significant**. JSON normalization is optional only if it preserves type distinctions. |
| Pin Python test dependencies | **Adopt; reject untested example numbers** | Add `requirements-ci-tests.txt` at root; select exact tested direct versions for `pytest`, `sympy`, `PyYAML`. Prefer a constraints/lock file or hash-pinned transitive packages for truly reproducible resolution. Log Python version and installed versions. Qwen's sample versions are illustrative, **not approved pins**. |
| Clarify taxonomy check provenance | **Verified** | `.github/workflows/taxonomy-official-data.yml` has job display name `Validate official taxonomy sources`. Branch-protection API remains inaccessible; confirm selected required checks and mergeability on a disposable PR. |
| Add `check_test_inventory.py` to PR-1 | **Adopt in report-only mode** | Create lightweight inventory script in PR-1 that lists discovered suites and currently uncovered files in `$GITHUB_STEP_SUMMARY`, with exit 0 for known omissions; **PR-2 switches to strict enforcement**, after registering the missing pytest suite. Deliberately unknown parsing failures must still fail fast, not be disguised as zero tests. |
| Proceed with implementation immediately | **Only when separately authorized** | This version is a plan revision, not an authorization to mutate the repository. PR-1 and PR-2 remain next once approved. |

### 0B.1 Specific PR-2 implementation sketch

**Schema shape (both definition `properties` blocks):**

```json
"id": {
  "type": "string",
  "minLength": 1,
  "description": "Stable source identifier for authored assessment content"
}
```

Do **not** list `id` in either base definition's `required` array. Implement the College Algebra pilot's stronger requirement in target-aware linter logic. Test (a) unrelated manifest with no IDs still passes, (b) Algebra with missing, blank, malformed or repeated IDs fails, (c) reordered Algebra items retain the same identifiers, and (d) dry-run ingestion does not drop or silently conflate tracked identity.

**Semantic generator parity:**

```python
with open(committed_path, encoding="utf-8") as f:
    committed = yaml.safe_load(f)
with open(generated_temp_path, encoding="utf-8") as f:
    generated = yaml.safe_load(f)
if generated != committed:
    raise SystemExit("College Algebra generated content differs from committed YAML")
```

The generator must first support writing **to a temporary output path**, without modifying committed YAML. Comparing Python mappings ignores mapping key order and serializer formatting, **but intentionally preserves list order** (important for question options and lesson sequencing). This gate verifies **generator parity**, not math truth; the independent ID-keyed SymPy/content oracle remains essential. Distinguish material content drift from harmless textual diff in diagnostic output, and never print secret scoring keys into public logs.

**CI dependency gate (versions selected only after compatibility checks):**

```bash
python3 -m pip install -r requirements-ci-tests.txt
python3 -m pip check
PYTHONPATH=. python3 -m pytest tool/tests/test_clep_algebra_math_accuracy.py -q
```

Ensure the requirements file contains exact, reviewed versions rather than broad `>=` constraints. For tighter reproducibility pin transitive dependencies and hashes as practical, keep the Python interpreter/environment explicit, and record a clean-run dependency resolution. Installing only exact *top-level* packages is not a blanket guarantee of reproducibility.

**Inventory gating transition:**

- **PR-1:** inventory script exists, scans the repository and current CI commands, writes an honest report of 44 discovered vs. 43 explicitly registered Python tests (snapshot count), flags algebra pytest as *known uncovered*, does not fail solely on that known gap, and does not claim all tests are executing.
- **PR-2:** the same script's strict mode fails on any unregistered `test_*.py`, no collected cases, or a missing framework/runner mapping; CI includes the actual Algebra `pytest` invocation. Validate the inventory mechanism with a synthetic new test file. No independent, always-green status may conceal an omitted suite.

---

## 0C. Local re-verification and implementation decisions (Claude Code, 2026-11-12)

**Decision:** The v4 plan is sound and remains in force. The re-check below was made against a local checkout of `main` at `a458b41` with the real toolchain, rather than remote inspection only. It corrects four facts and makes one sequencing refinement.

### 0C.1 Verified facts and corrections

| Item | Result on 2026-11-12 | Consequence |
|---|---|---|
| Python test inventory | 44 `tool/tests/test_*.py`; every one except `test_clep_algebra_math_accuracy.py` appears in a CI runner command. `tool/tests/` also holds one Dart test (`guarded_connection_test.dart`, run directly by CI) | §0A.1 confirmed. The inventory script must report non-Python test files too, not only `test_*.py` |
| Algebra suite health | `PYTHONPATH=. python -m pytest tool/tests/test_clep_algebra_math_accuracy.py -q` → **9 passed in ~2 s** (Python 3.13.4, pytest 9.0.2, SymPy 1.14.0, PyYAML 6.0.2) | Activating the suite in CI is low-risk: no latent failure is waiting. These are candidate pins, still to be confirmed on the CI runner's Python |
| Generator↔YAML parity | `build_manifest()` output equals `yaml.safe_load(content/clep_college_algebra.yaml)`, both directly and after a `safe_dump` round-trip | A parity gate can call `build_manifest()` in-process and compare without writing any file. The generator does not need a `--check` flag that touches the filesystem |
| `supabase test db` invocations | **Four**, not three: incremental upgrade, historical backfill, clean reset, and post-ingestion | Corrected in §0A.1, §0A.3, A2 and §14 |
| pgTAP SQL files | **68** files now (67 at Grok review time, 66 in sample run #1261) | Count drifts with feature work; always record the count alongside the run that produced it |
| Flutter 3.47.7 CLI | `--concurrency` / `-j`, `--total-shards` / `--shard-index`, and `--file-reporter json:<path>` all supported | §0/E1 "verify on pinned Flutter" prerequisite is met. The help text does not print the default concurrency, so PR-5 benchmarks must log the runner's `nproc` |
| Script location | No `scripts/` directory exists. AGENTS.md puts developer utilities in `tool/` and Python tests in `tool/tests/` | **All `scripts/ci/…` paths in this plan become `tool/ci/…`** (applied throughout). Tests for these scripts live in `tool/tests/` and must themselves be registered in CI |

### 0C.2 Sequencing refinement for PR-2

§0A's full PR-2 (authored IDs → schema → target-aware linter → ingestion mapping → ID-keyed oracles → mutations) is a large cross-layer change. Meanwhile the existing algebra suite, though order-dependent and partly disconnected from YAML (Q-03), **does** assert real selected options against SymPy and passes today. Leaving it unexecuted until the ID work lands gives **zero** protection in the meantime. The §0A risk rule already allows splitting within the correctness phase, so PR-2 is split as follows:

- **PR-2a — activate and guard.** Pinned `requirements-ci-tests.txt`, real pytest step in `Analyze, test, and build`, read-only generator↔YAML semantic parity gate (`tool/ci/check_algebra_manifest_parity.py`), and inventory **strict mode**. **Closes Q-01 and Q-06 only.** The PR description must say plainly that Q-03 stays open and that the suite still reads authoring modules by position.
- **PR-2b — stable identity.** Authored IDs, optional schema `id`, target-slug-scoped linter enforcement, and the ingestion mapping decision (§0A.2 steps 1–4).
- **PR-2c — independent oracle.** Committed-YAML fixtures keyed by ID, oracle and distractor checks, prompt-drift protection, and the mutation set (§0A.2 steps 6–9). **Closes Q-03.**

This is not acceptance of a partial fix: each PR closes only the findings it fully proves, and nothing is labeled as covering more than it does.

**Inventory guard mode (refines §0B "report-only"):** PR-1 ships the guard in **ratchet mode**, not pure report-only. Gaps named in its `KNOWN_GAPS` table (today only the algebra suite) are reported as warnings; **any other gap fails immediately**, so a newly added unregistered suite cannot slip in while PR-2a is pending. The guard also fails on stale `KNOWN_GAPS` entries and on unparseable test or workflow files (never "zero tests"). This blocks nothing on current `main`, which has exactly the one known gap. PR-2a removes that entry and switches CI to `--strict`. Collection counts are static (AST for Python, call-site count for Dart scripts) so the guard needs no third-party packages; runtime collection is still proven by the runners themselves.

### 0C.3 Implementation status tracker

| PR | Scope | Status |
|---|---|---|
| PR-1 | Ratchet-mode `tool/ci/check_test_inventory.py` + `tool/tests/test_check_test_inventory.py`; `flutter test --file-reporter json:build/reports/flutter-tests.json` summarized into `$GITHUB_STEP_SUMMARY` by `tool/ci/summarize_flutter_test_report.py` (counts, skips, failures, slowest files and tests, runner CPU count; always exits 0) + `tool/tests/test_summarize_flutter_test_report.py`. No job renames, no new runners, no artifacts | PR #241, merged |
| PR-2a | `requirements-ci-tests.txt` (full transitive exact pins, `pip check`); `tool/ci/check_algebra_manifest_parity.py` (type-strict, deterministic, read-only, prints paths only) + 14 mutation tests; real `pytest` step for the algebra suite; inventory guard switched to `--strict` with empty `KNOWN_GAPS`. Evidence: wrong key in authoring source → pytest **and** parity fail; wrong key in committed YAML only → pytest passes, **parity fails**. Closes **Q-01, Q-06**; Q-03 open | PR #242, merged (CI green; runner Python 3.14.4; pinned set installed in an isolated venv because the runner's system Python fails `pip check` on unrelated packages) |
| PR-2b | 100 authored semantic IDs (`alg-sim-*` ×60, `alg-fmt-*` ×40) in `tool/curriculum_clep_algebra`; generator `validate_stable_ids` (format, prefix, uniqueness, 60+40 count); optional `id` (kebab-case pattern) in both schema definitions, not `required`; `tool/lint_manifest.dart` rule `stable-item-id` required for target slug `clep-college-algebra`, and format/uniqueness-checked wherever present; ingestion maps `id` → `metadata.source_item_id` (fails closed on conflict) and `--dry-run` now builds the real payload and verifies every id survives. **Formative IDs are manifest-only** (no `questions` source-id column; persistence would need a separately reviewed migration). Learner exposure checked: `clep_issue_simulation_exam` allowlists other metadata keys and RLS hides protected rows. IDs name the skill tested, never the answer | PR #243, merged |
| PR-2c | `tool/tests/clep_algebra_oracles.py`: one oracle per ID (100/100), truth computed by SymPy from each prompt's own mathematics, every option's text mapped to its meaning so exactly one option must be correct and it must be the keyed one (distractors proven false); 7 definitional items use reviewed rationales with computed witnesses where possible; prompt fingerprints force oracle re-derivation on any rewording. `test_clep_algebra_math_accuracy.py` rewritten to read the **committed YAML by ID** (316 tests, ~7 s): coverage both ways, per-item oracle, every wrong key for every item, option edit/reorder, prompt edit, renamed ID, domain exclusions, explanation draft-note scan; Haladyna and 20–30% balance gates retained. Corrupting one key in the committed YAML now fails this suite on its own (it passed 9/9 before). **Oracle review found two content defects, fixed in a separate commit:** the zero-discriminant formative key claimed the repeated root is always *rational*; and a simulation distractor (`x ≥ 3`) for the quadratic-inverse restriction was also correct. Closes **Q-03** | PR #244, merged |
| PR-3 | `test/integration/lesson_import_local_supabase_test.dart`: production `LessonImportService`/`LessonCrudService`/`LessonContentService` with an injected pure-Dart `SupabaseClient` (no platform channels) against the **existing DB job's** local stack, synthetic `@example.test` users via the local admin API, loopback-only guard, `REQUIRE_LOCAL_SUPABASE=true` fail-closed in CI (skipped with reason in the Flutter job). 6 tests: full readback fidelity + service-role row counts; invalid key writes nothing; simulated mid-import failure and a **real** DB rejection (duplicate item id) both clean up in the database; cross-learner RLS read denial. **It exposed a production bug:** `LessonContentService` wrote a `created_by` column that does not exist in the migration-defined `terms`/`questions`/`concepts` tables (PGRST204), so every JSON import with content failed against a migrations-built DB; the app's own read path and `lesson_creation_service` already use `user_id`. Fixed to write `user_id`. Also: `data/samples/sample_lesson_valid.json` (served to agents by the MCP server) was rejected by the importer (free `text` items) while `test_import.dart` printed success; fixed the fixture and replaced the diagnostic with `test/services/lesson_import_sample_fixture_test.dart` (production preview, exact counts, documents that `order` is ignored). Legacy `test_lesson_creation.dart` / `test_import.dart` removed. Closes **Q-02** | PR #245, merged |
| PR-4a | Setup-gap fixes for tests that passed via error paths; `tool/ci/check_test_log_noise.py` ratchet (see §0C.4) | PR #247, merged |
| PR-4b | `tool/ci/mutation_seeds.py`: 8 critical seeds, all killed after one survivor was fixed; weekly `mutation-seeds.yml` (see §7 C2) | PR #248, merged. Full weekly run not yet observed on CI |
| PR-5 | Step 1: advisory `flutter-test-benchmark.yml` + `tool/ci/flutter_test_benchmark.py` (default/3/4/6 × 5 trials; invalid if any trial fails or collects a different inventory). Baseline (10 green runs): job p50 546 s, `Run tests` 274 s, web builds 62 + 64 s serial. Default concurrency is `max(1, nproc ~/ 2)` = 2 on a 4-vCPU runner. Step 2 result (run 43529109440, 4 vCPU / 16 GiB, 5 trials each, all passed, identical inventory `43029c0610fea3ca`, 3,139 passed / 5 skipped): default p50 306 s; `-j 3` 237 s (−23%, peak mem 3.2 GiB); `-j 4` 262 s; `-j 6` 247 s. 3/4/6 differ by less than runner noise (bimodal ~200 s / ~255 s across machines); `-j 3` adopted on `Run tests`. Sharding and splitting the web builds are **not** pursued: remaining job time no longer justifies extra runners (E1 step 4). First real CI run on `-j 3`: `Run tests` 227 s, job 487 s | PR #257, merged |
| PR-6 | DB job profiled from 4 green logs: each `supabase test db` = 71 files / 1,793 tests in ~5 s; cost is image pulls ~69 s, `supabase start` ~36 s, three `db reset`s ~40 s each (21 s container restart). Changes: pending-migration isolation (git-only) moved before `supabase start`, so the duplicate baseline `db reset` is dropped; `supabase start -x` skips 7 unused services; every pgTAP pass tee'd with `pipefail` and `tool/ci/check_pgtap_parity.py` (+6 tests) fails unless all four scenarios ran, passed and report identical totals. All six E3 scenarios retained. DB job is not the critical path after PR-5 (~335 s vs ~487 s). First CI run: DB job 264 s; parity 71/1,793 ×4 PASS | PR #258, merged |
| PR-7 | `tool/tests/test_browser_smoke.py` (Playwright 1.64.1, Chromium, 8 tests ~25 s) against the release web build with the placeholder backend, using Flutter accessibility-tree selectors: (1) guest rail navigation, Help always visible, explicit pre-reader entry, persistence across reload with no forced redirect; (2) **explicit gap**: signed-in create/readback (covered by the DB job's import test); in the browser a guest goal save fails closed; (3) guest deep links to five admin/moderation consoles denied with no controls; the simulation requires registration. All tests fail on page errors or non-allow-listed hosts. **Exposed a real a11y bug:** on ≥900dp the NavigationRail was absent from the semantics tree (routed page's `BlockSemantics`); fixed in `app_shell.dart`, with a widget regression test. Advisory parallel CI job `Browser smoke (Chromium guest journeys)`; not required yet. Closes **Q-08**. First CI run: 8/8 in 24 s, job 159 s in parallel | PR #259, merged |
| PR-8 | Advisory `Early feedback (changed files)` job on PRs: `tool/ci/early_feedback.py` (+13 tests) classifies the PR diff (`HEAD^1..HEAD` of the merge commit) with the E5 table and runs only related fast checks (analyze, name-mapped Flutter tests ≤40 files, schema/feature-registry contracts for high-risk Dart, migration history for DB, manifest lint + ingest dry run for content, matching unittest suites). Unknown and CI/dependency paths get every early check; docs-only gets none. **No path-based gating, no aggregator:** the three required checks still run in full on every PR. Also fixes `cancel-in-progress` to apply to PRs only: on main it had cancelled CI for 3 merge commits (`95e9d33`, `8945883`, `27ffe5a`, 2026-11-12), leaving them unverified. First CI run: early job 58 s with the full early set | PR #260, merged |
| PR-9 | `docs/testing/TEST_QUALITY_POLICY.md` (required vs advisory checks, discovery, mandatory evidence by risk area, skip/quarantine, flaky, log noise, coverage, timing, local commands, review checklist; owner: repository maintainer). Enforcement: `tool/ci/check_test_skips.py` (+10 tests) in the required job fails on unregistered skips, stale entries and expired or under-specified quarantines (max 30 days); today's 5 skips are registered as `conditional` (DB-job import test, 50k load probe, 3 BYOK tests behind the hard-off latch). Weekly `test-quality-audit.yml`: full suite with coverage, `tool/ci/summarize_coverage.py` (+4 tests; report-only, by critical area, generated code excluded, **no percentage gate**), dated lcov + JSON report artifacts kept 90 days. PR template gains a Test Quality checklist | PR #261, in progress |

**Open follow-ups after PR-9** (not done; each is its own reviewable change):

- Promote `Browser smoke (Chromium guest journeys)` to required after a sustained stable record (maintainer decision).
- Browser journey 2 (signed-in create → reload → readback) needs a local-backend browser harness; covered today at the service layer only.
- Five `KNOWN_NOISE` test files from §0C.4 and the `ScopeResolver` test-fake type-name check.
- Python tooling coverage (needs a pinned `coverage` package) and a Supabase security/contract matrix document (§12).
- Two SQL-level mutation seeds (cross-learner attempt read; protected keys in a simulation response) that need the DB job.
- Confirm the first scheduled runs of `mutation-seeds.yml` and `test-quality-audit.yml` on `main`.
- Review third-party Action pinning and deprecated Node runtimes (§9 E6).
- Verify branch-protection required-check settings through an authorized admin view (connector read returned 403).

### 0C.4 PR-4 split and PR-4a results (log triage, Q-07; first Q-04 fixes)

PR-4 is split: **PR-4a** fixes test-setup gaps that made passing tests exercise error paths by accident and adds a ratchet against new ones; **PR-4b** adds the C2 mutation seed runner and the assertion upgrades it drives.

Measured on a full local run (JSON reporter): **0 error events**, but ~220 lines of setup-gap messages in passing tests. PR-4a outcome:

| Test | Problem | Fix |
|---|---|---|
| `audio_settings_test`, `audio_service_mockito_test`, `pre_reader_literacy_test`, `audio_lesson_provider_test` | `flutter_tts` unmocked (`MissingPluginException` ×117) | `test/test_helpers/platform_channel_fakes.dart`: per-test fake engine that also emits `speak.onComplete` |
| `connectivity_service_mockito_test` | plugin unmocked; all 5 assertions were `isA<bool>()` | rewritten: faked channel, 14 tests on transport types, stream, degraded / permission / recovery health |
| `notification_service_mockito_test` | **no assertions**; `initialize` unstubbed | rewritten: 11 tests verifying every scheduled argument, rethrow, cancel; documents that inactive filtering is the caller's job |
| `v2_stabilization_test` (fail-closed context) | **false green**: empty result came from a `LateInitializationError`, not the not-found branch | real empty context lookups; asserts which branch ran |
| `scope_resolver_rpc_test` (RPC fallback) | **false green**: fallback crashed on an unstubbed mock; safety net returned the expected empty scope | `FakeSupabaseClient` with seeded nodes/concepts; asserts the cascade's result |
| `community_qa_service_test` | "offline" simulated by an uninitialized `Supabase.instance` (×34) | injected offline client throwing `SocketException` |
| `library_create_chooser_test`, `app_initialization_provider_test` | uninitialized Supabase / `shared_preferences` | provider overrides / mock initial values |

`tool/ci/check_test_log_noise.py` (+8 unit tests) now runs after the Flutter suite in **ratchet mode**: setup-gap signatures fail CI unless the file is in `KNOWN_NOISE` with a reason; clean known files fail as stale. Five documented follow-ups remain listed: `audio_lesson_orchestrator_test` (its playback tests only pass because TTS fails instantly; with a working engine they run at real pacing; needs a controllable clock), `overview_tour_screen_test`, `library_v2_test`, and two community widget tests (services reach an uninitialized global client inside the widget tree). Also recorded: `ScopeResolver._resolveOnline` special-cases test fakes by runtime type name (`contains('Fake')`), a production-code smell to remove.

---

## 1. Executive decision

**Recommendation:** Improve **test effectiveness first**, then improve **execution efficiency** without reducing the protection offered by the suite. Use a measured, staged rollout rather than replacing the workflows in one large change.

LearningApp already has substantial and valuable automated protection: recent successful CI shows **2,585 passing Flutter tests**, **4 expected Flutter skips**, and **1,709 pgTAP assertions across 66 SQL test files per full database test execution**. Security, assessment-answer integrity, database authorization, upload failure-handling, feature gating, and pre-reader navigation have meaningful tests. The primary risks are not simply “too few tests.” They are **uneven assertion quality, some important test discovery gaps, incomplete end-to-end verification, and inefficient scheduling of expensive work**.

The recommended first deliverable is a **quality-and-timing baseline**. Next, close the confirmed gaps (particularly the omitted algebra accuracy tests and the skipped/weak legacy integration tests), then restructure CI for independent parallel execution. The work should conclude with measured evidence that coverage and failure-detection are **at least as strong as before**, while runtime is improved.

### Non-negotiable rules

1. **Do not delete, skip, weaken, or silently reclassify existing security/privacy, scoring, migration, account-erasure, or integrity tests for speed.** Replacements require demonstrably equivalent or stronger behavior checks.
2. **“Green” must mean a test actually performed and asserted its intended behavior.** No catching initialization errors and returning success; no diagnostic scripts represented as automated assertions.
3. **Changes must not touch production** as part of CI optimization. All DB resets, race probes, and integration scenarios target disposable local/test infrastructure.
4. **No feature releases through test refactoring.** Keep Fast mode available, BYOK disabled under its existing release gate, and experimental/unverified features appropriately labeled and gated.
5. **Preserve the existing source-of-truth and append-only migration rules.** Tests cannot quietly rewrite or bypass migration history.
6. **Do not trade developer latency for unbounded runner consumption.** GitHub currently marks this repository **public**, making standard GitHub-hosted runner compute free. Still measure elapsed time, aggregate runner-seconds, cache/artifact usage, and readiness for a later private-repo transition; no paid/larger runners without explicit approval.
7. **No merge solely on a fast preliminary check.** The full set of required checks must pass on the reviewed code and applicable merge/branch policy before merge. Preserve all three exact required check names in §0 unless branch settings are deliberately migrated in a separately reviewed change.

---

## 2. Audited baseline: verified facts vs. assumptions

### 2.1 Observed CI

Workflow: [`.github/workflows/flutter-ci.yml`](https://github.com/RACCHUS/LearningApp/blob/main/.github/workflows/flutter-ci.yml)

- Triggers: PRs into `main`, pushes to `main`, and manual dispatch.
- Existing main jobs run **in parallel**:
  - **Analyze, test, and build**: Flutter analysis and tests, many Python/CLI checks, Excel worker smoke test, content validation, two sequential web release builds.
  - **Verify clean Supabase migrations and complete official taxonomy ingestion**: local Supabase, incremental migration path, historical backfill rehearsal, clean reset, pgTAP, official taxonomy ingestion, lint.
- Separate **Official Taxonomy Data** workflow runs on PR and supports manually triggered validate/ingest modes.
- Flutter cache and a pinned taxonomy source cache already exist. Optimization should not be based on the mistaken assumption that caching is absent.
- Migration-history verification runs in both principal jobs; the governance Flutter tests also run ahead of the full Flutter suite, which normally includes those test files again.

### 2.2 Sample timing evidence

| Step / stage | PR run #1259 | Push run #1261 | Interpretation |
|---|---:|---:|---|
| Flutter full test suite | 3m 24s | 4m 19s | Primary single-job critical-path cost |
| Standard web release build | 1m 06s | 1m 04s | Currently sequential |
| Simulation-preview release build | 1m 07s | 1m 03s | Currently sequential after standard build |
| Flutter static analysis | 16s | 26s | Not the main bottleneck |
| Initial Supabase start + incremental verification step | 2m 43s | 2m 24s | Includes more than startup; instrument before attributing its full duration to startup |
| Historical backfill rehearsal | 51s | 43s | Important distinct migration scenario |
| Clean-slate reset step | 50s | 43s | Repeated reset cost |
| End-to-end job result | ~7m 16s Flutter job | ~8m 20s Flutter job | Database job finished sooner in both samples |

[PR run #1259](https://github.com/RACCHUS/LearningApp/actions/runs/43235491460) · [Push run #1261](https://github.com/RACCHUS/LearningApp/actions/runs/43236263959)

**Important:** Timing samples are observations, not stable performance guarantees. The jobs overlap; **do not add Flutter and database durations** to compute overall CI latency. Do not infer test-file execution time from interleaved Flutter test reporter lines: use per-test timing events or profiling instead.

### 2.3 Test inventory observed

- Flutter test output: **2,585 passed, 4 skipped** in sample run #1261.
- Database pgTAP: sample run #1261 reported **66 files and 1,709 assertions per completed invocation**; the current repository directory contains **67 `supabase/tests/*.sql` files**. These describe different snapshots, not a contradiction, and the workflow executes pgTAP on multiple database states.
- `tool/tests` includes **44 Python files named `test_*.py`**. The inspected CI explicitly names **43** of those, omitting `test_clep_algebra_math_accuracy.py`. That file uses **pytest + SymPy**, not just `unittest`.
- Legacy `test/integration/test_lesson_creation.dart` uses `skip: true`. The project’s test README says it is an environment-dependent/manual integration script; it is **not** an active verified end-to-end CI gate.
- The standalone `test/integration/test_import.dart` prints a success message after **reimplementing/simulating** the order calculation rather than checking the production import implementation. It is a diagnostic, not strong regression proof.
- The opted-in 50,000-item synthetic export load probe executes as a **separate Flutter test step** (about **9 seconds** in sampled logs), not inside the 3–4-minute ordinary full suite; preserve it and avoid incorrectly attributing suite tail latency to this probe. The separate simulation-preview web build also has a distinct purpose.
- BYOK tests are intentionally gated while BYOK is unreleased. Preserve gating, while ensuring the **disabled-state security tests remain active**.

### 2.4 What this audit has **not** proved

- Repository-wide line/branch coverage: **not measured**.
- Actual flake rate over 30 days: **not measured**.
- Root cause of `MissingStubError` / `MissingPluginException` messages observed in otherwise passing logs: **not established**; they may be intentional negative-path simulation.
- Number of *unique* behaviors covered by 2,585 tests or 1,709 database assertions: **unknown**.
- Browser end-to-end quality in a deployed web runtime: **not established** by the reviewed CI.
- Performance achievable after changing `flutter test` concurrency or sharding: **not benchmarked**.
- Exact `main` branch-protection required-check settings: **not directly readable through this GitHub integration** (403). Current CI job names match the three reported requirements; validate merge behavior on a controlled PR.
- Public repository status: **verified** 2026-11-12 from GitHub metadata; standard public hosted-runner compute is free under GitHub billing docs (storage and larger runners may differ).
- Whether every hardcoded algebra proof matches the *authored* item prompt/option: **not established**, and some checked expressions are independent of actual item data.

The implementation must resolve these unknowns by measurement, not confident-sounding assumptions.

---

## 3. Audit findings and corresponding work

| ID | Severity | Finding | Remediation | Completion evidence |
|---|---|---|---|---|
| **Q-01** | **P0 / critical** | College Algebra `pytest`/SymPy accuracy suite exists but is not invoked in CI | Add pytest **step in existing Flutter CI job**, with tested exact dependency pins and correct working directory; enable inventory guard in PR-2 | Test is collected/executed and fails when a known wrong answer is injected |
| **Q-02** | **P0 / high** | Legacy lesson-creation E2E test is skipped and could return early on setup problems | Replace with deterministic disposable-DB integration coverage, fail closed on setup and add actual readback assertions | E2E test fails on simulated service/write/load failure |
| **Q-03** | **P0 / high** | Some “math proof” assertions are disconnected from real authored answer choices | Tie production source/derived artifact, **stable item IDs**, independent math oracle, selected option and explanation together | Mutating item key/option/prompt independently kills tests |
| **Q-04** | **P1 / high** | Some tests use shallow assertions (`isNotNull`, broad `throwsA(anything)`, field existence only) | Risk-prioritized assertion upgrades | Wrong output/incorrect exception/partial persistence fails the test |
| **Q-05** | **P1 / high** | No measured coverage baseline or risk-based coverage floor in inspected CI | Generate coverage artifacts/reports; map uncovered critical logic | Published baseline and prioritized uncovered code list |
| **Q-06** | **P0 / high** | Test enumeration is manually curated for Python tooling | Framework-appropriate discovery; PR-1 report-only inventory → PR-2 enforced guard | Added test file is discovered or CI explicitly fails |
| **Q-07** | **P1 / medium** | Noise in passing logs (plugin and stub errors) lacks triage | Classify expected negative-path messages vs unexpected errors; improve fixtures | Zero unexplained warnings in clean baseline or documented issue ownership |
| **E-01** | **P1 / high** | Full Flutter suite occupies 3–4+ minutes in one job | **First** benchmark intra-job Flutter concurrency against current defaults; **then** optionally trial 2 shards if worthwhile | Same test inventory, faster/steadier wall clock, measured runner use |
| **E-02** | **P1 / high** | Two release builds run sequentially | Preserve both; benchmark separate jobs or safe serial execution; **never** run two Flutter builds concurrently against one mutable `.dart_tool` checkout | Both modes compiled, tested, artifacts isolated, no race |
| **E-03** | **P1 / medium** | Multiple DB resets and migrations prolong database job | Instrument each DB sub-phase; no direct template-db shortcut without full-environment equivalence proof | Same scenarios and assertions, lower DB job duration or documented tradeoff |
| **E-04** | **P2 / medium** | Some checks run twice across jobs | Remove proven redundancy only after mapping what each verifies | Equivalent gates remain, no missing required check context |
| **E-05** | **P2 / medium** | Every change receives costly unrelated validation | Safe change-classification for early feedback; always-green required aggregator; full pre-merge verification | Docs-only PR gets early feedback without bypassing full required checks |
| **Q-08** | **P2 / high value** | No demonstrated automated browser learning journey test gate | Add small, deterministic Playwright/browser suite | At least one real user journey passes in actual browser |
| **Q-09** | **P2 / high value** | No measured mutation sensitivity for critical business rules | Introduce targeted mutation experiments | Known wrong scoring/authorization behavior reliably fails |

---

## 4. Test-quality standard: what every test should prove

Establish a lightweight quality rubric applied during new PR review and retrospective audits. An important test should answer:

1. **Behavior:** Which user outcome, product invariant, security boundary, or API contract is protected?
2. **Oracle:** What independent evidence tells us the result is correct? Does it validate actual output rather than merely repeat implementation logic?
3. **Negative path:** What happens with invalid, missing, duplicated, stale, unauthorized, or interrupted inputs?
4. **Side effects:** Are persisted records, emitted events, permissions, storage objects, and cleanup verified where relevant?
5. **Determinism:** Is time, randomness, network, locale, storage, and global state controlled?
6. **Failure visibility:** Does any setup/teardown error cause a clear failure rather than silently returning?
7. **Sensitivity:** Would a plausible one-line implementation defect make this test fail?
8. **Isolation:** Can this test run in parallel, multiple times, and with different order without relying on another test’s residue?
9. **Cost:** Is this verification at the cheapest appropriate layer? Should expensive I/O move to fewer integration cases while unit cases cover branches?
10. **Traceability:** Is the test linked to a requirement, regression, design invariant, or known failure mode?

### Classify tests correctly

- **Unit:** Pure transformations and deterministic rules; many fast negative cases; fake external I/O.
- **Component/widget:** Renders real widgets and checks user interaction, semantics, focus, display and navigation.
- **Contract:** Client/DB/API payload compatibility, schema, migrations, release flags; especially nullability and protected fields.
- **Integration:** Multiple real components with disposable local services (DB/storage), verification through actual I/O and readback.
- **E2E/browser:** Browser navigation through a learner-visible workflow; keep small, stable, and high impact.
- **Performance/scale:** Measured probe with a documented baseline, threshold model, and noise strategy.
- **Content correctness:** Independent factual/mathematical validation of the authored prompt, chosen key, explanations, metadata, and alignment to target/exam blueprint.
- **Security abuse tests:** Active attempts to bypass auth, role, scope, ownership, retention, quotas, or protected scoring.

A test file called “integration” does not become integration coverage just because its name says so.

### Anti-patterns to flag (review candidates, not automatic deletion)

- A test ending in only `expect(value, isNotNull)` despite promising correctness.
- Broad `throwsA(anything)` when an exact error class/status matters.
- `assert 2 == 2`, tautologies, or “expected” values calculated from the same code path as actual values.
- Printing “PASS” without executable assertions and non-zero process exit on failure.
- `try/catch { print(...); return; }` during test setup.
- Tests with `skip: true` but no owner, purpose, or replacement plan.
- Arbitrary `sleep`/`Future.delayed` where controlled clocks, fake async, or completion signals would be appropriate.
- Real network calls, externally changing data, or live credentials in basic unit tests.
- Shared global fake/DB state leaking across test cases.
- Snapshot/golden assertions so broad or frequently regenerated that reviewers cannot detect a real UI regression.
- A mock programmed to return the exact asserted result, without any verification of request construction or production adapter behavior.
- Coverage-only tests that exercise a line but not its decision or side effect.

Do not mechanically replace every broad assertion: assess whether the specific error type is part of the tested contract.

---

## 5. Workstream A — Fix missing and misleading verification first

### A1. Restore CLEP College Algebra accuracy verification (**P0**)

**Targets:** [`tool/tests/test_clep_algebra_math_accuracy.py`](https://github.com/RACCHUS/LearningApp/blob/main/tool/tests/test_clep_algebra_math_accuracy.py), [`tool/generate_clep_algebra_course.py`](https://github.com/RACCHUS/LearningApp/blob/main/tool/generate_clep_algebra_course.py), [`content/clep_college_algebra.yaml`](https://github.com/RACCHUS/LearningApp/blob/main/content/clep_college_algebra.yaml), four `tool/curriculum_clep_algebra/domain_0*` sources, `formative_lesson_questions.py`, the JSON Schema and ingest mapper.

**Confirmed architecture:** The generator uses four imported domain objects and `FORMATIVE_QUESTIONS_BY_LESSON` to create the 5,000+-line committed YAML. The existing test imports those Python objects directly, and `items[n]` ties its checks to item order. The current CI executes the YAML-level CLEP pipeline, but does not independently verify YAML ↔ generator parity or the missing pytest suite. Both relevant schema definitions use `additionalProperties: false`, without `id` fields; the Dart ingestion mapper currently drops top-level assessment item IDs. **Therefore, simply adding `pytest` to CI is insufficient.**

**Implementation sequence (all required for closing Q-01/Q-03):**

1. Add **authored** semantic IDs to **all 60 simulation** and **40 formative** questions; retain identity on harmless edits/reordering. Protect uniqueness, format, semantics, and stable mapping at the generator and schema layer. Do not generate random IDs per build or rely on list indices.
2. Add a **nonrequired** `id` string property to both `AssessmentItem` and `LegacyQuestion` schema definitions; preserve strict `additionalProperties: false`, but **do not make ID globally required**. Update `tool/lint_manifest.dart` and tests to require nonempty/unique IDs when the manifest **target slug is `clep-college-algebra`**, independent of filename, and leave unrelated existing curricula valid without IDs.
3. Choose an intentional ingestion-identity contract. In current `tool/ingest_curriculum.dart`, map simulation IDs to durable safe metadata (or another explicitly designed destination); prove SQL ingestion retains them. The `questions` table is different: either document IDs as **manifest-only** for PR-2 or design a separately reviewed additive persistence migration if downstream identity is required. No hidden assumption that top-level IDs automatically appear in the database.
4. Implement a **read-only, deterministic generator parity check**: regenerate to a temporary YAML path or use a `--check` mode; compare `yaml.safe_load(generated)` against `yaml.safe_load(committed)`. Mapping key order, whitespace and quotes do not matter; **list/option order, IDs, types and field values do matter**. The generator must not overwrite checked-out production YAML during CI.
5. Refactor the algebra pytest fixtures to **load the committed YAML** and index items by stable ID. Ensure exactly 60 simulation and 40 formative IDs are present, correctly typed, and never duplicated.
6. Build independently reviewed expected mathematical outcomes (and semantic prompt contracts) keyed by IDs. Verify `prompt/assumptions → expected answer → actual selected YAML option → explanation`. Use SymPy for symbolic/numeric mathematics, explicit exclusions and tolerances, and separately reviewed oracles for conceptual items that cannot be parsed mechanically. Do not derive the expected answer from `correct_index`, a generator module whose output isn't compared, or a hardcoded equation disconnected from the actual prompt.
7. Verify relevant distractors are not also correct. Bind at least a semantic fingerprint/curated parser to the prompt so a prompt change without oracle review fails rather than being silently ignored.
8. Add targeted failure-seeding tests that mutate the real manifest **key, option, prompt, domain restriction, ID, and generator parity** separately; prove each is detected. Do not modify published assessment data or test against production services.
9. Create root `requirements-ci-tests.txt` with tested exact pins for `pytest`, `sympy`, and `PyYAML`; replace floating `PyYAML>=6.0` in the touched CI step, add `python3 -m pip check`, and use a resolved transitive lock/hash strategy for stronger reproducibility. **Do not adopt sample pin versions without test evidence.** Install once inside the **existing** `Analyze, test, and build` runner and execute:

   ```bash
   PYTHONPATH=. python3 -m pytest tool/tests/test_clep_algebra_math_accuracy.py -q
   ```

10. **Activate A3's PR-1 inventory script in strict mode** and ensure the CI command truly collects/tests the registered file; do not rely on a static string match alone.
11. Decide separately whether answer-key position distribution **20–30% per position** is a strict publication policy or an advisory metric. For now, **treat it as advisory** while preserving the generator's existing maximum 40% and pipeline's existing maximum 45% gates, unless the product owner specifically approves a new hard policy. Do not describe any of these distribution heuristics as proof of mathematical or psychometric correctness.
12. Record the exact regression it catches, run count, dependency versions, runtime delta, and generator parity result in the PR summary. If the cross-layer changes cannot be reviewed safely as one PR, split the implementation into two *gated* corrections and close the finding only after both succeed.

**Done when:** The actual committed YAML is generator-parity-checked and mathematically verified against independent, ID-keyed oracles; all applicable tests genuinely execute; source/schema/ingest ID behavior is explicit; deliberately broken *shipped* item content fails CI; no external credentials are required. See mandatory detailed gates in **§0A**.

### A2. Replace inactive legacy lesson-creation integration test (**P0**)

**Targets:** `test/integration/test_lesson_creation.dart`, `test/integration/test_import.dart`, actual lesson CRUD/import/service adapters.

**Plan**

1. Convert the old skipped test into a genuine **disposable local Supabase** test **inside the existing database job**, which already starts local Supabase. **This job has a 20-minute timeout and four separate pgTAP runs, so instrument headroom before adding any new full-stack work.** Never start a second Supabase Docker stack in the Flutter job. If Flutter/Dart test dependencies are needed, reuse the DB job’s existing Flutter setup rather than layering another SDK installation.
2. Use a dedicated synthetic learner, no production URLs/keys, and isolated records/table namespace as appropriate.
3. Create a real lesson through the supported creation/import path, then retrieve it through the supported read path.
4. Assert complete fidelity: title, user ownership, ordered terms, question text/options/**correct answer key**, explanation, concepts, citations/metadata as applicable, and persisted counts.
5. Assert invalid keys never produce a saved lesson, even when other items are valid; test preflight before side effects.
6. Simulate write failure after creating an initial record. Check the actual cleanup/reporting contract and absence/presence of orphaned rows, not just an in-memory `deletedIds` list.
7. Make all initialization, database, timeout, and cleanup failures **fail** the test; no logging-and-returning.
8. Replace `test_import.dart`’s self-reimplemented order calculation with assertions against the **production order code path** or relabel it explicitly as a non-gating diagnostic tool.
9. Maintain local service contract/component tests alongside a **single bounded true DB-integration suite**. Where a full Flutter plugin context is not viable, run a pure-Dart HTTP/RPC integration harness within the database job and pair it with pgTAP contracts; reserve browser-level lessons for the separately scoped smoke tests. Do not require a DB round trip for every parsing edge case.
10. Guard against accidentally using hosted production URLs or secrets; load only `supabase status -o env` values for CI, then check local loopback URL/DB host allowlists. A setup error, skipped initialization, or missing fixture **must fail**, not return success.

**Done when:** One real lesson-creation-and-readback scenario and meaningful failure/cleanup scenarios run automatically and fail reliably on injected errors.

### A3. Audit the rest of Python test discovery (**P0; report in PR-1, enforce in PR-2**)

- Use `unittest` discovery for files genuinely written as `unittest` tests, and `pytest` for pytest-style files.
- Avoid a single accidental “run all files” command that double-executes or changes test semantics. Maintain a simple manifest/classifier with test framework and expected discovery route, or converge deliberately on pytest (which can run many unittest tests) **after proving compatibility**.
- Add lightweight `tool/ci/check_test_inventory.py` in **PR-1 as report-only**: enumerate `tool/tests/test_*.py`, display registered vs. omitted modules in `$GITHUB_STEP_SUMMARY`, and prominently flag the known algebra omission without changing the required check outcome. In **PR-2**, enable **strict mode**: each module must map to a verified runner (`unittest`, `pytest`, or intentional exception), and CI rejects uncollected modules, accidental duplicates, missing runner dependencies, and test files with zero collected cases. Every future test file must run or cause a clear CI failure.
- Keep coverage of isolated Python filesystem/docker interfaces. Require network-disabled default cases where possible.

**Done when:** Adding a supported new test file cannot silently result in a green CI job that never executes it.

### A4. Make the log trustworthy (**P1**)

- Search successful runs for `MissingStubError`, `MissingPluginException`, `LateInitializationError`, unexpected warnings, and swallowed failures.
- For each occurrence, record source test, expected/intentional status, and code path. Add test-local interception or explicit expected-error assertions where appropriate.
- Fix incomplete mocks of plugin methods, controlled local storage, and provider initialization. Avoid weakening real production error reporting to quiet CI.
- Log expected negative-path exceptions as **expected assertions**, not an unexplained wall of errors.
- In E2E/service tests, treat unexpected warning/error output as a failure only after distinguishing genuine errors from intentional negative tests.

---

## 6. Workstream B — Critical product behavior matrix

Risk-rank each requirement and ensure the correct test layers. The matrix below is an **audit/implementation checklist**, not a claim that these tests are absent; several have existing coverage.

| Product surface | Highest-risk regressions | Required evidence |
|---|---|---|
| **Answer keys and generated content** | Missing/ambiguous MCQ becomes option A; invalid short answer silently graded; content discarded | Unit truth table + import integration + DB rejection + mutation tests |
| **CLEP simulation** | Protected key leaks; unauthorized issue/submit; duplicates; incorrect blueprint quota/scoring; unsafe recovery | pgTAP auth/role tests + RPC contract tests + scoped UI journey + authored math correctness |
| **Fast / Overview modes** | Wrong exam blueprint, oversold readiness, suppressed prerequisite, hidden coverage gap | Planner and provider tests with independently expected target-specific plans; UI truthfulness checks |
| **External content discovery/evaluation** | Claims of proven readiness from unverified content; wrong attribution; broken return-to-context | Provenance/claims contract tests, mocked link outcome, browser journey |
| **Lesson creation/import** | Partial writes, stale local state, wrong answer, content order loss | Real DB import/readback and adverse write tests |
| **Feature controls / kill switches** | Disabled feature still routable; cross-feature cascading failure; reenable restores wrong state | Fail-closed registry tests, route/widget integration, one browser smoke case |
| **BYOK disabled state** | Credentials sent or stored unexpectedly; bypass via direct client or mock | Disabled-state network-denial and storage tests always active; provider-specific enabled tests behind controlled test-only gate |
| **Pre-reader / accessibility** | Outside taps redirect; wrong adult/kids order; audio pause/restart broken; inaccessible controls | Widget interaction, semantics/keyboard, real browser route/audio-controls smoke |
| **Progress / offline / sync** | Double-awarded progress, lost outbox, divergent stored state, wrong user scope | Unit state machine + persistence + local DB race/conflict tests |
| **Excel worker/uploads** | Malformed/unsafe file accepted; cross-owner access; unauthorized storage; failed cleanup | Python failure matrix, sandbox worker smoke, DB storage races, log evidence |
| **Analytics / privacy** | Consent bypass, identity exposure, incorrect retention/erasure, small-cohort leakage | pgTAP role/consent/retention tests, client outbox tests, admin view tests |
| **Migrations / taxonomy** | Schema drift, backwards migration rewrite, bad hosted-upgrade order, changed source hashes | Append-only checker, incremental upgrade, historical rehearsal, fresh reset, pinned-source validation |
| **Real learner completion** | Individually green components fail when chained | Small browser E2E on guest and authenticated/disposable test paths |

### Test contracts to standardize

For critical boundaries, create versioned fixtures containing:

- **Input**: authored question, API payload, signed-in state, target version, feature flags, and source status.
- **Expected result**: exact state/fields/permissions; explicit absence of protected fields.
- **Expected persistence**: user-scoped DB state or no-write guarantee.
- **Failure cases**: missing fields, invalid types, stale/replayed requests, ownership mismatch, timing limits, and offline transitions.
- **Evidence**: a test ID, requirements/reference link, and coverage/mutation indicator.

Avoid copying large fixtures into multiple test files; use checked-in immutable examples and small builders. Builders must not silently auto-correct invalid inputs that tests intend to reject.

---

## 7. Workstream C — Independent content and assessment oracles

### C1. Math/logic correctness

Build an **item-to-oracle link** for each CLEP Algebra question: stable item ID, canonical prompt variables/expression, intended assumptions/domains, expected solution (including equivalence class if appropriate), selected response, and explanation requirements.

Required checks:

1. Every answer key falls within the available option range, and ambiguity/duplicate keyed options are handled per the canonical policy.
2. The selected option is mathematically equivalent to the oracle’s solution, **not just positioned at a hardcoded index**.
3. Excluded denominators, complex/radical domains, units, rounding, and extraneous roots are explicitly checked.
4. False distractors are actually false under stated assumptions, not merely different strings.
5. Short-answer accepted responses cover valid representations while rejecting clearly invalid alternatives.
6. The explanation logically supports the selected option and does not contain contradictions or draft scratch notes. Automation can flag questionable explanations, but a content-editor review may still be required.
7. Blueprint/quota metadata points to the correct target and release; Fast mode must not accidentally select Psychology mapping for Algebra or vice versa.
8. Store stable negative fixture tests for each confirmed historical content/scoring bug.

**Do not overclaim:** Code can check formula equivalence for suitable items but cannot automatically prove every educational claim, psychometric fairness, or learner readiness. Human subject-matter review remains a separate gate where needed.

### C2. Mutation-test seed set

Use isolated, deliberately defective *temporary test copies* or mutation tooling (never commit a broken production path) to prove that tests catch:

- Missing MCQ key transformed to `0`.
- Client-provided score accepted instead of server result.
- Unauthorized user reading another learner’s attempts.
- Protected explanation or `correct_index` included in a simulation response.
- Disabled BYOK client making an HTTP call.
- Feature kill switch ignored by one entry route.
- Lesson import swallowing partial DB failure.
- Incorrect target blueprint selected for an exam.
- Incorrect answer option mapped by the algebra accuracy verifier.

**Initial acceptance:** Every hand-selected, supported critical mutation in this seed set should be detected by one or more required tests. Then measure a broader mutation score, triage equivalent mutants, and set a defensible target from the baseline; do **not** invent a global threshold now.

**Implementation status (PR-4b, 2026-11-12).** `tool/ci/mutation_seeds.py` runs the client-side seeds: baseline must pass, the edit must match exactly once, the targeted tests must fail, and the file is restored byte for byte (it refuses files with uncommitted changes). Every PR runs `--check` plus 12 runner unit tests; the full run is `.github/workflows/mutation-seeds.yml` (manual dispatch and weekly, not a required check).

| Seed | Plan item | First run |
|---|---|---|
| `answer-key-missing-becomes-option-a` | missing MCQ key → 0 | killed |
| `byok-latch-enabled` | disabled BYOK making calls | killed |
| `lesson-import-swallows-partial-failure` | import swallowing partial DB failure | killed |
| `absent-feature-flag-treated-as-on` | kill switch re-enabled on registry failure | killed |
| `contribution-ignores-kill-switch` | kill switch ignored by one entry route | **survived** → widget tests injected the gate's value; added real-gate provider tests; now killed |
| `client-score-trusted-over-server` | client score accepted instead of server result | killed |
| `wrong-exam-blueprint` | incorrect target blueprint for an exam | killed |
| `algebra-shipped-answer-key-wrong` | wrong algebra option in shipped YAML | killed |

Not yet seeded (need the database job): unauthorized reads of another learner's attempts and protected `correct_index`/explanation in a simulation response. These are covered by pgTAP today; SQL-level seeds are a follow-up.

---

## 8. Workstream D — Runtime instrumentation before optimization

### D1. Measure stages and test cases

- Start **lean**: use existing GitHub Actions job/step timestamps and `$GITHUB_STEP_SUMMARY`; avoid a new custom dashboard. Track current test-file inventory separately from each historical run's own test-file count. Measure queue time, checkout, Flutter setup/cache, dependency resolution, analysis, Python suite, full tests, each build, Supabase startup/readiness, migration scenarios, pgTAP, taxonomy, and cleanup. Add a tiny extraction script only if built-in reports are demonstrably insufficient.
- Capture **test-level** duration and flaky-retry metadata with `flutter test --file-reporter=json:<path>` **after confirming support on pinned Flutter 3.47.7**; keep human-readable console reporting. Distinguish test duration from parallel/interleaved reporter output and process startup. Keep output small, scrub IDs/secrets, and avoid uploading full verbose test logs unless necessary.
- Save historical 7-day and 30-day **p50/p95 elapsed times**, failure rates, reruns, and aggregate runner-minutes. Use at least 5 comparable baseline runs for preliminary decisions, ideally 10+ across different PR types.
- Tag jobs by `flutter`, `database`, `taxonomy`, `web-build`, `content-math`, `browser`, `tooling`.
- Record the exact Git SHA, Flutter SDK (`3.47.7` as audited), Supabase CLI (`2.67.1` as audited), runner image, cache hit/miss, and test inventory hashes for reproducibility.
- Upload timing/coverage data as a small artifact with limited retention; exclude secrets, user files, and any production/private data.

### D2. Baseline GitHub Job Summary (dashboard deferred)

Each relevant run should publish a compact, human-readable `$GITHUB_STEP_SUMMARY` table. Avoid introducing a dashboard, database, or paid reporting service merely to watch CI timings:

| Metric | Baseline | Optimized | Change | Pass rule |
|---|---|---|---|---|
| Required CI wall time p50 / p95 | Measure | Measure | % | Improvement without quality regression |
| Aggregate job runtime | Measure | Measure | % | Increase justified and bounded |
| Flutter tests executed | 2,585 sample | Actual | Delta | No unintended omissions |
| pgTAP assertions per applicable run | 1,709 sample | Actual | Delta | No unintended omissions |
| Python tests collected by framework | Audit | Actual | Delta | All registered suites collected |
| Distinct critical behavior contracts | Inventory | Actual | Delta | No lost high-risk contract |
| Skipped/xfail tests | 4 ordinary Flutter sample | Actual | Delta | Every skip justified and owned |
| Flake rate / reruns | Measure | Measure | Delta | Stable or better |
| Coverage by risk area | Measure | Measure | Delta | No regression in critical modules |
| Critical mutation detection | Measure | Measure | Delta | All seed mutations detected |

Avoid an arbitrary count-only “test quality score”; combine the quality rubric, risk coverage, and verified mutation sensitivity.

---

## 9. Workstream E — Restructure GitHub Actions safely

### E1. Optimize Flutter concurrency first; preserve exact required check names

**First experiment (same existing runner/job):**

1. Record the pinned Flutter version (currently `3.47.7`) and run `flutter test --help` to confirm **supported `--concurrency`, `--total-shards` / `--shard-index`, and `--file-reporter` options**. The normal no-flag invocation delegates to Dart's default concurrency; it is **not** concurrency-off. Benchmark **that real default** against explicit values rather than comparing to an imaginary one.
2. Benchmark the same commit/fixtures using the current default and explicit concurrency values (example: 2, 4, 6, 8), constrained by hosted runner CPU/memory. Use 5+ comparable trials, check test counts, flakiness, max memory, CPU oversubscription, and elapsed time.
3. Inspect slow test files and recurring setup costs before assuming sharding will help. Preserve the **separately run 50k synthetic export probe**; it does not account for the ordinary-suite 3–4-minute duration.
4. Only if the same-runner optimization plateaus, trial **two** runner shards. Consider three only if incremental improvement is clear. Use runner-supported sharding (`--total-shards`, `--shard-index`) after verifying support in Flutter 3.47.7, and compare exact discovered/collected inventory plus skips, not just total pass counts.
5. Measure two distinct outcomes: **developer elapsed wall time** and **aggregate job runtime / storage**. With a currently **public** repo, standard GitHub-hosted compute is free; do not claim each extra minute burns a private-account monthly quota. Still enforce an efficiency budget and no paid runner upgrades.

**Required-check compatibility when splitting the original `verify` job:**

- Existing `Analyze, test, and build` becomes the **one** always-evaluated fan-in **job name**, not the new `static-and-contracts` or `flutter-tests` names. Do **not** leave an old job with the same display name and a new aggregator with that name; GitHub may regard duplicate check names as ambiguous.
- The aggregator explicitly lists all required upstream `needs`: Flutter suite/matrix, fast static-contract checks, both web-build variants **if moved out**, Docker worker and critical content validations **if moved out**. External workflow checks such as taxonomy and the existing DB job remain separately required; do not falsely imply `needs` can read across workflows.
- Its job condition uses `if: ${{ always() }}`. Its executable verification step checks **every** required `needs.<job>.result == 'success'` and fails closed for `failure`, `skipped`, `cancelled`, or unexpected missing results. Do not put `continue-on-error` on required children.
- A required job which GitHub marks `skipped` can sometimes satisfy branch rules, so **do not make the final aggregator itself conditional/skippable** on PRs where it is required. Explicitly test failure, cancellation, and skipped-child scenarios in a controlled PR.
- Keep other check names **unchanged**: `Validate official taxonomy sources` and `Verify clean Supabase migrations and complete official taxonomy ingestion`. If the DB job itself is split later, its same-name replacement must also be a fail-closed final check.
- Branch-protection configuration is **reported** as requiring those names, but the connector's protection endpoint returned `403`. Before first topology-changing PR, inspect settings with an authorized admin UI/access route and verify a disposable PR's merge box reports every required check on the final SHA. Never bypass protection to merge a CI change.

**Illustrative aggregator sketch (reconcile `needs` IDs with final workflow; not paste-ready):**

```yaml
jobs:
  # Other jobs use different `name:` values, e.g. static-and-contracts,
  # flutter-suite, web-standard, web-preview. Do not reuse old check name.
  required-flutter-gate:
    name: Analyze, test, and build
    if: ${{ always() }}
    needs: [static-contracts, flutter-suite, web-standard, web-preview]
    runs-on: ubuntu-latest
    steps:
      - name: Reject failed, cancelled, or skipped dependencies
        env:
          REQUIRED_RESULTS_JSON: ${{ toJSON(needs) }}
        run: |
          python3 - <<'PY_GATE'
          import json, os, sys
          results = json.loads(os.environ['REQUIRED_RESULTS_JSON'])
          required = ['static-contracts','flutter-suite','web-standard','web-preview']
          failures = {job: results.get(job, {}).get('result', 'missing')
                      for job in required
                      if results.get(job, {}).get('result') != 'success'}
          print('Required CI upstream results:', {j: results.get(j, {}).get('result') for j in required})
          if failures:
              sys.exit('Missing or non-success required jobs: ' + repr(failures))
          PY_GATE
```

Keep the existing two-job topology until the measured case for splitting is convincing. Avoid new workflow files with duplicate required check names.

### E2. Preserve both web build variants; avoid shared-state races

- Both **standard** and `--dart-define=ENABLE_SIMULATION_PREVIEW=true` release builds must pass on the reviewed merge SHA before merge. Maintain a meaningful runtime/compile-time gate check, not just compiler exit.
- **Do not launch both Flutter build commands simultaneously in the same checkout.** Supplying `-o build/web_standard` and `-o build/web_preview` is useful for output separation but **does not guarantee isolation** of `.dart_tool` or other intermediate state. Either keep them sequential or use genuinely independent checkout/workspace/runner contexts with isolated mutable paths and verified artifact paths.
- Before adding jobs, measure repeated serial builds and investigate whether build cache reuse, unnecessary clean operations, or build configuration changes offer savings. On draft PRs, optional early feedback can run one build, but ready-to-merge full CI **must** run both; avoid a permanently green required aggregator over an unexecuted preview build.
- If independent build jobs are chosen, use separate standard runners, output directories, artifact labels, immutable SHA, and `needs` linkage to the required same-name aggregator. Compare wall-clock gain, startup overhead, test coverage, cache/storage footprint, and policy constraints.
- Do not strip the preview build solely to hit an arbitrary elapsed target; maintain the intentional preview compilation and feature-gating checks.

### E3. Database job optimization (second bottleneck)

Current distinct coverage to retain:

1. **Incremental upgrade from `origin/main`** with pending migrations isolated and restored.
2. **Historical hosted-ledger replay/backfill** in the order actually needed for production reconciliation.
3. **Fresh clean-slate reset** with pgTAP.
4. **Actual local Storage race/ownership probes** where applicable.
5. **Official taxonomy ingestion and strict coverage** on a known clean state.
6. **Post-ingestion integrity, pgTAP, and database lint**.

Safe optimization candidates:

- Instrument exactly how much is spent on Docker image download, service startup/readiness, SQL migration application, pgTAP, taxonomy source preparation, taxonomy ingestion and lint.
- Reuse an already-running local Supabase **only when** state isolation is proven; each distinct migration scenario must get its intended baseline.
- Keep the Supabase Docker stack in its existing dedicated job and add new pure Dart↔database integration tests **there**, not in a newly booted duplicate stack. Consider independent DB jobs only if startup duplication, runner usage, and isolation are measured and acceptable.
- Cache **immutable, cryptographically verified source artifacts**, not untrusted or mutable DB state. A local `pg_dump` or `CREATE DATABASE ... TEMPLATE` is only a **research candidate**, not an approved replacement for `supabase db reset`: it cannot be declared byte-for-byte equivalent to a full Supabase environment. Before even trialing it, demonstrate roles, extensions, migration ledger, seed, storage/auth metadata, pgTAP, race probes, historical-upgrade semantics, and repeatability are unchanged on multiple fresh runners.
- Investigate whether some validation can run before expensive `supabase start`, but do not pretend pure lint is an adequate substitute for actual migration execution.
- Keep test data synthetic and local; **never** point reset/migration commands at production. Reject URL and database targets that are not known local/disposable; do not use remote reset or a template of production state. Optimizations must preserve the existing incremental, hosted-ledger replay, clean-slate, and post-ingestion scenarios.

### E4. Avoid unnecessary repeated validation

- Migration-history immutability runs in both main jobs. Decide whether it should be an independently required contract job and remove duplicate invocations **only if** no scenario relies on a fresh branch-specific check.
- Governance tests run as an explicit subset before the full suite. Decide whether early failure feedback is worth the few seconds; if removed, ensure they are still in the sharded full suite and visible as a separate contract report where appropriate.
- Bundle groups of small Python unittest invocations **only where** they share dependencies and independent isolation; preserve per-module reporting so debugging remains easy.
- Investigate checkout `fetch-depth: 0` only for jobs that do not need history; retain full history for migration immutability/`origin/main` comparison.

### E5. Change-aware early checks without false-green required checks

Use a conservative path-to-risk classifier, for example:

| Changed files | Early checks | Full merge gate |
|---|---|---|
| Documentation only | Markdown/links and lightweight lint | Required verification policy still applies; do not bypass protected checks |
| Flutter UI | Flutter analysis, relevant widget/service tests, main web build | Full Flutter + required DB/security/other configured checks |
| `lib/models`, `lib/services`, test helpers | Relevant contracts + tests | Full relevant suites |
| Content/manifests | Schema, source provenance, content math, ingestion dry-run | Full content + database and app checks |
| Supabase migrations/functions/RLS | Migration checks + local DB suite immediately | Full DB/security suite, complete required checks |
| Auth/permissions/assessment scoring/storage/feature flags | All affected security and cross-boundary checks immediately | Full comprehensive required suites |
| CI/build/lockfiles/test infrastructure | Full workflows | Full workflows |
| Unknown/ambiguous changed path | Full workflows | Full workflows |

**Rules:**

- Prefer a **fast preliminary feedback job** plus **unchanged/full required merge gate**, at least for the first rollout.
- If introducing path-based gating later, use a **required aggregator that always runs**, handles `success`/`failure`/`cancelled`/`skipped` explicitly, and is tested against GitHub branch protection.
- Do not rely on `on.pull_request.paths` exclusions for required workflows; a path-skipped required check can remain pending and block merge.
- Include merge-queue `merge_group` handling **if** the repository uses a merge queue.
- Rerun on updated SHA; ensure no stale green check is treated as verification for new code.
- Concurrency cancellation must not cancel unrelated branches/PRs or cause main-branch push verification to disappear in a way that changes release policy.

### E6. Dependency and workflow supply-chain hygiene

- Keep version pinning of Flutter and Supabase CLI explicit; test upgrades on a dedicated branch.
- Review third-party GitHub Actions for supported Node runtimes and supply-chain posture. The audited DB log warned that `actions/cache@v4` and `supabase/setup-cli@v1` target deprecated Node 20; investigate supported updates rather than suppressing warnings.
- Prefer reviewed full commit-SHA pinning for third-party Actions where practical, with automated update review. Do not casually float versions during a CI performance refactor.
- Minimize job `permissions`, isolate secrets from PR code, and retain protections for guarded production deployment workflows.

---

## 10. Workstream F — Real browser E2E smoke tests

The app is a PWA; add small true browser tests to cover gaps that `flutter test` and successful `flutter build web` cannot.

### First PR gate: only 2–3 critical smoke journeys (expand for release)

1. **Guest navigation + explicit pre-reader routing:** Open the built app, navigate ordinary Library/learning UI, verify no accidental literacy redirect, then explicitly select pre-reader entry and confirm it works. Check key accessibility semantics.
2. **Lesson creation → persistent readback:** In a disposable, local auth/backend test, create a synthetic lesson, reload and read it back; verify actual ordered terms/questions, answer index, explanation and ownership. If browser infrastructure cannot safely support it yet, defer as an explicit gap while the DB-job integration gate supplies lower-layer proof.
3. **Synthetic assessment safety:** Start a practice/simulation fixture, verify gated availability, grading/report language, and that protected answer-key fields are not exposed in an unauthorized browser/client payload. No real exam bank or learner data in test traces.

**Release/nightly expansion (not every PR initially):** narration pause/resume/restart; Fast-mode plan truthfulness; feature kill switches; BYOK disabled-state/zero provider requests; analytics consent/erasure; cross-browser semantics and mobile viewport behavior. Give each journey a risk owner and bounded timeout; promote to PR gate after sustained stability.

**Implementation notes:**

- Evaluate Playwright (or another compatible browser harness) against **actual Flutter 3.47.7 web output**. Flutter renders primarily on canvas; regular DOM text/role selectors may not exist until the Flutter accessibility semantics tree is enabled. Prefer the documented invisible `aria-label="Enable accessibility"` control in a test harness or a deliberately scoped `SemanticsBinding.instance.ensureSemantics()` bootstrap; validate both selector stability and accessibility behavior. Avoid brittle hardcoded `flt-glass-pane` shadow-DOM internals as a long-term test API. Pin browser/harness versions and use accessible semantic labels in the app.
- Prefer deterministic fake clocks, mocked third-party resources, and local/disposable Supabase fixtures.
- Do not require production OAuth, production API tokens, real credit/medical/user data, or expensive external LLM calls.
- Start with Chromium as the baseline; add browser diversity based on actual supported target platforms and risk. Accessibility checks should supplement—not replace—manual review.
- Add screenshots/traces **on failure only**, avoiding capture of sensitive content; enforce artifact retention limits.
- Keep the PR gate small and fast; run a broader browser/device matrix in nightly or release candidate validation if needed.

---

## 11. Workstream G — Flakiness and performance stability

### Flake management

- Gather rerun rates and failures by test ID for at least 30 days where history is available.
- Reproduce suspected flaky tests with repeated isolated runs, randomized ordering where supported, and controlled clocks/seeded randomness.
- Investigate collisions in Hive/SharedPreferences, global provider state, temporary files, Supabase schemas, and test fixture user IDs before enabling more parallel execution.
- Quarantine only with an **explicit issue, owner, expiration, and alternative protection**; never quietly delete assertions or add unlimited retries.
- Retries are diagnostics, not a replacement for reliable tests. Required checks should expose flakiness rather than present a misleading pass.

### Performance probes

- Keep the 50,000-item synthetic export probe separate from normal test assertions because it tests a different workload.
- Replace unbounded timing assertions with controlled baselines, release/commit provenance, and tolerance for noisy hosted runners. Use p95 or repeated trials before making new gates.
- Investigate slow tests and high setup overhead by measured file/test timing, not logs that interleave multiple workers.
- If a performance fixture validates no real-world latency SLA, label it **load/synthetic** rather than guaranteeing product performance.

---

## 12. Coverage and reporting policy

### First report (no arbitrary percentage gate)

Generate:

- Flutter/Dart **line and branch coverage where supported**; separate unit, widget, service, and integration observations.
- Python coverage for tooling, broken down by package/subsystem.
- A Supabase **security/contract matrix**, because pgTAP assertion count is not equivalent to line coverage of SQL functions/RLS policies.
- A list of critical untested files/branches and risk-specific gaps.
- Explicit coverage exclusions with reasoning (generated mocks, vendored code, generated output, etc.).

### Progressive gates

1. No unexplained drop in coverage on **changed critical code**.
2. All defined P0 invariants have at least one direct negative-path test and one boundary-level verification where applicable.
3. High-risk changes require tests that would fail under a representative bug/mutation.
4. Introduce numerical floors **after** baseline and false-positive assessment. Track critical-module coverage separately from aggregate project-wide coverage.
5. Coverage and test result files are uploaded as artifacts with a digest/commit reference, and results are presented in PR checks without requiring a paid reporting service.

Do not replace functional test review with raw coverage percentages or test counts.

---

## 13. Implementation phases and suggested PR sequence

Each phase should be a reviewable PR or small cluster; **do not implement all at once**. Branch from a fresh, verified `main` and rebase/update with concurrent work carefully. The repository is active, so avoid testing a stale branch or overwriting parallel feature work.

### Phase 0 — Measurement and risk inventory

**PR-1: `ci: lean baseline timing and quality inventory`**

- Pin baseline SHA and sample runs; collect timings, successful/skipped test inventory, and coverage baseline using existing GitHub logs.
- Publish a **GitHub Job Summary** (`$GITHUB_STEP_SUMMARY`) and, if supported by the pinned Flutter toolchain, a compact `--file-reporter=json:...` test report. Avoid custom dashboards, databases, or large default artifacts.
- Document three required check names, with **branch-settings verification blocked by connector 403**, plus environment/secrets dependencies and public-repository billing status.
- Add lightweight `tool/ci/check_test_inventory.py` **in report-only mode**, reporting the known omitted suite and other unknowns without failing the baseline PR merely because of already-recorded gaps; fail on unexpected script execution/parsing errors. **Switch it to blocking mode in PR-2**, paired with the missing suite, rather than declaring an uncollected suite acceptable forever. Add no performance-sensitive gating yet and do not interact with production.

**Exit criteria:** Full original pipeline still green; baseline artifacts readable and reproducible; confirmed findings are recorded with test locations.

### Phase 1 — Correctness and completeness first

**PR-2: `test(content): close generator-to-shipped-manifest algebra verification gap`**

> **v4.1:** delivered as PR-2a (activate + parity + strict inventory; closes Q-01/Q-06), PR-2b (stable IDs) and PR-2c (ID-keyed oracle + mutations; closes Q-03). See §0C.2.

- **Mandatory source chain:** author stable IDs in domain/formative source modules → extend `AssessmentItem` and `LegacyQuestion` JSON Schema with **optional** `id` properties → require IDs only for College Algebra by **target slug** in linter → verify Dart mapper behavior → deterministic **read-only `yaml.safe_load` generator↔committed YAML semantic parity gate** → independent math/logic oracle keyed by ID against actual YAML selected options.
- Verify **60 simulation + 40 formative** item identities; reject missing/duplicate IDs; explicitly document simulation ID preservation in metadata and whether formative IDs are manifest-only or require approved additive DB persistence.
- Use `PYTHONPATH=. python3 -m pytest tool/tests/test_clep_algebra_math_accuracy.py -q`, with **tested exact** `pytest`, `sympy`, and `PyYAML` pins in root `requirements-ci-tests.txt` and `python3 -m pip check`, **inside the existing Flutter CI job**. Prefer locked/hash-pinned transitive dependencies. No new runner and no floating `PyYAML>=6.0` in the touched step.
- Enable **strict mode** on the `tool/ci/check_test_inventory.py` script created in **PR-1**; verify all Python files are mapped to an executable framework collection route, with zero-collected suite detection.
- Prove controlled mutations of shipped prompt, key, option, domain restriction, ID and YAML-generator parity cause CI failures; record active versus advisory answer-key distribution policies separately.
- **No acceptance of a partial fix:** Running existing pytest against only Python generator modules does not close Q-01/Q-03. If needed, split the cross-layer change into two reviewable correctness PRs, but maintain a failing/disabled-not-required status until the complete gate is genuinely active.

**PR-3: `test(import): real lesson creation/readback and fail-closed integration`**

- Replace the inactive legacy test with real disposable integration coverage **within the existing DB job / local Supabase stack**; choose pure Dart RPC/HTTP contracts plus pgTAP where Flutter plugin runtime is unnecessary.
- Add partial-write cleanup and invalid-key negative cases, fail on setup errors, and reject any nonlocal target.
- Demote diagnostic scripts or transform them into real assertive tests.

**PR-4: `test(quality): strengthen critical assertions and error handling`**

- Focus on P0/P1 components, not bulk cosmetic rewrite.
- Triage unexpected error logs and ensure setup failures fail tests.
- Add minimal mutation seed runner in isolated CI context.

**Exit criteria:** Missing suite now executes; previously unverified scenarios produce actual failures when intentionally broken; no reduction in existing protections.

### Phase 2 — Scheduling and runtime improvements

**PR-5: `ci: measured Flutter concurrency and build scheduling`**

- Benchmark **intra-job** `flutter test --concurrency` against the current/default behavior first; inspect CPU, memory, flakiness and collected test inventory.
- Preserve both web builds; benchmark serial reuse versus completely isolated parallel jobs, **never concurrent builds against a shared `.dart_tool` tree**.
- Only if justified, trial 2 test shards, then optionally 3; preserve exact collected inventory and measure wall time/aggregate job-seconds.
- **If splitting**, replace the old visible `Analyze, test, and build` check with a single `if: always()` fail-closed fan-in job **of the same exact name**. Do not rename taxonomy or DB required checks, and test branch protection with a disposable PR before merging.

**PR-6: `ci(db): profile and optimize local migration rehearsal`**

- Break out timings of service start, schema resets, incremental migration/backfill, taxonomy ingestion, pgTAP, and lint.
- Optimize only proven duplicates or safe reuse; all scenarios retained.

**Exit criteria:** Several comparable runs show material latency improvement without test loss, new flakiness, hidden skips, or unacceptable runner-minute growth.

### Phase 3 — Better feedback and genuine user-journey proof

**PR-7: `test(e2e): deterministic browser learner smoke`**

- Add **2–3** highest-risk Chromium journeys (guest/pre-reader routing, lesson create/readback where feasible, simulated assessment safety) using disposable/test-only services.
- Enable/verify Flutter Web semantics for accessibility-based Playwright selectors, using documented mechanisms rather than brittle canvas coordinates; upload failure evidence safely.
- Move optional journeys to release/nightly until they are stable and inexpensive.

**PR-8: `ci: changed-file feedback and required aggregate status`**

- Introduce early targeted checks while maintaining **unchanged full pre-merge required checks**.
- **Do not create a second aggregator** if PR-5 already introduced the exact-name required fan-in. Reuse/test that same aggregator for skipped/failed/cancelled cases and confirm all three required statuses appear on the current SHA.
- Keep check-name changes out of scope unless explicitly reviewed and authorized.

**Exit criteria:** Fast feedback appears earlier and real browser journeys are verified; skipped optional jobs cannot masquerade as a passed required merge gate.

### Phase 4 — Ongoing governance

**PR-9: `ci: regressions, flaky-test and coverage policy`**

- Enforce a risk-based testing policy, preserve historical runtime data, document owners, and publish review guidelines.
- Add a recurring but bounded audit in existing CI/nightly release workflow if needed.

**Exit criteria:** Teams and agents adding features know which tests are mandatory, how they are discovered, and how to verify that the tests detect mistakes.

---

## 14. Detailed acceptance criteria (must all pass before final merge)

### Quality gates

- [ ] PR-1 reports all discovered/registered/missing `tool/tests/test_*.py` without false-green claims; PR-2 enforces runner mapping and actual collection, leaving no unaccounted test file.
- [ ] College Algebra pytest/SymPy suite **actually executes** in full CI; no green-on-not-collected outcome.
- [ ] Canonical generator output is compared **read-only via `yaml.safe_load` semantic equality** to `content/clep_college_algebra.yaml`; formatting-only changes pass, while content/options/key/ID/list-order drift fails.
- [ ] All 60 simulation and 40 formative items have unique stable IDs at the authoring source and in the committed YAML; the global JSON Schema allows optional IDs, while College Algebra **requires** IDs via target-aware linter logic. Existing unrelated manifests without IDs still validate; ingestion identity handling is deliberately validated.
- [ ] Real committed YAML prompts, selected answers and domain restrictions are independently checked by per-ID oracles; a hardcoded equation disconnected from YAML is insufficient.
- [ ] The 20–30% position distribution heuristic is explicitly classified as advisory or separately approved merge policy; active generator/pipeline 40%/45% limits are preserved.
- [ ] A deliberately wrong algebra key or option causes the expected test to fail.
- [ ] Missing/ambiguous MCQ answer keys remain unscorable/rejected; no fallback to option A.
- [ ] Legacy skipped lesson-creation test is replaced by active, deterministic equivalent-or-stronger coverage, or remains explicitly documented as legacy alongside fully active replacement.
- [ ] Invalid import creates no records; partial failure is accurately surfaced and cleanup outcomes are asserted.
- [ ] DB job retains all four `supabase test db` invocations (incremental, historical backfill, clean reset, post-ingestion) and fits within a measured margin below the 20-minute timeout after adding local integration.
- [ ] Existing simulation/privacy/RLS/owner/storage/retention tests remain active, with equivalent or higher assurance.
- [ ] BYOK remains disabled and its disabled-state safety gates are tested.
- [ ] Feature flag off/on and Fast mode contracts remain accurate.
- [ ] Expected skips are named and justified; unexpected skipping or zero-collected tests fails.
- [ ] At least the critical mutation seed set is demonstrated to be caught.
- [ ] Test coverage baseline is recorded, and no identified P0 risk is left without appropriate direct verification.
- [ ] Unexpected errors/warnings in passing tests are triaged.

### Performance gates

- [ ] Full CI wall-clock baseline and optimized p50/p95 are compared on comparable workloads, with sample count stated.
- [ ] If sharding is activated, all Flutter tests appear in exactly one shard (or a justified dedicated suite), with the canonical discovery inventory preserved. If not, existing full-suite execution remains intact.
- [ ] Both web build variants run and compile; normal and preview gating are verified.
- [ ] All defined database scenarios (incremental, historical backfill, fresh reset, after ingestion) still execute where required.
- [ ] No flake-rate regression beyond observed noise; failure diagnosis remains straightforward.
- [ ] Aggregate runner-seconds, cache/artifact impacts, and observed startup penalties are reported. Standard GitHub-hosted runners are currently free for this **public** repository; no paid runner or third-party service added.
- [ ] Target **~5–6 minutes** for normal full required PR checks is evaluated against data, **not asserted as achieved in advance**.
- [ ] Change-aware feedback never allows a PR to merge without its full required protection set.

### Operational/safety gates

- [ ] No access to production DB/storage or secret-bearing third-party APIs from test-only optimization.
- [ ] Three exact reported required status check names are preserved, with a fail-closed same-name aggregator if splitting occurs; GitHub branch settings and controlled merge behavior are verified via an authorized route (connector protection read returned 403).
- [ ] Existing guarded production deployment workflows remain unchanged unless a separate authorized deployment/security review requires it.
- [ ] CI token permissions and third-party Actions are reviewed; no new unreviewed secret exposure.
- [ ] Tests/documentation/commands can be reproduced locally or in a clean GitHub runner with explicit dependencies.
- [ ] Final PRs contain before/after evidence and a rollback strategy.

---

## 15. Decision metrics and success targets

### Initial **proposed** performance target (not a promise)

| Scenario | Current observed | Goal | Confidence |
|---|---:|---:|---|
| Full required PR checks | ~7–9 min | **~5–6 min** | Plausible; benchmark required |
| Fast preliminary feedback | Not separately measured | **~1–3 min** where possible | Requires new job topology; must not authorize merge alone |
| Full required suite after further DB improvements | Not established | **Explore <5 min** | Stretch goal, may be limited by DB work |

**Decision rule:** Trial same-runner concurrency before extra shards; if sharding produces only marginal wall-clock gains or substantial runner consumption/cache churn, prefer fewer shards. Public standard runners are currently free, but developer feedback, storage, quotas under a future private repo, and flakiness still matter. The correct outcome may be a **6-minute** high-assurance workflow rather than a fragile 3-minute one.

### Quality measures worth reporting

- **Execution completeness:** expected versus collected tests by framework and category.
- **Critical requirement coverage:** each P0 risk mapped to one or more verified tests.
- **Mutation sensitivity:** targeted known-bug mutations killed/survived, with any equivalent mutants documented.
- **End-to-end confidence:** actual user journeys verified with real browser and disposable services.
- **Signal quality:** unexpected warnings, retry counts, and false-green setup conditions.
- **Maintainability:** fixture complexity, flaky tests, speed of failure diagnosis, and duplicate assertion coverage.

---

## 16. Risks, trade-offs, and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Hidden suite activation exposes longstanding failing tests | Medium | High | Treat as genuine quality findings; fix cause, do not skip to force green |
| More runners increase runner use/cache/storage, even if standard compute is currently free for public repo | High | Medium | Record aggregate job-seconds, concurrency limits and artifact/cache use; re-evaluate billing if visibility changes |
| Shard imbalance reduces speedup | Medium | Medium | Use per-test/file timing and test runner sharding; revisit balance after real runs |
| Parallelization reveals state leakage | Medium | High | Audit fixture isolation, global providers, fake clocks, Hive/temp files |
| Changed/duplicated required-check name blocks merging or produces ambiguous results | Medium | High | Preserve all 3 exact names; use a **single** same-name fail-closed aggregator for any split job, and verify branch policy in an authorized UI/test PR |
| DB optimization accidentally drops a migration scenario or replaces full Supabase state with incomplete snapshot | Medium | Critical | Scenario matrix, roles/storage/auth/seed/ledger checks and assertion inventory must match baseline; template snapshots are experimental, not accepted shortcuts |
| Test “improvement” rewrites logic to match incorrect code | Medium | Critical | Independent oracle, explicit known-bug mutation, human content/requirements review |
| Integration accidentally uses production services | Low if guarded | Critical | Explicit local URL guards, throw on production-like hosts, ephemeral credentials |
| Broad coverage threshold incentivizes low-value tests | High | Medium | Risk-based changed-code coverage and mutation sensitivity |
| E2E browser suite introduces instability | Medium | Medium | Start small with deterministic services and timeouts; diagnose root causes, not retry blindly |
| CI dependency upgrade breaks unrelated code | Medium | Medium | Separate dependency updates and pin versions; compare before/after |
| Security tests skipped for “docs-only” changes | Medium | High | Always-run full required merge gate until safe classifier + branch policy are proven |

---

## 17. Rollback and operational playbook

1. **Before:** Preserve current `flutter-ci.yml`, `taxonomy-official-data.yml`, relevant branch-check names, baseline SHA, and sample run timings. Record active PRs and branch-protection requirements.
2. **During:** Use a dedicated branch and small PRs; require independent review of test deletion/replacement and CI changes. Maintain the old job while validating new equivalents where feasible.
3. **If new CI flakes:** Identify failing shard or job, compare run/fixture/runner data, revert scheduling changes if necessary; do not unconditionally mark failures successful.
4. **If migration coverage changes:** Stop and revert; restore all original rehearsal scenarios before proceeding.
5. **If a required status check gets stuck:** Restore the **exact** previous job name and required-check wiring; use a controlled PR to confirm the same-name aggregator rather than bypassing protection.
6. **If runner use/storage or costs rise:** Remember standard-hosted compute is currently free on public LearningApp, but additional concurrency/storage and any future private-repo move require review. Reduce shard count, minimize artifacts, or keep builds serial if the latency benefit is small.
7. **After:** Publish a concise final evidence report: tests executed, coverage baseline, mutation results, full CI timings, job-minutes, known remaining gaps, and any deferred work.

---

## 18. Suggested review checklist for every future AI-generated or human PR

This plan is especially important in a fast-moving multi-agent development workflow.

- [ ] What user-visible or data-integrity behavior changed?
- [ ] Which existing test proves the behavior? Which new regression test was added?
- [ ] Does at least one test fail with the **old broken implementation**, not just pass after the fix?
- [ ] For assessment content, was the actual authored answer independently validated?
- [ ] For DB/security code, are unauthorized user/role/error paths tested in actual pgTAP/local DB?
- [ ] For service code, is there a direct contract test plus necessary integration test?
- [ ] For a UI interaction, does the test click/type/navigate as a real user would, and assert resulting state?
- [ ] Did any test get skipped, loosened, deleted, renamed, or moved out of discovery? If so, what replaces it?
- [ ] Did a test introduce nondeterminism, real API calls, secrets, shared mutable state, or long sleeps?
- [ ] Do all applicable full required checks pass on the final commit SHA?
- [ ] Does performance evidence distinguish elapsed wall time from total runner consumption?
- [ ] Is any experimental or disabled feature still gated exactly as intended?

**Review principle:** A meaningful failing test is useful information. A passing test that cannot detect its target failure is false confidence.

---

## 19. Proposed repo artifacts (create during implementation, not in this plan-only request)

Suggested names are illustrative and should be reconciled with repo conventions:

```text
.github/workflows/flutter-ci.yml                     # Refactor carefully; retain required checks
.github/workflows/...                                # Optional small reusable workflows
requirements-ci-tests.txt                            # Tested exact direct pins; lock/hash transitive as feasible
tool/ci/check_algebra_manifest_parity.py              # Read-only yaml.safe_load semantic generated-vs-committed comparison
tool/ci/algebra_oracles/                          # Independent ID-keyed math/semantic oracle data; only if needed
tool/ci/check_test_inventory.py                      # PR-1 report-only; PR-2 strict collected-suite guard
# Prefer $GITHUB_STEP_SUMMARY first; add a tiny script only if needed
tool/ci/check_required_results.py                    # Optional same-name required-job fan-in logic; never duplicate required check
tool/ci/check_no_production_targets.py               # Test-only environment safety
tool/ci/critical_mutations/                         # Controlled mutation seed fixtures
integration_test/ or e2e/                            # Bounded browser smoke (2–3 PR paths)
.github/.../test-quality-policy.md                    # Critical test/skip/coverage policy
reports/ci-baseline/                                 # Only if intentionally committed;
                                                     # prefer GH artifacts for noisy data
```

Do not introduce directories merely for aesthetics; prefer a small set of understandable scripts and reuse existing tooling when appropriate.

---

## 20. Specific sources inspected and review verification

Additional source-of-truth checks made for Argon **and Grok** reviews, 2026-11-12:

- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions): **public standard hosted-runner compute is free**, unlike private-repo allowances; larger runners/storage may differ.
- [GitHub branch protection behavior](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches): exact status check naming matters; **skipped** is a branch-acceptable state, so the aggregator must explicitly reject skipped required children; duplicate job names are discouraged.
- [Supabase local `db reset` semantics](https://supabase.com/docs/reference/cli/supabase-db-reset): recreates local Postgres container and reapplies migrations/seeds; cannot declare a template-copy replacement equivalent without evidence.
- [Flutter Web accessibility](https://docs.flutter.dev/ui/accessibility/web-accessibility): semantics are opt-in via the accessibility control or `SemanticsBinding.instance.ensureSemantics()`, which affects real browser automation and accessibility testing.
- [Flutter test reporting example](https://github.com/flutter/flutter/issues/150370): `--file-reporter=json:<path>` syntax appears in Flutter tooling examples; **verify with the pinned 3.47.7 CLI before adopting it**.
- **GitHub repository API (authorized connection):** `RACCHUS/LearningApp` is currently **public**. Existing main CI job names are `Analyze, test, and build` and `Verify clean Supabase migrations and complete official taxonomy ingestion`. The branch-protection API request returned **403 Resource not accessible by integration**, so the required-check selection remains to be confirmed via an authorized interface.
- **Existing CI logs:** 50k synthetic load probe is a separate ~9-second test step, not the several-minute ordinary Flutter suite.



Repository evidence available as of baseline date:

- [Flutter CI workflow](https://github.com/RACCHUS/LearningApp/blob/main/.github/workflows/flutter-ci.yml)
- [Official Taxonomy Data workflow](https://github.com/RACCHUS/LearningApp/blob/main/.github/workflows/taxonomy-official-data.yml)
- [Flutter tests README](https://github.com/RACCHUS/LearningApp/blob/main/test/README.md)
- [Legacy integration README](https://github.com/RACCHUS/LearningApp/blob/main/test/integration/README.md)
- [College Algebra accuracy tests](https://github.com/RACCHUS/LearningApp/blob/main/tool/tests/test_clep_algebra_math_accuracy.py)
- [Taxonomy workflow](https://github.com/RACCHUS/LearningApp/blob/main/.github/workflows/taxonomy-official-data.yml) — confirms exact third required-looking CI job display name
- [Algebra manifest generator](https://github.com/RACCHUS/LearningApp/blob/main/tool/generate_clep_algebra_course.py) — current `build_manifest`, semantic content source imports, and direct write of committed YAML
- [Committed College Algebra manifest](https://github.com/RACCHUS/LearningApp/blob/main/content/clep_college_algebra.yaml) — the actual pipeline input
- [Curriculum JSON Schema](https://github.com/RACCHUS/LearningApp/blob/main/content/schema/curriculum_manifest.schema.json) — `AssessmentItem` and `LegacyQuestion` definitions currently reject unrecognized top-level keys
- [Dart ingestion transform](https://github.com/RACCHUS/LearningApp/blob/main/tool/ingest_curriculum.dart) — explicit assessment-item mapping currently drops top-level ID
- [Latest manifest ingestion SQL](https://github.com/RACCHUS/LearningApp/blob/main/supabase/migrations/20261112010000_manifest_answer_key_integrity.sql) — assessment `metadata` copied; formative `questions` written without source item ID
- [CLEP content pipeline tests](https://github.com/RACCHUS/LearningApp/blob/main/tool/tests/test_clep_content_pipeline.py)
- [Lesson import service tests](https://github.com/RACCHUS/LearningApp/blob/main/test/services/lesson_import_service_test.dart)
- [Lesson import service implementation](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/lesson/lesson_import_service.dart)
- [Generation session tests](https://github.com/RACCHUS/LearningApp/blob/main/test/generation_session_test.dart)
- [Answer-key tests](https://github.com/RACCHUS/LearningApp/blob/main/test/models/answer_key_test.dart)
- [Pre-reader navigation tests](https://github.com/RACCHUS/LearningApp/blob/main/test/widgets/pre_reader_home_navigation_test.dart)
- [CLEP simulation service tests](https://github.com/RACCHUS/LearningApp/blob/main/test/services/clep_simulation_service_test.dart)
- [Protected CLEP bank/privacy pgTAP tests](https://github.com/RACCHUS/LearningApp/blob/main/supabase/tests/clep_simulation_bank_and_privacy_test.sql)
- [Manifest answer-key integrity pgTAP tests](https://github.com/RACCHUS/LearningApp/blob/main/supabase/tests/manifest_answer_key_integrity_test.sql)
- [Excel brokered upload tests](https://github.com/RACCHUS/LearningApp/blob/main/tool/tests/test_brokered_upload.py)
- [Skipped legacy lesson creation test](https://github.com/RACCHUS/LearningApp/blob/main/test/integration/test_lesson_creation.dart)
- [Standalone import diagnostic](https://github.com/RACCHUS/LearningApp/blob/main/test/integration/test_import.dart)
- [CI run #1259](https://github.com/RACCHUS/LearningApp/actions/runs/43235491460)
- [CI run #1261](https://github.com/RACCHUS/LearningApp/actions/runs/43236263959)

### Evidence caveat

Repository code and recorded CI logs were inspected remotely; GitHub public-repo metadata and official tooling docs were additionally verified for this revision. For Grok review, the current repository also showed **67 `supabase/tests/*.sql` files**, 44 `test_*.py` files, and the ID-propagation gaps detailed in §0A. **v4.1 addendum:** §0C records a local-checkout re-verification with the pinned Flutter 3.47.7 CLI and a local run of the algebra suite and generator parity; it supersedes the counts above where they differ. The original v4 text that follows describes the v4 review only. This plan **does not claim** a new branch was created, tests independently rerun, coverage/mutation tooling executed, branch protection read successfully, GitHub settings changed, or any CI improvement implemented. Performance and cost-overhead estimates remain hypotheses until benchmarked. All performance improvements remain **hypotheses to benchmark**.

---

## 21. Final execution order

1. **Use lightweight measurement; preserve check names.** Capture baseline with GitHub Job Summaries; treat all three exact required statuses as fixed, verify protection settings through authorized UI when possible, and document public-runner economics.
2. **Fix missing/false-green verification immediately.** PR-1 creates a **report-only** Python inventory; PR-2 switches it to **blocking**, and adds **stable authored IDs + backward-compatible optional schema IDs (required by Algebra-target linter only) + ingest identity checks + read-only semantic generator/YAML parity + real-YAML independent math/logic oracles** within the existing Flutter CI job; PR-3 puts real Dart↔local-Supabase integration in the **existing DB job** (instrument the existing 20-minute timeout headroom first).
3. **Improve critical test oracles.** Prioritize answer correctness, server grading, privacy, storage, content provenance, readiness honesty, and feature switches.
4. **Prove test effectiveness.** Run targeted known-bug mutations; record measured coverage rather than inflated counts.
5. **Optimize within the existing job first.** Benchmark Flutter concurrency and serial build reuse before sharding; only split with proven benefits, isolated build state, measured job usage, and a single required same-name `Analyze, test, and build` aggregator.
6. **Optimize the database job only with scenario parity.** Profile actual resets and Docker/startup; preserve full migration/security evidence.
7. **Add only 2–3 deterministic browser smoke journeys first.** Enable Flutter Web semantics for robust locators, use local/disposable data, and expand to release/nightly checks when stable.
8. **Make quality durable.** Add discovery guards, strict skip policy, timing report, test-review checklist, and carefully engineered fast preliminary feedback.

**Success is not “all checks complete in three minutes.” Success is “the right checks reliably detect meaningful regressions, run without waste, and make a green PR genuinely trustworthy.”**
