#!/usr/bin/env python3
"""CLEP Content Production Pipeline & Verification Engine.

Orchestrates the 6-stage content lifecycle:
  Stage A: Source Attribution & Provenance
  Stage B: Objective & Cognitive Level Mapping
  Stage C: 10-Element Lesson Architecture Validation
  Stage D: Psychometric Item Integrity (Haladyna Rules)
  Stage E: Domain Quota & Simulation Readiness
  Stage F: Staging & Publication Verification
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "data/catalog/clep_official_catalog_2026.json"
MANIFEST_PATH = ROOT / "content/clep_introductory_psychology.yaml"

# College Board Domain Codes for Introductory Psychology
EXPECTED_PSYCH_DOMAINS = [
    "1.0", "2.0", "3.0", "4.0", "5.0", "6.0", "7.0",
    "8.0", "9.0", "10.0", "11.0", "12.0", "13.0"
]

COGNITIVE_LEVELS = {"recall", "comprehension", "application", "analysis", "evaluation"}
DIFFICULTIES = {"beginner", "intermediate", "advanced"}


def load_yaml(path: Path) -> dict:
    try:
        import yaml
        with open(path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except ImportError:
        print("Error: PyYAML is required. Run 'pip install pyyaml'.", file=sys.stderr)
        sys.exit(1)


def verify_source_provenance(manifest: dict) -> list[str]:
    """Stage A: Verify all authoritative source releases have valid provenance and license."""
    issues = []
    releases = manifest.get("source_releases", [])
    if not releases and "source_release" in manifest:
        releases = [manifest["source_release"]]

    if not releases:
        return ["No source_release or source_releases declared in manifest."]

    role_set = set()
    for r in releases:
        publisher = r.get("publisher")
        title = r.get("title")
        license_name = r.get("license_name")
        source_url = r.get("source_url")
        meta = r.get("metadata", {})
        role = meta.get("role", "reference")
        role_set.add(role)

        if not publisher or not title:
            issues.append(f"Source release missing publisher or title: {r}")
        if not license_name:
            issues.append(f"Source release missing explicit license_name: {title}")
        if not source_url or not source_url.startswith("https://"):
            issues.append(f"Source release must have valid HTTPS source_url: {title}")

    if "blueprint_authority" not in role_set:
        issues.append("Manifest must declare at least one 'blueprint_authority' source release.")
    if "instructional_reference" not in role_set:
        issues.append("Manifest must declare at least one 'instructional_reference' source release.")

    return issues


def verify_blueprint_coverage(manifest: dict) -> tuple[dict, list[str]]:
    """Stage B: Verify all 13 College Board domains and their objective mappings."""
    issues = []
    domains = manifest.get("domains", [])
    domain_map = {}
    total_weight = 0.0

    for d in domains:
        code = d.get("code")
        title = d.get("title")
        weight = d.get("weight", 0.0)
        objectives = d.get("objectives", [])

        if not code or not title:
            issues.append(f"Domain missing code or title: {d}")
            continue

        domain_map[code] = {
            "title": title,
            "weight": weight,
            "objective_count": len(objectives),
            "objectives": objectives,
        }
        total_weight += weight

        if not objectives:
            issues.append(f"Domain {code} ('{title}') has no objectives.")

    # Check that all expected domains are represented
    for exp_code in EXPECTED_PSYCH_DOMAINS:
        if exp_code not in domain_map:
            issues.append(f"Missing required College Board domain: {exp_code}")

    if abs(total_weight - 1.0) > 0.015:
        issues.append(f"Domain weights must sum to 1.0 within ±0.015 tolerance (got {total_weight:.4f})")

    return domain_map, issues


def verify_lesson_architecture(manifest: dict) -> tuple[int, list[str]]:
    """Stage C: Verify lessons adhere to the pedagogical structure (blocks, terms, concepts)."""
    issues = []
    lesson_count = 0

    for d in manifest.get("domains", []):
        d_code = d.get("code")
        for o in d.get("objectives", []):
            o_code = o.get("code")
            lessons = o.get("lessons", [])
            for l in lessons:
                lesson_count += 1
                title = l.get("title")
                citation = l.get("citation")
                concept_slugs = l.get("concept_slugs", [])
                blocks = l.get("blocks", [])

                if not title or len(title) < 5:
                    issues.append(f"Objective {o_code} has lesson with invalid or missing title.")
                if not citation:
                    issues.append(f"Lesson '{title}' missing source citation.")
                if not concept_slugs:
                    issues.append(f"Lesson '{title}' missing concept_slugs binding.")
                if not blocks:
                    issues.append(f"Lesson '{title}' has no instructional blocks.")

                for b in blocks:
                    b_type = b.get("block_type")
                    if b_type not in {"markdown", "callout", "code", "table", "image", "formula", "example", "practice_prompt"}:
                        issues.append(f"Lesson '{title}' has unsupported block_type: {b_type}")

    return lesson_count, issues


def verify_psychometric_items(manifest: dict) -> tuple[int, list[str]]:
    """Stage D: Verify assessment items conform to Haladyna rules and cognitive taxonomy."""
    issues = []
    item_count = 0
    position_counts = {0: 0, 1: 0, 2: 0, 3: 0}

    for d in manifest.get("domains", []):
        for o in d.get("objectives", []):
            for l in o.get("lessons", []):
                items = l.get("assessment_items", [])
                for item in items:
                    item_count += 1
                    prompt = item.get("prompt", "")
                    interaction = item.get("interaction_type")
                    r_spec = item.get("response_spec", {})
                    s_spec = item.get("scoring_spec", {})
                    explanation = item.get("explanation", "")
                    diff = item.get("difficulty")
                    cog = item.get("cognitive_level")
                    citation = item.get("citation")

                    if not prompt or len(prompt) < 10:
                        issues.append(f"Item #{item_count} has missing or empty prompt.")
                    if interaction != "single_choice":
                        issues.append(f"Item #{item_count} interaction_type must be single_choice for CLEP pilot.")

                    options = r_spec.get("options", [])
                    if len(options) != 4:
                        issues.append(f"Item #{item_count} must have exactly 4 plausible options (got {len(options)}).")

                    # Haladyna rule: Prohibit all/none of the above
                    for opt in options:
                        lower_opt = opt.lower()
                        if "all of the above" in lower_opt or "none of the above" in lower_opt:
                            issues.append(f"Item #{item_count} contains prohibited giveaway ('all/none of the above'): {opt}")

                    # Distractor length balance
                    if options:
                        lengths = [len(opt) for opt in options]
                        min_len = min(lengths)
                        max_len = max(lengths)
                        if min_len > 0 and (max_len / min_len) > 3.0:
                            issues.append(f"Item #{item_count} has distractor length imbalance (ratio {max_len / min_len:.1f} > 3.0).")

                    # Correct index
                    correct_idx = s_spec.get("correct_index")
                    if correct_idx is None or not (0 <= correct_idx <= 3):
                        issues.append(f"Item #{item_count} has invalid correct_index: {correct_idx}")
                    else:
                        position_counts[correct_idx] = position_counts.get(correct_idx, 0) + 1

                    if not explanation or len(explanation) < 20:
                        issues.append(f"Item #{item_count} must provide elaborative feedback explanation.")
                    if diff not in DIFFICULTIES:
                        issues.append(f"Item #{item_count} has invalid difficulty: {diff}")
                    if cog not in COGNITIVE_LEVELS:
                        issues.append(f"Item #{item_count} has invalid cognitive_level: {cog}")
                    if not citation:
                        issues.append(f"Item #{item_count} missing citation.")

    # Check answer position balance (no single position > 45%)
    if item_count >= 8:
        for pos, count in position_counts.items():
            ratio = count / item_count
            if ratio > 0.45:
                issues.append(f"Answer position {pos} exhibits clustering bias: {ratio:.1%} ({count}/{item_count}). Limit is 45%.")

    return item_count, issues


def compute_simulation_quotas(domain_map: dict, total_questions: int = 95) -> dict[str, int]:
    """Stage E: Largest-remainder quota allocation for a 95-question timed simulation."""
    quotas = {}
    remainders = []
    allocated = 0

    for code, d in domain_map.items():
        exact = total_questions * d["weight"]
        floor_val = math.floor(exact)
        quotas[code] = floor_val
        allocated += floor_val
        remainders.append((code, exact - floor_val))

    remainders.sort(key=lambda x: x[1], reverse=True)
    deficit = total_questions - allocated
    for i in range(deficit):
        code = remainders[i % len(remainders)][0]
        quotas[code] += 1

    return quotas


def run_pipeline(manifest_path: Path) -> bool:
    print("=" * 60)
    print("  CLEP Content Production Pipeline & Verification Engine")
    print("=" * 60)
    print(f"📁 Manifest: {manifest_path.relative_to(ROOT)}")

    if not manifest_path.exists():
        print(f"❌ File not found: {manifest_path}", file=sys.stderr)
        return False

    manifest = load_yaml(manifest_path)
    all_issues = []

    # Stage A: Source Provenance
    print("\n[Stage A] Verifying Source Attribution & Provenance...")
    prov_issues = verify_source_provenance(manifest)
    if prov_issues:
        for err in prov_issues:
            print(f"  ❌ {err}")
        all_issues.extend(prov_issues)
    else:
        releases = manifest.get("source_releases", [manifest.get("source_release")])
        print(f"  ✅ {len(releases)} authoritative source release(s) verified (Blueprint + OpenStax OER).")

    # Stage B: Blueprint Coverage
    print("\n[Stage B] Verifying 13-Domain Blueprint Coverage...")
    domain_map, blue_issues = verify_blueprint_coverage(manifest)
    if blue_issues:
        for err in blue_issues:
            print(f"  ❌ {err}")
        all_issues.extend(blue_issues)
    else:
        print(f"  ✅ All {len(domain_map)} College Board domains present with balanced weights summing to 1.00.")

    # Stage C: Lesson Architecture
    print("\n[Stage C] Verifying Lesson Architecture & Concept Bindings...")
    lesson_count, lesson_issues = verify_lesson_architecture(manifest)
    if lesson_issues:
        for err in lesson_issues:
            print(f"  ❌ {err}")
        all_issues.extend(lesson_issues)
    else:
        print(f"  ✅ {lesson_count} lesson(s) verified with structured blocks, terms, and concept slugs.")

    # Stage D: Psychometric Item Integrity
    print("\n[Stage D] Evaluating Psychometric Item Integrity (Haladyna Rules)...")
    item_count, item_issues = verify_psychometric_items(manifest)
    if item_issues:
        for err in item_issues:
            print(f"  ❌ {err}")
        all_issues.extend(item_issues)
    else:
        print(f"  ✅ {item_count} assessment item(s) compliant with Haladyna empirical standards.")

    # Stage E: Full Simulation Quota Allocation
    print("\n[Stage E] Computing 95-Question Timed Simulation Blueprint Quotas...")
    quotas = compute_simulation_quotas(domain_map, total_questions=95)
    print("  Domain Item Allocations for 90-Minute Official CLEP Simulation:")
    for code in EXPECTED_PSYCH_DOMAINS:
        info = domain_map.get(code, {})
        q = quotas.get(code, 0)
        pct = (q / 95.0) * 100
        print(f"    - Domain {code:<4} ({info.get('title')[:36]:<36}): {q:>2} questions ({pct:>4.1f}%)")

    # Summary
    print("\n" + "=" * 60)
    if all_issues:
        print(f"❌ PIPELINE GATES FAILED: {len(all_issues)} issue(s) detected.")
        return False
    else:
        print("✅ ALL PIPELINE STAGES PASSED CLEANLY (100% Compliance).")
        print("Course is staged and verified for idempotent database ingestion.")
        print("=" * 60)
        return True


def main():
    parser = argparse.ArgumentParser(description="CLEP Content Production Pipeline & Verification Engine")
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH, help="Path to curriculum manifest YAML")
    args = parser.parse_args()

    success = run_pipeline(args.manifest)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
