#!/usr/bin/env python3
"""Validate demand-research and source-discovery files (ingestion plan v1.2
§4 and §5, slices 3 and 4) and compute acquisition priority (§4.3).

    python tool/verify_research.py            # validate everything (CI)
    python tool/verify_research.py --report   # also print priorities

Files (YAML, one record each, aggregate public data only):
  data/research/opportunities/*.yaml   opportunity briefs (§4.2) with
                                       observations (§4.1) and factors (§4.3)
  data/research/sources/*.yaml         source candidates (§5.2)

Key rules:
  * Unknown is null, never zero. A factor score needs evidence and a rater.
  * An observed value needs a source locator; suppressed, missing and
    not-applicable values are null and say which.
  * No personal fields anywhere (emails, names, user ids, IPs).
  * Demand status `measured_comparable` needs two evidence classes and two
    comparable observations in one cohort; `measured_*` needs observations.
  * The high-demand lane needs measured demand.
  * Priority uses only known weights; a score is usable for allocation only
    with at least 70% of the weight known, and its bounds are always shown.
  * Hard gates come before scoring: a failed gate blocks acquire/adapt/create.
  * A source whose rights aren't verified may only be discovered, linked or
    referenced (never adapted, redistributed or AI-transformed); a
    registry_source_id must exist in data/content_sources.json.
"""
from __future__ import annotations

import json
import re
import sys
from datetime import date
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[1]
RESEARCH = REPO / "data" / "research"
REGISTRY = REPO / "data" / "content_sources.json"

WEIGHTS = {
    "demand": 25,
    "underserved_need": 20,
    "outcome_value": 20,
    "cross_goal_reuse": 15,
    "source_feasibility": 10,
    "improvement_potential": 10,
}
MIN_KNOWN_WEIGHT = 70
LANES = {"high_demand", "underserved", "strategic"}
DEMAND_STATUS = {"unmeasured", "research_in_progress", "measured_limited", "measured_comparable", "stale"}
EVIDENCE_CLASSES = {"official_participation", "education", "labor", "public_interest",
                    "internal_demand", "unmet_need", "outcome_value"}
VALUE_STATES = {"observed", "suppressed", "missing", "not_applicable"}
DIRECTNESS = {"direct", "indirect"}
RECOMMENDATIONS = {"acquire", "adapt", "link", "create", "improve", "defer"}
BUILDING = {"acquire", "adapt", "create"}
DEFER_REASONS = {"low_current_priority", "rights_unknown", "strong_external_alternative",
                 "no_reliable_source", "high_maintenance", "adapter_not_ready"}
GATES = ("permitted_operation", "source_trust", "outcome_defined", "safety_ok", "capacity_ok", "validation_feasible")
EFFORT = {"S", "M", "L"}
RIGHTS_STATES = {"unverified", "in_review", "verified", "rejected"}
SAFE_ACTIONS = {"discover", "link", "reference"}
ALL_ACTIONS = SAFE_ACTIONS | {"quote", "adapt", "redistribute", "ai_transform"}
SOURCE_RECOMMENDATIONS = {"discover", "register", "link_only", "defer", "reject"}
PERSONAL_KEYS = re.compile(r"(^|_)(email|e_mail|phone|name_of_person|full_name|user_id|learner_id|ip|ip_address|address)($|_)")
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
URL = re.compile(r"^https://[^\s]+$")


def _date_ok(value) -> bool:
    try:
        d = value if isinstance(value, date) else date.fromisoformat(str(value))
    except ValueError:
        return False
    return d <= date.today()


def _personal_keys(node, path="") -> list[str]:
    found = []
    if isinstance(node, dict):
        for k, v in node.items():
            if PERSONAL_KEYS.search(str(k).lower()):
                found.append(f"{path}{k}")
            found += _personal_keys(v, f"{path}{k}.")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            found += _personal_keys(v, f"{path}{i}.")
    return found


def priority(factors: dict) -> dict:
    """§4.3: provisional score over known weights, with bounds for unknowns."""
    known = {k: (factors.get(k) or {}).get("score") for k in WEIGHTS}
    known = {k: v for k, v in known.items() if v is not None}
    known_weight = sum(WEIGHTS[k] for k in known)
    achieved = sum(WEIGHTS[k] * v / 5 for k, v in known.items())
    unknown_weight = 100 - known_weight
    score = round(100 * achieved / known_weight, 1) if known_weight else None
    return {
        "known_weight": known_weight,
        "provisional_score": score,
        "lower_bound": round(achieved, 1),
        "upper_bound": round(achieved + unknown_weight, 1),
        "usable": known_weight >= MIN_KNOWN_WEIGHT,
    }


