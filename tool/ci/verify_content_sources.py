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
5. Manifest source pins are real (ingestion plan D-6). A ``sha256`` must be
   64 lowercase hex characters, not a repeated or low-variety pattern, not
   a digest of a common word, and not shared with another source. A source
   without one records why in ``metadata.checksum_status`` (or is pinned by
   the importer's archive version); otherwise that is a warning.
6. Every manifest source release declares its operation in
   ``metadata.use`` (plan v1.2 §6, slice 5): a reference citation must not
   hide an adaptation, so there is no silent default. An undeclared release
   fails unless it is in data/rights_discrepancy_allowlist.json, tied to an
   open decision; an allowlist entry that no longer matches also fails, so
   the frozen list can only shrink. ``--publish-check <manifest>`` fails for
   a manifest that still has an allowlisted discrepancy (run before publishing).

Exit 0 when clean (warnings allowed), 1 on any problem.
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
REGISTRY = REPO / "data" / "content_sources.json"
ALLOWLIST = REPO / "data" / "rights_discrepancy_allowlist.json"
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


CHECKSUM_STATUSES = {"unverified_remote_document"}
# Digests of words people type when inventing a hash ("hello", "test", ...).
_COMMON_WORDS = ["", "hello", "test", "foo", "bar", "password", "example", "placeholder", "hash"]
_COMMON_DIGESTS = {
    hashlib.new(alg, w.encode()).hexdigest()[:16]
    for w in _COMMON_WORDS for alg in ("md5", "sha1", "sha256")
}
_SHARED_RUN = 20  # two real SHA-256 digests share a 20-hex-char run with negligible probability


def pin_problem(sha: str) -> str | None:
    """Why ``sha`` cannot be a real SHA-256 digest, or None if it could be."""
    if not re.fullmatch(r"[0-9a-f]{64}", sha):
        return "is not 64 lowercase hex characters"
    if len(set(sha)) < 10:
        return "uses too few distinct characters to be a real digest"
    if re.fullmatch(r"(.{1,16}?)\1+.{0,15}", sha):
        return "is a repeated pattern"
    if sha[:16] in _COMMON_DIGESTS:
        return "starts with the digest of a common word"
    return None


def check_pins(releases: list[tuple[str, dict]], problems: list[str], warnings: list[str]) -> None:
    """Rule 5: manifest pins must be real or explicitly absent (D-6)."""
    pinned: list[tuple[str, str, str]] = []
    for where, r in releases:
        meta = r.get("metadata") or {}
        label = r.get("id") or r.get("source_url") or r.get("title") or "?"
        sha = r.get("sha256")
        if sha:
            why = pin_problem(str(sha))
            if why:
                problems.append(f"{where}: sha256 for {label} {why}; recompute it from a retrieved copy "
                                f"or remove it and set metadata.checksum_status")
            else:
                pinned.append((where, label, str(sha)))
        elif meta.get("checksum_status") is not None:
            if meta["checksum_status"] not in CHECKSUM_STATUSES:
                problems.append(f"{where}: {label} checksum_status must be one of {sorted(CHECKSUM_STATUSES)}")
        elif not meta.get("imported_by"):
            warnings.append(f"{where}: {label} has no sha256 and no metadata.checksum_status")
    for i, (w1, l1, s1) in enumerate(pinned):
        for w2, l2, s2 in pinned[i + 1:]:
            if s1 == s2 and l1 == l2:
                continue  # the same source pinned in two manifests
            if any(s1[k:k + _SHARED_RUN] in s2 for k in range(len(s1) - _SHARED_RUN + 1)):
                problems.append(f"{w1} ({l1}) and {w2} ({l2}): sha256 values share a "
                                f"{_SHARED_RUN}-character run, so at least one is not real")


def load_allowlist(root: Path) -> list[dict]:
    path = root / "data" / "rights_discrepancy_allowlist.json"
    if not path.exists():
        return []
    return json.loads(path.read_text(encoding="utf-8")).get("entries") or []


def check_declared_uses(undeclared: set[tuple[str, str]], allowlist: list[dict],
                        problems: list[str]) -> None:
    """Rule 6: every manifest release declares metadata.use, unless frozen."""
    listed = set()
    for e in allowlist:
        key = (str(e.get("manifest")), str(e.get("release_id")))
        if e.get("issue") != "undeclared_use" or not str(e.get("open_decision") or "").strip():
            problems.append(f"rights allowlist: {key} needs issue 'undeclared_use' and an open_decision")
        listed.add(key)
        if key not in undeclared:
            problems.append(f"rights allowlist: {key[0]} / {key[1]} is no longer a discrepancy; "
                            "remove it from data/rights_discrepancy_allowlist.json")
    for manifest, release in sorted(undeclared - listed):
        problems.append(f"{manifest}: source release {release!r} must declare metadata.use "
                        "(link, reference, quote, adapt, redistribute or ai_transform)")


def scan(reg: dict, root: Path) -> tuple[list[str], list[str]]:
    problems: list[str] = []
    warnings: list[str] = []
    undeclared: set[tuple[str, str]] = set()
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
    all_releases: list[tuple[str, dict]] = []
    if manifests:
        import yaml  # only needed for manifests

        for path in manifests:
            data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
            releases = data.get("source_releases") or (
                [data["source_release"]] if data.get("source_release") else []
            )
            for s in releases:
                # Rule 6: the operation must be declared. An allowlisted,
                # undeclared release is still checked as a reference.
                declared = (s.get("metadata") or {}).get("use")
                if declared is None:
                    undeclared.add((Path(path).name, str(s.get("id"))))
                use = declared or "reference"
                check_use(reg, Path(path).name, s.get("source_url"), s.get("license"),
                          use, problems, warnings)
                all_releases.append((Path(path).name, s))
    check_pins(all_releases, problems, warnings)
    check_declared_uses(undeclared, load_allowlist(root), problems)
    return problems, warnings


def publish_check(root: Path, manifest: str) -> list[str]:
    """A manifest with a frozen rights discrepancy cannot be published."""
    name = Path(manifest).name
    return [f"{name}: cannot be published while {e.get('release_id')!r} has an open rights "
            f"question ({e.get('open_decision')})"
            for e in load_allowlist(root) if e.get("manifest") == name]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", type=Path, default=REPO)
    ap.add_argument("--publish-check", metavar="MANIFEST",
                    help="fail if this manifest still has an allowlisted rights discrepancy")
    args = ap.parse_args(argv)
    if args.publish_check:
        blocked = publish_check(args.root, args.publish_check)
        for b in blocked:
            print(f"ERROR: {b}")
        if blocked:
            return 1
        print(f"Publish rights check PASS: {Path(args.publish_check).name} has no open rights question.")
        return 0
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
