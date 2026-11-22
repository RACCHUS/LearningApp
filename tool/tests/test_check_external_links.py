import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_external_links as c  # noqa: E402


class LinkCheckTests(unittest.TestCase):
    def test_collects_every_source_and_companion_url(self):
        urls = c.collect_urls()
        self.assertTrue(urls)
        self.assertTrue(all(u.startswith("https://") for u in urls))
        # Companion resources and Bridge sources are both included.
        files = {f for fs in urls.values() for f in fs}
        self.assertTrue(any(f.endswith(".companion.json") for f in files))
        self.assertTrue(any(f.endswith(".bridge.json") for f in files))

    def test_dead_means_an_error_status_or_no_response(self):
        self.assertFalse(c.is_dead(200))
        self.assertFalse(c.is_dead(301))
        self.assertTrue(c.is_dead(404))
        self.assertTrue(c.is_dead(500))
        self.assertTrue(c.is_dead("URLError"))


if __name__ == "__main__":
    unittest.main()
