#!/usr/bin/env python3
"""Validate College Board official CLEP exam catalog and generate safe seed targets.

Reconciled against official College Board CLEP exam specifications (November 2026).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "data/catalog/clep_official_catalog_2026.json"

EXPECTED_TOTAL_EXAMS = 34
OFFICIAL_HOST = "clep.collegeboard.org"
VALID_CATEGORIES = {
    "Composition and Literature",
    "Science and Mathematics",
    "Business",
    "History and Social Sciences",
    "World Languages",
}
VALID_STATUSES = {
    "planned",
    "sourced",
    "drafted",
    "reviewed",
    "approved",
    "published",
    "needs_update",
    "archived",
}


def valid_url(url: str) -> bool:
    p = urlsplit(url)
    return (
        p.scheme == "https"
        and p.netloc == OFFICIAL_HOST
        and not p.fragment
        and not any(ch.isspace() for ch in url)
        and p.path.startswith("/clep-exams/")
    )


def validate_catalog(manifest: dict) -> dict[str, any]:
    assert manifest.get("schema_version") == 1, "schema_version must be 1"
    assert manifest.get("program") == "College-Level Examination Program (CLEP)"
    assert manifest.get("issuer") == "College Board"
    assert manifest.get("total_exams") == EXPECTED_TOTAL_EXAMS

    exams = manifest.get("exams", [])
    assert len(exams) == EXPECTED_TOTAL_EXAMS, f"Expected {EXPECTED_TOTAL_EXAMS} exams, got {len(exams)}"

    seen_slugs: set[str] = set()
    seen_codes: set[str] = set()
    categories_found: set[str] = set()

    for idx, exam in enumerate(exams):
        assert isinstance(exam, dict), f"Exam #{idx} must be a dictionary"
        slug = exam.get("source_key")
        code = exam.get("exam_code")
        title = exam.get("title")
        category = exam.get("category")
        dest_type = exam.get("destination_type")
        url = exam.get("official_url")
        status = exam.get("status")
        time_limit = exam.get("time_limit_minutes")
        question_count = exam.get("question_count_approx")
        credit = exam.get("credit_recommendation")

        assert slug and re.match(r"^clep-[a-z0-9-]+$", slug), f"Invalid slug: {slug}"
        assert slug not in seen_slugs, f"Duplicate slug: {slug}"
        seen_slugs.add(slug)

        assert code and re.match(r"^CLEP-[A-Z0-9-]+$", code), f"Invalid exam_code: {code}"
        assert code not in seen_codes, f"Duplicate exam_code: {code}"
        seen_codes.add(code)

        assert title and len(title) >= 3, f"Missing title for {slug}"
        assert category in VALID_CATEGORIES, f"Invalid category {category} for {slug}"
        categories_found.add(category)

        assert dest_type == "standardized_exam", f"destination_type must be standardized_exam for {slug}"
        assert valid_url(url), f"Invalid official_url: {url} for {slug}"
        assert status in VALID_STATUSES, f"Invalid status: {status} for {slug}"

        assert isinstance(time_limit, int) and 60 <= time_limit <= 180, f"Invalid time_limit: {time_limit}"
        assert isinstance(question_count, int) and 30 <= question_count <= 160, f"Invalid question count: {question_count}"

        assert isinstance(credit, dict), f"Missing credit_recommendation for {slug}"
        assert credit.get("standard_score") == 50, f"Standard score must be 50 for {slug}"
        assert credit.get("semester_hours", 0) >= 3, f"Semester hours must be >= 3 for {slug}"

        # If domains are specified (e.g. for sourced pilot courses), validate weighting
        if "domains" in exam:
            domains = exam["domains"]
            assert isinstance(domains, list) and len(domains) >= 3, f"Domains must be a non-empty list for {slug}"
            total_nominal = 0.0
            for d in domains:
                assert "code" in d and "title" in d, f"Domain missing code or title in {slug}"
                w_min = d.get("weight_min", 0.0)
                w_max = d.get("weight_max", 0.0)
                w_nom = d.get("weight_nominal", 0.0)
                assert 0.0 < w_min <= w_nom <= w_max < 1.0, f"Invalid weights for domain {d.get('code')} in {slug}"
                total_nominal += w_nom
            assert abs(total_nominal - 1.0) <= 0.02, f"Nominal domain weights must sum to 1.0 (got {total_nominal}) for {slug}"

    assert categories_found == VALID_CATEGORIES, f"All 5 categories must be represented, missing: {VALID_CATEGORIES - categories_found}"

    return {
        "total_exams": len(exams),
        "categories": sorted(categories_found),
        "unique_slugs": len(seen_slugs),
        "unique_codes": len(seen_codes),
    }


def render_target_seed_sql(manifest: dict) -> str:
    """Generate idempotent seed SQL for public.learning_targets."""
    lines = [
        "-- Seed official College Board CLEP standardized exam learning targets",
        "INSERT INTO public.learning_targets (",
        "    id,",
        "    slug,",
        "    title,",
        "    description,",
        "    target_type,",
        "    provider_name,",
        "    is_official,",
        "    metadata",
        ") VALUES",
    ]
    records = []
    for exam in manifest.get("exams", []):
        slug = exam["source_key"]
        title = exam["title"].replace("'", "''")
        category = exam["category"]
        desc = (
            f"Official College Board CLEP {title} examination ({category}). "
            f"Passing recommendation: ACE scaled score 50 ({exam['credit_recommendation']['semester_hours']} semester hours credit)."
        ).replace("'", "''")
        meta = json.dumps({
            "program": "CLEP",
            "issuer": "College Board",
            "exam_code": exam["exam_code"],
            "category": category,
            "official_url": exam["official_url"],
            "time_limit_minutes": exam["time_limit_minutes"],
            "question_count_approx": exam["question_count_approx"],
            "credit_recommendation": exam["credit_recommendation"],
            "special_requirements": exam["special_requirements"],
        }).replace("'", "''")

        # Deterministic UUIDv5-style or fixed target ID based on slug
        record_sql = (
            f"    (gen_random_uuid(), '{slug}', '{title}', '{desc}', "
            f"'standardized_exam', 'College Board', true, '{meta}'::jsonb)"
        )
        records.append(record_sql)

    lines.append(",\n".join(records))
    lines.append("ON CONFLICT (slug) DO UPDATE SET")
    lines.append("    title = EXCLUDED.title,")
    lines.append("    description = EXCLUDED.description,")
    lines.append("    provider_name = EXCLUDED.provider_name,")
    lines.append("    is_official = EXCLUDED.is_official,")
    lines.append("    metadata = EXCLUDED.metadata;")
    return "\n".join(lines)


def main():
    if not CATALOG_PATH.exists():
        print(f"Error: Catalog not found at {CATALOG_PATH}", file=sys.stderr)
        sys.exit(1)

    with open(CATALOG_PATH, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    stats = validate_catalog(manifest)
    print(f"CLEP Catalog validation PASSED: {stats['total_exams']} official exams across {len(stats['categories'])} categories.")


if __name__ == "__main__":
    main()

