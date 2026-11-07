#!/usr/bin/env python3
"""Validate selected Florida DBPR/FREC real estate pathways and render safe promotion SQL."""
from __future__ import annotations
import json, sys
from datetime import date, datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/catalog/florida_real_estate_p2h_pathways_2026_10.json"
FREC_INTENTIONS = "https://www.myfloridalicense.com/intentions2.asp?boardid=25&chBoard=true&div=Real+Estate"
CHECKLIST_URL = "https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=750&clientCode=2501&xactCode=1010"
RE1_GUIDE = "https://www2.myfloridalicense.com/pro/re/documents/re1.pdf"
STATUTE_URL = "https://www.flsenate.gov/Laws/Statutes/2026/475.17"

STEP_URLS = {
    ("dbpr_fl", "real-estate-sales-associate"): {
        FREC_INTENTIONS,
        CHECKLIST_URL,
        RE1_GUIDE,
        STATUTE_URL,
    }
}
IDENTITIES = set(STEP_URLS)
STAGES = {
    "education",
    "training",
    "experience",
    "examination",
    "background_screening",
    "application",
    "appointment",
    "continuing_education",
    "authorization",
    "other",
}
PREFIX = "P2h"


def validate_tree(node, allowed_urls, depth=0):
    assert isinstance(node, dict) and depth <= 8
    op = node.get("op")
    if op in ("all", "any"):
        assert set(node) == {"op", "children"} and isinstance(
            node["children"], list
        ) and 2 <= len(node["children"]) <= 20
        return sum(validate_tree(x, allowed_urls, depth + 1) for x in node["children"])
    assert op == "step" and set(node) in (
        {"op", "label", "stage", "source_url"},
        {"op", "label", "stage", "source_url", "condition"},
    )
    assert isinstance(node["label"], str) and 8 <= len(node["label"].strip()) <= 280
    assert node["stage"] in STAGES and node["source_url"] in allowed_urls
    if "condition" in node:
        assert isinstance(node["condition"], str) and 10 <= len(node["condition"].strip()) <= 280
    return 1


def validate_payload(payload):
    assert payload["schema_version"] == 1 and payload["review_scope"] == "selected_regulator_sourced_steps"
    assert payload["no_license_issuance"] is True and payload["no_fees_verified"] is True
    rows = payload["records"]
    assert len(rows) == 1
    seen = set()
    for r in rows:
        identity = (r["source_namespace"], r["source_key"])
        assert identity in IDENTITIES and identity not in seen
        seen.add(identity)
        assert r["revision"] == 1 and r["supersedes_revision"] is None and r["jurisdiction"] == "US-FL"
        assert r["route_kind"] == "examination" and r["coverage"] == "selected_steps_only" and r["source_url"] == FREC_INTENTIONS
        assert r["source_checked_on"] == "2026-11-07" and r["reviewed_on"] == "2026-11-07"
        assert date.fromisoformat(r["source_checked_on"]) <= date.today()
        assert 80 <= len(r["overview"].strip()) <= 1200 and 8 <= len(r["title"].strip()) <= 180 and len(r["review_note"].strip()) >= 80
        assert r["source_retrieved_at"].endswith("Z")
        retrieved = datetime.fromisoformat(r["source_retrieved_at"].replace("Z", "+00:00"))
        assert retrieved.tzinfo is not None and retrieved <= datetime.now(timezone.utc)
        assert r["uncertainty_status"] == "conditional" and r["pathway_kind"] == "initial_licensure"
        assert validate_tree(r["pathway_tree"], STEP_URLS[identity]) >= 10
        labels = []

        def walk(n):
            if n["op"] == "step":
                labels.append(n["label"])
            else:
                for child in n["children"]:
                    walk(child)

        walk(r["pathway_tree"])
        assert len(labels) == len(set(labels))
    assert seen == IDENTITIES
    return rows


def validate():
    return validate_payload(json.loads(DATA.read_text(encoding="utf-8")))


def q(v):
    return "'" + str(v).replace("'", "''") + "'"


def sql():
    rows = validate()
    lines = ["begin;", "set local statement_timeout='25s';"]
    for r in rows:
        ns, key = q(r["source_namespace"]), q(r["source_key"])
        rev = int(r["revision"])
        tree = q(json.dumps(r["pathway_tree"], ensure_ascii=False, separators=(",", ":")))
        checked = q(r["source_retrieved_at"])
        title, overview = q(r["title"]), q(r["overview"])
        source, route = q(r["source_url"]), q(r["route_kind"])
        prev = r["supersedes_revision"]
        supersedes_clause = f"{prev}" if prev is not None else "null"
        if prev is not None:
            lines += [
                "update public.catalog_license_pathway_versions set publication_status='retired' "
                + f"where source_namespace={ns} and source_key={key} and revision={prev} and publication_status='published';"
            ]
        lines += [
            "insert into public.catalog_license_pathway_versions "
            "(source_namespace,source_key,revision,jurisdiction,route_kind,title,overview,coverage,source_url,source_checked_at,source_retrieved_at,review_note,uncertainty_status,pathway_kind,supersedes_revision,review_status,publication_status,reviewer,reviewed_at,pathway_tree) "
            f"values ({ns},{key},{rev},'US-FL',{route},{title},{overview},'selected_steps_only',{source},{checked},{checked},{q(r['review_note'])},{q(r['uncertainty_status'])},{q(r['pathway_kind'])},{supersedes_clause},'approved','published','Catalog Team / Regulatory Review',now(),{tree}::jsonb) "
            "on conflict (source_namespace,source_key,revision) do nothing;"
        ]
    lines.append("commit;")
    return "\n".join(lines)


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "validate"
    if action == "validate":
        rows = validate()
        print(f"OK: validated {len(rows)} Florida DBPR/FREC real estate pathway record(s)")
    elif action == "sql":
        print(sql())
    else:
        sys.exit(f"Unknown action {action}")

