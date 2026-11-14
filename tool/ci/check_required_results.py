#!/usr/bin/env python3
"""Fail-closed gate behind the required `Analyze, test, and build` check (plan §9 E1).

The required check is a small job with `if: always()` that `needs:` every job
it stands for. GitHub may report a needed job as `success`, `failure`,
`cancelled` or `skipped`; only `success` counts. A skipped or cancelled job
must never look like a pass, and a job missing from the results (e.g. renamed
without updating the gate) fails too.

Reads the JSON of `${{ toJSON(needs) }}` from the NEEDS_JSON environment
variable, checks the job ids given as arguments, writes a table to stdout and
`$GITHUB_STEP_SUMMARY`, and exits 1 unless every required job succeeded.
No dependencies.
"""
from __future__ import annotations

import json
import os
import sys


def evaluate(needs: dict, required: list[str]) -> list[tuple[str, str]]:
    """Returns (job, result) for every required job; result is 'missing' if absent."""
    rows = []
    for job in required:
        entry = needs.get(job)
        result = entry.get("result") if isinstance(entry, dict) else None
        rows.append((job, result if isinstance(result, str) and result else "missing"))
    return rows


def render(rows: list[tuple[str, str]]) -> str:
    lines = ["## Required gate: Analyze, test, and build", "", "| Job | Result |", "|---|---|"]
    lines += [f"| `{job}` | {'success' if result == 'success' else f'**{result}**'} |" for job, result in rows]
    failed = [job for job, result in rows if result != "success"]
    lines += ["", "All required jobs succeeded." if not failed else
              f"**Gate failed:** {', '.join(failed)} did not succeed (skipped, cancelled and missing count as failures)."]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    required = list(sys.argv[1:] if argv is None else argv)
    if not required:
        print("error: name at least one required job id", file=sys.stderr)
        return 2
    try:
        needs = json.loads(os.environ.get("NEEDS_JSON", ""))
    except json.JSONDecodeError:
        print("error: NEEDS_JSON is missing or not valid JSON", file=sys.stderr)
        return 2
    if not isinstance(needs, dict):
        print("error: NEEDS_JSON must be a JSON object", file=sys.stderr)
        return 2
    rows = evaluate(needs, required)
    text = render(rows)
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(text)
    return 0 if all(result == "success" for _, result in rows) else 1


if __name__ == "__main__":
    sys.exit(main())
