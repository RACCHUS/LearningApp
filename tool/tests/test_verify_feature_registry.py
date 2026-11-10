"""Regression tests for the no-network feature-registry validator."""
import sys
import unittest
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_DIR))
from verify_feature_registry import verify  # noqa: E402

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


if __name__ == "__main__":
    unittest.main()
