#!/usr/bin/env python3
"""Check outside-source use against data/content_sources.json.

Runbook: docs/content_intelligence/CONTENT_INGESTION_RUNBOOK.md.

1. The registry is well formed: known license ids, every source's
   allowed_uses within its license's max_uses, evidence recorded.
2. Every source cited by a Bridge, a companion or a curriculum manifest is
   in the registry (matched by URL prefix).
3. The use each file makes of a source is allowed. Bridges and companions
   declare it in ``rights_posture``; manifests use sources as alignment
   references. Uses beyond link/reference also need status "approved".
4. The license a file states matches the registry. A known mismatch that
   the owner still has to decide is recorded as the source's ``open_issue``
   and reported as a warning instead of a failure.

Exit 0 when clean (warnings allowed), 1 on any problem.
"""
from __future__ import annotations

import argparse
import glob
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
REGISTRY = REPO / "data" / "content_sources.json"
USES = {"link", "reference", "quote", "adapt", "redistribute", "ai_transform"}
STATUSES = {"approved", "proposed", "candidate", "restricted"}
POSTURE_TO_USE = {
    "link_only": "link",
    "reference": "reference",
    "may_quote": "quote",
    "may_adapt": "adapt",
    "may_redistribute": "redistribute",
}


def normalize_license(text: str | None) -> str:
    """Maps a free-text license statement to a registry license id."""
    t = (text or "").lower()
    if re.search(r"by-nc-sa|noncommercial-sharealike|non-commercial-sharealike", t):
        return "cc_by_nc_sa_4"
    if re.search(r"by-sa|attribution-sharealike", t):
        return "cc_by_sa_4"
    if re.search(r"cc by 4\.0|attribution 4\.0|\(cc by\b", t):
        return "cc_by_4"
    if "public domain" in t:
        return "public_domain_us_gov"
    if re.search(r"proprietary|copyright|all rights reserved", t):
        return "proprietary"
    return "unknown"


def validate_registry(reg: dict) -> list[str]:
    problems: list[str] = []
    licenses = reg.get("licenses") or {}
    if set(reg.get("uses") or {}) != USES:
        problems.append(f"registry 'uses' must define exactly {sorted(USES)}")
    for lid, lic in licenses.items():
        extra = set(lic.get("max_uses", [])) - USES
        if extra:
            problems.append(f"license {lid}: unknown uses {sorted(extra)}")
    seen: set[str] = set()
    prefixes: dict[str, str] = {}
    for s in reg.get("sources") or []:
        sid = s.get("id", "?")
        if sid in seen:
            problems.append(f"duplicate source id {sid}")
        seen.add(sid)
        lic = licenses.get(s.get("license"))
        if lic is None:
            problems.append(f"{sid}: unknown license '{s.get('license')}'")
            continue
        allowed = set(s.get("allowed_uses") or [])
        if not allowed:
            problems.append(f"{sid}: allowed_uses is empty")
        beyond = allowed - set(lic["max_uses"])
        if beyond:
            problems.append(f"{sid}: allowed_uses {sorted(beyond)} exceed what {s['license']} permits")
        if "ai_transform" in allowed and "adapt" not in allowed:
            problems.append(f"{sid}: ai_transform needs adapt")
        if s.get("status") not in STATUSES:
            problems.append(f"{sid}: status must be one of {sorted(STATUSES)}")
        ev = s.get("license_evidence") or {}
        if not ev.get("url", "").startswith("https://") or not re.match(
            r"^\d{4}-\d{2}-\d{2}$", ev.get("checked_at", "")
        ) or not ev.get("statement"):
            problems.append(f"{sid}: license_evidence needs an https url, checked_at (YYYY-MM-DD) and statement")
        if lic.get("attribution_required") and not s.get("attribution"):
            problems.append(f"{sid}: attribution template required by {s['license']}")
        for p in s.get("url_prefixes") or []:
            if not p.startswith("https://"):
                problems.append(f"{sid}: url prefix must be https: {p}")
            if p in prefixes:
                problems.append(f"{sid}: url prefix {p} already used by {prefixes[p]}")
            prefixes[p] = sid
        if not s.get("url_prefixes"):
            problems.append(f"{sid}: needs at least one url prefix")
    return problems


