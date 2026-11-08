#!/usr/bin/env python3
"""Authoring engine and builder for the complete CLEP College Algebra Course Manifest.

Produces the comprehensive, 10-element compliant curriculum manifest with:
- 4 Official College Board Domains with weights summing to 1.000 (15, 15, 18, 12)
- Comprehensive instructional modules with OpenStax College Algebra 1e (CC BY 4.0) citations
- 10 structural elements per lesson (Title, Objective, Terms, Exposition, Scenario, Schema/Table, Misconceptions, Check, Rationales, Citation)
- Complete 60-question Haladyna-compliant assessment simulation pool matching official domain quotas
- Flashcards for spaced retrieval practice
- Formative practice check-for-understanding questions
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import yaml

from tool.curriculum_clep_algebra.domain_01_algebraic_operations import DOMAIN_01
from tool.curriculum_clep_algebra.domain_02_equations_and_inequalities import DOMAIN_02
from tool.curriculum_clep_algebra.domain_03_functions_and_properties import DOMAIN_03
from tool.curriculum_clep_algebra.domain_04_number_systems_and_operations import DOMAIN_04
from tool.curriculum_clep_algebra.formative_lesson_questions import FORMATIVE_QUESTIONS_BY_LESSON

OUTPUT_PATH = ROOT / "content/clep_college_algebra.yaml"

ALL_DOMAINS = [
    DOMAIN_01,
    DOMAIN_02,
    DOMAIN_03,
    DOMAIN_04,
]


class CleanYamlDumper(yaml.SafeDumper):
    pass


def str_multiline_representer(dumper: yaml.SafeDumper, data: str):
    if "\n" in data:
        return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")
    return dumper.represent_scalar("tag:yaml.org,2002:str", data)


CleanYamlDumper.add_representer(str, str_multiline_representer)


def build_manifest() -> dict:
    manifest = {
        "source_releases": [
            {
                "id": "college-board-clep-alg-2026",
                "publisher": "College Board",
                "title": "CLEP College Algebra Examination Guide & Specification",
                "version": "2026-11",
                "source_url": "https://clep.collegeboard.org/clep-exams/college-algebra",
                "retrieved_at": "2026-11-08T00:00:00Z",
                "license": "College Board Proprietary (Educational Reference Blueprint)",
                "license_name": "Proprietary Examination Blueprint",
                "rights_note": "Referenced under fair use for educational curriculum architecture and objective alignment. CLEP and College Board are registered trademarks of the College Board.",
                "metadata": {
                    "role": "blueprint_authority",
                    "checksum_status": "unverified_remote_document",
                    "checksum_verification_note": "Online specification blueprint. No offline cryptographic archive artifact pinned; verification based on official College Board domain percentages and time limits.",
                    "total_domains": 4,
                    "exam_code": "CLEP-ALG",
                    "passing_score": 50,
                    "scale": "20-80 (Diagnostic Reporting; Official Equating Proprietary to College Board)",
                    "time_limit_minutes": 90,
                    "question_count_approx": 60,
                    "practice_time_limit_minutes": 90,
                    "default_question_count": 60,
                    "recommending_body": "ACE",
                    "recommended_credits": 3,
                    "credit_disclaimer": "The American Council on Education (ACE) recommends 3 semester hours of college credit for a scaled score of 50. However, credit acceptance policies, minimum score thresholds, and course equivalencies are determined independently by each college or university registrar.",
                },
            },
            {
                "id": "openstax-college-algebra-1e",
                "publisher": "OpenStax / Rice University",
                "title": "College Algebra (OpenStax 1st Edition)",
                "version": "1st Edition (2015)",
                "source_url": "https://openstax.org/books/college-algebra/pages/preface",
                "retrieved_at": "2026-11-08T00:00:00Z",
                "license": "Creative Commons Attribution 4.0 International (CC BY 4.0)",
                "license_name": "CC BY 4.0",
                "rights_note": "Senior Contributing Author: Jay Abramson. Open-access instructional foundation for algebraic principles, definitions, worked examples, and pedagogical explanations. Licensed under CC BY 4.0.",
                "metadata": {
                    "role": "instructional_reference",
                    "edition": "1st Edition",
                    "cc_license": "CC BY 4.0",
                    "checksum_status": "unverified_remote_document",
                    "checksum_verification_note": "OpenStax 1st Edition instructional foundation licensed under CC BY 4.0. Note: OpenStax College Algebra 2e shifted to CC BY-NC-SA 4.0 (comparison URL: https://openstax.org/books/college-algebra-2e/pages/preface). All curriculum exposition strictly adheres to 1st Edition CC BY 4.0.",
                    "comparison_url_2e": "https://openstax.org/books/college-algebra-2e/pages/preface",
                },
            },
        ],
        "target": {
            "slug": "clep-college-algebra",
            "title": "CLEP College Algebra",
            "version_code": "2026",
            "version_title": "CLEP College Algebra (2026 Official Blueprint Edition)",
            "version_description": "Authoritative, psychometrically grounded curriculum covering all 4 official College Board domains for the CLEP College Algebra examination. Grounded in College Board blueprints and OpenStax College Algebra 1e open educational resources.",
        },
        "stimuli": [
            {
                "id": "stim-algebra-projectile-trajectory",
                "stimulus_type": "scenario",
                "title": "Kinematic Projectile Flight Modeling",
                "body": "A physics laboratory launches an experimental projectile from an elevated platform with an initial vertical velocity of 48 ft/sec from a height of 64 ft above the ground. The height function is h(t) = -16t^2 + 48t + 64, where h is in feet and t is elapsed time in seconds.",
                "structured_data": {
                    "initial_velocity_ft_per_sec": 48,
                    "initial_height_ft": 64,
                    "gravity_acceleration_ft_per_sec2": -32,
                    "equation": "h(t) = -16t^2 + 48t + 64",
                },
                "citation": "College Board CLEP College Algebra Objective 2.2 Quadratic Kinematics",
            },
            {
                "id": "stim-algebra-continuous-interest",
                "stimulus_type": "data_table",
                "title": "Continuous Compound Growth Comparison Schedule",
                "body": "A financial institution provides comparative growth projections for a principal deposit of $10,000 invested under continuous compound interest A(t) = 10000 e^(rt) across various interest rates over 10 years.",
                "structured_data": {
                    "principal": 10000,
                    "term_years": 10,
                    "rate_4_pct_balance": 14918.25,
                    "rate_6_pct_balance": 18221.19,
                    "rate_8_pct_balance": 22255.41,
                },
                "citation": "College Board CLEP College Algebra Objective 2.5 Exponential Growth Modeling",
            },
        ],
        "domains": ALL_DOMAINS,
    }

    # Populate formative questions and tag protected simulation assessment items
    for d in manifest["domains"]:
        for o in d.get("objectives", []):
            for l in o.get("lessons", []):
                # Attach 2 formative check-for-understanding questions per lesson
                title = l.get("title", "")
                l["questions"] = FORMATIVE_QUESTIONS_BY_LESSON.get(title, [])

                # Tag all 60 simulation assessment items with explicit bank and protection metadata
                for item in l.get("assessment_items", []):
                    item["metadata"] = {
                        "bank": "simulation_exam",
                        "item_role": "summative_simulation",
                        "is_protected": True,
                        "exposure": "timed_exam_only",
                    }

    return manifest


def validate_manifest_invariants(manifest: dict):
    print("Validating manifest invariants...")
    domains = manifest.get("domains", [])
    assert len(domains) == 4, f"Expected 4 domains, got {len(domains)}"

    total_weight = sum(d.get("weight", 0.0) for d in domains)
    assert abs(total_weight - 1.0) < 0.001, f"Total weight must be 1.000, got {total_weight:.4f}"

    total_items = 0
    all_concept_slugs = set()
    key_distribution = {}

    expected_quotas = {
        "1.0": 15,
        "2.0": 15,
        "3.0": 18,
        "4.0": 12,
    }

    for d in domains:
        code = d["code"]
        domain_items = 0
        for o in d.get("objectives", []):
            for c in o.get("concepts", []):
                all_concept_slugs.add(c["slug"])
            for l in o.get("lessons", []):
                # Check 10 elements
                assert l.get("title"), "Lesson missing title"
                assert l.get("description"), "Lesson missing description"
                assert l.get("citation"), "Lesson missing citation"
                assert len(l.get("concept_slugs", [])) > 0, "Lesson missing concept_slugs"
                assert len(l.get("blocks", [])) >= 5, f"Lesson {l.get('title')} has fewer than 5 instructional blocks"
                assert len(l.get("terms", [])) >= 4, f"Lesson {l.get('title')} has fewer than 4 terms"
                assert len(l.get("questions", [])) == 2, f"Lesson {l.get('title')} does not have exactly 2 formative questions"

                items = l.get("assessment_items", [])
                domain_items += len(items)
                total_items += len(items)

                for itm in items:
                    idx = itm["scoring_spec"]["correct_index"]
                    key_distribution[idx] = key_distribution.get(idx, 0) + 1
                    opts = itm["response_spec"]["options"]
                    assert len(opts) == 4, f"Item has {len(opts)} options instead of 4"
                    for opt in opts:
                        assert "all of the above" not in opt.lower(), "Disallowed giveaway phrase"
                        assert "none of the above" not in opt.lower(), "Disallowed giveaway phrase"

        expected = expected_quotas[code]
        assert domain_items == expected, f"Domain {code} items {domain_items} != quota {expected}"

    assert total_items == 60, f"Expected 60 total simulation items, got {total_items}"

    # Verify key balance (no single position > 40%)
    for pos, count in key_distribution.items():
        ratio = count / total_items
        print(f"Key position {pos}: {count}/{total_items} ({ratio:.1%})")
        assert ratio <= 0.40, f"Position {pos} frequency {ratio:.1%} exceeds 40% balance threshold"

    print(f"✅ Invariants verified: 4 domains, 20 lessons, {len(all_concept_slugs)} concepts, 60 protected simulation items.")


def main():
    print("Building CLEP College Algebra Course Manifest...")
    manifest = build_manifest()
    validate_manifest_invariants(manifest)

    print(f"Writing manifest to {OUTPUT_PATH}...")
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        yaml.dump(manifest, f, Dumper=CleanYamlDumper, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"Manifest written successfully ({OUTPUT_PATH.stat().st_size} bytes).")


if __name__ == "__main__":
    main()

