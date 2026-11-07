"""P2g revision-2 class-specific CILB qualification and SQL tests."""
import json,sys,unittest
from copy import deepcopy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; sys.path.insert(0,str(ROOT/"tool"))
import catalog_p2g_contractor_pathways as p

class ContractorRevisionTwoTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls): cls.data=json.loads(p.DATA.read_text(encoding="utf-8"))
 def test_cgc_and_cbc_upgrade_rules_are_distinct(self):
  rows={r["source_key"]:r for r in p.validate_payload(self.data)}
  cgc=json.dumps(rows["certified-general-contractor"]["pathway_tree"])
  cbc=json.dumps(rows["certified-building-contractor"]["pathway_tree"])
  self.assertIn("residential or building contractor license held at least four years",cgc)
  self.assertIn("residential contractor license held at least three years",cbc)
  self.assertNotIn("building contractor license held at least three years",cbc)
 def test_class_specific_experience_and_military_routes(self):
  rows={r["source_key"]:r for r in p.validate_payload(self.data)}
  cgc=json.dumps(rows["certified-general-contractor"]["pathway_tree"])
  cbc=json.dumps(rows["certified-building-contractor"]["pathway_tree"])
  self.assertIn("four stories",cgc); self.assertNotIn("four stories",cbc)
  self.assertIn("at least four of the experience areas",cgc); self.assertIn("at least four of the six experience areas",cbc)
  self.assertEqual(cgc.count("Veteran route:"),3); self.assertEqual(cbc.count("Veteran route:"),3)
 def test_financial_responsibility_is_not_misrepresented_as_bond(self):
  text=json.dumps(p.validate_payload(self.data))
  self.assertIn("660",text); self.assertIn("14-hour",text); self.assertNotIn("licensing bond",text)
 def test_step_urls_and_revision_metadata(self):
  for row in p.validate_payload(self.data):
   self.assertEqual((row["revision"],row["supersedes_revision"]),(2,1))
  data=deepcopy(self.data); data["records"][0]["pathway_tree"]["children"][0]["children"][0]["source_url"]="https://attacker.example/"
  with self.assertRaises(AssertionError): p.validate_payload(data)
 def test_sql_retires_old_revision_atomically(self):
  sql=p.sql()
  self.assertEqual(sql.count("insert into public.catalog_license_pathway_versions"),2)
  self.assertEqual(sql.count("set publication_status='retired'"),2)
  self.assertIn("supersedes_revision",sql); self.assertIn("revision=2",sql); self.assertIn("revision=1",sql)
  self.assertNotIn("set pathway_tree",sql.lower()); self.assertNotIn("delete from",sql.lower())
if __name__=="__main__": unittest.main()
