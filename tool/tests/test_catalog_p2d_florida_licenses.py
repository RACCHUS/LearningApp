"""P2d Florida license evidence validation: fail closed before promotion."""
import json
import sys
import unittest
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import catalog_p2d_florida_licenses as subject

class FloridaLicenseReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(subject.DATA.read_text("utf-8"))
        cls.candidates = json.loads(subject.SEED.read_text("utf-8"))

    def test_six_distinct_licenses_and_no_award_or_popularity_claim(self):
        rows = subject.validate_payload(self.data, self.candidates)
        self.assertEqual(len(rows), 6)
        self.assertEqual(sum(r["seed_candidate"] for r in rows), 3)
        self.assertTrue(all(r["destination_type"] == "professional_license" and r["jurisdiction"] == "US-FL" for r in rows))

    def test_hostile_lookalike_domain_rejected(self):
        data = deepcopy(self.data)
        data["records"][0]["resource"]["resource_url"] = "https://www.myfloridacfo.com.attacker.test/path"
        with self.assertRaises(AssertionError):
            subject.validate_payload(data, self.candidates)

    def test_wrong_type_or_jurisdiction_rejected(self):
        for field, value in (("destination_type", "licensure_exam"), ("jurisdiction", "US-GA")):
            data = deepcopy(self.data)
            data["records"][0][field] = value
            with self.assertRaises(AssertionError):
                subject.validate_payload(data, self.candidates)

    def test_unsourced_candidate_mismatch_rejected(self):
        data = deepcopy(self.data)
        data["records"][2]["title"] = "Unverified alternative title"
        with self.assertRaises(AssertionError):
            subject.validate_payload(data, self.candidates)

    def test_duplicate_and_false_rights_rejected(self):
        data = deepcopy(self.data)
        data["records"][0]["source_key"] = data["records"][1]["source_key"]
        with self.assertRaises(AssertionError):
            subject.validate_payload(data, self.candidates)
        data = deepcopy(self.data)
        data["records"][0]["resource"]["rights_scope"] = "copy_course_content"
        with self.assertRaises(AssertionError):
            subject.validate_payload(data, self.candidates)

    def test_new_ids_are_not_in_original_seed(self):
        data = deepcopy(self.data)
        data["records"][0]["seed_candidate"] = True
        with self.assertRaises(AssertionError):
            subject.validate_payload(data, self.candidates)

    def test_idempotent_transaction_guard_and_existing_row_safety(self):
        sql = subject.render_sql(subject.validate())
        self.assertTrue(sql.startswith("begin;"))
        self.assertTrue(sql.endswith("commit;\n"))
        self.assertEqual(sql.count("insert into public.catalog_verified_destinations"), 6)
        self.assertEqual(sql.count("insert into public.catalog_destination_resources"), 6)
        self.assertEqual(sql.count("insert into public.catalog_intake_candidates"), 3)
        self.assertIn("on conflict (source_namespace,source_key) do nothing", sql)
        self.assertIn("requirements_status='not_verified'", sql)
        self.assertNotIn("insert into public.learning_targets", sql)
        self.assertNotIn("insert into public.courses", sql)
        self.assertNotIn("delete from", sql.lower())
        self.assertNotIn("truncate ", sql.lower())

if __name__ == "__main__":
    unittest.main()
