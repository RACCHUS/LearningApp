"""Curriculum freshness check (master plan v2.6 §7.2, §8.7).

Compares the OpenStax book version each open-textbook manifest is pinned to
(content/open_*.yaml, source_releases[0].version) with the publisher's
current release (https://openstax.org/rex/release.json). With --report it
records each change as a `source_changed` curriculum refresh item, and with
--raise-due it raises `review_due` items for published versions past their
review-by date. Both use service-role RPCs from migration 20261122010000;
neither changes anything learners see.

    python tool/check_open_source_versions.py                  # report only
    python tool/check_open_source_versions.py --report --raise-due

--report/--raise-due need SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_open_content_index import BOOKS, USER_AGENT  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
RELEASE_URL = "https://openstax.org/rex/release.json"


def manifest_pins(root: Path = REPO) -> list[dict]:
    """Target slug, source id and pinned book version of each open manifest."""
    import yaml

    out = []
    for path in sorted(glob.glob(str(root / "content" / "open_*.yaml"))):
        data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
        releases = data.get("source_releases") or []
        if not releases:
            continue
        version = str(releases[0].get("version") or "").strip()
        out.append({
            "manifest": Path(path).name,
            "slug": (data.get("target") or {}).get("slug"),
            "source_id": releases[0].get("id"),
            "pin": version.split()[0].lower() if version else None,
        })
    return out


def compare(pins: list[dict], release: dict, books: list[dict] = BOOKS) -> list[dict]:
    """Each pin with the publisher's current version and whether it changed.

    A book the release no longer lists counts as changed ("missing")."""
    uuid_by_source = {b["source_id"]: b["book"].split("@")[0] for b in books}
    current_books = release.get("books") or {}
    rows = []
    for p in pins:
        uuid = uuid_by_source.get(p["source_id"])
        entry = current_books.get(uuid) if uuid else None
        current = (entry or {}).get("defaultVersion")
        current = current.lower() if isinstance(current, str) else "missing"
        rows.append({**p, "current": current, "changed": current != p["pin"]})
    return rows


def _rpc(name: str, payload: dict) -> object:
    url = os.environ["SUPABASE_URL"].rstrip("/") + f"/rest/v1/rpc/{name}"
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode(), method="POST",
        headers={"apikey": key, "Authorization": f"Bearer {key}",
                 "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read() or b"null")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--report", action="store_true", help="record source changes as refresh items")
    ap.add_argument("--raise-due", action="store_true", help="raise review_due items")
    args = ap.parse_args(argv)

    req = urllib.request.Request(RELEASE_URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        release = json.loads(resp.read())

    rows = compare(manifest_pins(), release)
    for r in rows:
        state = "CHANGED" if r["changed"] else "current"
        print(f"{r['manifest']}: pinned {r['pin']}, publisher {r['current']} -> {state}")

    if args.report:
        for r in rows:
            if r["changed"] and r["slug"]:
                raised = _rpc("report_curriculum_source_change",
                              {"p_target_slug": r["slug"], "p_current_release": r["current"]})
                print(f"  raised {raised} source_changed item(s) for {r['slug']}")
    if args.raise_due:
        print(f"review_due items raised: {_rpc('raise_due_curriculum_refresh_items', {})}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
