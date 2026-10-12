"""Public issuer pilot: narrow source scope, domain allowlist and safe defaults."""
import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tool"))
import catalog_verified_pilot as pilot


class VerifiedPilotTests(unittest.TestCase):
    def setUp(self):
        self.original=pilot.REVIEW
        self.data=json.loads(pilot.REVIEW.read_text(encoding="utf-8"))

    def tearDown(self):
        pilot.REVIEW=self.original

    def validate_changed(self, data):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/"pilot.json"
            path.write_text(json.dumps(data),encoding="utf-8")
            pilot.REVIEW=path
            return pilot.validate()

    def test_ten_narrow_reviewed_records(self):
        rows=pilot.validate()
        self.assertEqual(len(rows),10)
        self.assertTrue(all(r["requirements_status"]=="not_verified" for r in rows))
        self.assertTrue(all(r["popularity_status"]=="not_measured" for r in rows))

    def test_refuse_official_url_outside_issuer_allowlist(self):
        data=deepcopy(self.data)
        data["records"][0]["official_url"]="https://aws.amazon.com.evil.example/unsafe"
        with self.assertRaises(AssertionError):
            self.validate_changed(data)

    def test_refuse_false_popularity_claim(self):
        data=deepcopy(self.data)
        data["popularity_claim"]=True
        with self.assertRaises(AssertionError):
            self.validate_changed(data)

    def test_refuse_unchecked_candidate(self):
        data=deepcopy(self.data)
        data["records"][0]["source_key"]="this-does-not-exist"
        with self.assertRaises(AssertionError):
            self.validate_changed(data)

    def test_refuse_duplicate_source_identity(self):
        data=deepcopy(self.data)
        data["records"][1]["source_namespace"]=data["records"][0]["source_namespace"]
        data["records"][1]["source_key"]=data["records"][0]["source_key"]
        with self.assertRaises(AssertionError):
            self.validate_changed(data)

    def test_transactional_sql_requires_approved_source(self):
        sql=pilot.review_sql()
        self.assertTrue(sql.startswith("begin;"))
        self.assertTrue(sql.rstrip().endswith("commit;"))
        self.assertIn("review_status='approved'",sql)
        self.assertIn("source_rights='approved_for_display'",sql)
        self.assertIn("requirements_status",pilot.REVIEW.read_text())
        self.assertNotIn("insert into public.learning_targets",sql.lower())
        self.assertNotIn("insert into public.courses",sql.lower())
        self.assertEqual(sql.lower().count("insert into public.catalog_verified_destinations"),10)


if __name__=="__main__":
    unittest.main()
