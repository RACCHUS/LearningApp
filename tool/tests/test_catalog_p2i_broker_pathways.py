"""P2i Florida DBPR/FREC real estate broker destination, pathway, and safe promotion SQL tests."""
from __future__ import annotations
import json
import sys
import unittest
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import catalog_p2i_broker_pathways as p


class RealEstateBrokerPathwayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload = json.loads(p.DATA.read_text(encoding="utf-8"))
        cls.seed = json.loads(p.SEED.read_text(encoding="utf-8"))

    def test_destination_identity_and_candidate_origin(self):
        validated = p.validate_payload(self.payload, self.seed)
        dest = validated["destination"]
        self.assertEqual(dest["source_namespace"], "dbpr_fl")
        self.assertEqual(dest["source_key"], "real-estate-broker")
        self.assertEqual(dest["destination_type"], "professional_license")
        self.assertEqual(dest["jurisdiction"], "US-FL")
        self.assertTrue(dest["official_url"].startswith("https://"))
        self.assertEqual(dest["resource"]["resource_key"], "dbpr-re2-broker-checklist")

    def test_experience_prerequisite_alternatives(self):
        row = self.payload["records"][0]
        root = row["pathway_tree"]
        self.assertEqual(root["op"], "all")
        exp_branch = root["children"][0]
        self.assertEqual(exp_branch["op"], "any")
        self.assertEqual(len(exp_branch["children"]), 3)

        text = json.dumps(exp_branch)
        self.assertIn("at least 24 months during the preceding 5 years", text)
        self.assertIn("under an active broker", text)
        self.assertIn("another state or jurisdiction", text)
        self.assertIn("mutual recognition", text)

    def test_education_alternatives_and_degree_exemption(self):
        row = self.payload["records"][0]
        root = row["pathway_tree"]
        edu_branch = root["children"][1]
        self.assertEqual(edu_branch["op"], "any")
        self.assertEqual(len(edu_branch["children"]), 3)

        text = json.dumps(edu_branch)
        self.assertIn("72-classroom-hour pre-licensing Course II", text)
        self.assertIn("four-year degree or higher in real estate", text)
        self.assertNotIn("The Florida Bar", text)  # FL Bar is NOT exempt from broker education without RE degree

    def test_exam_alternatives(self):
        row = self.payload["records"][0]
        root = row["pathway_tree"]
        exam_branch = root["children"][4]
        self.assertEqual(exam_branch["op"], "any")
        self.assertEqual(len(exam_branch["children"]), 2)

        text = json.dumps(exam_branch)
        self.assertIn("Pearson VUE", text)
        self.assertIn("scaled score of 75", text)
        self.assertIn("40-question Florida Real Estate Law", text)

    def test_brokerage_activation_and_post_licensing(self):
        row = self.payload["records"][0]
        text = json.dumps(row["pathway_tree"])
        self.assertIn("Livescan", text)
        self.assertIn("FL920010Z", text)
        self.assertIn("sole proprietor broker, qualifying broker", text)
        self.assertIn("60 hours of FREC-approved broker post-licensing", text)
        self.assertIn("null and void", text)

    def test_step_sources_and_rejection_of_untrusted_urls(self):
        row = self.payload["records"][0]
        allowed = p.STEP_URLS[(row["source_namespace"], row["source_key"])]
        for url in allowed:
            self.assertTrue(url.startswith("https://"))

        data = deepcopy(self.payload)
        data["records"][0]["pathway_tree"]["children"][0]["children"][0]["source_url"] = "https://untrusted-broker-dump.org/broker"
        with self.assertRaises(AssertionError):
            p.validate_payload(data, self.seed)

    def test_sql_rendering_guards_and_idempotence(self):
        sql = p.sql()
        self.assertIn("begin;", sql)
        self.assertIn("update public.catalog_intake_candidates", sql)
        self.assertIn("insert into public.catalog_verified_destinations", sql)
        self.assertIn("insert into public.catalog_destination_resources", sql)
        self.assertIn("insert into public.catalog_license_pathway_versions", sql)
        self.assertIn("'dbpr_fl', 'real-estate-broker', 1", sql)
        self.assertIn("on conflict (source_namespace, source_key) do nothing;", sql)
        self.assertIn("on conflict (source_namespace, source_key, revision) do nothing;", sql)
        self.assertIn("commit;", sql)
        self.assertNotIn("delete from", sql.lower())
        self.assertNotIn("drop table", sql.lower())


if __name__ == "__main__":
    unittest.main()

