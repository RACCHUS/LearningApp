"""P2 external-source link validation and fail-closed schema protections."""
import json
import sys
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tool"))
import catalog_p2_resources as subject

class PreparationLinksTests(unittest.TestCase):
    def setUp(self):
        self.path=subject.DATA
        self.data=json.loads(subject.DATA.read_text(encoding="utf-8"))
    def tearDown(self):
        subject.DATA=self.path
    def changed(self,value):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/"links.json"
            p.write_text(json.dumps(value),encoding="utf-8")
            subject.DATA=p
            return subject.validate()
    def test_eight_verified_external_links(self):
        self.assertEqual(len(subject.validate()),8)
        self.assertTrue(all(x["rights_scope"]=="external_link_only"
                            for x in subject.validate()))
    def test_off_domain_url_rejected(self):
        d=deepcopy(self.data)
        d["resources"][0]["resource_url"]="https://aws.amazon.com.attacker.test/unsafe"
        with self.assertRaises(AssertionError):self.changed(d)
    def test_unapproved_destination_rejected(self):
        d=deepcopy(self.data)
        d["resources"][0]["source_namespace"]="unreviewed"
        with self.assertRaises(AssertionError):self.changed(d)
    def test_duplicate_source_resource_identity_rejected(self):
        d=deepcopy(self.data)
        d["resources"][1]["resource_key"]=d["resources"][0]["resource_key"]
        d["resources"][1]["source_namespace"]=d["resources"][0]["source_namespace"]
        d["resources"][1]["source_key"]=d["resources"][0]["source_key"]
        with self.assertRaises(AssertionError):self.changed(d)
    def test_sql_is_transactional_and_does_not_create_courses(self):
        sql=subject.sql()
        self.assertTrue(sql.startswith("begin;"))
        self.assertTrue(sql.endswith("commit;"))
        self.assertEqual(sql.count("insert into public.catalog_destination_resources"),8)
        self.assertNotIn("insert into public.courses",sql)
        self.assertNotIn("insert into public.learning_targets",sql)
    def test_unverified_access_cost_cannot_be_asserted(self):
        d=deepcopy(self.data)
        d["assertions"]["no_verified_prices_or_fees"]=False
        with self.assertRaises(AssertionError):self.changed(d)

if __name__=="__main__":
    unittest.main()