def check_opportunity(path: Path, data: dict) -> list[str]:
    name = path.name
    p: list[str] = []
    for key in _personal_keys(data):
        p.append(f"{name}: personal field '{key}' is not allowed (aggregate public data only)")
    if not SLUG.match(str(data.get("id", ""))) or data.get("id") != path.stem:
        p.append(f"{name}: id must be a slug equal to the file name")
    for key in ("title", "intended_learner", "outcome"):
        if not str(data.get(key) or "").strip():
            p.append(f"{name}: {key} is required")
    lane = data.get("lane")
    if lane not in LANES:
        p.append(f"{name}: lane must be one of {sorted(LANES)}")
    status = data.get("demand_status")
    if status not in DEMAND_STATUS:
        p.append(f"{name}: demand_status must be one of {sorted(DEMAND_STATUS)}")

    observations = data.get("observations") or []
    classes = set()
    cohorts: dict[str, int] = {}
    for i, o in enumerate(observations):
        where = f"{name}: observations[{i}]"
        ec = o.get("evidence_class")
        if ec not in EVIDENCE_CLASSES:
            p.append(f"{where}: evidence_class must be one of {sorted(EVIDENCE_CLASSES)}")
        state = o.get("state")
        if state not in VALUE_STATES:
            p.append(f"{where}: state must be one of {sorted(VALUE_STATES)}")
        value = o.get("value")
        if state == "observed":
            if not isinstance(value, (int, float)) or isinstance(value, bool):
                p.append(f"{where}: an observed value must be a number")
            if not URL.match(str(o.get("source_locator") or "")):
                p.append(f"{where}: an observed value needs an https source_locator")
            classes.add(ec)
            if o.get("cohort"):
                cohorts[o["cohort"]] = cohorts.get(o["cohort"], 0) + 1
        elif value is not None:
            p.append(f"{where}: a {state} value must be null (it is not zero)")
        for key in ("metric", "unit", "period", "geography", "publisher"):
            if not str(o.get(key) or "").strip():
                p.append(f"{where}: {key} is required")
        if o.get("directness") not in DIRECTNESS:
            p.append(f"{where}: directness must be direct or indirect")
        if not _date_ok(o.get("checked_on")):
            p.append(f"{where}: checked_on must be a past YYYY-MM-DD date")
    if status in ("measured_limited", "measured_comparable") and not classes:
        p.append(f"{name}: demand_status {status} needs at least one observed value")
    if status == "measured_comparable" and (len(classes) < 2 or max(cohorts.values(), default=0) < 2):
        p.append(f"{name}: measured_comparable needs two evidence classes and two comparable "
                 "observations in one cohort")

    factors = data.get("factors") or {}
    for key in factors:
        if key not in WEIGHTS:
            p.append(f"{name}: unknown factor '{key}'")
    for key in WEIGHTS:
        f = factors.get(key) or {}
        score = f.get("score")
        if score is None:
            continue
        if not isinstance(score, int) or isinstance(score, bool) or not 0 <= score <= 5:
            p.append(f"{name}: factors.{key}.score must be an integer 0-5 or null (unknown)")
            continue
        if not f.get("evidence"):
            p.append(f"{name}: factors.{key} has a score but no evidence")
        if not str(f.get("rated_by") or "").strip():
            p.append(f"{name}: factors.{key} has a score but no rated_by")
    demand_score = (factors.get("demand") or {}).get("score")
    if demand_score is not None and status not in ("measured_limited", "measured_comparable"):
        p.append(f"{name}: a demand score needs measured demand (demand_status measured_*)")
    if lane == "high_demand" and (demand_score is None or status not in ("measured_limited", "measured_comparable")):
        p.append(f"{name}: the high_demand lane needs measured demand")

    gates = data.get("gates") or {}
    for g in GATES:
        if gates.get(g) not in (True, False, None):
            p.append(f"{name}: gates.{g} must be true, false or null")
    rec = data.get("recommendation")
    if rec not in RECOMMENDATIONS:
        p.append(f"{name}: recommendation must be one of {sorted(RECOMMENDATIONS)}")
    if rec in BUILDING and any(gates.get(g) is not True for g in GATES):
        p.append(f"{name}: recommendation {rec} needs every hard gate passed (gates come before scoring)")
    if rec == "defer":
        if data.get("defer_reason") not in DEFER_REASONS:
            p.append(f"{name}: defer needs defer_reason from {sorted(DEFER_REASONS)}")
        if not str(data.get("revisit_trigger") or "").strip():
            p.append(f"{name}: defer needs a revisit_trigger")
    effort = data.get("effort") or {}
    if effort.get("size") not in EFFORT or not str(effort.get("reason") or "").strip():
        p.append(f"{name}: effort needs size S/M/L and a reason")
    override = data.get("override")
    if override is not None:
        if not str(override.get("reason") or "").strip() or not _date_ok(override.get("date")):
            p.append(f"{name}: an override needs a reason and a past date")
    return p


