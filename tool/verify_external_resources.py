#!/usr/bin/env python3
"""Check the outside-resource catalog and its objective maps (companion plan
v1.0 §3.3-§3.5, §7.2; contracts fixed by EX-0).

``data/external_resources/<id>.yaml`` is one catalog resource: a link-only
record of something that stays outside LearningApp (a course, video, book).
``data/resource_maps/<target_slug>__<resource_id>.yaml`` says which objectives
of one target the resource covers. The check is offline:

1. Resource fields: id equals the file name; kind, access and rights posture
   are known values; links are https; unknown facts are null, never guessed;
   a paid resource states a price band and the date it was checked; an embed
   is allowed only with a provider and the terms that allow it; every stated
   fact has an https source; targets are slugs of manifests in content/.
2. Review: status is pending, approved or changes_required; an approved
   review names its reviewer kind (and model, for AI) and date.
3. Ranking isolation (§3.5): no field anywhere may carry a paid placement,
   affiliate or ranking value, and no personal fields.
4. Maps: the file name matches its target and resource; every objective of
   the target is listed exactly once, either with sections or as not
   covered; depth, practice and confidence are known values.

A map never grants a rights use and never counts as evidence of learning.
"""
from __future__ import annotations

import re
import sys
from datetime import date
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
RESOURCES = REPO / "data" / "external_resources"
MAPS = REPO / "data" / "resource_maps"
CONTENT = REPO / "content"

KIND = {"video", "video_series", "course", "book", "article", "podcast", "class", "other"}
ACCESS = {"free_no_login", "free_with_login", "paid"}
RIGHTS = {"link_only"}
PRICE_BAND = {"under_25", "25_to_100", "100_to_500", "over_500", "subscription"}
REVIEW = {"pending", "approved", "changes_required"}
DEPTH = {"introduces", "teaches", "practises"}
CONFIDENCE = {"high", "medium", "low"}
TRI = (True, False, None)
ID = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
# §3.5: the learner's benefit is the only ranking input, so the data may not
# carry anything a paid placement could ride on. Personal fields as in
# verify_research.py.
FORBIDDEN = re.compile(
    r"(sponsor|affiliat|commission|placement|promot|boost|featured|rank|priority"
    r"|email|user_id|ip_address|phone)",
    re.IGNORECASE,
)


def _https(v) -> bool:
    return isinstance(v, str) and v.startswith("https://") and len(v) > len("https://")


def _date(v) -> date | None:
    try:
        return date.fromisoformat(str(v))
    except ValueError:
        return None


def _forbidden_keys(node, path="") -> list[str]:
    out = []
    if isinstance(node, dict):
        for k, v in node.items():
            here = f"{path}.{k}" if path else str(k)
            if FORBIDDEN.search(str(k)):
                out.append(here)
            out += _forbidden_keys(v, here)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            out += _forbidden_keys(v, f"{path}[{i}]")
    return out


def _review(doc: dict, name: str) -> list[str]:
    p = []
    review = doc.get("review") or {}
    status = review.get("status")
    if status not in REVIEW:
        p.append(f"{name}: review.status must be one of {sorted(REVIEW)}")
    if status == "approved":
        if review.get("reviewer_kind") not in ("ai", "human"):
            p.append(f"{name}: an approved review needs reviewer_kind ai or human")
        if review.get("reviewer_kind") == "ai" and not str(review.get("reviewer_model") or "").strip():
            p.append(f"{name}: an AI review needs reviewer_model")
        reviewed = _date(review.get("reviewed_on"))
        if reviewed is None:
            p.append(f"{name}: an approved review needs reviewed_on (YYYY-MM-DD)")
        elif reviewed > date.today():
            p.append(f"{name}: review.reviewed_on is in the future")
    if not str(doc.get("authored_by") or "").strip():
        p.append(f"{name}: authored_by is required")
    return p


def target_slugs(content_dir: Path = CONTENT) -> dict[str, Path]:
    """Target slug -> manifest path, for every manifest in content/."""
    out = {}
    for path in sorted(content_dir.glob("*.yaml")):
        slug = ((yaml.safe_load(path.read_text(encoding="utf-8")) or {}).get("target") or {}).get("slug")
        if slug:
            out[str(slug)] = path
    return out


