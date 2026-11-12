#!/usr/bin/env python3
"""Inventory guard: every tool/tests suite must be executed by a CI runner.

Discovers test files under ``tool/tests`` and the runner commands in
``.github/workflows/*.yml``, then reports, for each file:

* which framework it is written for (unittest, pytest, Dart),
* how many test cases it statically declares,
* which CI runner command(s) execute it.

Problems it detects:

* ``unregistered``      no CI command runs the file at all;
* ``runner_mismatch``   the file is pytest-style but only a unittest command
                        names it (unittest would collect zero tests);
* ``zero_tests``        the file declares no test cases;
* ``duplicate``         the same runner names the file more than once;
* ``stale_known_gap``   an entry in KNOWN_GAPS is no longer a gap.

Modes:

* default (ratchet): known gaps listed in KNOWN_GAPS are reported as
  warnings; any *other* problem fails. A newly added, unregistered test
  file therefore fails CI immediately.
* ``--strict``: every problem fails, KNOWN_GAPS is ignored.

Unparseable test or workflow files always fail (exit 2): a parse error is
never reported as "zero tests".

No network, no third-party dependencies (workflow files are scanned as
text, not loaded with PyYAML, so the guard runs before any pip install).
"""
from __future__ import annotations

import argparse
import ast
import fnmatch
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# Known gaps tolerated in ratchet mode. Each entry must be removed when the
# gap closes (the guard fails on stale entries). See
# LearningApp_CI_Test_Quality_Optimization_Plan.md §0C.2 (PR-2a).
# CI runs this guard with --strict, so entries here only matter for local
# ratchet-mode runs. Keep it empty; a new entry needs a plan reference.
KNOWN_GAPS: dict[str, str] = {}

UNITTEST = "unittest"
PYTEST = "pytest"
DART = "dart"

_UNITTEST_DISCOVER = re.compile(r"unittest\s+discover\b(?P<args>[^\n]*)")
_UNITTEST_DIR = re.compile(r"-s\s+['\"]?(?P<dir>[\w./-]+)['\"]?")
_UNITTEST_PATTERN = re.compile(r"-p\s+['\"]?(?P<pat>[\w.*?\[\]-]+)['\"]?")
_PYTEST_CMD = re.compile(r"(?:^|[\s;&|(])(?:python3?\s+-m\s+)?pytest\b(?P<args>[^\n]*)")
_DART_FILE = re.compile(r"\bdart\s+(?:run\s+|test\s+)?(?P<path>tool/tests/[\w./-]+\.dart)\b")


class InventoryError(Exception):
    """A file could not be parsed; the inventory cannot be trusted."""


@dataclass
class TestFile:
    name: str
    framework: str
    test_count: int
    runners: list[str] = field(default_factory=list)


@dataclass
class Problem:
    kind: str
    file: str
    detail: str
    known: bool = False


def classify_python(path: Path) -> tuple[str, int]:
    """Return (framework, statically declared test count) for a test module."""
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (SyntaxError, UnicodeDecodeError) as exc:
        raise InventoryError(f"cannot parse {path}: {exc}") from exc

    unittest_cases = 0
    pytest_cases = 0
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test"):
            pytest_cases += 1
        elif isinstance(node, ast.ClassDef):
            methods = sum(
                1
                for item in node.body
                if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef))
                and item.name.startswith("test")
            )
            if _is_testcase_subclass(node):
                unittest_cases += methods
            elif node.name.startswith("Test"):
                pytest_cases += methods

    if pytest_cases and not unittest_cases:
        return PYTEST, pytest_cases
    # Mixed modules are run by unittest in this repo; pytest-only functions
    # inside them would be silently skipped, so count only what unittest sees.
    return UNITTEST, unittest_cases


def _is_testcase_subclass(node: ast.ClassDef) -> bool:
    for base in node.bases:
        name = base.attr if isinstance(base, ast.Attribute) else getattr(base, "id", "")
        if name.endswith("TestCase"):
            return True
    return False


def discover_tests(tests_dir: Path) -> dict[str, TestFile]:
    files: dict[str, TestFile] = {}
    for path in sorted(tests_dir.glob("test_*.py")):
        framework, count = classify_python(path)
        files[path.name] = TestFile(path.name, framework, count)
    for path in sorted(tests_dir.glob("*_test.dart")):
        text = path.read_text(encoding="utf-8")
        # package:test suites declare test(...); standalone scripts such as
        # guarded_connection_test.dart assert with require(...)/expect(...).
        count = len(re.findall(r"\b(?:test|require|expect)\s*\(", text))
        files[path.name] = TestFile(path.name, DART, count)
    return files


