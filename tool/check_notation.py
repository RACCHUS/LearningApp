#!/usr/bin/env python3
"""Notation profile per target (ingestion plan v1.2 §8.9).

A slice that mixes sources must read as one course. ``data/notation_profiles.yaml``
gives each curriculum manifest a profile; this check scans the learner-facing
text of the manifest against it:

  bare_latex        a LaTeX command (\\frac, \\sqrt, \\times...) outside $...$ in a
                    LaTeX course: the app shows the backslashes as text.
  plain_math        x^2, <=, >=, != or sqrt( outside $...$ in a LaTeX course
                    (the same course writes math as LaTeX elsewhere).
  excel_case        a lower-case Excel function call (sum( instead of SUM().
  decimal_comma     a decimal comma before a unit (2,5 cm) where the profile
                    uses a decimal point.
  thousands_space   a space as thousands separator (12 500) where the profile
                    uses a comma.

Deterministic rules are fixed at the source (generators and the importer), so
new manifests start clean. The rest is flagged: ``data/notation_baseline.json``
freezes today's counts per manifest and rule. A count above its baseline
fails, and so does a baseline above the real count (lower it: the list can
only shrink). ``--write-baseline`` records the current counts.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
PROFILES = REPO / "data" / "notation_profiles.yaml"
BASELINE = REPO / "data" / "notation_baseline.json"

# Fields that are not shown to learners as course text.
SKIP = frozenset({"citation", "source_url", "url", "slug", "concept_slugs", "tags", "emoji", "id",
                  "source_release_id", "locator", "scoring_spec", "metadata"})
MATH = re.compile(r"\$\$[^$]+\$\$|\$(?!\s)[^$\n]+?(?<!\s)\$")
LATEX_CMD = re.compile(r"\\[A-Za-z]+")
PLAIN_MATH = re.compile(r"[A-Za-z0-9)\]]\^[A-Za-z0-9({-]|<=|>=|!=|\bsqrt\(")
EXCEL_FN = re.compile(r"(?<![\w$.])(sum|average|min|max|count|counta|if|round|vlookup|xlookup|"
                      r"sumif|countif|concat|text|today|now)\(")
# A comma followed by exactly three digits is a thousands separator (1,152 cm).
DECIMAL_COMMA = re.compile(r"\b\d+,(?:\d{1,2}|\d{4,}) ?(?:%|cm|mm|km|kg|g|ml|°)(?!\w)")
THOUSANDS_SPACE = re.compile(r"(?<![\d.,])\b\d{1,3}(?: \d{3})+\b(?![\d,.])")
RULES = ("bare_latex", "plain_math", "excel_case", "decimal_comma", "thousands_space")


def texts(node, path=()):
    """(path, text) for every learner-facing string."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k not in SKIP:
                yield from texts(v, path + (str(k),))
    elif isinstance(node, list):
        for v in node:
            yield from texts(v, path)
    elif isinstance(node, str):
        yield path, node


def findings(manifest: dict, profile: dict) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {r: [] for r in RULES}
    latex = profile.get("math_markup") == "latex"
    for path, s in texts({"domains": manifest.get("domains"), "stimuli": manifest.get("stimuli")}):
        where = "/".join(p for p in path if p not in ("domains", "objectives", "lessons"))
        outside = MATH.sub(" ", s)
        if latex:
            for m in LATEX_CMD.finditer(outside):
                out["bare_latex"].append(f"{where}: {m.group(0)}")
            for m in PLAIN_MATH.finditer(outside):
                out["plain_math"].append(f"{where}: {outside[max(0, m.start() - 12):m.end() + 8].strip()}")
        if profile.get("excel_function_case") == "upper":
            for m in EXCEL_FN.finditer(s):
                out["excel_case"].append(f"{where}: {m.group(0)}")
        if profile.get("decimal_separator") == ".":
            for m in DECIMAL_COMMA.finditer(outside):
                out["decimal_comma"].append(f"{where}: {m.group(0)}")
        if profile.get("thousands_separator") == ",":
            for m in THOUSANDS_SPACE.finditer(outside):
                out["thousands_space"].append(f"{where}: {m.group(0)}")
    return out


def wrap_bare_latex_option(option: str) -> str:
    """Deterministic fix for an answer option that is a bare LaTeX expression:
    an option with a LaTeX command and no $ is wrapped in $...$ whole."""
    s = option.strip()
    if "$" in s or not LATEX_CMD.search(s):
        return option
    return f"${s}$"


def load_profiles() -> dict:
    return (yaml.safe_load(PROFILES.read_text(encoding="utf-8")) or {}).get("manifests") or {}


def counts(profiles: dict, content: Path = REPO / "content") -> tuple[dict, dict]:
    result, detail = {}, {}
    for name, profile in sorted(profiles.items()):
        manifest = yaml.safe_load((content / name).read_text(encoding="utf-8"))
        f = findings(manifest, profile)
        result[name] = {r: len(v) for r, v in f.items() if v}
        detail[name] = f
    return result, detail


def check(profiles: dict, baseline: dict, content: Path = REPO / "content") -> list[str]:
    problems = []
    names = {p.name for p in content.glob("*.yaml")}
    for p in content.glob("*.yaml"):
        doc = yaml.safe_load(p.read_text(encoding="utf-8"))
        if isinstance(doc, dict) and "domains" in doc and p.name not in profiles:
            problems.append(f"{p.name}: no notation profile in data/notation_profiles.yaml")
    for name in profiles:
        if name not in names:
            problems.append(f"notation profile for {name}: no such manifest in content/")
    current, detail = counts({k: v for k, v in profiles.items() if k in names}, content)
    for name, rules in current.items():
        allowed = baseline.get(name, {})
        for rule, n in rules.items():
            if n > allowed.get(rule, 0):
                sample = "; ".join(detail[name][rule][:3])
                problems.append(f"{name}: {n} {rule} (baseline {allowed.get(rule, 0)}), e.g. {sample}")
        for rule, n in allowed.items():
            if n > rules.get(rule, 0):
                problems.append(f"{name}: baseline {rule} is {n} but only {rules.get(rule, 0)} remain; "
                                "lower it (python tool/check_notation.py --write-baseline)")
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--write-baseline", action="store_true", help="record the current counts as the baseline")
    ap.add_argument("--report", metavar="MANIFEST", help="list every finding for one manifest")
    args = ap.parse_args(argv)
    profiles = load_profiles()
    if args.report:
        _, detail = counts({args.report: profiles[args.report]})
        for rule, items in detail[args.report].items():
            for item in items:
                print(f"{rule}: {item}")
        return 0
    if args.write_baseline:
        current, _ = counts(profiles)
        BASELINE.write_text(json.dumps({
            "about": "Frozen notation findings per manifest (plan v1.2 §8.9; tool/check_notation.py). Counts may only fall.",
            "counts": {k: v for k, v in current.items() if v}}, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {BASELINE.relative_to(REPO)}")
        return 0
    baseline = json.loads(BASELINE.read_text(encoding="utf-8")).get("counts", {}) if BASELINE.exists() else {}
    problems = check(profiles, baseline)
    for p in problems:
        print(f"ERROR: {p}")
    if problems:
        return 1
    print(f"Notation check PASS: {len(profiles)} manifest profile(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
