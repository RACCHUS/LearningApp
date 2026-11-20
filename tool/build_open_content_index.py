#!/usr/bin/env python3
"""Build the open content index: every section of the approved open books,
with its link and key terms, so the app can offer existing open content
before anyone generates new content with AI (master plan v2.6 §4.3 steps
3-4; runbook docs/content_intelligence/CONTENT_INGESTION_RUNBOOK.md).

Run by a maintainer when books are added or updated (needs network):

    python tool/build_open_content_index.py            # writes assets/open_content/index.json
    python tool/build_open_content_index.py --check    # offline: validate the committed index

Only sources registered in data/content_sources.json that allow at least
"link" are indexed, and the license each book reports in the OpenStax
archive must match the registry, or the build stops.
"""
from __future__ import annotations

import argparse
import html
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "assets" / "open_content" / "index.json"
REGISTRY = REPO / "data" / "content_sources.json"
ARCHIVE = "https://openstax.org/apps/archive/20260604.144757/contents/"
USER_AGENT = "LearningApp-open-content-index/1 (+https://learningapp-2ed8a.web.app)"

# Pinned book versions (read 2026-11-20). Update deliberately, then rebuild.
BOOKS = [
    {"source_id": "openstax-college-algebra-1e", "slug": "college-algebra",
     "book": "9b08c294-057f-4201-9f48-5d6ad992740d@ebc5beb", "subject": "algebra math"},
    {"source_id": "openstax-prealgebra-1e", "slug": "prealgebra",
     "book": "caa57dab-41c7-455e-bd6f-f443cda5519c@eb2e29d", "subject": "prealgebra math arithmetic"},
    {"source_id": "openstax-psychology-1e", "slug": "psychology",
     "book": "4abf04bf-93a0-45c3-9cbc-2cefd46e68cc@8993bfc", "subject": "psychology"},
]

ARCHIVE_LICENSE = {
    "Creative Commons Attribution License": "cc_by_4",
    "Creative Commons Attribution-ShareAlike License": "cc_by_sa_4",
    "Creative Commons Attribution-NonCommercial-ShareAlike License": "cc_by_nc_sa_4",
}

SKIP_TITLES = re.compile(
    r"^(preface|index|introduction to|chapter review|key terms|key equations|"
    r"key concepts|exercises|review exercises|practice test|answer key|summary|"
    r"review questions|critical thinking|personal application)", re.I)


def plain(markup: str) -> str:
    """Section titles come as HTML spans; keep readable text only."""
    text = re.sub(r"<[^>]+>", " ", markup or "")
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def split_number(title: str) -> tuple[str, str]:
    m = re.match(r"^(\d+(?:\.\d+)*)\s+(.*)$", title)
    return (m.group(1), m.group(2)) if m else ("", title)


def sections(tree: dict, chapter: str = "") -> list[dict]:
    """Leaf pages that teach something, with their chapter title."""
    out = []
    for node in tree.get("contents") or []:
        title = plain(node.get("title", ""))
        if node.get("contents"):
            _, chapter_title = split_number(re.sub(r"^Chapter\s+", "", title))
            out += sections(node, chapter_title or title)
            continue
        number, name = split_number(title)
        if not number or SKIP_TITLES.match(name):
            continue
        out.append({
            "page": (node.get("id") or "").split("@")[0],
            "slug": node.get("slug", ""),
            "number": number,
            "title": name,
            "chapter": chapter,
        })
    return out


def key_terms(content: str, limit: int = 12) -> list[str]:
    """Terms the section itself marks as defined (data-type="term")."""
    found = []
    pattern = r'<(\w+)\b[^>]*data-type="term"[^>]*>(.*?)</\1>'
    for _, raw in re.findall(pattern, content or "", re.S):
        term = plain(raw).lower()
        if 2 < len(term) <= 40 and term not in found:
            found.append(term)
        if len(found) >= limit:
            break
    return found


def fetch(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def build(delay: float) -> dict:
    registry = {s["id"]: s for s in json.loads(REGISTRY.read_text(encoding="utf-8"))["sources"]}
    entries = []
    for book in BOOKS:
        source = registry.get(book["source_id"])
        if source is None or "link" not in source["allowed_uses"]:
            raise SystemExit(f"{book['source_id']} is not registered for link use")
        meta = fetch(f"{ARCHIVE}{book['book']}.json")
        reported = ARCHIVE_LICENSE.get((meta.get("license") or {}).get("name", ""), "unknown")
        if reported != source["license"]:
            raise SystemExit(
                f"{book['source_id']}: archive reports {reported}, registry says "
                f"{source['license']}; update the registry first")
        for sec in sections(meta["tree"]):
            page = fetch(f"{ARCHIVE}{book['book']}:{sec['page']}.json")
            time.sleep(delay)
            entries.append({
                "source_id": book["source_id"],
                "book": meta.get("title", ""),
                "number": sec["number"],
                "title": sec["title"],
                "chapter": sec["chapter"],
                "subject": book["subject"],
                "url": f"https://openstax.org/books/{book['slug']}/pages/{sec['slug']}",
                "key_terms": key_terms(page.get("content", "")),
            })
        print(f"{book['source_id']}: {sum(1 for e in entries if e['source_id'] == book['source_id'])} sections")
    return {
        "schema_version": 1,
        "built_from": ARCHIVE,
        "note": "Generated by tool/build_open_content_index.py. Do not edit by hand.",
        "sections": entries,
    }


def check(index: dict) -> list[str]:
    registry = {s["id"]: s for s in json.loads(REGISTRY.read_text(encoding="utf-8"))["sources"]}
    problems = []
    seen = set()
    for i, e in enumerate(index.get("sections") or []):
        where = f"sections[{i}]"
        for field in ("source_id", "number", "title", "url"):
            if not e.get(field):
                problems.append(f"{where}: missing {field}")
        src = registry.get(e.get("source_id"))
        if src is None:
            problems.append(f"{where}: source {e.get('source_id')} is not registered")
            continue
        if "link" not in src["allowed_uses"]:
            problems.append(f"{where}: {src['id']} does not allow link")
        if not any(e.get("url", "").startswith(p) for p in src["url_prefixes"]):
            problems.append(f"{where}: url is outside {src['id']}'s registered prefixes")
        if e.get("url") in seen:
            problems.append(f"{where}: duplicate url {e.get('url')}")
        seen.add(e.get("url"))
    if not index.get("sections"):
        problems.append("index has no sections")
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="validate the committed index offline")
    ap.add_argument("--delay", type=float, default=0.3, help="seconds between page requests")
    args = ap.parse_args(argv)
    if args.check:
        problems = check(json.loads(OUT.read_text(encoding="utf-8")))
        for p in problems:
            print(f"ERROR: {p}")
        print("Open content index check " + ("FAILED" if problems else "PASS"))
        return 1 if problems else 0
    index = build(args.delay)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(index, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(REPO)} ({len(index['sections'])} sections)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
