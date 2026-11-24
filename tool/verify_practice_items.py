#!/usr/bin/env python3
"""Verify original practice items (ingestion plan v1.2 §8.6, D-14 bank depth).

Checks every file in content/practice/:
  * authoring: author_ref and ai_drafted at file level, and either a
    source_release_id (open-textbook manifest content/open_<source>.yaml) or a
    `manifest:` path for a hand-authored manifest;
  * structure: ids unique, slug-shaped and not shared with a held-out item;
    known objectives; supported types; an explanation and a citation;
  * mathematics, with sympy: the same `verify` modes as the held-out checks
    (tool/verify_held_out_items.py), so a wrong key or a second correct option
    fails;
  * reviews: an approved `review` is complete and by someone other than the
    author (decision D-16, same rules as the held-out checks);
  * independence: no practice prompt repeats a held-out prompt for the same
    target or reuses a held-out expression (held-out checks must stay unseen);
  * answer-position spread: no option position keys more than half of the
    single-choice items;
  * merged: every approved item is in the target manifest exactly as written
    (the open-textbook importer merges them; hand-authored manifests copy
    them into `questions`), and no unapproved item is;
  * depth: every objective of the manifest has at least
    ``min_practice_per_objective`` graded items.

    python tool/verify_practice_items.py
"""
from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify_held_out_items as ho  # noqa: E402

REPO = ho.REPO
PRACTICE = REPO / "content" / "practice"
NUMERIC_SUFFIX = "\n\nAnswer with a number."


def manifest_items(manifest: dict) -> dict[str, list[dict]]:
    """Graded items per objective code, normalized to one shape."""
    out: dict[str, list[dict]] = {}
    for d in manifest["domains"]:
        for o in d["objectives"]:
            items = out.setdefault(str(o["code"]), [])
            for lesson in o.get("lessons") or []:
                for q in lesson.get("assessment_items") or []:
                    items.append({"id": q.get("id"), "prompt": q.get("prompt"),
                                  "options": (q.get("response_spec") or {}).get("options"),
                                  "scoring_spec": q.get("scoring_spec")})
                for q in lesson.get("questions") or []:
                    items.append({"id": q.get("id"), "prompt": q.get("question_text"),
                                  "options": q.get("options"),
                                  "scoring_spec": {"correct_index": q.get("correct_answer")}})
    return out


def expected_prompt(item: dict) -> str:
    """How the item's prompt appears in the manifest."""
    prompt = item.get("prompt", "")
    if item.get("interaction_type") == "numeric_entry" and not prompt.endswith(NUMERIC_SUFFIX):
        prompt += NUMERIC_SUFFIX
    return prompt


def held_out_for(target_slug: str) -> list[dict]:
    items = []
    for f in sorted(ho.DRAFTS.glob("*.yaml")):
        data = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
        if data.get("target_slug") == target_slug:
            items += data.get("items") or []
    return items


def is_approved(item: dict) -> bool:
    review = item.get("review")
    return isinstance(review, dict) and review.get("review_status") == "approved"


def check_file(path: Path) -> list[str]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    items = data.get("items") or []
    name = path.name
    problems: list[str] = []
    manifest = ho.published_manifest(data.get("source_release_id", ""), data.get("manifest"))
    graded = manifest_items(manifest)
    by_id = {q["id"]: (code, q) for code, qs in graded.items() for q in qs if q.get("id")}

    author = str(data.get("author_ref") or "").strip()
    if not author:
        problems.append(f"{name}: author_ref is required")
    if not isinstance(data.get("ai_drafted"), bool):
        problems.append(f"{name}: ai_drafted must be true or false")

    held = held_out_for(str(data.get("target_slug", "")))
    held_ids = {h.get("id") for h in held}
    held_prompts = {ho._norm(h.get("prompt", "")) for h in held}
    held_math = "\n".join(ho._math_norm(h.get("prompt", "")) for h in held)

    for iid, n in Counter(i.get("id") for i in items).items():
        if n > 1:
            problems.append(f"{name}: duplicate id {iid}")
    keyed_positions = Counter()
    for item in items:
        iid = item.get("id", "?")
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", str(iid)):
            problems.append(f"{name}: id {iid!r} is not a lowercase slug")
        if iid in held_ids:
            problems.append(f"{name}: {iid} uses a held-out item's id")
        code = str(item.get("objective"))
        if code not in graded:
            problems.append(f"{name}: {iid} names unknown objective {item.get('objective')}")
        if item.get("interaction_type") not in ho.TYPES:
            problems.append(f"{name}: {iid} has unsupported type {item.get('interaction_type')}")
        if not str(item.get("explanation", "")).strip():
            problems.append(f"{name}: {iid} needs an explanation")
        if not str(item.get("citation", "")).strip():
            problems.append(f"{name}: {iid} needs a citation")
        problems += [f"{name}: {p}" for p in ho.check_review(item, author)]
        if ho._norm(item.get("prompt", "")) in held_prompts:
            problems.append(f"{name}: {iid} repeats a held-out prompt")
        for seg in ho.math_segments(item.get("prompt", "")):
            if seg in held_math:
                problems.append(f"{name}: {iid} reuses ${seg}$ from a held-out check")
        if item.get("interaction_type") == "single_choice":
            keyed_positions[(item.get("scoring_spec") or {}).get("correct_index")] += 1
        problems += [f"{name}: {p}" for p in ho.check_item(item)]

        found = by_id.get(iid)
        if not is_approved(item):
            if found:
                problems.append(f"{name}: {iid} is in the manifest but isn't approved")
            continue
        if not found:
            problems.append(f"{name}: approved item {iid} is missing from the manifest")
            continue
        m_code, q = found
        if m_code != code:
            problems.append(f"{name}: {iid} is under objective {m_code} in the manifest, not {code}")
        if str(q.get("prompt") or "").strip() != expected_prompt(item).strip():
            problems.append(f"{name}: {iid} prompt differs from the manifest")
        if item.get("interaction_type") == "single_choice":
            if q.get("options") != (item.get("response_spec") or {}).get("options"):
                problems.append(f"{name}: {iid} options differ from the manifest")
            if (q.get("scoring_spec") or {}).get("correct_index") != item["scoring_spec"].get("correct_index"):
                problems.append(f"{name}: {iid} key differs from the manifest")
        elif (q.get("scoring_spec") or {}).get("correct_value") != item["scoring_spec"].get("correct_value"):
            problems.append(f"{name}: {iid} key differs from the manifest")

    total_choice = sum(keyed_positions.values())
    if total_choice >= 6:
        pos, count = keyed_positions.most_common(1)[0]
        if count / total_choice > 0.5:
            problems.append(f"{name}: option {pos} keys {count} of {total_choice} single-choice items")
    need = int(data.get("min_practice_per_objective", 10))
    for code, qs in graded.items():
        if len(qs) < need:
            problems.append(f"{name}: objective {code} has {len(qs)} graded items, needs {need}")
    return problems


def main() -> int:
    files = sorted(PRACTICE.glob("*.yaml"))
    problems: list[str] = []
    count = 0
    for f in files:
        problems += check_file(f)
        count += len((yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("items") or [])
    for p in problems:
        print(f"ERROR: {p}")
    if problems:
        print(f"Practice items check FAILED: {len(problems)} problem(s).")
        return 1
    print(f"Practice items check PASS: {count} item(s) in {len(files)} file(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
