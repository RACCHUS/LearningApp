#!/usr/bin/env python3
"""Verbatim-overlap audit: a curriculum manifest's own text against open books.

Rights operations (ingestion plan v1.2 §6): before a manifest declares how it
uses a source (``metadata.use``: reference or adapt), measure how much of its
text is the source's text. The audit splits both into 8-word shingles
(lowercased words and numbers) and reports, per lesson and overall, the share
of the manifest's shingles found in each book and the longest matching run,
the distinct matched passages, and, with two books, shingles found only in the
second (for example text that exists only in a CC BY-NC-SA later edition).

A share near zero with short runs of standard terminology means the text is
independently written: declare ``reference``. Long runs or a material share
mean adapted text: declare ``adapt`` (only where the source allows it) and
attribute it. Read the matched passages before deciding; the numbers are
evidence, not the decision.

Usage:
  python tool/rights_overlap_audit.py clep_college_algebra.yaml \\
      9b08c294-057f-4201-9f48-5d6ad992740d@ebc5beb \\
      35d7cce2-48dd-4403-b6a5-e828cb5a17da@789b540 \\
      --cache build/rights_audit_cache --json build/rights_audit.json

Books are OpenStax archive ids with versions (``uuid@version``). Pages are
fetched from the pinned archive once and cached; nothing is redistributed.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.request
from pathlib import Path
from typing import Iterable, Iterator

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_open_content_index import ARCHIVE, plain  # noqa: E402

N = 8
USER_AGENT = "LearningApp-rights-audit/1 (+https://learningapp-2ed8a.web.app)"
# Fields that are not the manifest's own prose.
SKIP_FIELDS = frozenset({"citation", "source_url", "url", "slug", "concept_slugs",
                         "tags", "emoji", "id"})


def words(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", text.lower())


def shingles(ws: list[str], n: int = N) -> list[str]:
    return [" ".join(ws[i:i + n]) for i in range(len(ws) - n + 1)]


def manifest_strings(node, skip: frozenset[str] = SKIP_FIELDS) -> Iterator[str]:
    if isinstance(node, dict):
        for k, v in node.items():
            if k not in skip:
                yield from manifest_strings(v, skip)
    elif isinstance(node, list):
        for v in node:
            yield from manifest_strings(v, skip)
    elif isinstance(node, str):
        yield node


def matched_runs(ws: list[str], book: set[str], n: int = N) -> list[str]:
    """Maximal passages of ``ws`` whose every n-word window is in ``book``."""
    hits = [s in book for s in shingles(ws, n)]
    runs, i = [], 0
    while i < len(hits):
        if hits[i]:
            j = i
            while j + 1 < len(hits) and hits[j + 1]:
                j += 1
            runs.append(" ".join(ws[i:j + n]))
            i = j + 1
        else:
            i += 1
    return runs


def segments(manifest: dict) -> Iterator[tuple[str, str, list[str]]]:
    """(objective code, label, words) for every lesson, then for the rest of
    each objective (concepts, flashcards, descriptions), then stimuli."""
    for dom in manifest.get("domains", []):
        for obj in dom.get("objectives", []):
            for lesson in obj.get("lessons", []):
                yield obj.get("code", ""), "lesson: " + str(lesson.get("title", ""))[:60], \
                    words(" ".join(manifest_strings(lesson)))
            rest = {k: v for k, v in obj.items() if k != "lessons"}
            yield obj.get("code", ""), "objective text", words(" ".join(manifest_strings(rest)))
        yield dom.get("code", ""), "domain text", words(" ".join(
            manifest_strings({k: v for k, v in dom.items() if k != "objectives"})))
    yield "", "stimuli", words(" ".join(manifest_strings(manifest.get("stimuli") or [])))


def audit(manifest: dict, books: dict[str, set[str]]) -> dict:
    keys = list(books)
    rows, runs = [], {k: set() for k in keys}
    totals = {k: 0 for k in keys}
    all_count = 0
    later_only: set[str] = set()
    for code, label, ws in segments(manifest):
        sh = shingles(ws)
        if not sh:
            continue
        all_count += len(sh)
        row = {"code": code, "segment": label, "words": len(ws)}
        for k in keys:
            found = sum(1 for s in sh if s in books[k])
            totals[k] += found
            seg_runs = matched_runs(ws, books[k])
            runs[k].update(seg_runs)
            row[k] = {"share": round(found / len(sh), 4),
                      "longest_run_words": max((len(r.split()) for r in seg_runs), default=0)}
        if len(keys) == 2:
            later_only.update(s for s in sh if s in books[keys[1]] and s not in books[keys[0]])
        rows.append(row)
    return {
        "shingle_words": N,
        "manifest_shingles": all_count,
        "books": {k: {
            "matched_shingles": totals[k],
            "share": round(totals[k] / all_count, 4) if all_count else 0.0,
            "longest_run_words": max((len(r.split()) for r in runs[k]), default=0),
            "segments_with_share_over_10pct": sum(1 for r in rows if r[k]["share"] > 0.10),
            "matched_passages": sorted(runs[k], key=lambda r: (-len(r), r)),
        } for k in keys},
        "later_edition_only": ({"book": keys[1], "not_in": keys[0], "shingles": sorted(later_only)}
                               if len(keys) == 2 else None),
        "segments": rows,
    }


def _leaves(tree: dict) -> Iterable[dict]:
    for c in tree.get("contents", []):
        if "contents" in c:
            yield from _leaves(c)
        else:
            yield c


def fetch_book(book: str, cache: Path) -> tuple[dict, set[str]]:
    """Every page of an archive book as shingles, cached under ``cache``."""
    cache.mkdir(parents=True, exist_ok=True)

    def get(url: str) -> dict:
        f = cache / (re.sub(r"[^A-Za-z0-9]", "_", url)[-150:] + ".json")
        if f.exists():
            return json.loads(f.read_text(encoding="utf-8"))
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as r:
            body = json.load(r)
        f.write_text(json.dumps(body), encoding="utf-8")
        time.sleep(0.2)
        return body

    meta = get(f"{ARCHIVE}{book}.json")
    out: set[str] = set()
    pages = 0
    for leaf in _leaves(meta["tree"]):
        page = get(f"{ARCHIVE}{book}:{leaf['id'].split('@')[0]}.json")
        out.update(shingles(words(plain(page["content"]))))
        pages += 1
    info = {"title": meta.get("title"), "license": (meta.get("license") or {}).get("name"),
            "pages": pages, "archive": ARCHIVE}
    return info, out


def main(argv: list[str] | None = None) -> int:
    import yaml

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("manifest", help="file name under content/")
    ap.add_argument("books", nargs="+", help="archive book ids with versions (uuid@version)")
    ap.add_argument("--cache", type=Path, default=REPO / "build" / "rights_audit_cache")
    ap.add_argument("--json", type=Path, help="write the full result here")
    args = ap.parse_args(argv)
    manifest = yaml.safe_load((REPO / "content" / args.manifest).read_text(encoding="utf-8"))
    infos, shingle_sets = {}, {}
    for b in args.books:
        infos[b], shingle_sets[b] = fetch_book(b, args.cache)
    result = audit(manifest, shingle_sets)
    result["manifest"] = args.manifest
    for b, info in infos.items():
        result["books"][b].update(info)
    for b, r in result["books"].items():
        print(f"{b} ({r['title']}, {r['license']}): {r['matched_shingles']}/{result['manifest_shingles']} "
              f"shingles ({r['share']:.2%}), longest run {r['longest_run_words']} words, "
              f"{r['segments_with_share_over_10pct']} segments over 10%")
    if result["later_edition_only"]:
        print(f"only in {args.books[1]}: {len(result['later_edition_only']['shingles'])} shingles")
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
