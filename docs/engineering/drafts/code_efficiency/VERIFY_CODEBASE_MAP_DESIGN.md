# `tool/verify_codebase_map.py` — design (DRAFT, not built, not in CI)

Status: Phase 1 design only. No tool file, no CI step. Activation needs owner approval and must follow `docs/testing/TEST_QUALITY_POLICY.md` (start as an advisory check; never rename `Analyze, test, and build`; join the gate only after the stability bar).

## 1. Purpose and limits

Checks that every **machine reference** in `docs/engineering/CODEBASE_MAP.md` points at a real file and a real line range. It does **not** prove that the referenced file still owns the behaviour; that needs a human reading the section when ownership changes (see `INSTRUCTION_SURFACE_INVENTORY.md` §3).

## 2. Reference grammar (frozen)

One HTML comment per reference, on its own line:

```
<!-- map-ref path="<repo-relative path>" role="owner|contract|test|policy" [lines="<start>-<end>"] -->
```

- Attribute order is fixed: `path`, `role`, optional `lines`. Double quotes only.
- Only these comments are parsed. Backticked paths, fenced code blocks and prose are ignored. A `map-ref` inside a fenced block (like the example above) is ignored.
- `lines` is inclusive, 1-based, `start <= end`.

Regular expression (applied per line, outside fenced blocks):

```
^<!-- map-ref path="([^"]+)" role="(owner|contract|test|policy)"(?: lines="([1-9][0-9]*)-([1-9][0-9]*)")? -->$
```

A line that starts with `<!-- map-ref` but does not match is an **error** (catches typos rather than silently skipping them).

## 3. Checks

| # | Check | Failure message |
|---|---|---|
| 1 | Grammar matches | `malformed map-ref at line N` |
| 2 | Path is relative, uses `/`, has no `..`, no leading `/`, no drive letter | `path escapes repository` |
| 3 | `realpath(repo/path)` stays inside the repository (symlink safety) | `path escapes repository` |
| 4 | Path is a tracked file (`git ls-files --error-unmatch`) | `missing or untracked: <path>` |
| 5 | If `lines` present: `end <= line count` (Python `splitlines()`) | `range a-b out of bounds (file has N lines)` |
| 6 | Each `## ` section with an `{#anchor}` has at least one `owner` and one `test` reference | `section <anchor> lacks owner/test` |
| 7 | Map size: ≤ 250 lines and ≤ 20,480 bytes | `map exceeds cap` |

Exit code 0 when clean, 1 on any failure; all failures are printed, not just the first.

Optional, separate and off by default: a symbol check (`--symbols`) that greps for a declared `symbol="…"` attribute in the referenced range. It is a text check, not semantic ownership.

## 4. Test fixtures (for `tool/tests/test_verify_codebase_map.py` when built)

| Fixture | Expected |
|---|---|
| Valid refs, with and without `lines` | pass |
| `path="../secrets.txt"` | escape error |
| `path="/etc/passwd"`, `path="C:/x"` | escape error |
| Symlink inside repo pointing outside | escape error |
| Missing file | missing error |
| `lines="10-5"`, `lines="1-99999"` | range error |
| `<!-- map-ref path=lib/x.dart role="owner" -->` (unquoted) | malformed error |
| `map-ref` inside a fenced block | ignored (pass) |
| Backticked `` `lib/does_not_exist.dart` `` in prose | ignored (pass) — false-positive guard |
| Section with only a `contract` ref | section error |

## 5. Prototype evidence

An ad-hoc check (not committed as a tool) applied checks 1, 4 and 5 to the draft map at pin `06221ed`: **all map-ref paths exist and all ranges are in bounds**. Runtime was well under a second on 53 references, but that is a single local run, not a benchmark.

## 6. Line-anchor drift

Line ranges go stale when files are edited above them. Options for the owner:

1. Keep ranges, and update them when the validator fails (cheap, noisy on busy files such as `router_provider.dart`).
2. Use ranges only for files that change rarely; use `symbol=` for busy files.

Recommendation: option 2. Busy files are listed in `audits/code_efficiency/data/churn_eligible.csv`.
