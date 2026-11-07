"""P2e revision-2 nursing pathways and immutable promotion SQL tests."""
import json,sys,unittest
from copy import deepcopy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; sys.path.insert(0,str(ROOT/"tool"))
import catalog_p2e_pathways as p

class NursingRevisionTwoTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls): cls.data=json.loads(p.DATA.read_text(encoding="utf-8"))
 def test_three_distinct_initial_licensure_routes(self):
  rows=p.validate_payload(self.data)
  self.assertEqual({r["source_key"] for r in rows},{"registered-nurse","licensed-practical-nurse"})
  for row in rows:
   self.assertEqual((row["revision"],row["supersedes_revision"]),(2,1))
   self.assertEqual(row["route_kind"],"other")
   routes=row["pathway_tree"]["children"][0]
   self.assertEqual(routes["op"],"any"); self.assertEqual(len(routes["children"]),3)
   text=json.dumps(routes)
   self.assertIn("MOBILE route",text); self.assertIn("Already-passed NCLEX route",text); self.assertIn("Examination route",text)
  rn=next(r for r in rows if r["source_key"]=="registered-nurse")
  lpn=next(r for r in rows if r["source_key"]=="licensed-practical-nurse")
  self.assertIn("pre-licensure MSN",json.dumps(rn["pathway_tree"]))
  self.assertNotIn("Practical Nursing Equivalency",json.dumps(rn["pathway_tree"]))
  self.assertIn("Practical Nursing Equivalency",json.dumps(lpn["pathway_tree"]))
  self.assertNotIn("pre-licensure MSN",json.dumps(lpn["pathway_tree"]))
 def test_bad_identity_and_unsupported_source_are_rejected(self):
  data=deepcopy(self.data); data["records"][0]["source_key"]="nclex-rn"
  with self.assertRaises(AssertionError): p.validate_payload(data)
  data=deepcopy(self.data); data["records"][0]["pathway_tree"]["children"][0]["children"][0]["children"][0]["children"][0]["source_url"]="https://attacker.example/"
  with self.assertRaises(AssertionError): p.validate_payload(data)
 def test_partial_scope_and_unique_steps(self):
  data=deepcopy(self.data); data["records"][0]["coverage"]="full_requirements"
  with self.assertRaises(AssertionError): p.validate_payload(data)
 def test_sql_retires_old_and_inserts_new_without_mutating_content(self):
  sql=p.sql()
  self.assertEqual(sql.count("insert into public.catalog_license_pathway_versions"),2)
  self.assertEqual(sql.count("set publication_status='retired'"),2)
  self.assertIn("supersedes_revision",sql); self.assertIn("revision=2",sql); self.assertIn("revision=1",sql)
  self.assertNotIn("set pathway_tree",sql.lower()); self.assertNotIn("delete from",sql.lower())
if __name__=="__main__": unittest.main()
