#!/usr/bin/env python3
"""Check that every pgTAP scenario in the database job ran the full suite (plan PR-6, §9 E3).

The ``verify-database`` job runs ``supabase test db`` once per migration
scenario (incremental upgrade, historical backfill, clean slate,
post-ingestion). Each run is tee'd to ``<dir>/<scenario>.log``. This script
reads those logs and fails unless:

* every expected scenario has a log,
* each log ends with pg_prove's ``Result: PASS``, and
* every scenario reports the same ``Files=N, Tests=M`` totals.

The last rule is the parity guard for PR-6's optimizations: a faster
database job is only acceptable if no scenario silently runs fewer pgTAP
files or assertions than the others. A Markdown table is written to stdout
and ``$GITHUB_STEP_SUMMARY``.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

DEFAULT_SCENARIOS = ("incremental", "backfill", "clean-slate", "post-ingestion")
TOTALS = re.compile(r"^Files=(\d+),\s*Tests=(\d+),\s*(\d+)\s+wallclock secs", re.MULTILINE)
RESULT = re.compile(r"^Result:\s*(\w+)\s*$", re.MULTILINE)


def read_scenario(log: Path) -> dict:
    if not log.is_file():
        return {"found": False}
    text = log.read_text(encoding="utf-8", errors="replace")
    totals = TOTALS.findall(text)
    results = RESULT.findall(text)
    info = {"found": True, "result": results[-1] if results else None}
    if totals:
        files, tests, secs = totals[-1]
        info.update(files=int(files), tests=int(tests), seconds=int(secs))
    return info


def find_problems(data: dict[str, dict]) -> list[str]:
    problems = []
    for name, info in data.items():
        if not info["found"]:
            problems.append(f"{name}: no pgTAP log (scenario did not run)")
        elif info.get("tests") is None:
            problems.append(f"{name}: no `Files=…, Tests=…` totals in log")
        elif info.get("result") != "PASS":
            problems.append(f"{name}: result is {info.get('result') or 'missing'}, not PASS")
    totals = {(i.get("files"), i.get("tests")) for i in data.values() if i.get("tests") is not None}
    if len(totals) > 1:
        detail = ", ".join(f"{n}={i.get('files')}/{i.get('tests')}" for n, i in data.items())
        problems.append(f"scenarios ran different pgTAP totals (files/tests): {detail}")
    return problems


def render(data: dict[str, dict], problems: list[str]) -> str:
    lines = [
        "## pgTAP scenario parity",
        "",
        "| Scenario | Files | Tests | pg_prove secs | Result |",
        "|---|---|---|---|---|",
    ]
    for name, info in data.items():
        if not info["found"]:
            lines.append(f"| {name} | — | — | — | **missing** |")
            continue
        lines.append(
            f"| {name} | {info.get('files', '—')} | {info.get('tests', '—')} | "
            f"{info.get('seconds', '—')} | {info.get('result') or '—'} |"
        )
    lines.append("")
    if problems:
        lines.append("**pgTAP parity failed:**")
        lines.extend(f"- {p}" for p in problems)
    else:
        lines.append(f"All {len(data)} scenarios passed the identical pgTAP suite.")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("log_dir", type=Path)
    parser.add_argument("--scenarios", nargs="+", default=list(DEFAULT_SCENARIOS))
    args = parser.parse_args(argv)

    data = {name: read_scenario(args.log_dir / f"{name}.log") for name in args.scenarios}
    problems = find_problems(data)
    text = render(data, problems)
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(text)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
