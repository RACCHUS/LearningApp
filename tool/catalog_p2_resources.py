#!/usr/bin/env python3
"""Validate an issuer-only external preparation link registry; render SQL by request.

Run:
    python3 tool/catalog_p2_resources.py validate
    python3 tool/catalog_p2_resources.py sql
No API keys, no database writes and no mirrored lesson/question content.
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit

ROOT=Path(__file__).resolve().parents[1]
SEED=ROOT/"data/catalog/issuer_verified_pilot_2026_10.json"
DATA=ROOT/"data/catalog/official_preparation_links_2026_10.json"
ALLOW={
    "aws":{"aws.amazon.com"},
    "microsoft":{"learn.microsoft.com"},
    "pmi":{"www.pmi.org"},
    "ncsbn":{"www.nclex.com"},
}
KINDS={"official_study_guide","issuer_training",
       "official_exam_plan","issuer_prep_directory"}

def validate()->list[dict]:
    pilot=json.loads(SEED.read_text(encoding="utf-8"))
    payload=json.loads(DATA.read_text(encoding="utf-8"))
    assert payload.get("schema_version")==1
    assert payload["review_scope"]=="issuer_owned_external_resource_links_only"
    assert all(payload["assertions"].values())
    reviewed={(r["source_namespace"],r["source_key"]) for r in pilot["records"]}
    rows=payload["resources"]
    assert len(rows)==payload["total"] and len(rows)>=5
    seen=set()
    for r in rows:
        identity=(r["source_namespace"],r["source_key"])
        key=(*identity,r["resource_key"])
        assert identity in reviewed and key not in seen
        seen.add(key)
        assert re.fullmatch(r"[a-z0-9_-]{3,70}",r["resource_key"])
        assert r["resource_kind"] in KINDS
        assert r["rights_scope"]=="external_link_only"
        assert r["reviewed_on"] in ("2026-10-11","2026-10-12")
        assert r["status"]=="published"
        assert len(r["review_note"].strip())>=30
        assert len(r["title"].strip())>=6
        assert r["sort_order"]>=1
        url=urlsplit(r["resource_url"])
        assert url.scheme=="https" and url.hostname in ALLOW[identity[0]]
        assert url.username is None and url.password is None
        assert not re.search(r"\s",r["resource_url"])
    return rows

def quote(s):
    return "'"+str(s).replace("'","''")+"'"

def sql():
    rows=validate()
    result=["begin;","set local statement_timeout='20s';"]
    for r in rows:
        cols=("source_namespace","source_key","resource_key","title","resource_kind",
              "resource_url","source_publisher","rights_scope","review_note","verified_at","status","sort_order")
        vals=(*(quote(r[k]) for k in cols[:9]),"now()",quote(r["status"]),str(r["sort_order"]))
        result.append(f"insert into public.catalog_destination_resources ({','.join(cols)}) "
                      f"values ({','.join(vals)}) on conflict (source_namespace,source_key,resource_key) do nothing;")
    result.append(f"do $count$ begin if (select count(*) from public.catalog_destination_resources where status='published') < {len(rows)} then raise exception 'Official link pilot missing records'; end if; end $count$;")
    result.append("commit;")
    return "\n".join(result)

if __name__=="__main__":
    try:
        if len(sys.argv)!=2 or sys.argv[1] not in ("validate","sql"):
            raise ValueError("Expected validate or sql")
        if sys.argv[1]=="sql": print(sql())
        else: print(json.dumps({"status":"issuer_external_links_valid",
                               "resources":len(validate()),
                               "copied_course_content":0,
                               "exam_questions":0}))
    except (AssertionError,ValueError,KeyError,TypeError) as exc:
        print(f"Resource evidence validation failed: {type(exc).__name__}",file=sys.stderr)
        sys.exit(2)
