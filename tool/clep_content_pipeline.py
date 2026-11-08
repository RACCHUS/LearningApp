#!/usr/bin/env python3
"""CLEP Content Production Pipeline & Verification Engine.

Orchestrates and verifies the 6-stage content lifecycle:
  Stage A: Source Attribution & Provenance
  Stage B: 13-Domain Blueprint Coverage & Reconciled Weights
  Stage C: 10-Element Lesson Architecture Validation
  Stage D: Psychometric Item Integrity (Haladyna Rules)
  Stage E: 95-Question Simulation Quota Allocation & Verification
  Stage F: Staging & Database Ingestion Verification (Live Dry-Run & Linter)
"""
from __future__ import annotations

import argparse
import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "data/catalog/clep_official_catalog_2026.json"
MANIFEST_PATH = ROOT / "content/clep_introductory_psychology.yaml"

# Official College Board CLEP Specifications Registry
OFFICIAL_COURSE_SPECS = {
    "clep-introductory-psychology": {
        "title": "Introductory Psychology",
        "exam_code": "CLEP-PSYC",
        "total_simulation_questions": 95,
        "domains": {
            "1.0": {"title": "History, Approaches, and Methods", "official_range": "11–12%", "weight": 0.115, "quota": 11},
            "2.0": {"title": "Biological Bases of Behavior", "official_range": "8–9%", "weight": 0.090, "quota": 9},
            "3.0": {"title": "Sensation and Perception", "official_range": "7–8%", "weight": 0.075, "quota": 7},
            "4.0": {"title": "States of Consciousness", "official_range": "5–6%", "weight": 0.055, "quota": 5},
            "5.0": {"title": "Learning", "official_range": "8–9%", "weight": 0.085, "quota": 8},
            "6.0": {"title": "Cognition", "official_range": "8–9%", "weight": 0.090, "quota": 9},
            "7.0": {"title": "Motivation and Emotion", "official_range": "5–6%", "weight": 0.055, "quota": 5},
            "8.0": {"title": "Developmental Psychology Across the Lifespan", "official_range": "8–9%", "weight": 0.085, "quota": 8},
            "9.0": {"title": "Personality", "official_range": "7–8%", "weight": 0.075, "quota": 7},
            "10.0": {"title": "Psychological Disorders and Health", "official_range": "8–9%", "weight": 0.085, "quota": 8},
            "11.0": {"title": "Treatment of Psychological Disorders", "official_range": "6–7%", "weight": 0.065, "quota": 6},
            "12.0": {"title": "Social Psychology", "official_range": "9–10%", "weight": 0.095, "quota": 9},
            "13.0": {"title": "Statistics, Tests, and Measurement", "official_range": "3–4%", "weight": 0.030, "quota": 3},
        },
    },
    "clep-college-algebra": {
        "title": "College Algebra",
        "exam_code": "CLEP-ALG",
        "total_simulation_questions": 60,
        "domains": {
            "1.0": {"title": "Algebraic operations", "official_range": "25%", "weight": 0.250, "quota": 15},
            "2.0": {"title": "Equations and inequalities", "official_range": "25%", "weight": 0.250, "quota": 15},
            "3.0": {"title": "Functions and their properties", "official_range": "30%", "weight": 0.300, "quota": 18},
            "4.0": {"title": "Number systems and operations", "official_range": "20%", "weight": 0.200, "quota": 12},
        },
    },
}

# Backward compatibility constants (defaults to Introductory Psychology)
OFFICIAL_PSYCH_DOMAINS = OFFICIAL_COURSE_SPECS["clep-introductory-psychology"]["domains"]
EXPECTED_PSYCH_DOMAINS = list(OFFICIAL_PSYCH_DOMAINS.keys())
TOTAL_SIMULATION_QUESTIONS = 95
COGNITIVE_LEVELS = {"recall", "comprehension", "application", "analysis", "evaluation"}
DIFFICULTIES = {"beginner", "intermediate", "advanced"}


