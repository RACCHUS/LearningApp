#!/usr/bin/env python3
"""P2e: validate selected, source-cited Florida nursing licensure pathway versions.

Default command validates local evidence; `render-sql` prints a guarded,
idempotent, administrator-only publishing transaction. No network/database access.
"""
from __future__ import annotations

import json
import re
import sys
from datetime import date
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/catalog/florida_nursing_p2e_pathways_2026_10.json"
BOARD_URL = "https://floridasnursing.gov/nurse-rn-lpn/"
IDENTITIES = {("fl_bon", "registered-nurse"), ("fl_bon", "licensed-practical-nurse")}
STAGES = {
    "education", "training", "experience", "examination",
    "background_screening", "application", "appointment",
    "continuing_education", "authorization", "other",
}


def validate_tree(node: dict, depth: int = 0) -> int:
    assert isinstance(node, dict) and depth <= 8
    op = node.get("op")
    if op in ("all", "any"):
        assert set(node) == {"op", "children"}
        children = node["children"]
        assert isinstance(children, list) and 2 <= len(children) <= 20
        return sum(validate_tree(x, depth + 1) for x in children)
    assert op == "step"
    assert set(node) in ({"op", "label", "stage", "source_url"},
                         {"op", "label", "stage", "source_url", "condition"})
    assert isinstance(node["label"], str) and 8 <= len(node["label"].strip()) <= 280
    assert node["stage"] in STAGES
    assert node["source_url"] == BOARD_URL
    if "condition" in node:
        assert isinstance(node["condition"], str)
        assert 10 <= len(node["condition"].strip()) <= 280
    return 1


def validate_payload(payload: dict) -> list[dict]:
    assert payload["schema_version"] == 1
    assert payload["review_scope"] == "selected_regulator_sourced_steps"
    assert payload["no_license_issuance"] is True
    assert payload["no_fees_verified"] is True
    rows = payload["records"]
    assert len(rows) == 2
    seen = set()
    for r in rows:
        identity = (r["source_namespace"], r["source_key"])
        assert identity in IDENTITIES and identity not in seen
        seen.add(identity)
        assert r["revision"] == 1 and r["jurisdiction"] == "US-FL"
        assert r["route_kind"] == "examination"
        assert r["coverage"] == "selected_steps_only"
        assert r["source_url"] == BOARD_URL
        assert r["source_checked_on"] == "2026-10-12"
        assert r["reviewed_on"] == "2026-10-12"
        assert date.fromisoformat(r["source_checked_on"]) <= date.today()
        assert 80 <= len(r["overview"].strip()) <= 1200
        assert 8 <= len(r["title"].strip()) <= 180
        assert len(r["review_note"].strip()) >= 80
        assert validate_tree(r["pathway_tree"]) >= 5
        labels = []
        def walk(node):
            if node["op"] == "step":
                labels.append(node["label"])
            else:
                for child in node["children"]:
                    walk(child)
        walk(r["pathway_tree"])
        assert len(labels) == len(set(labels))
    return rows


def validate() -> list[dict]:
    return validate_payload(json.loads(DATA.read_text(encoding="utf-8")))


def q(value: str) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def sql() -> str:
    rows = validate()
    lines = ["begin;", "set local statement_timeout='25s';"]
    for r in rows:
        ns, key = q(r["source_namespace"]), q(r["source_key"])
        tree = q(json.dumps(r["pathway_tree"], ensure_ascii=False, separators=(",", ":")))
        checked_at = q(r["source_checked_on"] + "T18:08:00Z")
        title, overview = q(r["title"]), q(r["overview"])
        source = q(r["source_url"])
        reviewer = q("Learning App source review")
        lines += [
            "do $review$ begin if not exists (select 1 from public.catalog_verified_destinations "
            f"where source_namespace={ns} and source_key={key} and destination_type='professional_license' "
            f"and jurisdiction='US-FL' and official_url={source} and publication_status='published') "
            f"then raise exception 'P2e source issuer not approved: {r['source_key']}'; end if; end $review$;",
            "insert into public.catalog_license_pathway_versions "
            "(source_namespace,source_key,revision,jurisdiction,route_kind,title,overview,coverage,"
            "source_url,source_checked_at,reviewed_at,reviewer,review_status,publication_status,pathway_tree) "
            f"values ({ns},{key},1,'US-FL','examination',{title},{overview},'selected_steps_only',"
            f"{source},{checked_at}::timestamptz,{checked_at}::timestamptz,{reviewer},'approved','published',{tree}::jsonb) "
            "on conflict (source_namespace,source_key,revision) do nothing;",
            "do $verify$ begin if not exists (select 1 from public.catalog_license_pathway_versions "
            f"where source_namespace={ns} and source_key={key} and revision=1 "
            f"and source_url={source} and jurisdiction='US-FL' and title={title} "
            "and route_kind='examination' and coverage='selected_steps_only' "
            f"and pathway_tree={tree}::jsonb and source_checked_at={checked_at}::timestamptz "
            "and review_status='approved' and publication_status='published' "
            "and reviewer='Learning App source review') "
            f"then raise exception 'P2e reviewed pathway mismatch: {r['source_key']}'; "
            "end if; end $verify$;",
        ]
    lines.append("commit;")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2 or sys.argv[1] not in ("validate", "render-sql"):
            raise ValueError("Expected validate|render-sql")
        if sys.argv[1] == "validate":
            records = validate()
            print(json.dumps({"approved_selected_pathways":len(records),
                "cited_steps":sum(validate_tree(r["pathway_tree"]) for r in records),
                "full_requirements_verified":0, "issued_licenses":0}))
        else:
            print(sql(),end="")
    except (AssertionError,KeyError,ValueError,TypeError) as exc:
        print("P2e review failed closed: " + type(exc).__name__,file=sys.stderr)
        sys.exit(2)
