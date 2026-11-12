#!/usr/bin/env python3
"""Critical mutation seeds: plant a known-bad bug, require the tests to fail.

Plan PR-4b (Workstream C2, finding Q-09). Each seed is one deliberately wrong
edit to production code that a real regression could plausibly introduce
(a missing answer key becoming option A, a disabled feature turning on, ...).
For each seed the runner:

1. checks the targeted test command passes on the unmodified code (baseline),
2. applies the edit to the working tree,
3. runs the command and expects it to FAIL ("killed"),
4. restores the original file bytes (always, in ``finally``).

A seed whose tests still pass ("survived") means the suite cannot detect that
bug, and the run fails.

Usage:
  python3 tool/ci/mutation_seeds.py --check            # every seed still applies (fast, no tests)
  python3 tool/ci/mutation_seeds.py                    # run all seeds
  python3 tool/ci/mutation_seeds.py --only byok-latch-enabled

Exit codes: 0 all killed (or --check ok), 1 a seed survived, 2 a seed is
stale, a baseline fails, or a target file has uncommitted changes.

It refuses to touch a file with uncommitted changes, so an interrupted local
run can always be undone with ``git checkout -- <file>``.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Seed:
    id: str
    risk: str
    file: str
    find: str
    replace: str
    command: tuple[str, ...]
    regex: bool = False


FLUTTER = "{flutter}"
PYTHON = "{python}"


def flutter_test(*paths: str) -> tuple[str, ...]:
    return (FLUTTER, "test", *paths)


SEEDS: tuple[Seed, ...] = (
    Seed(
        id="answer-key-missing-becomes-option-a",
        risk="A missing MCQ answer key is silently scored as option A (index 0).",
        file="lib/models/answer_key.dart",
        # Anchored on fromIndex's own null check (fromText has the same message).
        find=(
            "    if (raw == null) {\n"
            "      return const AnswerKeyResult.rejected(\n"
            "        AnswerKeyStatus.missingKey,\n"
            "        'No correct answer was given.',\n"
            "      );"
        ),
        replace="    if (raw == null) {\n      return _checkIndex(0, options);",
        command=flutter_test("test/models/answer_key_test.dart"),
    ),
    Seed(
        id="byok-latch-enabled",
        risk="The hard BYOK release latch is switched on without review.",
        file="lib/services/ai/byok_release_gate.dart",
        find="  static const bool enabled = false;",
        replace="  static const bool enabled = true;",
        command=flutter_test("test/services/ai/byok_release_gate_test.dart"),
    ),
    Seed(
        id="lesson-import-swallows-partial-failure",
        risk="A failed content write mid-import is swallowed, leaving a partial lesson reported as success.",
        file="lib/services/lesson/lesson_import_service.dart",
        find="        await entry.value();",
        replace="        await entry.value().catchError((Object _) {});",
        command=flutter_test("test/services/lesson_import_service_test.dart"),
    ),
    Seed(
        id="absent-feature-flag-treated-as-on",
        risk="After registry activation, an absent or unreachable flag re-enables a killed feature.",
        file="lib/providers/site_feature_provider.dart",
        find="  return snapshot?[key]?.enabled ?? false;",
        replace="  return snapshot?[key]?.enabled ?? true;",
        command=flutter_test("test/services/governance/site_feature_service_test.dart"),
    ),
    Seed(
        id="contribution-ignores-kill-switch",
        risk="One entry point (public lesson contribution) ignores its feature kill switch.",
        file="lib/providers/lesson_contribution_provider.dart",
        find="final publicContributionEnabledProvider = Provider<bool>((ref) {\n  return isSiteFeatureEnabled(",
        replace="final publicContributionEnabledProvider = Provider<bool>((ref) {\n  return true || isSiteFeatureEnabled(",
        command=flutter_test("test/widgets/share_with_community_test.dart"),
    ),
    Seed(
        id="client-score-trusted-over-server",
        risk="The client's own answered count is shown as the score instead of the server-graded raw_score.",
        file="lib/services/assessment/clep_simulation_service.dart",
        find="    final correct = (json['raw_score'] as num?)?.toInt() ??",
        replace="    final correct = clientAnsweredCount ?? (json['raw_score'] as num?)?.toInt() ??",
        command=flutter_test("test/services/clep_simulation_service_test.dart"),
    ),
    Seed(
        id="wrong-exam-blueprint",
        risk="Every exam target gets the CLEP Psychology blueprint (e.g. Algebra planned against Psychology domains).",
        file="lib/models/overview_outline.dart",
        find="    return clepPsychologyOfficialDomains;\n  }\n  return const <OfficialDomainBlueprint>[];",
        replace="    return clepPsychologyOfficialDomains;\n  }\n  return clepPsychologyOfficialDomains;",
        command=flutter_test("test/services/planning/learning_strategy_planner_test.dart"),
    ),
    Seed(
        id="algebra-shipped-answer-key-wrong",
        risk="A shipped College Algebra item's answer key points at a wrong option.",
        file="content/clep_college_algebra.yaml",
        find=r"(- id: alg-sim-scientific-notation-quotient\r?\n(?:[^\n]*\n)*?\s*correct_index: )2",
        replace=r"\g<1>3",
        regex=True,
        command=(PYTHON, "-m", "pytest", "-q", "tool/tests/test_clep_algebra_math_accuracy.py"),
    ),
)


class SeedError(Exception):
    pass


def _newline(text: str) -> str:
    return "\r\n" if "\r\n" in text else "\n"


def mutate(seed: Seed, original: str) -> str:
    """Return the mutated text; the seed must match exactly once."""
    if seed.regex:
        pattern = re.compile(seed.find)
        if len(pattern.findall(original)) != 1:
            raise SeedError(f"{seed.id}: pattern must match exactly once in {seed.file}")
        mutated = pattern.sub(seed.replace, original, count=1)
    else:
        nl = _newline(original)
        find = seed.find.replace("\n", nl)
        if original.count(find) != 1:
            raise SeedError(f"{seed.id}: snippet must occur exactly once in {seed.file} (found {original.count(find)})")
        mutated = original.replace(find, seed.replace.replace("\n", nl), 1)
    if mutated == original:
        raise SeedError(f"{seed.id}: mutation changes nothing")
    return mutated


def resolve(command: tuple[str, ...]) -> list[str]:
    flutter = shutil.which("flutter") or "flutter"
    python = os.environ.get("CI_TEST_PYTHON") or sys.executable
    return [flutter if c == FLUTTER else python if c == PYTHON else c for c in command]


def run(command: tuple[str, ...], timeout: int) -> tuple[int, float]:
    env = dict(os.environ, PYTHONPATH=str(ROOT))
    start = time.monotonic()
    try:
        proc = subprocess.run(resolve(command), cwd=ROOT, env=env, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=timeout)
        code = proc.returncode
    except subprocess.TimeoutExpired:
        code = 124
    return code, time.monotonic() - start


def is_dirty(path: str) -> bool:
    try:
        out = subprocess.run(["git", "status", "--porcelain", "--", path], cwd=ROOT,
                             capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return False  # not a git checkout: nothing to protect
    return bool(out.strip())


def check(seeds) -> list[str]:
    problems = []
    for seed in seeds:
        path = ROOT / seed.file
        if not path.is_file():
            problems.append(f"{seed.id}: {seed.file} not found")
            continue
        try:
            mutate(seed, path.read_bytes().decode("utf-8"))
        except SeedError as exc:
            problems.append(str(exc))
    return problems


def execute(seeds, timeout: int) -> tuple[list[tuple[Seed, str, float]], list[str]]:
    results, errors = [], []
    baselines: dict[tuple[str, ...], int] = {}
    for seed in seeds:
        if seed.command not in baselines:
            baselines[seed.command], _ = run(seed.command, timeout)
        if baselines[seed.command] != 0:
            errors.append(f"{seed.id}: baseline `{' '.join(seed.command)}` fails without any mutation")
            continue
        if is_dirty(seed.file):
            errors.append(f"{seed.id}: {seed.file} has uncommitted changes; refusing to mutate it")
            continue
        path = ROOT / seed.file
        original = path.read_bytes()
        mutated = mutate(seed, original.decode("utf-8"))
        try:
            path.write_bytes(mutated.encode("utf-8"))
            code, seconds = run(seed.command, timeout)
        finally:
            path.write_bytes(original)
        results.append((seed, "killed" if code != 0 else "SURVIVED", seconds))
    return results, errors


def render(results, errors) -> str:
    lines = ["## Critical mutation seeds", "", "| Seed | Simulated defect | Result | Time |", "|---|---|---|---:|"]
    for seed, outcome, seconds in results:
        lines.append(f"| `{seed.id}` | {seed.risk} | {'killed' if outcome == 'killed' else '**SURVIVED**'} | {seconds:.0f}s |")
    for error in errors:
        lines.append(f"| error | {error} | **ERROR** | |")
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true", help="only verify every seed still applies exactly once")
    parser.add_argument("--only", action="append", default=[], help="run only these seed ids")
    parser.add_argument("--timeout", type=int, default=900, help="per-command timeout in seconds")
    args = parser.parse_args(argv)

    unknown = set(args.only) - {s.id for s in SEEDS}
    if unknown:
        print(f"::error::unknown seed ids: {sorted(unknown)}")
        return 2
    seeds = [s for s in SEEDS if not args.only or s.id in args.only]

    stale = check(seeds)
    if stale or args.check:
        for problem in stale:
            print(f"::error::stale mutation seed: {problem}")
        if not stale:
            print(f"All {len(seeds)} mutation seeds apply exactly once.")
        return 2 if stale else 0

    results, errors = execute(seeds, args.timeout)
    text = render(results, errors)
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(text + "\n")
    if errors:
        return 2
    return 1 if any(outcome != "killed" for _, outcome, _ in results) else 0


if __name__ == "__main__":
    sys.exit(main())
