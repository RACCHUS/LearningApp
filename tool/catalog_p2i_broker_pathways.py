#!/usr/bin/env python3
"""Validate Florida DBPR/FREC real estate broker destination and pathway manifest, and render safe promotion SQL."""
from __future__ import annotations
import json, re, sys
from datetime import date, datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/catalog/florida_broker_p2i_pathways_2026_11.json"
SEED = ROOT / "data/catalog/initial_destination_candidates.json"

FREC_INTENTIONS = "https://www.myfloridalicense.com/intentions2.asp?boardid=25&chBoard=true&div=Real+Estate"
CHECKLIST_URL = "https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=752&clientCode=2501&xactCode=1010"
RE2_GUIDE = "https://www2.myfloridalicense.com/pro/re/documents/re2.pdf"
STATUTE_URL = "https://www.flsenate.gov/Laws/Statutes/2026/475.17"

STEP_URLS = {
    ("dbpr_fl", "real-estate-broker"): {
        FREC_INTENTIONS,
        CHECKLIST_URL,
        RE2_GUIDE,
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
PREFIX = "P2i"


def valid_url(value: str) -> bool:
    p = urlsplit(value)
    return (
        p.scheme == "https"
        and p.hostname in {"www.myfloridalicense.com", "www2.myfloridalicense.com", "www.flsenate.gov"}
        and p.username is None
        and p.password is None
        and not p.fragment
        and not any(ch.isspace() for ch in value)
    )


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


def validate_payload(payload, seed_candidates):
    assert payload["schema_version"] == 1 and payload["review_scope"] == "selected_regulator_sourced_steps"
    assert payload["no_license_issuance"] is True and payload["no_fees_verified"] is True

    # 1. Validate destination metadata against candidate intake seed
    dest = payload["destination"]
    identity = (dest["source_namespace"], dest["source_key"])
    assert identity in IDENTITIES
    candidates_by_id = {
        (c["source_namespace"], c["source_key"]): c for c in seed_candidates["candidates"]
    }
    assert identity in candidates_by_id
    candidate = candidates_by_id[identity]
    assert dest["destination_type"] == candidate["destination_type"] == "professional_license"
    assert dest["title"] == candidate["title"]
    assert dest["jurisdiction"] == candidate["jurisdiction"] == "US-FL"
    assert valid_url(dest["official_url"])
    assert len(dest["verification_note"].strip()) >= 40
    assert 1 <= dest["editorial_order"] <= 9999

    res = dest["resource"]
    assert re.fullmatch(r"[a-z0-9_-]{3,70}", res["resource_key"])
    assert res["resource_kind"] == "regulator_license_checklist"
    assert valid_url(res["resource_url"])
    assert len(res["review_note"].strip()) >= 30

    # 2. Validate pathway records
    rows = payload["records"]
    assert len(rows) == 1
    for r in rows:
        row_id = (r["source_namespace"], r["source_key"])
        assert row_id == identity
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
    return payload


def validate():
    return validate_payload(
        json.loads(DATA.read_text(encoding="utf-8")),
        json.loads(SEED.read_text(encoding="utf-8")),
    )


def q(v):
    return "'" + str(v).replace("'", "''") + "'"


def sql():
    payload = validate()
    dest = payload["destination"]
    row = payload["records"][0]

    ns, key = q(dest["source_namespace"]), q(dest["source_key"])
    title, issuer = q(dest["title"]), q(dest["issuer_name"])
    url, issuer_url = q(dest["official_url"]), q(dest["issuer_url"])
    note = q(dest["verification_note"])
    order = int(dest["editorial_order"])

    lines = [
        "begin;",
        "set local statement_timeout='25s';",
        "",
        "-- 1. Approve matching intake candidate identity",
        "update public.catalog_intake_candidates",
        f"   set source_url={url}, review_status='approved', publication_status='published',",
        "       source_rights='approved_for_display', verified_at=coalesce(verified_at, now()),",
        "       metadata=jsonb_set(metadata, '{issuer_identity_reviewed}', 'true'::jsonb, true)",
        f" where source_namespace={ns} and source_key={key}",
        "   and review_status='pending' and publication_status='draft';",
        "",
        "-- 2. Promote verified destination into public directory",
        "insert into public.catalog_verified_destinations",
        "(source_namespace, source_key, destination_type, title, issuer_name, jurisdiction, official_url, verification_note, verified_at, editorial_order)",
        "select source_namespace, source_key, destination_type, title, issuer_name, jurisdiction, source_url,",
        f"       {note}, verified_at, {order}",
        "  from public.catalog_intake_candidates",
        f" where source_namespace={ns} and source_key={key}",
        "   and review_status='approved' and publication_status='published'",
        "on conflict (source_namespace, source_key) do nothing;",
        "",
        "-- 3. Add official checklist resource link",
    ]

    res = dest["resource"]
    res_cols = (
        "source_namespace", "source_key", "resource_key", "title", "resource_kind",
        "resource_url", "source_publisher", "rights_scope", "review_note", "verified_at", "status", "sort_order"
    )
    res_vals = [
        ns, key, q(res["resource_key"]), q(res["title"]), q(res["resource_kind"]),
        q(res["resource_url"]), q(res["source_publisher"]), q(res["rights_scope"]),
        q(res["review_note"]), "now()", q(res["status"]), str(res["sort_order"])
    ]
    lines += [
        f"insert into public.catalog_destination_resources ({','.join(res_cols)})",
        f"values ({','.join(res_vals)})",
        "on conflict (source_namespace, source_key, resource_key) do nothing;",
        "",
        "-- 4. Publish structured regulator pathway revision",
    ]

    rev = int(row["revision"])
    tree = q(json.dumps(row["pathway_tree"], ensure_ascii=False, separators=(",", ":")))
    checked = q(row["source_retrieved_at"])
    p_title, p_overview = q(row["title"]), q(row["overview"])
    p_source, p_route = q(row["source_url"]), q(row["route_kind"])
    p_note, p_uncert, p_kind = q(row["review_note"]), q(row["uncertainty_status"]), q(row["pathway_kind"])

    lines += [
        "insert into public.catalog_license_pathway_versions",
        "(source_namespace, source_key, revision, jurisdiction, route_kind, title, overview, coverage, source_url, source_checked_at, source_retrieved_at, review_note, uncertainty_status, pathway_kind, supersedes_revision, review_status, publication_status, reviewer, reviewed_at, pathway_tree)",
        f"values ({ns}, {key}, {rev}, 'US-FL', {p_route}, {p_title}, {p_overview}, 'selected_steps_only', {p_source}, {checked}, {checked}, {p_note}, {p_uncert}, {p_kind}, null, 'approved', 'published', 'Catalog Team / Regulatory Review', now(), {tree}::jsonb)",
        "on conflict (source_namespace, source_key, revision) do nothing;",
        "",
        "commit;",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "validate"
    if action == "validate":
        payload = validate()
        print(f"OK: validated Florida DBPR/FREC real estate broker destination and pathway (P2i)")
    elif action == "sql":
        print(sql())
    else:
        sys.exit(f"Unknown action {action}")

