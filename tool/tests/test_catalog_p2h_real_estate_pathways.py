"""P2h Florida DBPR/FREC real estate sales associate pathway and safe promotion SQL tests."""
from __future__ import annotations
import json
import sys
import unittest
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import catalog_p2h_real_estate_pathways as p


class RealEstatePathwayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(p.DATA.read_text(encoding="utf-8"))

    def test_single_verified_record_identity(self):
        rows = p.validate_payload(self.data)
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(row["source_namespace"], "dbpr_fl")
        self.assertEqual(row["source_key"], "real-estate-sales-associate")
        self.assertEqual(row["revision"], 1)
        self.assertIsNone(row["supersedes_revision"])
        self.assertEqual(row["route_kind"], "examination")
        self.assertEqual(row["coverage"], "selected_steps_only")
        self.assertEqual(row["uncertainty_status"], "conditional")
        self.assertEqual(row["pathway_kind"], "initial_licensure")

    def test_education_alternatives_and_exemptions(self):
        row = p.validate_payload(self.data)[0]
        root = row["pathway_tree"]
        self.assertEqual(root["op"], "all")
        edu_branch = root["children"][0]
        self.assertEqual(edu_branch["op"], "any")
        self.assertEqual(len(edu_branch["children"]), 4)

        text = json.dumps(edu_branch)
        self.assertIn("63-classroom-hour pre-licensing Course I", text)
        self.assertIn("four-year degree or higher in real estate", text)
        self.assertIn("The Florida Bar", text)
        self.assertIn("mutual recognition agreement", text)
        for state in ("AL", "AR", "CT", "GA", "IL", "KY", "MS", "NE", "RI", "WV"):
            self.assertIn(state, text)

    def test_exam_alternatives(self):
        row = p.validate_payload(self.data)[0]
        root = row["pathway_tree"]
        exam_branch = root["children"][4]
        self.assertEqual(exam_branch["op"], "any")
        self.assertEqual(len(exam_branch["children"]), 2)

        text = json.dumps(exam_branch)
        self.assertIn("Pearson VUE", text)
        self.assertIn("scaled score of 75", text)
        self.assertIn("40-question Florida Real Estate Law", text)

    def test_background_broker_and_post_licensing(self):
        row = p.validate_payload(self.data)[0]
        text = json.dumps(row["pathway_tree"])
        self.assertIn("Livescan", text)
        self.assertIn("FL920010Z", text)
        self.assertIn("DBPR Form RE 11", text)
        self.assertIn("45-hour FREC-approved post-licensing course", text)
        self.assertIn("null and void without grace period", text)

    def test_step_sources_and_rejection_of_untrusted_urls(self):
        row = p.validate_payload(self.data)[0]
        allowed = p.STEP_URLS[(row["source_namespace"], row["source_key"])]
        for url in allowed:
            self.assertTrue(url.startswith("https://"))

        data = deepcopy(self.data)
        data["records"][0]["pathway_tree"]["children"][0]["children"][0]["source_url"] = "https://untrusted-exam-dump.com/frec"
        with self.assertRaises(AssertionError):
            p.validate_payload(data)

    def test_sql_rendering_idempotence(self):
        sql = p.sql()
        self.assertIn("begin;", sql)
        self.assertIn("insert into public.catalog_license_pathway_versions", sql)
        self.assertIn("'dbpr_fl','real-estate-sales-associate',1", sql)
        self.assertIn("on conflict (source_namespace,source_key,revision) do nothing;", sql)
        self.assertIn("commit;", sql)
        self.assertNotIn("delete from", sql.lower())
        self.assertNotIn("drop table", sql.lower())


if __name__ == "__main__":
    unittest.main()