def check_source(path: Path, data: dict, registry: dict) -> list[str]:
    name = path.name
    p: list[str] = []
    for key in _personal_keys(data):
        p.append(f"{name}: personal field '{key}' is not allowed")
    if not SLUG.match(str(data.get("id", ""))) or data.get("id") != path.stem:
        p.append(f"{name}: id must be a slug equal to the file name")
    for key in ("publisher", "resource"):
        if not str(data.get(key) or "").strip():
            p.append(f"{name}: {key} is required")
    if not URL.match(str(data.get("canonical_url") or "")):
        p.append(f"{name}: canonical_url must be an https URL")
    if not _date_ok(data.get("metadata_checked_at")):
        p.append(f"{name}: metadata_checked_at must be a past YYYY-MM-DD date")
    rights = data.get("rights_review_state")
    if rights not in RIGHTS_STATES:
        p.append(f"{name}: rights_review_state must be one of {sorted(RIGHTS_STATES)}")
    actions = set(data.get("permitted_actions") or [])
    if not actions <= ALL_ACTIONS:
        p.append(f"{name}: unknown permitted_actions {sorted(actions - ALL_ACTIONS)}")
    if rights != "verified" and not actions <= SAFE_ACTIONS:
        p.append(f"{name}: without verified rights only discover, link and reference are allowed")
    if rights == "verified" and not URL.match(str(data.get("license_evidence_locator") or "")):
        p.append(f"{name}: verified rights need an https license_evidence_locator")
    rec = data.get("recommendation")
    if rec not in SOURCE_RECOMMENDATIONS:
        p.append(f"{name}: recommendation must be one of {sorted(SOURCE_RECOMMENDATIONS)}")
    if rec == "defer" and (data.get("defer_reason") not in DEFER_REASONS
                           or not str(data.get("revisit_trigger") or "").strip()):
        p.append(f"{name}: defer needs a defer_reason and a revisit_trigger")
    reg_id = data.get("registry_source_id")
    if reg_id is not None:
        entry = registry.get(reg_id)
        if entry is None:
            p.append(f"{name}: registry_source_id '{reg_id}' is not in data/content_sources.json")
        else:
            allowed = set(entry.get("allowed_uses") or [])
            extra = actions - SAFE_ACTIONS - allowed
            if extra:
                p.append(f"{name}: permitted_actions {sorted(extra)} go beyond the registry's allowed_uses")
    elif actions - SAFE_ACTIONS:
        p.append(f"{name}: actions beyond discover/link/reference need a registry_source_id")
    return p


def load_registry() -> dict:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    return {s["id"]: s for s in data["sources"]}


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    registry = load_registry()
    problems: list[str] = []
    opportunities = []
    counts = {"opportunities": 0, "sources": 0}
    for kind, folder in (("opportunities", RESEARCH / "opportunities"), ("sources", RESEARCH / "sources")):
        for path in sorted(folder.glob("*.yaml")):
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            counts[kind] += 1
            if kind == "opportunities":
                problems += check_opportunity(path, data)
                opportunities.append((data, priority(data.get("factors") or {})))
            else:
                problems += check_source(path, data, registry)
    for problem in problems:
        print(f"ERROR: {problem}")
    if "--report" in argv:
        print("lane | id | known weight | provisional | bounds | usable | recommendation")
        for data, pr in sorted(opportunities, key=lambda x: (str(x[0].get("lane")), -(x[1]["provisional_score"] or -1))):
            print(f"{data.get('lane')} | {data.get('id')} | {pr['known_weight']}% | "
                  f"{pr['provisional_score']} | {pr['lower_bound']}-{pr['upper_bound']} | "
                  f"{'yes' if pr['usable'] else 'no (under 70% known)'} | {data.get('recommendation')}")
    if problems:
        print(f"Research check FAILED: {len(problems)} problem(s).")
        return 1
    print(f"Research check PASS: {counts['opportunities']} opportunity file(s), {counts['sources']} source file(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
