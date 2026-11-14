#!/usr/bin/env python3
"""Ratchet guard: a passing Flutter run must not log test-setup failures.

Reads a ``flutter test --file-reporter json:<path>`` report and looks at what
tests printed. Messages like ``MissingPluginException`` or ``MissingStubError``
in a *passing* run mean a test never set up a dependency, so the code under
test silently took its error path and the test checked something other than
its name says (plan PR-4a, finding Q-07).

Intentional negative-path logging ("Simulated network timeout", a deliberate
PostgrestException, ...) is not matched: only the setup-gap signatures below
are.

Modes:

* default (ratchet): files listed in KNOWN_NOISE are reported as warnings;
  setup-gap messages from any other test file fail. A KNOWN_NOISE file that
  ran and is now clean also fails, so the list only shrinks.
* ``--strict``: every match fails.

Exit codes: 0 clean, 1 new or stale noise, 2 unreadable/empty report.
No third-party dependencies.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

SETUP_GAP_PATTERNS: dict[str, re.Pattern[str]] = {
    "missing-plugin": re.compile(r"MissingPluginException"),
    "missing-mock-stub": re.compile(r"MissingStubError"),
    "late-init": re.compile(r"LateInitializationError"),
    "supabase-uninitialized": re.compile(r"You must initialize the supabase instance"),
    "binding-uninitialized": re.compile(r"_binaryMessenger != null \|\| BindingBase\.debugBindingType\(\)"),
}

# Test files allowed to log setup-gap messages for now, with the reason and
# the follow-up. Remove an entry when the file is fixed (stale entries fail).
KNOWN_NOISE: dict[str, str] = {}


class ReportError(Exception):
    pass


def repo_relative(path: str, root: Path = REPO_ROOT) -> str:
    """Repository-relative POSIX path, independent of where the checkout lives."""
    posix = path.replace("\\", "/")
    root_posix = root.as_posix().rstrip("/") + "/"
    if posix.lower().startswith(root_posix.lower()):
        return posix[len(root_posix):]
    # Report produced in another checkout location: anchor on the test dir.
    marker = posix.rfind("/test/")
    return posix[marker + 1:] if marker >= 0 else posix


def scan(lines, root: Path = REPO_ROOT) -> tuple[dict[str, Counter], set[str], dict]:
    """Return ({file: Counter(kind)}, files that ran, first sample per (file, kind))."""
    suites: dict[int, str] = {}
    test_suite: dict[int, int] = {}
    hits: dict[str, Counter] = defaultdict(Counter)
    samples: dict[tuple[str, str], str] = {}
    parsed = 0
    for raw in lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            event = json.loads(raw)
        except json.JSONDecodeError:
            continue
        parsed += 1
        kind = event.get("type")
        if kind == "suite":
            suites[event["suite"]["id"]] = repo_relative(str(event["suite"].get("path", "?")), root)
        elif kind == "testStart":
            test_suite[event["test"]["id"]] = event["test"].get("suiteID")
        elif kind == "print":
            message = str(event.get("message", ""))
            file = suites.get(test_suite.get(event.get("testID")), "?")
            for name, pattern in SETUP_GAP_PATTERNS.items():
                if pattern.search(message):
                    hits[file][name] += 1
                    samples.setdefault((file, name), message.strip().splitlines()[0][:200])
    if parsed == 0 or not suites:
        raise ReportError("report contains no test suites")
    return hits, set(suites.values()), samples


def evaluate(hits, ran: set[str], known: dict[str, str], strict: bool):
    """Return (failures, warnings) as lists of (file, detail)."""
    failures, warnings = [], []
    for file, kinds in sorted(hits.items()):
        detail = ", ".join(f"{k} x{c}" for k, c in sorted(kinds.items()))
        if file in known and not strict:
            warnings.append((file, detail))
        else:
            failures.append((file, detail))
    if not strict:
        for file in sorted(known):
            if file in ran and file not in hits:
                failures.append((file, "listed in KNOWN_NOISE but now clean; remove the entry"))
    return failures, warnings


def render(failures, warnings, samples, strict: bool) -> str:
    lines = ["## Test log noise (setup gaps in passing tests)", ""]
    lines.append(f"Mode: **{'strict' if strict else 'ratchet'}**.")
    if not failures and not warnings:
        lines.append("No setup-gap messages in test output.")
    else:
        lines += ["", "| Status | File | Signatures | Example |", "|---|---|---|---|"]
        for status, rows in (("FAIL", failures), ("known", warnings)):
            for file, detail in rows:
                kind = detail.split(" x")[0]
                example = samples.get((file, kind), "").replace("|", "\\|")
                lines.append(f"| {status} | `{file}` | {detail} | {example[:120]} |")
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Fail on test-setup gaps logged by a passing Flutter run.")
    parser.add_argument("report", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args(argv)
    try:
        with args.report.open(encoding="utf-8", errors="replace") as fh:
            hits, ran, samples = scan(fh)
    except (OSError, ReportError) as exc:
        print(f"::error::test log noise check could not read {args.report}: {exc}")
        return 2

    failures, warnings = evaluate(hits, ran, KNOWN_NOISE, args.strict)
    text = render(failures, warnings, samples, args.strict)
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(text + "\n")
    for file, detail in failures:
        print(f"::error file={file}::test log noise: {detail}")
    for file, detail in warnings:
        print(f"::warning file={file}::known test log noise: {detail}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
