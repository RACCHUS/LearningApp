#!/usr/bin/env python3
"""Ratchet guard: every skipped Flutter test must be registered and justified (plan PR-9).

Reads a ``flutter test --file-reporter json:<path>`` report and compares the
tests it reports as *skipped* with ``SKIP_REGISTRY`` below. Fails when:

* a skipped test matches no registry entry (a new, unexplained skip);
* a registry entry matches no skipped test (stale: the test now runs, or was
  renamed or deleted; remove or update the entry so the list only shrinks);
* a ``quarantine`` entry is past its ``expires`` date, or has no expiry,
  tracking reference or alternative protection.

Kinds:

``conditional``
    By design the test runs only in another job or only under a release
    gate, e.g. the local-Supabase import test (DB job) or BYOK provider tests
    (hard-disabled release latch). ``runs_in`` says where it is covered.

``quarantine``
    A flaky or broken test temporarily skipped. Requires ``tracking`` (an
    issue or PR reference), ``protection`` (what still guards the behavior)
    and ``expires`` (ISO date, at most 30 days out). See
    docs/testing/TEST_QUALITY_POLICY.md.

Exit codes: 0 ok, 1 policy violation, 2 unreadable report. No dependencies
beyond the sibling report parser.
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from summarize_flutter_test_report import parse  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
MAX_QUARANTINE_DAYS = 30

SKIP_REGISTRY: list[dict] = [
    {
        "file": "test/integration/lesson_import_local_supabase_test.dart",
        "kind": "conditional",
        "reason": "Needs the local Supabase stack; skipped with a reason in the Flutter job.",
        "runs_in": "Required DB job: REQUIRE_LOCAL_SUPABASE=true makes missing config a failure.",
    },
    {
        "file": "test/services/assessment/reference_practice_json_load_probe_test.dart",
        "kind": "conditional",
        "reason": "Synthetic 50k-step load probe; opt-in via --dart-define=EXM_STRESS=true.",
        "runs_in": "Required Flutter job, dedicated 'EXM 50k synthetic JSON export load probe' step.",
    },
    {
        "file": "test/services/ai/byok_provider_test.dart",
        "kind": "conditional",
        "reason": "BYOK provider behavior; skipped while the hard-disabled BYOK release latch is off.",
        "runs_in": "Not run until BYOK is approved for release. Disabled-state safety tests run "
                   "unconditionally; enabling the latch makes these entries stale and forces review.",
        "expected": 3,
    },
]


def matches(entry: dict, skipped: str) -> bool:
    path, _, name = skipped.partition(": ")
    return path == entry["file"] and entry.get("name_contains", "") in name


def find_problems(skipped: list[str], registry: list[dict], today: dt.date) -> list[str]:
    problems = []
    for name in skipped:
        if not any(matches(e, name) for e in registry):
            problems.append(f"unregistered skip: {name}")
    for entry in registry:
        label = entry["file"] + (f" [{entry['name_contains']}]" if entry.get("name_contains") else "")
        hits = [s for s in skipped if matches(entry, s)]
        if not hits:
            problems.append(f"stale registry entry (no longer skipped): {label}")
        elif entry.get("expected") is not None and len(hits) != entry["expected"]:
            problems.append(f"{label}: expected {entry['expected']} skipped tests, found {len(hits)}")
        if entry.get("kind") not in {"conditional", "quarantine"}:
            problems.append(f"{label}: kind must be 'conditional' or 'quarantine'")
        if not entry.get("reason"):
            problems.append(f"{label}: missing reason")
        if entry.get("kind") == "conditional" and not entry.get("runs_in"):
            problems.append(f"{label}: conditional skip must say where it runs (runs_in)")
        if entry.get("kind") == "quarantine":
            for key in ("tracking", "protection", "expires"):
                if not entry.get(key):
                    problems.append(f"{label}: quarantine needs '{key}'")
            if entry.get("expires"):
                try:
                    expires = dt.date.fromisoformat(entry["expires"])
                except ValueError:
                    problems.append(f"{label}: expires is not an ISO date")
                else:
                    if expires < today:
                        problems.append(f"{label}: quarantine expired on {expires}")
                    elif (expires - today).days > MAX_QUARANTINE_DAYS:
                        problems.append(f"{label}: quarantine longer than {MAX_QUARANTINE_DAYS} days")
    return problems


def render(skipped: list[str], registry: list[dict], problems: list[str]) -> str:
    lines = ["## Skipped-test registry", "",
             f"{len(skipped)} skipped test(s); {len(registry)} registry entr{'y' if len(registry) == 1 else 'ies'}.", "",
             "| Test file | Kind | Skipped | Covered by / expires |", "|---|---|---|---|"]
    for e in registry:
        hits = sum(matches(e, s) for s in skipped)
        where = e.get("runs_in") or f"expires {e.get('expires')} ({e.get('tracking')})"
        lines.append(f"| `{e['file']}` | {e['kind']} | {hits} | {where} |")
    lines.append("")
    if problems:
        lines.append("**Skip policy violations:**")
        lines.extend(f"- {p}" for p in problems)
    else:
        lines.append("Every skip is registered and justified.")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("report", type=Path)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--today", type=dt.date.fromisoformat, default=dt.date.today())
    args = parser.parse_args(argv)

    if not args.report.is_file():
        print(f"error: no report at {args.report}", file=sys.stderr)
        return 2
    with args.report.open(encoding="utf-8", errors="replace") as fh:
        report = parse(fh, args.root)
    if report.success is None or (report.passed + report.failed + report.skipped) == 0:
        print("error: report is empty or interrupted; cannot check skips", file=sys.stderr)
        return 2

    problems = find_problems(report.skipped_names, SKIP_REGISTRY, args.today)
    text = render(report.skipped_names, SKIP_REGISTRY, problems)
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(text)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
