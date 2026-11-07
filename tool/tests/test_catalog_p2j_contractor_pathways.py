"""P2j Florida DBPR/CILB certified residential contractor destination, pathway, and safe promotion SQL tests."""
from __future__ import annotations
import json
import sys
import unittest
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import catalog_p2j_contractor_pathways as p


class ResidentialContractorPathwayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload = json.loads(p.DATA.read_text(encoding="utf-8"))

    def test_destination_identity(self):
        validated = p.validate_payload(self.payload)
        dest = validated["destination"]
        self.assertEqual(dest["source_namespace"], "dbpr_fl")
        self.assertEqual(dest["source_key"], "certified-residential-contractor")
        self.assertEqual(dest["destination_type"], "professional_license")
        self.assertEqual(dest["jurisdiction"], "US-FL")
        self.assertTrue(dest["official_url"].startswith("https://"))
        self.assertEqual(dest["resource"]["resource_key"], "cilb-5c-checklist")

    def test_qualification_matrix_and_military_routes(self):
        row = self.payload["records"][0]
        root = row["pathway_tree"]
        self.assertEqual(root["op"], "all")
        matrix = root["children"][0]
        self.assertEqual(matrix["op"], "any")
        self.assertEqual(len(matrix["children"]), 8)

        text = json.dumps(matrix)
        self.assertIn("four-year engineering, architecture or building-construction degree", text)
        self.assertIn("one year as a foreman plus at least three years", text)
        self.assertIn("four years as a skilled worker or foreman", text)
        self.assertIn("Military-veteran qualification alternative", text)

    def test_residential_scope_restriction(self):
        row = self.payload["records"][0]
        root = row["pathway_tree"]
        scope_step = root["children"][1]
        self.assertEqual(scope_step["stage"], "experience")
        self.assertIn("not exceeding three stories", scope_step["condition"])
        self.assertIn("residential construction experience areas", scope_step["label"])

    def test_financial_responsibility_alternatives(self):
        row = self.payload["records"][0]
        root = row["pathway_tree"]
        fin_branch = root["children"][3]
        self.assertEqual(fin_branch["op"], "any")
        self.assertEqual(len(fin_branch["children"]), 2)

        text = json.dumps(fin_branch)
        self.assertIn("FICO credit score of 660 or higher", text)
        self.assertIn("14-hour financial responsibility course", text)
        self.assertNotIn("bond substitute", text.lower())

    def test_exam_livescan_and_insurance(self):
        row = self.payload["records"][0]
        text = json.dumps(row["pathway_tree"])
        self.assertIn("FL920250Z", text)
        self.assertIn("Pearson VUE", text)
        self.assertIn("Business & Finance and Residential Trade Knowledge", text)
        self.assertIn("public liability and property damage insurance", text)
        self.assertIn("$100,000/$25,000", text)

    def test_step_sources_and_rejection_of_untrusted_urls(self):
        row = self.payload["records"][0]
        allowed = p.STEP_URLS[(row["source_namespace"], row["source_key"])]
        for url in allowed:
            self.assertTrue(url.startswith("https://"))

        data = deepcopy(self.payload)
        data["records"][0]["pathway_tree"]["children"][0]["children"][0]["source_url"] = "https://untrusted-contractor-dump.net/crc"
        with self.assertRaises(AssertionError):
            p.validate_payload(data)

    def test_sql_rendering_guards_and_idempotence(self):
        sql = p.sql()
        self.assertIn("begin;", sql)
        self.assertIn("insert into public.catalog_intake_candidates", sql)
        self.assertIn("update public.catalog_intake_candidates", sql)
        self.assertIn("insert into public.catalog_verified_destinations", sql)
        self.assertIn("insert into public.catalog_destination_resources", sql)
        self.assertIn("insert into public.catalog_license_pathway_versions", sql)
        self.assertIn("'dbpr_fl', 'certified-residential-contractor', 1", sql)
        self.assertIn("on conflict (source_namespace, source_key) do nothing;", sql)
        self.assertIn("on conflict (source_namespace, source_key, revision) do nothing;", sql)
        self.assertIn("commit;", sql)
        self.assertNotIn("delete from", sql.lower())
        self.assertNotIn("drop table", sql.lower())


if __name__ == "__main__":
    unittest.main()

