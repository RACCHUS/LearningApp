#!/usr/bin/env python3
"""Bundle the outside-resource catalog for the app (companion plan v1.0
EX-5): data/external_resources/*.yaml and data/resource_maps/*.yaml become
assets/companion/resource_catalog.json.

Every record and map goes in, with its review status. The app shows a
resource as a recommendation only when both its record and its map for the
goal are approved; that rule lives in the app and is tested there.

No ranking field is carried: tool/verify_external_resources.py already
refuses any key that could hold a paid placement, and this script copies
only the fields listed below.

    python tool/build_resource_catalog.py           # write the asset
    python tool/build_resource_catalog.py --check   # CI: fail if out of date
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "data" / "external_resources"
MAPS = ROOT / "data" / "resource_maps"
OUT = ROOT / "assets" / "companion" / "resource_catalog.json"

RECORD_FIELDS = (
    "id", "kind", "publisher", "title", "canonical_url", "locale", "edition_or_published", "access",
    "price", "has_practice", "captions", "transcript", "stated_length_hours", "targets",
    "metadata_checked_at",
)
SECTION_FIELDS = ("label", "locator", "start_seconds", "end_seconds", "depth", "has_practice", "confidence")


def _review(doc: dict) -> dict:
    r = doc.get("review") or {}
    return {k: r.get(k) for k in ("status", "reviewer_kind", "reviewer_model", "reviewed_on") if r.get(k) is not None}


def _plain(v):
    return v.isoformat() if hasattr(v, "isoformat") else v


def build() -> str:
    resources = []
    for path in sorted(RESOURCES.glob("*.yaml")):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        rec = {k: _plain(doc.get(k)) for k in RECORD_FIELDS}
        rec["review"] = _review(doc)
        resources.append(rec)
    maps = []
    for path in sorted(MAPS.glob("*.yaml")):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        maps.append({
            "target_slug": doc.get("target_slug"),
            "resource_id": doc.get("resource_id"),
            "review": _review(doc),
            "coverage": [
                {
                    "objective": str(c.get("objective")),
                    "covered": bool(c.get("covered")),
                    "sections": [{k: s.get(k) for k in SECTION_FIELDS} for s in c.get("sections") or []],
                }
                for c in doc.get("coverage") or []
            ],
        })
    catalog = {"format": "la-resource-catalog/1", "resources": resources, "maps": maps}
    return json.dumps(catalog, indent=1, ensure_ascii=False, default=str) + "\n"


def main(argv: list[str]) -> int:
    text = build()
    if "--check" in argv:
        current = OUT.read_text(encoding="utf-8").replace("\r\n", "\n") if OUT.exists() else ""
        if current != text:
            print(f"{OUT.relative_to(ROOT)} is out of date; run python tool/build_resource_catalog.py")
            return 1
        print(f"{OUT.relative_to(ROOT)} matches data/")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
