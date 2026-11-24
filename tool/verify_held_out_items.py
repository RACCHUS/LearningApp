#!/usr/bin/env python3
"""Verify held-out check items (ingestion plan v1.2 §8.6, D-14).

Checks every file in content/held_out/:
  * authoring: author_ref and ai_drafted at file level, and an
    objective_concepts map matching the published manifest's concepts;
  * reviews: an approved `review` names a reviewer who is not the author,
    their qualification, a past YYYY-MM-DD date and rights approval;
  * structure: ids unique and slug-shaped, known objectives, supported
    interaction types, a keyed answer, an explanation and a citation;
  * depth: at least ``min_items_per_objective`` items for every objective of
    the target's published manifest (content/open_<source>.yaml);
  * independence: no prompt repeats a lesson item or practice prompt from
    that manifest;
  * answer-position spread: no single option position keys more than half
    of the single-choice items;
  * mathematics, with sympy: the keyed numeric value or option is right and
    every other option is wrong, except options listed in
    ``same_value_distractors`` (deliberate "right value, wrong form"
    distractors in simplest-form questions).

The expressions come from repository files only (sympy's parser evaluates
them), never from learners or the network.

    python tool/verify_held_out_items.py
"""
from __future__ import annotations

import re
import sys
from collections import Counter
from datetime import date
from pathlib import Path

import sympy as sp
import yaml
from sympy.parsing.sympy_parser import parse_expr, standard_transformations

REPO = Path(__file__).resolve().parents[1]
DRAFTS = REPO / "content" / "held_out"
TYPES = {"numeric_entry", "single_choice"}
SYMBOLS = {name: sp.Symbol(name) for name in ("x", "y", "a", "b")}
NAMES = {**SYMBOLS, "sqrt": sp.sqrt, "Rational": sp.Rational, "Abs": sp.Abs,
         "real_root": sp.real_root}


def expr(text: str) -> sp.Expr:
    return parse_expr(str(text), local_dict=dict(NAMES), transformations=standard_transformations)


def same(a: sp.Expr, b: sp.Expr) -> bool:
    return sp.simplify(a - b) == 0


def _norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def keyed_value(item: dict) -> sp.Expr | None:
    """The mathematically correct answer the verify block describes."""
    v = item.get("verify") or {}
    if "expression" in v:
        e = expr(v["expression"])
        subs = {SYMBOLS[k]: val for k, val in (v.get("substitute") or {}).items()}
        return sp.nsimplify(e.subs(subs)) if subs else e
    x = SYMBOLS["x"]
    if "degree_of" in v:
        return sp.Integer(sp.degree(expr(v["degree_of"]), x))
    if "leading_coefficient_of" in v:
        return sp.LC(sp.Poly(sp.expand(expr(v["leading_coefficient_of"])), x))
    if "largest_root_of" in v:
        return max(sp.solve(expr(v["largest_root_of"]), x))
    if "denominator_zero_of" in v:
        roots = sp.solve(sp.denom(sp.together(expr(v["denominator_zero_of"]))), x)
        return roots[0] if len(roots) == 1 else None
    return None


def check_item(item: dict) -> list[str]:
    iid = item.get("id", "?")
    problems: list[str] = []
    v = item.get("verify")
    if not v:
        return [f"{iid}: missing verify block"]
    kind = item.get("interaction_type")
    if kind == "numeric_entry":
        target = keyed_value(item)
        key = (item.get("scoring_spec") or {}).get("correct_value")
        if target is None or key is None:
            return [f"{iid}: cannot compute the keyed value"]
        if not same(target, sp.nsimplify(key)):
            problems.append(f"{iid}: keyed {key} but the expression gives {target}")
        return problems

    options = (item.get("response_spec") or {}).get("options") or []
    idx = (item.get("scoring_spec") or {}).get("correct_index")
    if not isinstance(idx, int) or not 0 <= idx < len(options):
        return [f"{iid}: correct_index out of range"]
    if "irrational_index" in v:
        vals = [expr(t) for t in v["values"]]
        irr = [i for i, val in enumerate(vals) if val.is_irrational]
        if irr != [v["irrational_index"]] or idx != v["irrational_index"]:
            problems.append(f"{iid}: irrational options are {irr}, keyed {idx}")
        return problems
    if "identity" in v:
        if not same(expr(v["identity"]), 0):
            problems.append(f"{iid}: the shown identity does not hold")
        return problems
    sym_opts = v.get("options") or []
    if len(sym_opts) != len(options):
        return [f"{iid}: verify.options must match the options"]
    target = keyed_value(item)
    allowed_equal = set(v.get("same_value_distractors") or [])
    for i, opt in enumerate(sym_opts):
        if opt is None:
            if i == idx:
                problems.append(f"{iid}: the keyed option has no expression to check")
            continue
        equal = same(expr(opt), target)
        if i == idx and not equal:
            problems.append(f"{iid}: keyed option {i} ({opt}) is not equal to {target}")
        if i != idx and equal and i not in allowed_equal:
            problems.append(f"{iid}: distractor {i} ({opt}) is also correct")
        if i != idx and not equal and i in allowed_equal:
            problems.append(f"{iid}: option {i} is listed as same-value but isn't")
    return problems


