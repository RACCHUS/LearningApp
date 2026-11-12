"""Regression tests for the no-network feature-registry validator."""
import sys
import unittest
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_DIR))
from verify_feature_registry import effective_seed_sql, verify  # noqa: E402

OK_SQL = """
INSERT INTO private.site_feature_controls
(feature_key,label,category,kind,enabled,maturity,release_ready,description)
VALUES
 ('tel.fast', 'Fast learning approach', 'Learning', 'release', true, 'experimental', true, 'Owner approved'),
 ('ai.byok', 'Bring Your Own Key', 'AI', 'release', false, 'experimental', false, 'Suspended');
"""
OK_DART = """
abstract final class SiteFeatureKeys {
 static const String telFast = 'tel.fast';
 static const String aiByok = 'ai.byok';
}
"""


class FeatureRegistryValidationTest(unittest.TestCase):
    def test_matching_safe_seed_passes(self):
        self.assertEqual(verify(OK_DART, OK_SQL), [])

    def test_missing_dart_key_fails(self):
        self.assertTrue(
            any("mismatch" in problem for problem in verify(
                "static const String telFast = 'tel.fast';", OK_SQL
            ))
        )

    def test_risky_default_on_is_rejected(self):
        unsafe = OK_SQL.replace(
            "'release', false, 'experimental', false, 'Suspended'",
            "'release', true, 'experimental', true, 'Suspended'",
        )
        self.assertTrue(
            any("cannot seed enabled" in problem for problem in verify(
                OK_DART, unsafe
            ))
        )

    def test_key_duplicates_are_rejected(self):
        repeated = OK_DART + "\nstatic const String extra = 'ai.byok';"
        self.assertTrue(any("Duplicate" in e for e in verify(repeated, OK_SQL)))

    def test_additive_seed_is_included_and_duplicates_rejected(self):
        import tempfile

        foundation = OK_SQL
        additive = """
INSERT INTO private.site_feature_controls
(feature_key,label,category,kind,enabled,maturity,release_ready,description)
VALUES
 ('learning.quick_rescue', 'Learning help', 'Learning', 'release', false, 'experimental', false, 'Off')
ON CONFLICT (feature_key) DO NOTHING;
"""
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            (d / "20261110220000_marketing_feature_control_foundation.sql").write_text(foundation)
            (d / "20261111000000_unrelated.sql").write_text("SELECT 1;")
            (d / "20261112000000_learning_quick_rescue_feature_control.sql").write_text(additive)
            sql = effective_seed_sql(d)
            dart = OK_DART.replace(
                "}", " static const String quick = 'learning.quick_rescue';\n}"
            )
            self.assertEqual(verify(dart, sql), [])
            self.assertTrue(any("mismatch" in e for e in verify(OK_DART, sql)))

            (d / "20261113000000_repeat.sql").write_text(additive)
            repeated = effective_seed_sql(d)
            self.assertTrue(any("Duplicate SQL" in e for e in verify(dart, repeated)))

            unsafe = additive.replace("false, 'experimental', false", "true, 'experimental', true")
            (d / "20261113000000_repeat.sql").write_text("SELECT 1;")
            (d / "20261112000000_learning_quick_rescue_feature_control.sql").write_text(unsafe)
            self.assertTrue(
                any("cannot seed enabled" in e for e in verify(dart, effective_seed_sql(d)))
            )

    def test_missing_foundation_is_an_error(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(FileNotFoundError):
                effective_seed_sql(Path(tmp))


if __name__ == "__main__":
    unittest.main()