def check_resource(path: Path, slugs: dict[str, Path]) -> list[str]:
    name = path.name
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        return [f"{name}: not valid YAML ({e})"]
    p = [f"{name}: field {k} is not allowed (ranking isolation and no personal data)"
         for k in _forbidden_keys(doc)]
    rid = doc.get("id")
    if not isinstance(rid, str) or not ID.fullmatch(rid) or rid != path.stem:
        p.append(f"{name}: id must be lowercase-with-hyphens and equal the file name")
    for key in ("publisher", "title", "locale"):
        if not str(doc.get(key) or "").strip():
            p.append(f"{name}: {key} is required")
    if doc.get("kind") not in KIND:
        p.append(f"{name}: kind must be one of {sorted(KIND)}")
    url = doc.get("canonical_url")
    if url is not None and not _https(url):
        p.append(f"{name}: canonical_url must be an https URL, or null for a resource with no link")
    if doc.get("rights_posture") not in RIGHTS:
        p.append(f"{name}: rights_posture must be link_only (a catalog record grants no reuse)")
    checked = _date(doc.get("metadata_checked_at"))
    if checked is None or checked > date.today():
        p.append(f"{name}: metadata_checked_at must be a past or present date (YYYY-MM-DD)")

    access = doc.get("access")
    if access not in ACCESS:
        p.append(f"{name}: access must be one of {sorted(ACCESS)}")
    price = doc.get("price")
    if access == "paid":
        if not isinstance(price, dict) or price.get("band") not in PRICE_BAND:
            p.append(f"{name}: a paid resource needs price.band, one of {sorted(PRICE_BAND)}")
        elif not re.fullmatch(r"[A-Z]{3}", str(price.get("currency") or "")) or _date(price.get("checked_at")) is None:
            p.append(f"{name}: price needs a 3-letter currency and checked_at (YYYY-MM-DD)")
    elif price is not None:
        p.append(f"{name}: price must be null unless access is paid")

    embed = doc.get("embed")
    if not isinstance(embed, dict) or embed.get("allowed") not in (True, False):
        p.append(f"{name}: embed.allowed must be true or false")
    elif embed["allowed"] and not (str(embed.get("provider") or "").strip() and _https(embed.get("terms_url"))):
        p.append(f"{name}: an allowed embed needs embed.provider and an https embed.terms_url")

    for key in ("has_practice", "captions", "transcript"):
        if doc.get(key) not in TRI:
            p.append(f"{name}: {key} must be true, false or null (unknown)")
    hours = doc.get("stated_length_hours")
    if hours is not None and (isinstance(hours, bool) or not isinstance(hours, (int, float)) or hours <= 0):
        p.append(f"{name}: stated_length_hours must be a positive number or null")

    facts = doc.get("facts") or []
    if not facts:
        p.append(f"{name}: at least one sourced fact is required")
    for i, f in enumerate(facts):
        if not isinstance(f, dict) or not str(f.get("claim") or "").strip() or not _https(f.get("source_url")):
            p.append(f"{name}: facts[{i}] needs a claim and an https source_url")

    targets = doc.get("targets") or []
    if not targets:
        p.append(f"{name}: targets must name at least one target slug")
    for t in targets:
        if t not in slugs:
            p.append(f"{name}: target {t!r} is not the slug of a manifest in content/")
    return p + _review(doc, name)


def _objectives(manifest: dict) -> list[str]:
    return [str(o["code"]) for d in manifest.get("domains", []) for o in d.get("objectives", [])]


def check_map(path: Path, slugs: dict[str, Path], resources: dict[str, dict]) -> list[str]:
    name = path.name
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        return [f"{name}: not valid YAML ({e})"]
    p = [f"{name}: field {k} is not allowed (ranking isolation and no personal data)"
         for k in _forbidden_keys(doc)]
    slug, rid = doc.get("target_slug"), doc.get("resource_id")
    if path.stem != f"{slug}__{rid}":
        p.append(f"{name}: file name must be <target_slug>__<resource_id>.yaml")
    if rid not in resources:
        p.append(f"{name}: resource_id {rid!r} is not in data/external_resources/")
    elif slug not in (resources[rid].get("targets") or []):
        p.append(f"{name}: resource {rid} does not list target {slug}")
    if slug not in slugs:
        return p + [f"{name}: target_slug {slug!r} is not the slug of a manifest in content/"]
    if not str(doc.get("method") or "").strip():
        p.append(f"{name}: method is required (how the map was made, from public facts only)")
    objectives = _objectives(yaml.safe_load(slugs[slug].read_text(encoding="utf-8")) or {})

    seen: set[str] = set()
    for entry in doc.get("coverage") or []:
        code = str(entry.get("objective"))
        where = f"{name}: objective {code}"
        if code not in objectives:
            p.append(f"{where} is not an objective of {slugs[slug].name}")
        if code in seen:
            p.append(f"{where} is listed twice")
        seen.add(code)
        sections = entry.get("sections") or []
        covered = entry.get("covered")
        if covered not in (True, False):
            p.append(f"{where}: covered must be true or false")
        elif covered != bool(sections):
            p.append(f"{where}: covered must be true with sections, false with none")
        for i, s in enumerate(sections):
            w = f"{where} section {i + 1}"
            if not str(s.get("label") or "").strip():
                p.append(f"{w}: label is required")
            if s.get("locator") is not None and not _https(s.get("locator")):
                p.append(f"{w}: locator must be an https URL or null")
            if s.get("depth") not in DEPTH:
                p.append(f"{w}: depth must be one of {sorted(DEPTH)}")
            if s.get("has_practice") not in TRI:
                p.append(f"{w}: has_practice must be true, false or null (unknown)")
            if s.get("confidence") not in CONFIDENCE:
                p.append(f"{w}: confidence must be one of {sorted(CONFIDENCE)}")
            start, end = s.get("start_seconds"), s.get("end_seconds")
            if (start is None) != (end is None) or (
                    start is not None and not (isinstance(start, int) and isinstance(end, int) and 0 <= start < end)):
                p.append(f"{w}: start_seconds and end_seconds must both be null, or whole numbers with start < end")
    for code in objectives:
        if code not in seen:
            p.append(f"{name}: objective {code} of {slugs[slug].name} is not listed (use covered: false)")
    return p + _review(doc, name)


def check_all(resources_dir: Path = RESOURCES, maps_dir: Path = MAPS, content_dir: Path = CONTENT) -> tuple[list[str], int, int]:
    slugs = target_slugs(content_dir)
    problems: list[str] = []
    resources: dict[str, dict] = {}
    resource_files = sorted(resources_dir.glob("*.yaml"))
    for path in resource_files:
        problems += check_resource(path, slugs)
        try:
            resources[path.stem] = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except yaml.YAMLError:
            pass
    map_files = sorted(maps_dir.glob("*.yaml"))
    for path in map_files:
        problems += check_map(path, slugs, resources)
    return problems, len(resource_files), len(map_files)


def main() -> int:
    problems, n_resources, n_maps = check_all()
    for x in problems:
        print(f"ERROR: {x}")
    if problems:
        return 1
    print(f"External resources check PASS: {n_resources} resource(s), {n_maps} map(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
