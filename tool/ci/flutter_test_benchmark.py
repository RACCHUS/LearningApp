#!/usr/bin/env python3
"""Record and compare ``flutter test --concurrency`` benchmark trials (plan PR-5, §9 E1).

Two subcommands:

``record``
    Turns one trial (a JSON file report, the measured wall time, and an
    optional memory sample log) into a small result JSON: outcome counts, a
    hash of the exact collected test inventory, peak memory used, and runner
    facts (CPU count, total memory).

``summarize``
    Reads every result JSON in a directory, groups trials by concurrency
    label and writes a Markdown comparison (p50/min/max wall time, outcome
    counts, peak memory) to stdout and ``$GITHUB_STEP_SUMMARY``.

A faster setting only counts if it ran the *same* tests. ``summarize``
therefore exits 1 when any trial failed or errored, had no report, or
collected a different test inventory than the others, so an invalid
benchmark can never look like a speed-up. It never touches the required
``Analyze, test, and build`` check; the benchmark workflow is advisory.

Background: without ``--concurrency``, ``flutter test`` passes nothing to
``package:test``, whose default is ``max(1, nproc ~/ 2)`` (test_core
``defaultConcurrency``). The "default" label records that real default.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from summarize_flutter_test_report import parse  # noqa: E402

RESULT_SCHEMA = 1


def inventory_hash(report) -> str:
    """Order-independent hash of every collected (non-hidden) test.

    Status is excluded: inventory equality asks "did the same tests run",
    while pass/fail is compared separately.
    """
    names = sorted(f"{path}::{name}" for _, path, name in report.slow_tests)
    digest = hashlib.sha256("\n".join(names).encode("utf-8")).hexdigest()
    return digest[:16]


def peak_memory_mib(log: Path | None) -> int | None:
    """Largest integer sample in a log of one 'used MiB' number per line."""
    if log is None or not log.is_file():
        return None
    peak = None
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line.isdigit():
            value = int(line)
            peak = value if peak is None else max(peak, value)
    return peak


def total_memory_mib() -> int | None:
    try:
        with open("/proc/meminfo", encoding="ascii") as fh:
            for line in fh:
                if line.startswith("MemTotal:"):
                    return int(line.split()[1]) // 1024
    except OSError:
        return None
    return None


def record(args) -> int:
    result = {
        "schema": RESULT_SCHEMA,
        "concurrency": args.concurrency,
        "trial": args.trial,
        "wall_seconds": round(float(args.wall_seconds), 1),
        "exit_code": int(args.exit_code),
        "cpu_count": os.cpu_count(),
        "memory_total_mib": total_memory_mib(),
        "peak_memory_used_mib": peak_memory_mib(args.memory_log),
        "report_found": args.report.is_file(),
    }
    if result["report_found"]:
        with args.report.open(encoding="utf-8", errors="replace") as fh:
            report = parse(fh, args.root)
        result.update(
            passed=report.passed,
            failed=report.failed,
            skipped=report.skipped,
            suites=len(report.suites),
            completed=report.success is not None,
            success=bool(report.success),
            inventory=inventory_hash(report),
            reporter_elapsed_seconds=round(report.end_ms / 1000, 1),
        )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, sort_keys=True))
    return 0


def _sort_key(label: str):
    return (0, 0) if label == "default" else (1, int(label)) if label.isdigit() else (2, label)


def load_results(results_dir: Path) -> list[dict]:
    results = []
    for path in sorted(results_dir.rglob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if isinstance(data, dict) and data.get("schema") == RESULT_SCHEMA:
            results.append(data)
    return results


def find_problems(results: list[dict]) -> list[str]:
    problems = []
    if not results:
        return ["no benchmark results found"]
    inventories = {}
    for r in results:
        who = f"concurrency={r.get('concurrency')} trial={r.get('trial')}"
        if not r.get("report_found"):
            problems.append(f"{who}: no JSON report")
            continue
        if not r.get("completed"):
            problems.append(f"{who}: report has no `done` event (interrupted)")
        if r.get("exit_code") != 0 or r.get("failed") or not r.get("success"):
            problems.append(f"{who}: test run failed (exit {r.get('exit_code')}, {r.get('failed')} failed)")
        inventories.setdefault(r.get("inventory"), []).append(who)
    if len(inventories) > 1:
        detail = "; ".join(f"{inv}: {len(who)} trial(s)" for inv, who in inventories.items())
        problems.append(f"collected test inventory differs between trials ({detail})")
    return problems


def render(results: list[dict], problems: list[str]) -> str:
    groups: dict[str, list[dict]] = {}
    for r in results:
        groups.setdefault(str(r.get("concurrency")), []).append(r)
    cpus = sorted({r.get("cpu_count") for r in results if r.get("cpu_count")})
    mems = sorted({r.get("memory_total_mib") for r in results if r.get("memory_total_mib")})
    lines = [
        "## Flutter test concurrency benchmark",
        "",
        f"Runner CPUs: {', '.join(map(str, cpus)) or '?'}; memory: "
        f"{', '.join(f'{m} MiB' for m in mems) or '?'}. "
        "`default` = no flag = `package:test` default `max(1, nproc ~/ 2)`.",
        "",
        "| Concurrency | Trials | Wall p50 | Wall min | Wall max | Passed | Skipped | Failed | Peak mem used |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    baseline = None
    for label in sorted(groups, key=_sort_key):
        trials = groups[label]
        walls = [t["wall_seconds"] for t in trials if t.get("report_found")]
        p50 = statistics.median(walls) if walls else None
        if label == "default":
            baseline = p50
        passed = sorted({t.get("passed") for t in trials})
        skipped = sorted({t.get("skipped") for t in trials})
        failed = sum(t.get("failed") or 0 for t in trials)
        peaks = [t["peak_memory_used_mib"] for t in trials if t.get("peak_memory_used_mib")]
        delta = ""
        if baseline and p50 and label != "default":
            delta = f" ({(p50 - baseline) / baseline:+.0%})"
        lines.append(
            f"| `{label}` | {len(trials)} | "
            f"{f'{p50:.0f}s{delta}' if p50 is not None else '—'} | "
            f"{f'{min(walls):.0f}s' if walls else '—'} | {f'{max(walls):.0f}s' if walls else '—'} | "
            f"{'/'.join(map(str, passed))} | {'/'.join(map(str, skipped))} | {failed} | "
            f"{f'{max(peaks)} MiB' if peaks else '—'} |"
        )
    lines.append("")
    if problems:
        lines.append("**Benchmark invalid — do not use these timings:**")
        lines.extend(f"- {p}" for p in problems)
    else:
        inv = results[0].get("inventory")
        lines.append(f"All {len(results)} trials passed and collected the identical test inventory (`{inv}`).")
    return "\n".join(lines) + "\n"


def summarize(args) -> int:
    results = load_results(args.results_dir)
    problems = find_problems(results)
    text = render(results, problems)
    print(text)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as fh:
            fh.write(text)
    return 1 if problems else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)

    rec = sub.add_parser("record", help="write one trial's result JSON")
    rec.add_argument("--report", type=Path, required=True)
    rec.add_argument("--concurrency", required=True, help="'default' or the integer passed to -j")
    rec.add_argument("--trial", type=int, required=True)
    rec.add_argument("--wall-seconds", type=float, required=True)
    rec.add_argument("--exit-code", type=int, required=True)
    rec.add_argument("--memory-log", type=Path)
    rec.add_argument("--root", type=Path, default=Path.cwd())
    rec.add_argument("--out", type=Path, required=True)
    rec.set_defaults(func=record)

    summ = sub.add_parser("summarize", help="compare all result JSONs in a directory")
    summ.add_argument("results_dir", type=Path)
    summ.set_defaults(func=summarize)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