def find_source(reg: dict, url: str | None) -> dict | None:
    """Longest matching prefix wins, so 'college-algebra-2e/' beats
    'college-algebra/'."""
    if not url:
        return None
    best, best_len = None, -1
    for s in reg.get("sources") or []:
        for p in s.get("url_prefixes") or []:
            if url.startswith(p) and len(p) > best_len:
                best, best_len = s, len(p)
    return best


def check_use(
    reg: dict, where: str, url: str | None, license_text: str | None, use: str,
    problems: list[str], warnings: list[str],
) -> None:
    source = find_source(reg, url)
    if source is None:
        problems.append(f"{where}: source {url!r} is not in data/content_sources.json")
        return
    sid = source["id"]
    if use not in USES:
        problems.append(f"{where}: unknown use '{use}' for {sid}")
        return
    if use not in source.get("allowed_uses", []):
        problems.append(f"{where}: {sid} does not allow '{use}' (allowed: {source.get('allowed_uses')})")
    elif use not in {"link", "reference"} and source.get("status") != "approved":
        problems.append(f"{where}: '{use}' of {sid} needs the owner's approval (status is {source.get('status')})")
    if license_text is not None:
        stated = normalize_license(license_text)
        if stated != source["license"]:
            msg = (f"{where}: states license {stated} for {sid}, "
                   f"registry says {source['license']}")
            if source.get("open_issue"):
                warnings.append(f"{msg} (open issue: owner decision pending)")
            else:
                problems.append(msg)


def scan(reg: dict, root: Path) -> tuple[list[str], list[str]]:
    problems: list[str] = []
    warnings: list[str] = []
    for path in sorted(glob.glob(str(root / "content" / "bridges" / "*.json"))):
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        for s in data.get("sources") or []:
            use = POSTURE_TO_USE.get(s.get("rights_posture"), s.get("rights_posture") or "?")
            check_use(reg, Path(path).name, s.get("url"), s.get("license"), use, problems, warnings)
    for path in sorted(glob.glob(str(root / "content" / "companions" / "*.json"))):
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        r = data.get("resource") or {}
        use = POSTURE_TO_USE.get(r.get("rights_posture"), r.get("rights_posture") or "?")
        check_use(reg, Path(path).name, r.get("url"), r.get("license"), use, problems, warnings)
    manifests = sorted(glob.glob(str(root / "content" / "*.yaml")))
    if manifests:
        import yaml  # only needed for manifests

        for path in manifests:
            data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
            releases = data.get("source_releases") or (
                [data["source_release"]] if data.get("source_release") else []
            )
            for s in releases:
                # A manifest uses its sources as alignment references unless
                # it declares otherwise (imported open textbooks: "adapt").
                use = (s.get("metadata") or {}).get("use", "reference")
                check_use(reg, Path(path).name, s.get("source_url"), s.get("license"),
                          use, problems, warnings)
    return problems, warnings


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", type=Path, default=REPO)
    args = ap.parse_args(argv)
    reg = json.loads((args.root / "data" / "content_sources.json").read_text(encoding="utf-8"))
    problems = validate_registry(reg)
    found, warnings = scan(reg, args.root)
    problems += found
    for w in warnings:
        print(f"WARNING: {w}")
    for p in problems:
        print(f"ERROR: {p}")
    if problems:
        print(f"Content sources check FAILED: {len(problems)} problem(s).")
        return 1
    print(f"Content sources check PASS: {len(reg['sources'])} registered sources, "
          f"{len(warnings)} open owner decision(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
