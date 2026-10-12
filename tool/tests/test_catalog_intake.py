"""Zero-network unit tests for safe credential candidate intake and ranking."""
import importlib.util
import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tool/catalog_intake.py"
spec = importlib.util.spec_from_file_location("catalog_intake", SCRIPT)
intake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(intake)


class CatalogIntakeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = intake.read_data(intake.CANDIDATES)
        cls.demand = intake.read_data(intake.SIGNALS)

    def test_real_seed_is_private_and_unique(self):
        result = intake.validate(self.catalog, self.demand)
        self.assertEqual(result["candidates"], 31)
        self.assertEqual(result["observations"], 0)
        self.assertGreaterEqual(result["types"]["certification"], 10)
        self.assertGreaterEqual(result["types"]["professional_license"], 5)

    def test_empty_measured_demand_does_not_invent_ranking(self):
        self.assertEqual(intake.score_candidates(self.catalog, self.demand), [])

    def test_rejects_unreviewed_publication(self):
        cat = deepcopy(self.catalog)
        cat["candidates"][0]["review_status"] = "approved"
        cat["candidates"][0]["publication_status"] = "published"
        with self.assertRaisesRegex(ValueError, "private and unreviewed"):
            intake.validate(cat, self.demand)

    def test_rejects_unreviewed_external_content_rights(self):
        cat = deepcopy(self.catalog)
        cat["candidates"][0]["source_rights"] = "approved_for_display"
        with self.assertRaisesRegex(ValueError, "approved reuse rights"):
            intake.validate(cat, self.demand)

    def test_rejects_duplicate_source_key(self):
        cat = deepcopy(self.catalog)
        cat["candidates"].append(deepcopy(cat["candidates"][0]))
        cat["candidate_count"] += 1
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            intake.validate(cat, self.demand)

    def test_rejects_non_https_issuer(self):
        cat = deepcopy(self.catalog)
        cat["candidates"][0]["source_url"] = "http://untrusted.example"
        with self.assertRaisesRegex(ValueError, "HTTPS"):
            intake.validate(cat, self.demand)

    def test_rejects_invented_value_without_provenance(self):
        observation = self._observation(self.catalog["candidates"][0], "bls_annual_openings", 200)
        observation["evidence_url"] = ""
        with self.assertRaisesRegex(ValueError, "invalid source URL"):
            intake.validate(self.catalog, {"schema_version": 1, "signals": [observation]})

    def test_rejects_negative_and_nan_metric(self):
        row = self.catalog["candidates"][0]
        for bad in (-1, float("nan")):
            record = self._observation(row, "bls_annual_openings", bad)
            with self.assertRaisesRegex(ValueError, "finite nonnegative"):
                intake.validate(self.catalog, {"schema_version": 1, "signals": [record]})

    def test_requires_two_categories_and_comparable_cohorts(self):
        row1, row2 = self.catalog["candidates"][:2]
        labor = [self._observation(row1, "bls_annual_openings", 120),
                 self._observation(row2, "bls_annual_openings", 60)]
        one_metric = {"schema_version": 1, "signals": labor}
        self.assertEqual(intake.score_candidates(self.catalog, one_metric), [])
        awards = [self._observation(row1, "ipeds_completions", 100),
                  self._observation(row2, "ipeds_completions", 50)]
        with_two = {"schema_version": 1, "signals": labor + awards}
        self.assertEqual(intake.validate(self.catalog, with_two)["observations"], 4)
        ranked = intake.score_candidates(self.catalog, with_two)
        self.assertEqual(len(ranked), 2)
        self.assertEqual(ranked[0]["source_key"], row1["source_key"])
        self.assertEqual(ranked[0]["coverage"], 0.60)
        self.assertEqual(ranked[0]["score_status"], "observed_partial")

    def test_different_periods_cannot_make_a_comparison(self):
        row1, row2 = self.catalog["candidates"][:2]
        labor = [self._observation(row1, "bls_annual_openings", 100),
                 self._observation(row2, "bls_annual_openings", 90)]
        labor[1]["observed_period"] = "2025"
        awards = [self._observation(row1, "ipeds_completions", 500),
                  self._observation(row2, "ipeds_completions", 250)]
        self.assertEqual(intake.score_candidates(self.catalog,
                         {"signals": labor + awards}), [])

    def test_import_requires_matching_project_and_modern_secret(self):
        with self.assertRaisesRegex(ValueError, "other than Learning App"):
            intake.import_candidates(self.catalog, "wrong-ref")
        import os
        old_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        old_url = os.environ.get("SUPABASE_URL")
        try:
            os.environ["SUPABASE_URL"] = f"https://{intake.PROJECT_REF}.supabase.co"
            os.environ.pop("SUPABASE_SERVICE_ROLE_KEY", None)
            with self.assertRaisesRegex(ValueError, "sb_secret_"):
                intake.import_candidates(self.catalog, intake.PROJECT_REF)
        finally:
            if old_key is None:
                os.environ.pop("SUPABASE_SERVICE_ROLE_KEY", None)
            else:
                os.environ["SUPABASE_SERVICE_ROLE_KEY"] = old_key
            if old_url is None:
                os.environ.pop("SUPABASE_URL", None)
            else:
                os.environ["SUPABASE_URL"] = old_url

    @staticmethod
    def _observation(row, metric, value):
        return {
            "source_namespace": row["source_namespace"],
            "source_key": row["source_key"],
            "metric": metric,
            "metric_value": value,
            "observed_period": "2024",
            "geography": "US",
            "publisher": "Test Official Publisher",
            "evidence_url": "https://example.gov/dataset",
            "method_note": "Unit-test fixture only",
            "data_rights": "metadata_only",
        }


if __name__ == "__main__":
    unittest.main()
