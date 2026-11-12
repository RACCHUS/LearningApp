#!/usr/bin/env python3
"""Summarize a ``flutter test --file-reporter json:<path>`` report.

Writes a compact Markdown table to stdout and, when set, to
``$GITHUB_STEP_SUMMARY``: test outcome counts, skipped tests, the slowest
test files (wall span including load/compile, and summed test time), the
slowest individual tests, and runner facts (CPU count, Python platform) that
the concurrency benchmarks in plan §9 E1 need.

Report-only (plan PR-1): this never changes the CI outcome. A missing or
partly written report (e.g. the test step crashed) is summarized as far as
possible and noted, and the script still exits 0. The ``flutter test`` step
itself remains the gate.

Per-file "span" is first event to last event for that suite in the reporter
stream. Suites run concurrently, so spans overlap and must not be added up
to get the suite's elapsed time; "total elapsed" is the reporter's own clock.
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import sys
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Suite:
    path: str
    first_ms: int | None = None
    last_ms: int | None = None
    test_ms: int = 0
    tests: int = 0

    def touch(self, time_ms: int) -> None:
        self.first_ms = time_ms if self.first_ms is None else min(self.first_ms, time_ms)
        self.last_ms = time_ms if self.last_ms is None else max(self.last_ms, time_ms)

    @property
    def span_ms(self) -> int:
        if self.first_ms is None or self.last_ms is None:
            return 0
        return self.last_ms - self.first_ms


@dataclass
class Report:
    suites: dict[int, Suite] = field(default_factory=dict)
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    skipped_names: list[str] = field(default_factory=list)
    failed_names: list[str] = field(default_factory=list)
    slow_tests: list[tuple[int, str, str]] = field(default_factory=list)
    end_ms: int = 0
    success: bool | None = None
    malformed_lines: int = 0


def _relative(path: str, root: Path) -> str:
    try:
        return Path(path).resolve().relative_to(root.resolve()).as_posix()
    except (ValueError, OSError):
        return path.replace("\\", "/")


def parse(lines, root: Path) -> Report:
    report = Report()
    starts: dict[int, tuple[int, int, str]] = {}  # testID -> (start ms, suiteID, name)
    for raw in lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            event = json.loads(raw)
        except json.JSONDecodeError:
            report.malformed_lines += 1
            continue
        if not isinstance(event, dict):
            report.malformed_lines += 1
            continue
        kind = event.get("type")
        time_ms = int(event.get("time", 0) or 0)
        report.end_ms = max(report.end_ms, time_ms)
        if kind == "suite":
            suite = event.get("suite", {})
            report.suites[suite.get("id")] = Suite(_relative(suite.get("path") or "?", root))
        elif kind == "testStart":
            test = event.get("test", {})
            suite_id = test.get("suiteID")
            starts[test.get("id")] = (time_ms, suite_id, test.get("name", "?"))
            if suite_id in report.suites:
                report.suites[suite_id].touch(time_ms)
        elif kind == "testDone":
            start = starts.get(event.get("testID"))
            if start is None:
                continue
            start_ms, suite_id, name = start
            suite = report.suites.get(suite_id)
            if suite is not None:
                suite.touch(time_ms)
            if event.get("hidden"):
                continue  # loading / setUpAll placeholders, not real tests
            duration = time_ms - start_ms
            path = suite.path if suite else "?"
            if suite is not None:
                suite.tests += 1
                suite.test_ms += duration
            if event.get("skipped"):
                report.skipped += 1
                report.skipped_names.append(f"{path}: {name}")
            elif event.get("result") == "success":
                report.passed += 1
            else:
                report.failed += 1
                report.failed_names.append(f"{path}: {name}")
            report.slow_tests.append((duration, path, name))
        elif kind == "done":
            report.success = bool(event.get("success"))
    return report


def _secs(ms: int) -> str:
    return f"{ms / 1000:.1f}s"


def _cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")


def render(report: Report, *, top: int, label: str, note: str | None) -> str:
    total = report.passed + report.failed + report.skipped
    status = {True: "success", False: "FAILED", None: "incomplete (no `done` event)"}[report.success]
    lines = [
        f"## {label}",
        "",
    ]
    if note:
        lines += [f"> {note}", ""]
    lines += [
        "| Metric | Value |",
        "|---|---|",
        f"| Reporter status | {status} |",
        f"| Tests (passed / failed / skipped / total) | {report.passed} / {report.failed} / {report.skipped} / {total} |",
        f"| Test files | {len(report.suites)} |",
        f"| Total elapsed (reporter clock) | {_secs(report.end_ms)} |",
        f"| Runner CPUs (`os.cpu_count()`) | {os.cpu_count()} |",
        f"| Platform | {platform.system()} {platform.machine()} |",
    ]
    if report.malformed_lines:
        lines.append(f"| Unparseable report lines | {report.malformed_lines} |")
    lines.append("")

    if report.failed_names:
        lines += ["### Failed tests", ""]
        lines += [f"- {_cell(n)}" for n in report.failed_names[:50]]
        lines.append("")
    if report.skipped_names:
        lines += ["<details><summary>Skipped tests ({})</summary>".format(len(report.skipped_names)), ""]
        lines += [f"- {_cell(n)}" for n in report.skipped_names]
        lines += ["", "</details>", ""]

    suites = sorted(report.suites.values(), key=lambda s: s.span_ms, reverse=True)[:top]
    if suites:
        lines += [
            f"### Slowest {len(suites)} test files",
            "",
            "Span includes load/compile and overlaps with other files; do not sum.",
            "",
            "| File | Span | Summed test time | Tests |",
            "|---|---:|---:|---:|",
        ]
        lines += [f"| `{_cell(s.path)}` | {_secs(s.span_ms)} | {_secs(s.test_ms)} | {s.tests} |" for s in suites]
        lines.append("")
    slow = sorted(report.slow_tests, reverse=True)[:top]
    if slow:
        lines += [f"### Slowest {len(slow)} tests", "", "| Test | File | Time |", "|---|---|---:|"]
        lines += [f"| {_cell(name)} | `{_cell(path)}` | {_secs(ms)} |" for ms, path, name in slow]
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Summarize a flutter test JSON file report.")
    parser.add_argument("report", type=Path)
    parser.add_argument("--top", type=int, default=15)
    parser.add_argument("--label", default="Flutter test report")
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)

    note = None
    if args.report.is_file():
        with args.report.open(encoding="utf-8", errors="replace") as fh:
            report = parse(fh, args.root)
        if report.success is None:
            note = "Report has no `done` event: the test run was interrupted. Counts are partial."
    else:
        report = Report()
        note = f"No report file at `{args.report}`; the test step did not produce one."

    text = render(report, top=args.top, label=args.label, note=note)
    print(text)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as fh:
            fh.write(text + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
