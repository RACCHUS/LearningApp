#!/usr/bin/env python3
"""Validate a narrow, evidence-reviewed public issuer-link pilot.

No external content is copied; no fees, eligibility requirements, exam items,
provider courses, or measured popularity scores may enter this manifest.
Default action is purely local validation, not publishing.
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT=Path(__file__).resolve().parents[1]
SEED=ROOT/"data/catalog/initial_destination_candidates.json"
REVIEW=ROOT/"data/catalog/issuer_verified_pilot_2026_10.json"
DOMAINS={
    "aws":{"aws.amazon.com"},
    "microsoft":{"learn.microsoft.com"},
    "pmi":{"www.pmi.org"},
    "ncsbn":{"www.nclex.com"},
    "dbpr_fl":{"www.myfloridalicense.com"},
}
REQUIRED={
    "source_namespace","source_key","official_url","verification_note",
    "reviewed_on","editorial_order","verification_scope",
    "requirements_status","popularity_status",
}

def validate() -> list[dict]:
    seed=json.loads(SEED.read_text(encoding="utf-8"))
    pilot=json.loads(REVIEW.read_text(encoding="utf-8"))
    assert pilot["schema_version"]==1 and pilot["popularity_claim"] is False
    assert pilot["review_scope"]=="issuer_identity_and_link_only"
    by_key={(r["source_namespace"],r["source_key"]):r for r in seed["candidates"]}
    rows=pilot["records"]
    assert pilot["total"]==len(rows) and len(rows)>=8
    seen=set()
    for row in rows:
        assert set(row)==REQUIRED
        identity=(row["source_namespace"],row["source_key"])
        assert identity in by_key and identity not in seen
        seen.add(identity)
        source=by_key[identity]
        assert source["review_status"]=="pending" and source["publication_status"]=="draft"
        assert source["source_rights"]=="link_metadata_only"
        assert row["reviewed_on"]=="2026-10-11"
        assert row["verification_scope"]=="issuer_identity_and_link"
        assert row["requirements_status"]=="not_verified"
        assert row["popularity_status"]=="not_measured"
        assert 1<=row["editorial_order"]<=9999
        assert len(row["verification_note"].strip())>=40
        url=row["official_url"]
        parsed=urlparse(url)
        assert parsed.scheme=="https" and parsed.hostname in DOMAINS[identity[0]]
        assert not parsed.username and not parsed.password and not parsed.fragment
        assert not re.search(r"\s",url)
    return rows

def quote(value: str)->str:
    return "'"+value.replace("'","''")+"'"

def review_sql() -> str:
    """One explicit, transaction-safe promotion script for admin SQL review.

    SQL is generated only from strictly validated checked-in records, not
    arbitrary user input. Never export or interpolate database secrets here.
    """
    rows=validate()
    lines=["begin;", "set local statement_timeout = '20s';"]
    for row in rows:
        ns,key=row["source_namespace"],row["source_key"]
        url=quote(row["official_url"])
        nsq,keyq=quote(ns),quote(key)
        note=quote(row["verification_note"])
        lines.extend([
            f"update public.catalog_intake_candidates set source_url={url}, "
            "review_status='approved',publication_status='published',"
            "source_rights='approved_for_display',verified_at=coalesce(verified_at,now()),"
            f"metadata=jsonb_set(metadata,'{{issuer_identity_reviewed}}','true'::jsonb,true) "
            f"where source_namespace={nsq} and source_key={keyq} "
            "and review_status='pending' and publication_status='draft';",
            f"insert into public.catalog_verified_destinations "
            "(source_namespace,source_key,destination_type,title,issuer_name,"
            "jurisdiction,official_url,verification_note,verified_at,editorial_order) "
            "select source_namespace,source_key,destination_type,title,issuer_name,"
            f"jurisdiction,source_url,{note},verified_at,{int(row['editorial_order'])} "
            "from public.catalog_intake_candidates "
            f"where source_namespace={nsq} and source_key={keyq} "
            "and review_status='approved' and publication_status='published' "
            "and source_rights='approved_for_display' "
            "on conflict (source_namespace,source_key) do nothing;"
        ])
    lines.extend([
      "do $pilot$ begin "
      f"if (select count(*) from public.catalog_verified_destinations where publication_status='published') < {len(rows)} "
      "then raise exception 'Reviewed pilot did not reach its required row count'; end if; "
      "end $pilot$;",
      "commit;"
    ])
    return "\n".join(lines)

if __name__=="__main__":
    if len(sys.argv)!=2 or sys.argv[1] not in ("validate","render-sql"):
        print("Usage: python tool/catalog_verified_pilot.py validate|render-sql",file=sys.stderr)
        sys.exit(2)
    try:
        if sys.argv[1]=="validate":
            rows=validate()
            print(json.dumps({"status":"issuer_identity_and_link_only","reviewed_records":len(rows),
            "requirements_verified":0,"popularity_scores":0}))
        else:
            print(review_sql())
    except (AssertionError,KeyError,ValueError,TypeError) as e:
        print(f"Verified issuer pilot validation failed: {type(e).__name__}",file=sys.stderr)
        sys.exit(2)
