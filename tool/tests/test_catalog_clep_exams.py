#!/usr/bin/env python3
"""Unit tests for College Board CLEP official exam catalog validator."""
from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from tool.catalog_clep_exams import (
    CATALOG_PATH,
    EXPECTED_TOTAL_EXAMS,
    VALID_CATEGORIES,
    render_target_seed_sql,
    validate_catalog,
)


class TestCatalogClepExams(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(CATALOG_PATH, "r", encoding="utf-8") as f:
            cls.manifest = json.load(f)

    def test_catalog_file_exists(self):
        self.assertTrue(CATALOG_PATH.exists(), f"Missing catalog file at {CATALOG_PATH}")

    def test_all_34_exams_present(self):
        self.assertEqual(self.manifest.get("total_exams"), EXPECTED_TOTAL_EXAMS)
        exams = self.manifest.get("exams", [])
        self.assertEqual(len(exams), EXPECTED_TOTAL_EXAMS)

    def test_categories_coverage(self):
        categories = {e["category"] for e in self.manifest["exams"]}
        self.assertEqual(categories, VALID_CATEGORIES)
        # Check specific counts per official category
        category_counts = {}
        for e in self.manifest["exams"]:
            cat = e["category"]
            category_counts[cat] = category_counts.get(cat, 0) + 1

        self.assertEqual(category_counts["Composition and Literature"], 6)
        self.assertEqual(category_counts["Science and Mathematics"], 7)
        self.assertEqual(category_counts["Business"], 5)
        self.assertEqual(category_counts["History and Social Sciences"], 12)
        self.assertEqual(category_counts["World Languages"], 4)

    def test_unique_slugs_and_codes(self):
        slugs = [e["source_key"] for e in self.manifest["exams"]]
        codes = [e["exam_code"] for e in self.manifest["exams"]]
        self.assertEqual(len(slugs), len(set(slugs)), "Duplicate slug detected")
        self.assertEqual(len(codes), len(set(codes)), "Duplicate exam_code detected")

    def test_official_urls(self):
        for e in self.manifest["exams"]:
            url = e["official_url"]
            self.assertTrue(
                url.startswith("https://clep.collegeboard.org/clep-exams/"),
                f"URL must be on official College Board domain: {url}",
            )

    def test_credit_recommendations(self):
        for e in self.manifest["exams"]:
            credit = e["credit_recommendation"]
            self.assertEqual(credit["standard_score"], 50)
            self.assertGreaterEqual(credit["semester_hours"], 3)
            self.assertEqual(credit["recommending_body"], "ACE")

    def test_introductory_psychology_pilot_spec(self):
        psyc = next(e for e in self.manifest["exams"] if e["source_key"] == "clep-introductory-psychology")
        self.assertEqual(psyc["status"], "sourced")
        self.assertEqual(psyc["time_limit_minutes"], 90)
        self.assertEqual(psyc["question_count_approx"], 95)
        self.assertIn("domains", psyc)
        domains = psyc["domains"]
        self.assertEqual(len(domains), 13)

        nominal_sum = sum(d["weight_nominal"] for d in domains)
        self.assertAlmostEqual(nominal_sum, 1.0, delta=0.015)

    def test_sql_generation(self):
        sql = render_target_seed_sql(self.manifest)
        self.assertIn("INSERT INTO public.learning_targets", sql)
        self.assertIn("standardized_exam", sql)
        self.assertIn("clep-introductory-psychology", sql)
        self.assertIn("clep-college-algebra", sql)
        self.assertIn("ON CONFLICT (slug) DO UPDATE", sql)

    def test_rejection_of_invalid_exam_count(self):
        bad = copy.deepcopy(self.manifest)
        bad["exams"].pop()
        bad["total_exams"] = 33
        with self.assertRaises(AssertionError):
            validate_catalog(bad)

    def test_rejection_of_duplicate_slug(self):
        bad = copy.deepcopy(self.manifest)
        bad["exams"][1]["source_key"] = bad["exams"][0]["source_key"]
        with self.assertRaises(AssertionError):
            validate_catalog(bad)


if __name__ == "__main__":
    unittest.main()

