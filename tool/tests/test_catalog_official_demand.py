"""Offline tests: official release parsing, numeric units and fail-closed writes."""
import csv
import importlib.util
import io
import os
import sys
import tempfile
import unittest
import zipfile
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import catalog_official_demand as mod


def synthetic_bls(count=710, wrong_title=False, duplicate=False):
    from openpyxl import Workbook
    book = Workbook()
    sh = book.active
    sh.title = "Table 1.2"
    sh.append(["Table 1.2 Occupational projections, 2024–34" if wrong_title
               else "Table 1.2 Occupational projections, 2025–35 (Employment in thousands)"])
    sh.append(["Occupation title", "2025 National Employment Matrix code",
               "Occupation type", "Occupational openings, 2025–35 annual average"])
    sh.append(["All occupations", "00-0000", "Summary", 17461.8])
    for i in range(count):
        code = f"11-{1000+i:04d}"
        if duplicate and i == count-1: code = "11-1000"
        sh.append([f"Fictional occupation {i}", code, "Line item", 2.3])
    b=io.BytesIO()
    book.save(b)
    return b.getvalue()


def synthetic_ipeds(codes=1001):
    buf=io.StringIO()
    wr=csv.writer(buf)
    wr.writerow(["UNITID","CIPCODE","AWLEVEL","CTOTALT"])
    for i in range(codes):
        for aw in range(1,7):
            wr.writerow([100000+i,f"11.{i:04d}",aw,10])
    wr.writerow(["100000","99","3","90000"])  # not an exact six-digit CIP
    wr.writerow(["100000","11.0000","7","-2"])  # special/suppressed
    compressed=io.BytesIO()
    with zipfile.ZipFile(compressed,"w",compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr("c2025_a.csv",buf.getvalue())
    return compressed.getvalue()


class OfficialDemandTests(unittest.TestCase):
    def test_bls_line_items_only_and_thousands_unit(self):
        parsed=mod.parse_bls(synthetic_bls())
        self.assertEqual(len(parsed),710)
        self.assertEqual(parsed[0]["metric_value"],"2.3")
        self.assertEqual(parsed[0]["metric_unit"],"thousands_of_jobs")
        self.assertEqual(parsed[0]["period"],"2025-2035")
        self.assertTrue(all(r["taxonomy_system"]=="bls_soc" for r in parsed))

    def test_bls_wrong_projection_cycle_rejected(self):
        with self.assertRaisesRegex(ValueError,"projection window changed"):
            mod.parse_bls(synthetic_bls(wrong_title=True))

    def test_bls_duplicate_detailed_soc_rejected(self):
        with self.assertRaisesRegex(ValueError,"Duplicate"):
            mod.parse_bls(synthetic_bls(duplicate=True))

    def test_ipeds_exact_six_digit_and_awlevel_cohorts(self):
        parsed=mod.parse_ipeds(synthetic_ipeds(),mod.IPEDS_INFO)
        self.assertEqual(len(parsed),1001*6)
        self.assertEqual(parsed[0]["metric_unit"],"awards")
        self.assertEqual(parsed[0]["metric_value"],"10")
        self.assertIn(parsed[0]["dimension"],{"awardlevel:1","awardlevel:2"})
        self.assertEqual(parsed[0]["period"],"2024-2025")

    def test_ipeds_no_unchecked_archive_member(self):
        with self.assertRaisesRegex(ValueError,"exactly one C2025_A"):
            mod.parse_ipeds(b"PK"+b"bad",mod.IPEDS_INFO)

    def test_wrong_project_blocks_live_import(self):
        with self.assertRaisesRegex(ValueError,"Wrong target project"):
            mod.ingest([],mod.BLS_URL,mod.BLS_SHA256,1,"wrong-project",
                       "BLS_EMP_2025_2035")

    def test_without_modern_secret_live_import_fails(self):
        prior_url=os.environ.get("SUPABASE_URL")
        prior_key=os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        try:
            os.environ["SUPABASE_URL"]=f"https://{mod.PROJECT}.supabase.co"
            os.environ.pop("SUPABASE_SERVICE_ROLE_KEY",None)
            with self.assertRaisesRegex(ValueError,"sb_secret_"):
                mod.ingest([],mod.BLS_URL,mod.BLS_SHA256,1,mod.PROJECT,
                           "BLS_EMP_2025_2035")
        finally:
            if prior_url is None: os.environ.pop("SUPABASE_URL",None)
            else: os.environ["SUPABASE_URL"]=prior_url
            if prior_key is None: os.environ.pop("SUPABASE_SERVICE_ROLE_KEY",None)
            else: os.environ["SUPABASE_SERVICE_ROLE_KEY"]=prior_key


if __name__ == "__main__":
    unittest.main()
