#!/usr/bin/env python3
"""Report-only Python tooling coverage by subsystem (plan §12).

Reads `coverage json` output for `tool/` (tests omitted) and writes a
Markdown table to stdout and `$GITHUB_STEP_SUMMARY`: overall statement
coverage, coverage per subsystem (each directory directly under `tool/`,
plus top-level scripts), and the least-covered files of meaningful size.

Like the Dart report there is **no percentage gate**: use it to find
untested tooling, then add tests that fail on a real bug. Exit 0 always,
except 2 when the input is missing or has no files.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

TOP_LEVEL = "(top-level tool scripts)"
MIN_STATEMENTS_FOR_LOW_LIST = 20


def subsystem(path: str) -> str:
    parts = path.replace("\\", "/").split("/")
    if "tool" in parts:
        parts = parts[parts.index("tool") + 1:]
    return parts[0] if len(parts) > 1 else TOP_LEVEL


def _pct(covered: int, total: int) -> str:
    return f"{100.0 * covered / total:.1f}%" if total else "—"


def render(data: dict, *, top: int) -> str:
    files = data.get("files", {})
    groups: dict[str, list[int]] = defaultdict(lambda: [0, 0, 0])  # files, covered, statements
    rows = []
    for path, info in files.items():
        summary = info.get("summary", {})
        total = int(summary.get("num_statements", 0))
        covered = int(summary.get("covered_lines", 0))
        group = groups[subsystem(path)]
        group[0] += 1
        group[1] += covered
        group[2] += total
        rows.append((path.replace("\\", "/"), covered, total))
    covered_all = sum(g[1] for g in groups.values())
    total_all = sum(g[2] for g in groups.values())
    lines = ["## Python tooling coverage by subsystem (report-only)", "",
             f"Overall `tool/` (tests excluded): **{_pct(covered_all, total_all)}** "
             f"({covered_all}/{total_all} statements, {len(rows)} files).", "",
             "| Subsystem | Files | Statements covered | Coverage |", "|---|---|---|---|"]
    for name, (count, covered, total) in sorted(groups.items(), key=lambda kv: -kv[1][2]):
        lines.append(f"| `{name}` | {count} | {covered}/{total} | {_pct(covered, total)} |")
    low = sorted((r for r in rows if r[2] >= MIN_STATEMENTS_FOR_LOW_LIST), key=lambda r: (r[1] / r[2], -r[2]))
    if low:
        lines += ["", f"<details><summary>Least-covered files (≥{MIN_STATEMENTS_FOR_LOW_LIST} statements)</summary>",
                  "", "| File | Coverage | Statements |", "|---|---|---|"]
        lines += [f"| `{p}` | {_pct(c, t)} | {c}/{t} |" for p, c, t in low[:top]]
        lines += ["", "</details>"]
    lines += ["", "No percentage gate (docs/testing/TEST_QUALITY_POLICY.md §7)."]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("coverage_json", type=Path)
    parser.add_argument("--top", type=int, default=15)
    args = parser.parse_args(argv)
    try:
        data = json.loads(args.coverage_json.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: cannot read coverage JSON: {exc}", file=sys.stderr)
        return 2
    if not isinstance(data, dict) or not data.get("files"):
        print("error: coverage JSON has no files", file=sys.stderr)
        return 2
    text = render(data, top=args.top)
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
