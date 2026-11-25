#!/usr/bin/env python3
"""Check reviewed objective-to-source mappings (ingestion plan v1.2 §8.1).

Each ``data/concept_mappings/*.yaml`` maps one manifest's objectives to the
sections of an open source that teach them (D-13: reconcile CLEP College
Algebra with the imported textbook). The check is offline:

1. Fields: match is exact, partial, prerequisite, supplementary or unrelated;
   depth is same, source_deeper or source_shallower; roles are teach,
   example, practice or check; confidence is high, medium or low; locators
   are https; review status is pending, approved or changes_required, and
   an approved review names its reviewer kind (and model, for AI) and date.
2. Coverage: every objective of the mapped manifest is mapped, and every
   mapped objective exists.
3. Citations agree: each ``Section X.Y[: Title]`` an objective cites is in
   its mapping, with the same title.
4. Imported sections agree: a section marked imported_in_learningapp is an
   objective of the imported manifest with the same title.

``--publish-check <manifest>`` fails when a mapping of that manifest is not
approved (the ingestion workflow runs it before writing).
"""
from __future__ import annotations

import argparse
import re
import sys
from datetime import date
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
MAPPINGS = REPO / "data" / "concept_mappings"
CONTENT = REPO / "content"

MATCH = {"exact", "partial", "prerequisite", "supplementary", "unrelated"}
DEPTH = {"same", "source_deeper", "source_shallower"}
ROLES = {"teach", "example", "practice", "check"}
CONFIDENCE = {"high", "medium", "low"}
REVIEW = {"pending", "approved", "changes_required"}
CITED = re.compile(r"Section (\d+\.\d+)(?::\s*([^;(]+?))?\s*(?:;|\(|$)")


def _title(s: str) -> str:
    return re.sub(r"\s+", " ", s or "").strip().rstrip(".").lower()


def _objectives(manifest: dict) -> dict[str, dict]:
    return {str(o["code"]): o for d in manifest.get("domains", []) for o in d.get("objectives", [])}


def check_file(path: Path, content_dir: Path = CONTENT) -> list[str]:
    name = path.name
    p: list[str] = []
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        return [f"{name}: not valid YAML ({e})"]
    src = (doc.get("from") or {}).get("manifest")
    if not src or not (content_dir / src).exists():
        return [f"{name}: from.manifest must name a file in content/"]
    objectives = _objectives(yaml.safe_load((content_dir / src).read_text(encoding="utf-8")))
    imported_name = (doc.get("to") or {}).get("imported_manifest")
    imported = {}
    if imported_name:
        if not (content_dir / imported_name).exists():
            p.append(f"{name}: to.imported_manifest {imported_name} is not in content/")
        else:
            imported = _objectives(yaml.safe_load((content_dir / imported_name).read_text(encoding="utf-8")))

    review = doc.get("review") or {}
    status = review.get("status")
    if status not in REVIEW:
        p.append(f"{name}: review.status must be one of {sorted(REVIEW)}")
    if status == "approved":
        if review.get("reviewer_kind") not in ("ai", "human"):
            p.append(f"{name}: an approved review needs reviewer_kind ai or human")
        if review.get("reviewer_kind") == "ai" and not str(review.get("reviewer_model") or "").strip():
            p.append(f"{name}: an AI review needs reviewer_model")
        try:
            if date.fromisoformat(str(review.get("reviewed_on"))) > date.today():
                p.append(f"{name}: review.reviewed_on is in the future")
        except ValueError:
            p.append(f"{name}: an approved review needs reviewed_on (YYYY-MM-DD)")

    mapped: dict[str, dict[str, dict]] = {}
    for i, m in enumerate(doc.get("mappings") or []):
        code = str(m.get("objective"))
        where = f"{name}: objective {code}"
        if code not in objectives:
            p.append(f"{where} is not an objective of {src}")
        if code in mapped:
            p.append(f"{where} is mapped twice")
        sections = mapped.setdefault(code, {})
        if not m.get("sections"):
            p.append(f"{where} has no sections")
        for s in m.get("sections") or []:
            sec = str(s.get("section"))
            w = f"{where} section {sec}"
            if not re.fullmatch(r"\d+\.\d+", sec):
                p.append(f"{w}: section must look like 2.7")
            if sec in sections:
                p.append(f"{w} is listed twice")
            sections[sec] = s
            if not str(s.get("title") or "").strip():
                p.append(f"{w}: title is required")
            if s.get("match") not in MATCH:
                p.append(f"{w}: match must be one of {sorted(MATCH)}")
            if s.get("depth") not in DEPTH:
                p.append(f"{w}: depth must be one of {sorted(DEPTH)}")
            roles = s.get("roles") or []
            if not roles or any(r not in ROLES for r in roles):
                p.append(f"{w}: roles must be a non-empty subset of {sorted(ROLES)}")
            if s.get("confidence") not in CONFIDENCE:
                p.append(f"{w}: confidence must be one of {sorted(CONFIDENCE)}")
            if not str(s.get("locator") or "").startswith("https://"):
                p.append(f"{w}: locator must be an https URL")
            if s.get("imported_in_learningapp") is True:
                obj = imported.get(sec)
                if obj is None:
                    p.append(f"{w}: marked imported, but {imported_name} has no objective {sec}")
                elif _title(obj.get("title")) != _title(s.get("title")):
                    p.append(f"{w}: title {s.get('title')!r} differs from the imported "
                             f"objective {obj.get('title')!r}")
            elif s.get("imported_in_learningapp") is not False:
                p.append(f"{w}: imported_in_learningapp must be true or false")

    for code, obj in objectives.items():
        if code not in mapped:
            p.append(f"{name}: objective {code} of {src} is not mapped")
            continue
        for sec, cited_title in CITED.findall(str(obj.get("citation") or "")):
            s = mapped[code].get(sec)
            if s is None:
                p.append(f"{name}: objective {code} cites section {sec}, which its mapping lacks")
            elif cited_title.strip() and _title(cited_title) != _title(s.get("title")):
                p.append(f"{name}: objective {code} cites section {sec} as {cited_title.strip()!r}, "
                         f"but it is {s.get('title')!r}")
    return p


def publish_check(manifest: str, mappings_dir: Path = MAPPINGS) -> list[str]:
    """Problems that block publishing ``manifest`` (a file name in content/)."""
    out = []
    for path in sorted(mappings_dir.glob("*.yaml")):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        if (doc.get("from") or {}).get("manifest") == Path(manifest).name:
            status = (doc.get("review") or {}).get("status")
            if status != "approved":
                out.append(f"{path.name}: the source mapping for {Path(manifest).name} is {status}, "
                           "not approved (plan v1.2 §8.1: reviewed mappings for high-stakes use)")
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--publish-check", metavar="MANIFEST", help="fail if this manifest's mapping is not approved")
    args = ap.parse_args(argv)
    if args.publish_check:
        problems = publish_check(args.publish_check)
        for x in problems:
            print(f"ERROR: {x}")
        if not problems:
            print(f"Source mapping check PASS: {Path(args.publish_check).name} has no unreviewed mapping.")
        return 1 if problems else 0
    problems: list[str] = []
    files = sorted(MAPPINGS.glob("*.yaml"))
    for path in files:
        problems += check_file(path)
    for x in problems:
        print(f"ERROR: {x}")
    if problems:
        return 1
    print(f"Concept mappings check PASS: {len(files)} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
