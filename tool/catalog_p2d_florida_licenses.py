#!/usr/bin/env python3
"""P2d: validate a reviewed Florida professional-license manifest and render guarded DML.

No DB connection or writes occur when this tool runs. The printed SQL must be
reviewed and executed by a trusted administrator, never a learner client.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/catalog/florida_license_p2d_2026_10.json"
SEED = ROOT / "data/catalog/initial_destination_candidates.json"
ALLOW = {
    "fl_dfs": {"www.myfloridacfo.com", "myfloridacfo.com"},
    "dbpr_fl": {"www.myfloridalicense.com", "www2.myfloridalicense.com"},
    "fl_bon": {"floridasnursing.gov"},
}
KEYS = {
    ("fl_dfs", "general-lines-2-20"),
    ("fl_dfs", "life-health-2-15"),
    ("dbpr_fl", "certified-general-contractor"),
    ("dbpr_fl", "certified-building-contractor"),
    ("fl_bon", "registered-nurse"),
    ("fl_bon", "licensed-practical-nurse"),
}

def valid_url(value: str, namespace: str) -> bool:
    p = urlsplit(value)
    return (
        p.scheme == "https" and p.hostname in ALLOW[namespace]
        and p.username is None and p.password is None and not p.fragment
        and not re.search(r"\\s", value)
    )

def validate_payload(data: dict, candidates: dict) -> list[dict]:
    assert data["schema_version"] == 1
    assert data["review_scope"] == "issuer_identity_and_link_only"
    assert data["no_credential_awards"] is True
    assert data["requirements_verified"] is False
    assert data["popularity_measured"] is False
    assert data["reviewed_on"] == "2026-10-12"
    existing = {(r["source_namespace"], r["source_key"]): r for r in candidates["candidates"]}
    rows = data["records"]
    assert len(rows) == 6
    assert {(r["source_namespace"], r["source_key"]) for r in rows} == KEYS
    for r in rows:
        identity = (r["source_namespace"], r["source_key"])
        ns = r["source_namespace"]
        assert r["destination_type"] == "professional_license"
        assert r["jurisdiction"] == "US-FL"
        assert r["reviewed_on"] == data["reviewed_on"]
        assert len(r["verification_note"].strip()) >= 40
        assert 1 <= r["editorial_order"] <= 9999
        assert valid_url(r["issuer_url"], ns) or (ns == "fl_bon" and valid_url(r["issuer_url"], ns))
        assert valid_url(r["official_url"], ns)
        if r["seed_candidate"]:
            assert identity not in existing
        else:
            baseline = existing[identity]
            for field in ("title", "issuer_name", "destination_type", "jurisdiction"):
                assert r[field] == baseline[field]
        res = r["resource"]
        assert re.fullmatch(r"[a-z0-9_-]{3,70}", res["resource_key"])
        assert res["resource_kind"] == "regulator_license_checklist"
        assert valid_url(res["resource_url"], ns)
        assert res["source_publisher"] == r["issuer_name"]
        assert res["rights_scope"] == "external_link_only"
        assert res["status"] == "published"
        assert len(res["review_note"].strip()) >= 30
        assert res["sort_order"] >= 1
    return rows

def validate() -> list[dict]:
    return validate_payload(json.loads(DATA.read_text("utf-8")), json.loads(SEED.read_text("utf-8")))

def q(value: object) -> str:
    return "'" + str(value).replace("'", "''") + "'"

def render_sql(rows: list[dict]) -> str:
    sql = ["begin;", "set local statement_timeout = '25s';"]
    for r in rows:
        ns, key = q(r["source_namespace"]), q(r["source_key"])
        title, issuer = q(r["title"]), q(r["issuer_name"])
        url, issuer_url = q(r["official_url"]), q(r["issuer_url"])
        if r["seed_candidate"]:
            sql.append(
                "insert into public.catalog_intake_candidates "
                "(source_namespace,source_key,destination_type,title,issuer_name,issuer_url,"
                "source_url,jurisdiction,review_status,publication_status,source_rights,metadata) "
                f"values ({ns},{key},'professional_license',{title},{issuer},{issuer_url},"
                f"{url},'US-FL','pending','draft','link_metadata_only',"
                """'{"origin":"p2d_official_regulator_review","popularity_measured":false}'::jsonb) """
                "on conflict (source_namespace,source_key) do nothing;"
            )
        # Fail closed on altered identity, review state, or an unexpected already-published URL.
        sql.append(
            "do $identity$ begin if not exists("
            "select 1 from public.catalog_intake_candidates "
            f"where source_namespace={ns} and source_key={key} and title={title} "
            f"and issuer_name={issuer} and destination_type='professional_license' "
            "and jurisdiction='US-FL' and "
            "((review_status='pending' and publication_status='draft' and source_rights='link_metadata_only') "
            f"or (review_status='approved' and publication_status='published' and source_rights='approved_for_display' and source_url={url}))) "
            f"then raise exception 'P2d unreviewed or changed identity: {r['source_namespace']}/{r['source_key']}'; "
            "end if; end $identity$;"
        )
        sql.append(
            "update public.catalog_intake_candidates "
            f"set source_url={url}, review_status='approved',publication_status='published',"
            "source_rights='approved_for_display',verified_at=coalesce(verified_at,now()),"
            "metadata=jsonb_set(metadata,'{issuer_identity_reviewed}','true'::jsonb,true) "
            f"where source_namespace={ns} and source_key={key} "
            "and review_status='pending' and publication_status='draft';"
        )
        sql.append(
            "insert into public.catalog_verified_destinations "
            "(source_namespace,source_key,destination_type,title,issuer_name,jurisdiction,"
            "official_url,verification_note,verified_at,editorial_order) "
            "select source_namespace,source_key,destination_type,title,issuer_name,jurisdiction,"
            f"source_url,{q(r['verification_note'])},verified_at,{int(r['editorial_order'])} "
            "from public.catalog_intake_candidates "
            f"where source_namespace={ns} and source_key={key} and review_status='approved' "
            "and publication_status='published' and source_rights='approved_for_display' "
            "on conflict (source_namespace,source_key) do nothing;"
        )
        res = r["resource"]
        cols = ("source_namespace","source_key","resource_key","title","resource_kind",
                "resource_url","source_publisher","rights_scope","review_note","verified_at","status","sort_order")
        values = [ns,key,*[q(res[c]) for c in cols[2:9]],"now()",q(res["status"]),str(res["sort_order"])]
        sql.append(
            f"insert into public.catalog_destination_resources ({','.join(cols)}) "
            f"values ({','.join(values)}) "
            "on conflict (source_namespace,source_key,resource_key) do nothing;"
        )
        sql.append(
            "do $verify$ begin if not exists("
            "select 1 from public.catalog_verified_destinations d "
            "join public.catalog_intake_candidates c using(source_namespace,source_key) "
            "join public.catalog_destination_resources x using(source_namespace,source_key) "
            f"where d.source_namespace={ns} and d.source_key={key} "
            f"and d.title={title} and d.issuer_name={issuer} and d.official_url={url} "
            "and d.destination_type='professional_license' and d.jurisdiction='US-FL' "
            "and d.verification_scope='issuer_identity_and_link' "
            "and d.requirements_status='not_verified' and d.popularity_status='not_measured' "
            "and d.publication_status='published' and c.review_status='approved' "
            "and c.publication_status='published' and c.source_rights='approved_for_display' "
            f"and x.resource_key={q(res['resource_key'])} and x.resource_url={q(res['resource_url'])} "
            "and x.status='published') "
            f"then raise exception 'P2d verification failed: {r['source_namespace']}/{r['source_key']}'; "
            "end if; end $verify$;"
        )
    sql += ["commit;"]
    return "\n".join(sql) + "\n"

def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in ("validate", "render-sql"):
        raise ValueError("Usage: catalog_p2d_florida_licenses.py validate|render-sql")
    rows = validate()
    if sys.argv[1] == "validate":
        print(json.dumps({"reviewed_licenses": len(rows), "new_private_candidates": sum(r["seed_candidate"] for r in rows),
              "source_links": len(rows), "structured_requirements_verified": 0, "popularity_scores": 0}))
    else:
        print(render_sql(rows), end="")

if __name__ == "__main__":
    try:
        main()
    except (AssertionError, ValueError, KeyError, TypeError) as exc:
        print(f"P2d validation failed closed: {type(exc).__name__}", file=sys.stderr)
        sys.exit(2)
