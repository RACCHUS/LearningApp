import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_open_source_versions as c  # noqa: E402

BOOKS = [{"source_id": "openstax-prealgebra-1e", "book": "caa57dab@eb2e29d"},
         {"source_id": "openstax-college-algebra-1e", "book": "9b08c294@ebc5beb"}]


class CompareTests(unittest.TestCase):
    def test_unchanged_changed_and_missing(self):
        pins = [
            {"manifest": "a.yaml", "slug": "open-prealgebra", "source_id": "openstax-prealgebra-1e", "pin": "eb2e29d"},
            {"manifest": "b.yaml", "slug": "open-algebra", "source_id": "openstax-college-algebra-1e", "pin": "ebc5beb"},
            {"manifest": "c.yaml", "slug": "open-other", "source_id": "unknown-book", "pin": "abc"},
        ]
        release = {"books": {"caa57dab": {"defaultVersion": "EB2E29D"},
                             "9b08c294": {"defaultVersion": "f00d123"}}}
        rows = {r["slug"]: r for r in c.compare(pins, release, BOOKS)}
        self.assertFalse(rows["open-prealgebra"]["changed"], "case is ignored")
        self.assertTrue(rows["open-algebra"]["changed"])
        self.assertEqual(rows["open-algebra"]["current"], "f00d123")
        self.assertTrue(rows["open-other"]["changed"])
        self.assertEqual(rows["open-other"]["current"], "missing")

    def test_repository_manifests_are_pinned(self):
        pins = c.manifest_pins()
        self.assertTrue(pins, "open-textbook manifests exist")
        for p in pins:
            self.assertRegex(p["pin"], r"^[0-9a-f]{7}$", p["manifest"])
            self.assertTrue(p["slug"].startswith("open-openstax-"), p["manifest"])


if __name__ == "__main__":
    unittest.main()
