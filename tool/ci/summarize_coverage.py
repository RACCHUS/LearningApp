#!/usr/bin/env python3
"""Report-only Dart line coverage by risk area (plan PR-9, §12).

Reads ``coverage/lcov.info`` from ``flutter test --coverage`` and writes a
Markdown table to stdout and ``$GITHUB_STEP_SUMMARY``:

* overall line coverage, excluding generated code;
* coverage per **critical area** (assessment and grading, auth and roles,
  feature controls and governance, privacy and analytics, offline/sync and
  storage, lesson import and generation), tracked separately from the
  aggregate as the plan requires;
* the least-covered critical files with meaningful size.

Deliberately **no percentage gate** (plan §12 "first report"): numbers are a
prompt for review, never a substitute for functional test review, and
floors come only after a baseline and a false-positive review. Exit 0 always,
except 2 when the lcov file is missing or empty.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

GENERATED = re.compile(r"(\.g\.dart|\.freezed\.dart|\.mocks\.dart|lib/l10n/app_localizations[^/]*\.dart)$")

# Area -> path patterns (first match wins). Order matters: more specific first.
CRITICAL_AREAS: list[tuple[str, re.Pattern[str]]] = [
    ("Assessment, simulation & grading", re.compile(
        r"lib/(services/(assessment|simulation|rubric)/|.*(assessment|grading|scoring|simulation|exam)[^/]*\.dart$)")),
    ("Auth, roles & moderation", re.compile(r"lib/.*(auth|role|moderation|permission)[^/]*\.dart$")),
    ("Feature controls & governance", re.compile(
        r"lib/(services/governance/|.*(site_feature|feature_flag|byok|governance|release_gate)[^/]*\.dart$)")),
    ("Privacy & analytics", re.compile(r"lib/(services/analytics/|.*(privacy|consent|analytics|erasure)[^/]*\.dart$)")),
    ("Offline, sync & storage", re.compile(
        r"lib/(services/offline/|.*(sync|offline|outbox|hive|storage|checkpoint)[^/]*\.dart$)")),
    ("Lesson import & generation", re.compile(
        r"lib/(services/(lesson|content_generation)/|.*(lesson_import|lesson_content|lesson_creation)[^/]*\.dart$)")),
]
MIN_LINES_FOR_LOW_LIST = 30


@dataclass
class FileCov:
    path: str
    found: int = 0
    hit: int = 0

    @property
    def pct(self) -> float:
        return 100.0 * self.hit / self.found if self.found else 100.0


def parse_lcov(text: str, root: str = "") -> list[FileCov]:
    files, current = [], None
    root = root.replace("\\", "/").rstrip("/") + "/" if root else ""
    for line in text.splitlines():
        if line.startswith("SF:"):
            path = line[3:].strip().replace("\\", "/")
            if root and path.startswith(root):
                path = path[len(root):]
            current = FileCov(path)
        elif current is not None and line.startswith("DA:"):
            _, _, count = line[3:].partition(",")
            current.found += 1
            current.hit += 1 if count.split(",")[0].strip() not in {"", "0"} else 0
        elif line.strip() == "end_of_record" and current is not None:
            files.append(current)
            current = None
    return files


def area_of(path: str) -> str | None:
    for name, pattern in CRITICAL_AREAS:
        if pattern.search(path):
            return name
    return None


def _pct(hit: int, found: int) -> str:
    return f"{100.0 * hit / found:.1f}%" if found else "—"


def render(files: list[FileCov], *, top: int) -> str:
    kept = [f for f in files if f.path.startswith("lib/") and not GENERATED.search(f.path)]
    excluded = len(files) - len(kept)
    total_found = sum(f.found for f in kept)
    total_hit = sum(f.hit for f in kept)
    lines = ["## Dart line coverage by risk area (report-only)", "",
             f"Overall `lib/`: **{_pct(total_hit, total_found)}** ({total_hit}/{total_found} lines, "
             f"{len(kept)} files; {excluded} generated/non-lib files excluded).", "",
             "| Critical area | Files | Lines hit / found | Coverage |", "|---|---|---|---|"]
    by_area: dict[str, list[FileCov]] = {}
    for f in kept:
        area = area_of(f.path)
        if area:
            by_area.setdefault(area, []).append(f)
    for name, _ in CRITICAL_AREAS:
        group = by_area.get(name, [])
        found = sum(f.found for f in group)
        hit = sum(f.hit for f in group)
        lines.append(f"| {name} | {len(group)} | {hit}/{found} | {_pct(hit, found)} |")
    critical = [f for g in by_area.values() for f in g if f.found >= MIN_LINES_FOR_LOW_LIST]
    critical.sort(key=lambda f: (f.pct, -f.found))
    if critical:
        lines += ["", f"<details><summary>Least-covered critical files (≥{MIN_LINES_FOR_LOW_LIST} lines)</summary>",
                  "", "| File | Area | Coverage | Lines |", "|---|---|---|---|"]
        for f in critical[:top]:
            lines.append(f"| `{f.path}` | {area_of(f.path)} | {f.pct:.1f}% | {f.hit}/{f.found} |")
        lines += ["", "</details>"]
    lines += ["", "No percentage gate: use this to find untested critical code, then add tests that would "
                  "fail on a real bug (docs/testing/TEST_QUALITY_POLICY.md)."]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("lcov", type=Path, nargs="?", default=Path("coverage/lcov.info"))
    parser.add_argument("--root", default=str(Path.cwd()))
    parser.add_argument("--top", type=int, default=20)
    args = parser.parse_args(argv)
    if not args.lcov.is_file():
        print(f"error: no lcov file at {args.lcov}", file=sys.stderr)
        return 2
    files = parse_lcov(args.lcov.read_text(encoding="utf-8", errors="replace"), args.root)
    if not files:
        print("error: lcov file has no records", file=sys.stderr)
        return 2
    text = render(files, top=args.top)
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
