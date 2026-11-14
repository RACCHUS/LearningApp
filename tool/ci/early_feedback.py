#!/usr/bin/env python3
"""Change-aware early feedback for pull requests (plan PR-8, §9 E5).

Advisory only. The three required checks always run in full; this job just
gives a fast first signal on the checks most related to what changed.

``plan``
    Reads changed paths (one per line, from ``git diff --name-only``),
    classifies them with a conservative path-to-risk table and writes a JSON
    plan of commands plus a Markdown summary. Unknown paths and CI, build or
    dependency changes are classified as ``full``: they get every early check,
    never fewer.

``run``
    Executes a plan's commands in order, records each one's time and result,
    appends a Markdown table to ``$GITHUB_STEP_SUMMARY`` and exits 1 if any
    command failed (all commands still run, so one failure does not hide
    another).

Deliberately not done here: skipping or path-filtering any required check,
and running suites that need the database stack, the pinned test venvs or a
browser (the algebra pytest suite, browser smoke). Those stay in their own
jobs.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath

MAX_TARGETED_DART_TESTS = 40
NEEDS_PINNED_VENV = re.compile(r"^\s*(import|from)\s+(pytest|playwright|sympy|yaml)\b", re.MULTILINE)

# (category, predicate) in priority order; a path takes the first match.
HIGH_RISK_WORDS = ("auth", "permission", "assessment", "scoring", "grading", "storage",
                   "feature_flag", "site_feature", "privacy", "consent", "byok", "governance")


@dataclass
class Plan:
    categories: dict[str, list[str]] = field(default_factory=dict)
    commands: list[dict] = field(default_factory=list)
    needs_flutter: bool = False
    notes: list[str] = field(default_factory=list)

    def add(self, name: str, cmd: str, *, flutter: bool = False) -> None:
        if any(c["cmd"] == cmd for c in self.commands):
            return
        self.commands.append({"name": name, "cmd": cmd})
        self.needs_flutter = self.needs_flutter or flutter


def categorize(path: str) -> str:
    p = PurePosixPath(path)
    parts = p.parts
    suffix = p.suffix.lower()
    if not parts:
        return "unknown"
    if parts[0] == ".github" or path.startswith("tool/ci/") or p.name in {
        "pubspec.yaml", "pubspec.lock", "analysis_options.yaml", "dart_test.yaml",
    } or (p.name.startswith("requirements") and suffix == ".txt"):
        return "ci-and-dependencies"
    if path.startswith("supabase/migrations/") or path.startswith("supabase/functions/") \
            or path.startswith("supabase/tests/") or path == "supabase/config.toml":
        return "database"
    if parts[0] in {"content", "data"} or path.startswith("assets/lessons/"):
        return "content"
    if suffix == ".dart" and parts[0] in {"lib", "test", "packages", "tool"}:
        lowered = path.lower()
        if parts[0] == "lib" and any(w in lowered for w in HIGH_RISK_WORDS):
            return "dart-high-risk"
        return "dart"
    if parts[0] == "tool" and suffix == ".py":
        return "python-tooling"
    if suffix in {".md", ".txt"} or parts[0] == "docs":
        return "docs"
    if parts[0] in {"assets", "web", "l10n"} or path.startswith("lib/l10n/"):
        return "app-assets"
    return "unknown"


def dart_tests_for(path: str, root: Path) -> list[str]:
    """Existing test files for a changed Dart path (itself if it is a test)."""
    p = PurePosixPath(path)
    if p.name.endswith("_test.dart"):
        return [path] if (root / path).is_file() and p.parts[0] == "test" else []
    if p.parts[0] != "lib":
        return []
    stem = p.stem
    direct = PurePosixPath("test", *p.parts[1:-1], f"{stem}_test.dart")
    found = []
    if (root / direct).is_file():
        found.append(str(direct))
    test_dir = root / "test"
    if test_dir.is_dir():
        for candidate in test_dir.rglob(f"{stem}_test.dart"):
            rel = candidate.relative_to(root).as_posix()
            if rel not in found:
                found.append(rel)
    return found


def python_suite_for(path: str, root: Path) -> str | None:
    """The unittest suite for a changed tool/*.py path, if it can run without pinned venvs."""
    p = PurePosixPath(path)
    name = p.name if p.name.startswith("test_") else f"test_{p.name}"
    suite = root / "tool" / "tests" / name
    if not suite.is_file():
        return None
    if NEEDS_PINNED_VENV.search(suite.read_text(encoding="utf-8", errors="replace")):
        return None
    return name


def build_plan(paths: list[str], root: Path) -> Plan:
    plan = Plan()
    for path in sorted({p.strip().replace("\\", "/") for p in paths if p.strip()}):
        plan.categories.setdefault(categorize(path), []).append(path)
    cats = set(plan.categories)
    full = bool(cats & {"ci-and-dependencies", "unknown"})

    if full:
        plan.notes.append("CI/dependency or unclassified paths changed: running every early check.")
    if full or cats & {"ci-and-dependencies", "python-tooling"}:
        plan.add("Test inventory guard (strict)", "python3 tool/ci/check_test_inventory.py --strict")
    if full or cats & {"dart", "dart-high-risk", "app-assets"}:
        plan.add("Flutter analyze", "flutter analyze", flutter=True)
    if full or "dart-high-risk" in cats:
        plan.add("Schema contract (client to migrations)", "dart run tool/verify_schema_contract.dart", flutter=True)
        plan.add("Feature registry contract", "python3 tool/verify_feature_registry.py")
    if full or "database" in cats:
        plan.add("Append-only migration history",
                 "dart run tool/verify_migration_history.dart --base-ref origin/main", flutter=True)
        plan.add("Schema contract (client to migrations)", "dart run tool/verify_schema_contract.dart", flutter=True)
    if "database" in cats:
        plan.notes.append("Database changes: the full local-Supabase scenarios run only in the required DB job.")
    if full or "content" in cats:
        plan.add("Curriculum manifest lint", "dart run tool/lint_manifest.dart --dir content/", flutter=True)
        plan.add("Curriculum ingestion dry run", "dart run tool/ingest_curriculum.dart --dir content/ --dry-run",
                 flutter=True)

    dart_paths = plan.categories.get("dart", []) + plan.categories.get("dart-high-risk", [])
    tests: list[str] = []
    for path in dart_paths:
        for t in dart_tests_for(path, root):
            if t not in tests:
                tests.append(t)
    if len(tests) > MAX_TARGETED_DART_TESTS:
        plan.notes.append(f"{len(tests)} related Dart test files: too many for early feedback; "
                          "the required job runs the full suite.")
    elif tests:
        plan.add(f"Related Flutter tests ({len(tests)} file(s))",
                 "flutter test --concurrency 3 " + " ".join(tests), flutter=True)
    elif dart_paths:
        plan.notes.append("No test file maps to the changed Dart files by name; the required job runs the full suite.")

    suites = []
    for path in plan.categories.get("python-tooling", []) + plan.categories.get("ci-and-dependencies", []):
        if path.endswith(".py"):
            suite = python_suite_for(path, root)
            if suite and suite not in suites:
                suites.append(suite)
    for suite in suites:
        plan.add(f"Python suite {suite}", f"python3 -m unittest discover -s tool/tests -p '{suite}'")

    if cats == {"docs"}:
        plan.notes.append("Documentation only: no early checks needed; required checks still run in full.")
    return plan


def render_plan(plan: Plan) -> str:
    lines = ["## Early feedback plan (advisory)", "",
             "The required checks always run in full; this is a faster first signal.", "",
             "| Category | Changed files |", "|---|---|"]
    for cat in sorted(plan.categories):
        files = plan.categories[cat]
        shown = ", ".join(f"`{f}`" for f in files[:5]) + (f" … +{len(files) - 5}" if len(files) > 5 else "")
        lines.append(f"| {cat} | {shown} |")
    lines += ["", "**Early checks:** " + (", ".join(c["name"] for c in plan.commands) or "none")]
    lines += [f"- {n}" for n in plan.notes]
    return "\n".join(lines) + "\n"


def _append_summary(text: str) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(text)


def cmd_plan(args) -> int:
    paths = Path(args.changed_files).read_text(encoding="utf-8").splitlines()
    plan = build_plan(paths, args.root)
    args.out.write_text(json.dumps({"commands": plan.commands, "needs_flutter": plan.needs_flutter,
                                    "categories": plan.categories, "notes": plan.notes}, indent=2),
                        encoding="utf-8")
    text = render_plan(plan)
    print(text)
    _append_summary(text)
    gh_out = os.environ.get("GITHUB_OUTPUT")
    if gh_out:
        with open(gh_out, "a", encoding="utf-8") as fh:
            fh.write(f"needs_flutter={'true' if plan.needs_flutter else 'false'}\n")
    return 0


def cmd_run(args) -> int:
    plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    rows, failed = [], 0
    for command in plan["commands"]:
        print(f"::group::{command['name']}", flush=True)
        start = time.monotonic()
        code = subprocess.call(command["cmd"], shell=True)
        secs = time.monotonic() - start
        print("::endgroup::", flush=True)
        failed += code != 0
        rows.append(f"| {command['name']} | {'pass' if code == 0 else f'**FAIL** (exit {code})'} | {secs:.0f}s |")
    text = "\n".join(["## Early feedback results", "", "| Check | Result | Time |", "|---|---|---|", *rows]) + "\n"
    if not rows:
        text += "\nNo early checks for these changes.\n"
    print(text)
    _append_summary(text)
    return 1 if failed else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("plan")
    p.add_argument("changed_files", help="file with one changed path per line")
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--root", type=Path, default=Path.cwd())
    p.set_defaults(func=cmd_plan)
    r = sub.add_parser("run")
    r.add_argument("plan")
    r.set_defaults(func=cmd_run)
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
