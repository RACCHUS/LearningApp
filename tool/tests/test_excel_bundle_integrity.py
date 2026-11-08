"""Check the generated self-host bundle has the EXACT latest Excel SQL migration.

This guard prevents a corrupted, duplicated, or stale consolidated schema from
shipping even when its separate migration file was fixed. It uses file text,
not a database, and must run before clean/upgrade migration checks.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MIGRATION = "20261107150000_software_learning_excel_brokered_upload_seal.sql"
BUNDLE = ROOT / "deploy/self-host/init-scripts/01-full-schema.sql"
SOURCE = ROOT / "supabase/migrations" / MIGRATION
HEADER = f"-- [100/101] Migration: {MIGRATION}"
INSERT = (
    "INSERT INTO supabase_migrations.schema_migrations "
    "(version, name) VALUES ('20261107150000', "
    "'software_learning_excel_brokered_upload_seal')"
)


class LatestExcelBundleTest(unittest.TestCase):
    def test_brokered_migration_bundle_is_byte_identical(self):
        source = SOURCE.read_text(encoding="utf-8").strip()
        bundle = BUNDLE.read_text(encoding="utf-8")
        self.assertEqual(bundle.count(HEADER), 1)
        self.assertEqual(bundle.count(INSERT), 1)
        self.assertIn("-- [101/101] Migration: 20261108000000_assessment_item_server_grading.sql", bundle)
        self.assertEqual(bundle.count("20261108000000_assessment_item_server_grading.sql"), 1)
        self.assertIn("101 immutable migrations", bundle)
        at = bundle.index(HEADER)
        begin = bundle.find("\n-- Excel pilot:", at)
        end = bundle.rfind("\n" + INSERT)
        self.assertGreater(begin, at)
        self.assertGreater(end, begin)
        self.assertEqual(bundle[begin:end].strip(), source)

    def test_no_partial_digest_patterns_or_repeated_claim_bodies(self):
        source = SOURCE.read_text(encoding="utf-8")
        self.assertEqual(source.count("AS $claim$"), 1)
        self.assertEqual(source.count("AS $complete$"), 1)
        self.assertEqual(source.count("AS $brokerlock$"), 1)
        self.assertEqual(source.count("AS $brokerseal$"), 1)
        self.assertEqual(source.count("COMMIT;"), 1)
        self.assertIn("p_digest !~ '^[a-f0-9]{64}$'", source)
        self.assertIn("a.upload_sha256 ~ '^[a-f0-9]{64}$'", source)


if __name__ == "__main__":
    unittest.main()