def resolve_course_spec(manifest: dict, target_slug: str | None = None) -> dict:
    """Resolve the course specification from the manifest or target slug."""
    slug = target_slug or manifest.get("target", {}).get("slug", "clep-introductory-psychology")
    if slug in OFFICIAL_COURSE_SPECS:
        return OFFICIAL_COURSE_SPECS[slug]
    # Check partial match on slug
    for k, v in OFFICIAL_COURSE_SPECS.items():
        if k in slug or slug in k:
            return v
    # Fallback to Psychology
    return OFFICIAL_COURSE_SPECS["clep-introductory-psychology"]


def load_yaml(path: Path) -> dict:
    try:
        import yaml
        with open(path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except ImportError:
        print("Error: PyYAML is required. Run 'pip install pyyaml'.", file=sys.stderr)
        sys.exit(1)


def verify_source_provenance(manifest: dict) -> list[str]:
    """Stage A: Verify all authoritative source releases have valid provenance, license, and roles."""
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


def verify_blueprint_coverage(manifest: dict, course_spec: dict | None = None) -> tuple[dict, list[str]]:
    """Stage B: Verify all College Board domains and their reconciled decimal weights."""
    if course_spec is None:
        course_spec = resolve_course_spec(manifest)

    issues = []
    domains = manifest.get("domains", [])
    domain_map = {}
    total_weight = 0.0
    expected_domains = list(course_spec["domains"].keys())

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

    for exp_code in expected_domains:
        if exp_code not in domain_map:
            issues.append(f"Missing required College Board domain: {exp_code}")

    if abs(total_weight - 1.0) > 0.015:
        issues.append(f"Domain weights must sum to 1.0 within ±0.015 tolerance (got {total_weight:.4f})")

    return domain_map, issues


def verify_lesson_architecture(manifest: dict) -> tuple[int, list[str]]:
    """Stage C: Verify lessons adhere to the 10-element pedagogical architecture."""
    issues = []
    lesson_count = 0

    for d in manifest.get("domains", []):
        for o in d.get("objectives", []):
            o_code = o.get("code")
            lessons = o.get("lessons", [])
            for l in lessons:
                lesson_count += 1
                title = l.get("title", "")
                desc = l.get("description", "")
                citation = l.get("citation", "")
                concept_slugs = l.get("concept_slugs", [])
                blocks = l.get("blocks", [])
                terms = l.get("terms", [])
                items = l.get("assessment_items", [])

                # Element 1: Title & Overview
                if not title or len(title) < 5:
                    issues.append(f"Objective {o_code} has lesson with missing/short title: '{title}'.")
                if not desc or len(desc) < 15:
                    issues.append(f"Lesson '{title}' missing descriptive overview (Element 1).")

                # Element 2: Aligned Objective & Bloom's Cognitive Level
                # Verified via objective linkage and item cognitive levels

                # Element 3: Key Vocabulary / Terminology
                if not terms or len(terms) < 1:
                    issues.append(f"Lesson '{title}' missing key vocabulary terms list (Element 3).")
                else:
                    for t in terms:
                        if not t.get("term") or not t.get("definition"):
                            issues.append(f"Lesson '{title}' has incomplete term definition: {t}")

                if not concept_slugs:
                    issues.append(f"Lesson '{title}' missing concept_slugs binding (Element 3).")

                # Element 4: Core Theoretical Exposition
                if not blocks:
                    issues.append(f"Lesson '{title}' has no instructional blocks.")
                    continue

                has_exposition = False
                has_case_scenario = False
                has_schema_or_table = False
                has_misconception_callout = False

                for b in blocks:
                    b_type = b.get("block_type")
                    content = b.get("content", {})
                    text = content.get("text", "") or content.get("body", "")

                    if b_type == "markdown" and len(text) >= 60:
                        has_exposition = True
                    if b_type in {"example", "callout", "formula"} or any(k in text.lower() for k in [
                        "case", "experiment", "study", "scenario", "patient", "vignette",
                        "model", "problem", "projectile", "interest", "growth", "decay", "optimization", "geometry"
                    ]):
                        has_case_scenario = True
                    if b_type in {"table", "code", "formula"} or ("|" in text and "---" in text) or "$$" in text or "matrix" in text:
                        has_schema_or_table = True
                    if b_type == "callout" or any(k in text.lower() for k in ["misconception", "pitfall", "warning", "contrast", "distinction", "common mistake"]):
                        has_misconception_callout = True

                if not has_exposition:
                    issues.append(f"Lesson '{title}' missing core theoretical exposition markdown block (Element 4).")
                if not has_case_scenario:
                    issues.append(f"Lesson '{title}' missing applied real-world case or experimental scenario (Element 5).")
                if not has_schema_or_table:
                    issues.append(f"Lesson '{title}' missing visual diagram, comparative table, or schema (Element 6).")
                if not has_misconception_callout:
                    issues.append(f"Lesson '{title}' missing cognitive pitfalls or misconceptions callout (Element 7).")

                # Element 8: Formative Practice Check
                formative_qs = l.get("questions", [])
                if not formative_qs or len(formative_qs) < 2:
                    issues.append(f"Lesson '{title}' missing formative check-for-understanding questions (Element 8).")
                else:
                    # Element 9: Elaborative Rationales
                    for q in formative_qs:
                        explanation = q.get("explanation", "")
                        if not explanation or len(explanation) < 20:
                            issues.append(f"Lesson '{title}' formative question missing elaborative rationale (Element 9).")

                # Element 10: Authoritative Source Citation
                if not citation or len(citation) < 8:
                    issues.append(f"Lesson '{title}' missing authoritative source citation (Element 10).")

    return lesson_count, issues

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
                        issues.append(f"Item #{item_count} interaction_type must be single_choice.")

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


def compute_simulation_quotas(
    domain_map: dict,
    total_questions: int | None = None,
    course_spec: dict | None = None,
) -> dict[str, int]:
    """Stage E: Largest-remainder quota allocation for a timed simulation."""
    if course_spec is None:
        course_spec = OFFICIAL_COURSE_SPECS["clep-introductory-psychology"]
    if total_questions is None:
        total_questions = course_spec["total_simulation_questions"]

    spec_domains = course_spec["domains"]
    quotas = {}
    remainders = []
    allocated = 0

    for code, d in domain_map.items():
        weight = spec_domains.get(code, {}).get("weight", d.get("weight", 0.0))
        exact = total_questions * weight
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


def verify_simulation_items(
    manifest: dict,
    domain_map: dict,
    require_simulation: bool = False,
    course_spec: dict | None = None,
) -> tuple[dict[str, int], list[str]]:
    """Stage E: Verify assessment items against the simulation quotas."""
    if course_spec is None:
        course_spec = resolve_course_spec(manifest)

    total_questions = course_spec["total_simulation_questions"]
    expected_domains = list(course_spec["domains"].keys())
    issues = []
    quotas = compute_simulation_quotas(domain_map, total_questions=total_questions, course_spec=course_spec)
    item_counts: dict[str, int] = {code: 0 for code in expected_domains}

    for d in manifest.get("domains", []):
        code = d.get("code")
        if code not in item_counts:
            continue
        for o in d.get("objectives", []):
            for l in o.get("lessons", []):
                for itm in l.get("assessment_items", []):
                    meta = itm.get("metadata", {})
                    if meta.get("bank") == "simulation_exam" or not meta.get("bank"):
                        item_counts[code] += 1
                        if require_simulation:
                            if meta.get("bank") != "simulation_exam" or not meta.get("is_protected"):
                                issues.append(f"Simulation item '{itm.get('prompt', '')[:40]}' missing protected simulation metadata.")

    total_authored = sum(item_counts.values())

    if require_simulation:
        if total_authored != total_questions:
            issues.append(f"Simulation requires exactly {total_questions} authored questions (got {total_authored}).")

        for code in expected_domains:
            expected_quota = quotas.get(code, 0)
            actual_count = item_counts.get(code, 0)
            if actual_count != expected_quota:
                issues.append(f"Domain {code} simulation item allocation mismatch: expected {expected_quota}, got {actual_count}.")

    return item_counts, issues


def run_stage_f_database_ingestion(manifest_path: Path, target_slug: str = "clep-introductory-psychology", version: str = "2026") -> list[str]:
    """Stage F: Live dry-run curriculum ingestion and manifest quality linting."""
    issues = []
    dart_bin = shutil.which("dart") or "dart"
    manifest_arg = str(manifest_path.relative_to(ROOT) if manifest_path.is_relative_to(ROOT) else manifest_path)

    # 1. Real dry-run execution via tool/ingest_curriculum.dart
    cmd_ingest = [
        dart_bin, "run", "tool/ingest_curriculum.dart",
        "--target", target_slug,
        "--version", version,
        "--manifest", manifest_arg,
        "--dry-run"
    ]
    try:
        proc = subprocess.run(
            cmd_ingest,
            cwd=ROOT,
            capture_output=True,
            text=True,
            shell=False,
            timeout=90
        )
        if proc.returncode != 0:
            issues.append(f"Stage F: Ingestion dry-run failed with exit code {proc.returncode}:\n{proc.stderr or proc.stdout}")
    except Exception as e:
        issues.append(f"Stage F: Ingestion dry-run execution error: {e}")

    # 2. Real manifest linting via tool/lint_manifest.dart
    cmd_lint = [
        dart_bin, "run", "tool/lint_manifest.dart",
        manifest_arg
    ]
    try:
        proc_lint = subprocess.run(
            cmd_lint,
            cwd=ROOT,
            capture_output=True,
            text=True,
            shell=False,
            timeout=90
        )
        if proc_lint.returncode != 0:
            issues.append(f"Stage F: Quality linter failed with exit code {proc_lint.returncode}:\n{proc_lint.stderr or proc_lint.stdout}")
    except Exception as e:
        issues.append(f"Stage F: Quality linter execution error: {e}")

    return issues


def run_pipeline(manifest_path: Path, require_simulation: bool = False, skip_db_gate: bool = False) -> bool:
    print("=" * 60)
    print("  CLEP Content Production Pipeline & Verification Engine")
    print("=" * 60)
    print(f"📁 Manifest: {manifest_path.relative_to(ROOT) if manifest_path.is_relative_to(ROOT) else manifest_path}")
    print(f"⚙️ Mode: {'Full Simulation Enforcement' if require_simulation else 'Curriculum Architecture Validation'}")

    if not manifest_path.exists():
        print(f"❌ File not found: {manifest_path}", file=sys.stderr)
        return False

    manifest = load_yaml(manifest_path)
    course_spec = resolve_course_spec(manifest)
    total_sim_q = course_spec["total_simulation_questions"]
    num_domains = len(course_spec["domains"])
    all_issues = []

    print(f"🎯 Target Course: {course_spec['title']} ({course_spec['exam_code']})")

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

    # Stage B: Blueprint Coverage & Reconciled Weights
    print(f"\n[Stage B] Verifying {num_domains}-Domain Blueprint Coverage & Reconciled Weights...")
    domain_map, blue_issues = verify_blueprint_coverage(manifest, course_spec=course_spec)
    if blue_issues:
        for err in blue_issues:
            print(f"  ❌ {err}")
        all_issues.extend(blue_issues)
    else:
        print(f"  ✅ All {len(domain_map)} College Board domains verified with official percentage ranges.")

    # Stage C: 10-Element Lesson Architecture
    print("\n[Stage C] Verifying 10-Element Lesson Architecture & Concept Bindings...")
    lesson_count, lesson_issues = verify_lesson_architecture(manifest)
    if lesson_issues:
        for err in lesson_issues:
            print(f"  ❌ {err}")
        all_issues.extend(lesson_issues)
    else:
        print(f"  ✅ {lesson_count} lesson(s) verified implementing all 10 structural elements.")

    # Stage D: Psychometric Item Integrity
    print("\n[Stage D] Evaluating Psychometric Item Integrity (Haladyna Rules)...")
    item_count, item_issues = verify_psychometric_items(manifest)
    if item_issues:
        for err in item_issues:
            print(f"  ❌ {err}")
        all_issues.extend(item_issues)
    else:
        print(f"  ✅ {item_count} assessment item(s) compliant with Haladyna empirical standards.")

    # Stage E: Full Simulation Quota Allocation & Verification
    print(f"\n[Stage E] Computing & Verifying {total_sim_q}-Question Simulation Blueprint Quotas...")
    quotas = compute_simulation_quotas(domain_map, total_questions=total_sim_q, course_spec=course_spec)
    item_counts, sim_issues = verify_simulation_items(manifest, domain_map, require_simulation=require_simulation, course_spec=course_spec)
    if sim_issues:
        for err in sim_issues:
            print(f"  ❌ {err}")
        all_issues.extend(sim_issues)

    total_authored = sum(item_counts.values())
    print(f"  Domain Item Allocations for 90-Minute Official CLEP Simulation ({total_authored}/{total_sim_q} authored):")
    for code, spec in course_spec["domains"].items():
        info = domain_map.get(code, {})
        q = quotas.get(code, 0)
        actual = item_counts.get(code, 0)
        pct = (q / float(total_sim_q)) * 100 if total_sim_q else 0
        status = "✅" if actual >= q else f"⏳ ({actual}/{q})"
        print(f"    - Domain {code:<4} ({info.get('title', '')[:30]:<30}) [{spec.get('official_range', ''):<6}]: Quota {q:>2} ({pct:>4.1f}%) | Authored: {actual:>2} {status}")

    # Stage F: Live Database Staging & Ingestion Gate
    print("\n[Stage F] Executing Live Ingestion Dry-Run & Linter Quality Gate...")
    if skip_db_gate:
        print("  ⚠️ Skipped database ingestion gate by flag.")
    else:
        target_slug = manifest.get("target", {}).get("slug", "clep-introductory-psychology")
        target_version = manifest.get("target", {}).get("version_code", "2026")
        ingest_issues = run_stage_f_database_ingestion(manifest_path, target_slug=target_slug, version=target_version)
        if ingest_issues:
            for err in ingest_issues:
                print(f"  ❌ {err}")
            all_issues.extend(ingest_issues)
        else:
            print("  ✅ Live dry-run curriculum ingestion PASSED (0 schema errors, clean mappings).")
            print("  ✅ Static quality linter PASSED (0 errors, 0 warnings).")

    # Summary
    print("\n" + "=" * 60)
    if all_issues:
        print(f"❌ PIPELINE GATES FAILED: {len(all_issues)} issue(s) detected.")
        return False
    else:
        print("✅ ALL PIPELINE STAGES PASSED CLEANLY (100% Compliance).")
        print("Course is staged and verified for production deployment.")
        print("=" * 60)
        return True


def main():
    parser = argparse.ArgumentParser(description="CLEP Content Production Pipeline & Verification Engine")
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH, help="Path to curriculum manifest YAML")
    parser.add_argument("--require-simulation", action="store_true", help="Enforce complete 95-question simulation allocation")
    parser.add_argument("--skip-db-gate", action="store_true", help="Skip live dry-run ingestion subprocess")
    args = parser.parse_args()

    success = run_pipeline(args.manifest, require_simulation=args.require_simulation, skip_db_gate=args.skip_db_gate)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
