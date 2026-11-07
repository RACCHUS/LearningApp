"""P2f revision-2 DFS alternative logic and immutable promotion SQL tests."""
import json,sys,unittest
from copy import deepcopy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; sys.path.insert(0,str(ROOT/"tool"))
import catalog_p2f_insurance_pathways as p

class InsuranceRevisionTwoTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls): cls.data=json.loads(p.DATA.read_text(encoding="utf-8"))
 def test_220_has_six_distinct_alternatives_and_no_cic(self):
  row=next(r for r in p.validate_payload(self.data) if r["source_key"]=="general-lines-2-20")
  text=json.dumps(row["pathway_tree"])
  self.assertIn("full-time responsible insurance duties in all listed",text)
  self.assertIn("licensed and appointed 4-40, 20-44 or 0-55",text)
  self.assertIn("CPCU",text); self.assertNotIn("CIC",text)
  self.assertIn("equivalent resident license",text)
  self.assertIn("48 months",text)
 def test_215_nested_life_and_health_and_reciprocity(self):
  row=next(r for r in p.validate_payload(self.data) if r["source_key"]=="life-health-2-15")
  root=row["pathway_tree"]["children"][0]
  self.assertEqual(root["op"],"any")
  combined=root["children"][1]
  self.assertEqual(combined["op"],"all")
  self.assertEqual([x["op"] for x in combined["children"]],["any","any"])
  text=json.dumps(row["pathway_tree"])
  for token in ("ChFC","FLMI","CEBS","ChHC","HIA","REBC","RHU","reciprocal state","CLU"):
   self.assertIn(token,text)
 def test_revisions_and_step_sources(self):
  for row in p.validate_payload(self.data):
   self.assertEqual((row["revision"],row["supersedes_revision"]),(2,1))
   for url in p.STEP_URLS[(row["source_namespace"],row["source_key"])]:
    self.assertTrue(url.startswith("https://"))
  data=deepcopy(self.data); data["records"][0]["pathway_tree"]["children"][0]["children"][0]["source_url"]="https://attacker.example/"
  with self.assertRaises(AssertionError): p.validate_payload(data)
 def test_sql_retires_old_revision_atomically(self):
  sql=p.sql()
  self.assertEqual(sql.count("insert into public.catalog_license_pathway_versions"),2)
  self.assertEqual(sql.count("set publication_status='retired'"),2)
  self.assertIn("supersedes_revision",sql); self.assertIn("revision=2",sql); self.assertIn("revision=1",sql)
  self.assertNotIn("set pathway_tree",sql.lower()); self.assertNotIn("delete from",sql.lower())
if __name__=="__main__": unittest.main()
