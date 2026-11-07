#!/usr/bin/env python3
"""Validate selected Florida RN/LPN regulator pathways and render safe revision promotion SQL."""
from __future__ import annotations
import json, sys
from datetime import date, datetime, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"data/catalog/florida_nursing_p2e_pathways_2026_10.json"
BOARD_URL="https://floridasnursing.gov/nurse-rn-lpn/"
IDENTITIES={("fl_bon","registered-nurse"),("fl_bon","licensed-practical-nurse")}
STAGES={"education","training","experience","examination","background_screening","application","appointment","continuing_education","authorization","other"}
PREFIX="P2e"

def validate_tree(node, allowed_urls=None, depth=0):
    assert isinstance(node,dict) and depth<=8
    op=node.get("op")
    if op in ("all","any"):
        assert set(node)=={"op","children"} and isinstance(node["children"],list) and 2<=len(node["children"])<=20
        return sum(validate_tree(x,allowed_urls,depth+1) for x in node["children"])
    assert op=="step" and set(node) in ({"op","label","stage","source_url"},{"op","label","stage","source_url","condition"})
    assert isinstance(node["label"],str) and 8<=len(node["label"].strip())<=280
    assert node["stage"] in STAGES and node["source_url"] in (allowed_urls or {BOARD_URL})
    if "condition" in node: assert isinstance(node["condition"],str) and 10<=len(node["condition"].strip())<=280
    return 1

def validate_payload(payload):
    assert payload["schema_version"]==1 and payload["review_scope"]=="selected_regulator_sourced_steps"
    assert payload["no_license_issuance"] is True and payload["no_fees_verified"] is True
    rows=payload["records"]; assert len(rows)==2; seen=set()
    for r in rows:
        identity=(r["source_namespace"],r["source_key"])
        assert identity in IDENTITIES and identity not in seen; seen.add(identity)
        assert r["revision"]==2 and r["supersedes_revision"]==1 and r["jurisdiction"]=="US-FL"
        assert r["route_kind"]=="other" and r["coverage"]=="selected_steps_only" and r["source_url"]==BOARD_URL
        assert r["source_checked_on"]=="2026-11-06" and r["reviewed_on"]=="2026-11-06"
        assert date.fromisoformat(r["source_checked_on"])<=date.today()
        assert 80<=len(r["overview"].strip())<=1200 and 8<=len(r["title"].strip())<=180
        assert len(r["review_note"].strip())>=80 and r["source_retrieved_at"].endswith("Z")
        retrieved=datetime.fromisoformat(r["source_retrieved_at"].replace("Z","+00:00"))
        assert retrieved.tzinfo is not None and retrieved<=datetime.now(timezone.utc)
        assert r["uncertainty_status"]=="conditional" and r["pathway_kind"]=="initial_licensure"
        assert validate_tree(r["pathway_tree"],{BOARD_URL})>=15
        labels=[]
        def walk(n):
            if n["op"]=="step": labels.append(n["label"])
            else:
                for child in n["children"]: walk(child)
        walk(r["pathway_tree"])
        assert len(labels)==len(set(labels))
        assert r["pathway_tree"]["op"]=="all"
        branches=r["pathway_tree"]["children"][0]
        assert branches["op"]=="any" and len(branches["children"])==3
    assert seen==IDENTITIES
    return rows

def validate():
    return validate_payload(json.loads(DATA.read_text(encoding="utf-8")))

def q(v):
    return "'"+str(v).replace("'","''")+"'"

def sql():
    rows=validate(); lines=["begin;","set local statement_timeout='25s';"]
    for r in rows:
        ns,key=q(r["source_namespace"]),q(r["source_key"])
        revision,previous=int(r["revision"]),int(r["supersedes_revision"])
        tree=q(json.dumps(r["pathway_tree"],ensure_ascii=False,separators=(",",":")))
        checked=q(r["source_retrieved_at"]); title,overview=q(r["title"]),q(r["overview"])
        source,route=q(r["source_url"]),q(r["route_kind"])
        lines += [
          "update public.catalog_license_pathway_versions set publication_status='retired' "
          f"where source_namespace={ns} and source_key={key} and revision={previous} and publication_status='published';",
          "do $retire$ begin if not exists (select 1 from public.catalog_license_pathway_versions "
          f"where source_namespace={ns} and source_key={key} and revision={previous} and publication_status='retired') "
          f"then raise exception '{PREFIX} prior revision not retired: {r['source_key']}'; end if; end $retire$;",
          "do $review$ begin if not exists (select 1 from public.catalog_verified_destinations "
          f"where source_namespace={ns} and source_key={key} and destination_type='professional_license' "
          f"and jurisdiction='US-FL' and official_url={source} and publication_status='published') "
          f"then raise exception '{PREFIX} source issuer not approved: {r['source_key']}'; end if; end $review$;",
          "insert into public.catalog_license_pathway_versions "
          "(source_namespace,source_key,revision,supersedes_revision,jurisdiction,route_kind,title,overview,coverage,source_url,source_checked_at,reviewed_at,reviewer,review_status,publication_status,pathway_tree,source_retrieved_at,review_note,uncertainty_status,pathway_kind) "
          f"values ({ns},{key},{revision},{previous},'US-FL',{route},{title},{overview},'selected_steps_only',{source},{checked}::timestamptz,{checked}::timestamptz,'Learning App source review','approved','published',{tree}::jsonb,{checked}::timestamptz,{q(r['review_note'])},{q(r['uncertainty_status'])},{q(r['pathway_kind'])}) "
          "on conflict (source_namespace,source_key,revision) do nothing;",
          "do $verify$ begin if not exists (select 1 from public.catalog_license_pathway_versions "
          f"where source_namespace={ns} and source_key={key} and revision={revision} and supersedes_revision={previous} "
          f"and jurisdiction='US-FL' and route_kind={route} and title={title} and source_url={source} "
          f"and pathway_tree={tree}::jsonb and source_checked_at={checked}::timestamptz and reviewed_at={checked}::timestamptz "
          f"and review_status='approved' and publication_status='published' and source_retrieved_at={checked}::timestamptz "
          f"and review_note={q(r['review_note'])} and uncertainty_status={q(r['uncertainty_status'])} and pathway_kind={q(r['pathway_kind'])}) "
          f"then raise exception '{PREFIX} revision mismatch: {r['source_key']}'; end if; end $verify$;",
          "do $verify_old$ begin if exists (select 1 from public.catalog_license_pathway_versions "
          f"where source_namespace={ns} and source_key={key} and revision={previous} and publication_status='published') "
          f"then raise exception '{PREFIX} old revision still published: {r['source_key']}'; end if; end $verify_old$;"
        ]
    lines.append("commit;")
    return "\n".join(lines)+"\n"

if __name__=="__main__":
    try:
        if len(sys.argv)!=2 or sys.argv[1] not in ("validate","render-sql"): raise ValueError("Expected validate|render-sql")
        if sys.argv[1]=="validate":
            rows=validate(); print(json.dumps({"approved_selected_pathways":len(rows),"cited_steps":sum(validate_tree(r["pathway_tree"],{BOARD_URL}) for r in rows),"full_requirements_verified":0,"issued_licenses":0}))
        else: print(sql(),end="")
    except (AssertionError,KeyError,ValueError,TypeError) as exc:
        print("P2e review failed closed: "+type(exc).__name__,file=sys.stderr); sys.exit(2)