REVIEW_STATUSES = {"approved", "pending", "rejected"}


def check_review(item: dict, author: str) -> list[str]:
    """An optional review block must be complete and by someone else (D-14)."""
    review = item.get("review")
    iid = item.get("id", "?")
    if review is None:
        return []
    if not isinstance(review, dict):
        return [f"{iid}: review must be a mapping"]
    problems = []
    status = review.get("review_status")
    if status not in REVIEW_STATUSES:
        problems.append(f"{iid}: review_status must be one of {sorted(REVIEW_STATUSES)}")
    if status != "approved":
        return problems
    reviewer = str(review.get("reviewer_ref") or "").strip()
    if not 2 <= len(reviewer) <= 150:
        problems.append(f"{iid}: reviewer_ref is required")
    elif reviewer.lower() == author.strip().lower():
        problems.append(f"{iid}: the reviewer cannot be the author")
    if not 3 <= len(str(review.get("reviewer_qualification") or "").strip()) <= 500:
        problems.append(f"{iid}: reviewer_qualification is required")
    if review.get("rights_review_status") != "approved":
        problems.append(f"{iid}: an approved item needs rights_review_status: approved")
    on = review.get("reviewed_on")
    try:
        when = on if isinstance(on, date) else date.fromisoformat(str(on))
        if when > date.today():
            problems.append(f"{iid}: reviewed_on is in the future")
    except ValueError:
        problems.append(f"{iid}: reviewed_on must be YYYY-MM-DD")
    return problems


def published_manifest(source_release_id: str) -> dict:
    path = REPO / "content" / f"open_{source_release_id.replace('-', '_')}.yaml"
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def check_file(path: Path) -> list[str]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    items = data.get("items") or []
    name = path.name
    problems: list[str] = []
    manifest = published_manifest(data.get("source_release_id", ""))
    objectives = {o["code"]: o for d in manifest["domains"] for o in d["objectives"]}
    seen_prompts = set()
    for o in objectives.values():
        for lesson in o["lessons"]:
            for q in lesson.get("assessment_items") or []:
                seen_prompts.add(_norm(q.get("prompt", "")))
            for b in lesson.get("blocks") or []:
                if b.get("block_type") == "practice_prompt":
                    seen_prompts.add(_norm((b.get("content") or {}).get("prompt", "")))

    author = str(data.get("author_ref") or "").strip()
    if not author:
        problems.append(f"{name}: author_ref is required")
    if not isinstance(data.get("ai_drafted"), bool):
        problems.append(f"{name}: ai_drafted must be true or false")
    mapped = data.get("objective_concepts") or {}
    for code, o in objectives.items():
        expected = sorted(c["slug"] for c in o.get("concepts") or [])
        if sorted(mapped.get(code) or []) != expected:
            problems.append(f"{name}: objective_concepts[{code}] must be {expected}")

    ids = Counter(i.get("id") for i in items)
    for iid, n in ids.items():
        if n > 1:
            problems.append(f"{name}: duplicate id {iid}")
    per_objective = Counter()
    keyed_positions = Counter()
    for item in items:
        iid = item.get("id", "?")
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", str(iid)):
            problems.append(f"{name}: id {iid!r} is not a lowercase slug")
        if item.get("objective") not in objectives:
            problems.append(f"{name}: {iid} names unknown objective {item.get('objective')}")
        if item.get("interaction_type") not in TYPES:
            problems.append(f"{name}: {iid} has unsupported type {item.get('interaction_type')}")
        if not str(item.get("explanation", "")).strip():
            problems.append(f"{name}: {iid} needs an explanation")
        if not str(item.get("citation", "")).strip():
            problems.append(f"{name}: {iid} needs a citation")
        problems += [f"{name}: {p}" for p in check_review(item, author)]
        if _norm(item.get("prompt", "")) in seen_prompts:
            problems.append(f"{name}: {iid} repeats a lesson prompt, so it isn't held out")
        per_objective[item.get("objective")] += 1
        if item.get("interaction_type") == "single_choice":
            keyed_positions[(item.get("scoring_spec") or {}).get("correct_index")] += 1
        problems += [f"{name}: {p}" for p in check_item(item)]
    need = int(data.get("min_items_per_objective", 6))
    for code in objectives:
        if per_objective[code] < need:
            problems.append(f"{name}: objective {code} has {per_objective[code]} items, needs {need}")
    total_choice = sum(keyed_positions.values())
    if total_choice >= 6:
        pos, count = keyed_positions.most_common(1)[0]
        if count / total_choice > 0.5:
            problems.append(f"{name}: option {pos} keys {count} of {total_choice} single-choice items")
    return problems


def main() -> int:
    files = sorted(DRAFTS.glob("*.yaml"))
    problems: list[str] = []
    count = 0
    for f in files:
        problems += check_file(f)
        count += len((yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("items") or [])
    for p in problems:
        print(f"ERROR: {p}")
    if problems:
        print(f"Held-out items check FAILED: {len(problems)} problem(s).")
        return 1
    print(f"Held-out items check PASS: {count} item(s) in {len(files)} file(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