def find_registrations(workflow_texts: dict[str, str], tests_dir_rel: str, names: list[str]) -> list[tuple[str, str, str]]:
    """Return (runner, file name, workflow) for every runner command naming a test file."""
    tests_dir_rel = tests_dir_rel.rstrip("/")
    regs: list[tuple[str, str, str]] = []
    for workflow, text in workflow_texts.items():
        for match in _UNITTEST_DISCOVER.finditer(text):
            args = match.group("args")
            dir_match = _UNITTEST_DIR.search(args)
            if not dir_match or dir_match.group("dir").rstrip("/") != tests_dir_rel:
                continue
            pat_match = _UNITTEST_PATTERN.search(args)
            pattern = pat_match.group("pat") if pat_match else "test*.py"
            for name in names:
                if name.endswith(".py") and fnmatch.fnmatchcase(name, pattern):
                    regs.append((UNITTEST, name, workflow))
        for match in _PYTEST_CMD.finditer(text):
            args = match.group("args")
            for token in args.split():
                token = token.strip("'\"")
                if token.rstrip("/") == tests_dir_rel:
                    regs.extend((PYTEST, n, workflow) for n in names if n.endswith(".py"))
                elif token.startswith(tests_dir_rel + "/"):
                    candidate = token[len(tests_dir_rel) + 1 :].split("::", 1)[0]
                    if candidate in names:
                        regs.append((PYTEST, candidate, workflow))
        for match in _DART_FILE.finditer(text):
            candidate = match.group("path")
            if candidate.startswith(tests_dir_rel + "/"):
                candidate = candidate[len(tests_dir_rel) + 1 :]
                if candidate in names:
                    regs.append((DART, candidate, workflow))
    return regs


def build_inventory(root: Path, tests_dir_rel: str = "tool/tests", workflows_rel: str = ".github/workflows") -> dict[str, TestFile]:
    tests_dir = root / tests_dir_rel
    if not tests_dir.is_dir():
        raise InventoryError(f"tests directory not found: {tests_dir}")
    workflows_dir = root / workflows_rel
    texts: dict[str, str] = {}
    for path in sorted(list(workflows_dir.glob("*.yml")) + list(workflows_dir.glob("*.yaml"))):
        try:
            texts[path.name] = path.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            raise InventoryError(f"cannot read workflow {path}: {exc}") from exc
    if not texts:
        raise InventoryError(f"no workflow files found in {workflows_dir}")

    files = discover_tests(tests_dir)
    for runner, name, _workflow in find_registrations(texts, tests_dir_rel, list(files)):
        files[name].runners.append(runner)
    return files


def find_problems(files: dict[str, TestFile], known_gaps: dict[str, str]) -> list[Problem]:
    problems: list[Problem] = []
    for f in files.values():
        if f.test_count == 0:
            problems.append(Problem("zero_tests", f.name, f"declares no {f.framework} test cases"))
        if not f.runners:
            problems.append(Problem("unregistered", f.name, f"no CI command runs this {f.framework} suite"))
        elif f.framework == PYTEST and PYTEST not in f.runners:
            problems.append(
                Problem("runner_mismatch", f.name, "pytest-style module is only run by unittest, which collects 0 tests")
            )
        for runner in sorted(set(f.runners)):
            if f.runners.count(runner) > 1:
                problems.append(
                    Problem("duplicate", f.name, f"run {f.runners.count(runner)} times by {runner}")
                )
    gap_files = {p.file for p in problems}
    for name in known_gaps:
        if name not in gap_files:
            problems.append(
                Problem("stale_known_gap", name, "listed in KNOWN_GAPS but no longer a gap; remove the entry")
            )
    for p in problems:
        p.known = p.file in known_gaps and p.kind != "stale_known_gap"
    return problems


def render_markdown(files: dict[str, TestFile], problems: list[Problem], strict: bool) -> str:
    by_framework: dict[str, int] = {}
    for f in files.values():
        by_framework[f.framework] = by_framework.get(f.framework, 0) + 1
    executed = sum(1 for f in files.values() if f.runners and not (f.framework == PYTEST and PYTEST not in f.runners))
    mode = "strict" if strict else "ratchet (known gaps tolerated)"
    lines = [
        "## tool/tests inventory",
        "",
        f"Mode: **{mode}**. Discovered **{len(files)}** suites "
        f"({', '.join(f'{k}: {v}' for k, v in sorted(by_framework.items()))}); "
        f"**{executed}** executed by a CI runner; "
        f"**{sum(f.test_count for f in files.values())}** statically declared test cases.",
        "",
    ]
    if problems:
        lines += ["| Status | Problem | File | Detail |", "|---|---|---|---|"]
        for p in problems:
            status = "known gap" if p.known and not strict else "FAIL"
            lines.append(f"| {status} | `{p.kind}` | `{p.file}` | {p.detail} |")
    else:
        lines.append("No gaps: every suite is executed by a matching runner.")
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--tests-dir", default="tool/tests")
    parser.add_argument("--workflows-dir", default=".github/workflows")
    parser.add_argument("--strict", action="store_true", help="fail on every gap, ignoring KNOWN_GAPS")
    args = parser.parse_args(argv)

    try:
        files = build_inventory(args.root, args.tests_dir, args.workflows_dir)
    except InventoryError as exc:
        print(f"::error::test inventory failed: {exc}")
        return 2

    known = {} if args.strict else KNOWN_GAPS
    problems = find_problems(files, known)
    report = render_markdown(files, problems, args.strict)
    print(report)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as fh:
            fh.write(report + "\n")

    failing = [p for p in problems if args.strict or not p.known]
    for p in problems:
        level = "error" if p in failing else "warning"
        print(f"::{level} file={args.tests_dir}/{p.file}::{p.kind}: {p.detail}")
    return 1 if failing else 0


if __name__ == "__main__":
    sys.exit(main())
