"""Tests for tool/verify_codebase_map.py (fixtures from the validator design)."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_codebase_map as vcm  # noqa: E402

GOOD_SECTION = (
    "## Feature {#feat}\n\n"
    '<!-- map-ref path="lib/a.dart" role="owner" lines="1-3" -->\n'
    "- Owner.\n"
    '<!-- map-ref path="test/a_test.dart" role="test" -->\n'
    "- Tests.\n"
)


class VerifyCodebaseMapTest(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        (self.root / "lib").mkdir()
        (self.root / "test").mkdir()
        (self.root / "lib/a.dart").write_text("one\ntwo\nthree\n", encoding="utf-8")
        (self.root / "test/a_test.dart").write_text("t\n", encoding="utf-8")
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)

    def errors(self, body: str, track: bool = True) -> list[str]:
        map_path = self.root / "MAP.md"
        map_path.write_text(body, encoding="utf-8")
        if track:
            subprocess.run(["git", "-C", str(self.root), "add", "MAP.md"], check=True)
        return vcm.check(self.root, map_path)

    def test_valid_refs_with_and_without_lines_pass(self):
        self.assertEqual(self.errors(GOOD_SECTION), [])

    def test_parent_escape_is_rejected(self):
        errs = self.errors(GOOD_SECTION + '<!-- map-ref path="../secrets.txt" role="contract" -->\n')
        self.assertTrue(any("escapes repository" in e for e in errs), errs)

    def test_absolute_and_drive_paths_are_rejected(self):
        for bad in ("/etc/passwd", "C:/x.dart", "lib\\a.dart"):
            errs = self.errors(GOOD_SECTION + f'<!-- map-ref path="{bad}" role="contract" -->\n')
            self.assertTrue(any("escapes repository" in e for e in errs), (bad, errs))

    @unittest.skipIf(os.name == "nt", "symlinks need privileges on Windows")
    def test_symlink_pointing_outside_is_rejected(self):
        outside = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, outside, True)
        (outside / "x.dart").write_text("x\n", encoding="utf-8")
        (self.root / "lib/link.dart").symlink_to(outside / "x.dart")
        errs = self.errors(GOOD_SECTION + '<!-- map-ref path="lib/link.dart" role="contract" -->\n')
        self.assertTrue(any("escapes repository" in e for e in errs), errs)

    def test_missing_file_is_reported(self):
        errs = self.errors(GOOD_SECTION + '<!-- map-ref path="lib/gone.dart" role="contract" -->\n')
        self.assertTrue(any("missing or untracked: lib/gone.dart" in e for e in errs), errs)

    def test_untracked_file_is_reported(self):
        (self.root / "lib/new.dart").write_text("n\n", encoding="utf-8")
        errs = self.errors(GOOD_SECTION + '<!-- map-ref path="lib/new.dart" role="contract" -->\n')
        self.assertTrue(any("missing or untracked: lib/new.dart" in e for e in errs), errs)

    def test_ranges_out_of_bounds_or_reversed_are_reported(self):
        for rng in ("2-1", "1-4"):
            body = GOOD_SECTION.replace('lines="1-3"', f'lines="{rng}"')
            errs = self.errors(body)
            self.assertTrue(any("out of bounds" in e for e in errs), (rng, errs))

    def test_unquoted_attribute_is_malformed(self):
        errs = self.errors(GOOD_SECTION + '<!-- map-ref path=lib/a.dart role="owner" -->\n')
        self.assertTrue(any("malformed map-ref" in e for e in errs), errs)

    def test_refs_inside_fenced_blocks_are_ignored(self):
        body = GOOD_SECTION + '```\n<!-- map-ref path="lib/nope.dart" role="owner" -->\n```\n'
        self.assertEqual(self.errors(body), [])

    def test_backticked_prose_paths_are_ignored(self):
        self.assertEqual(self.errors(GOOD_SECTION + "See `lib/does_not_exist.dart`.\n"), [])

    def test_section_without_test_is_reported(self):
        body = '## Only contract {#only}\n<!-- map-ref path="lib/a.dart" role="contract" -->\n'
        errs = self.errors(body)
        self.assertTrue(any("section #only" in e for e in errs), errs)

    def test_policy_counts_as_owner(self):
        body = (
            "## Policy {#pol}\n"
            '<!-- map-ref path="lib/a.dart" role="policy" -->\n'
            '<!-- map-ref path="test/a_test.dart" role="test" -->\n'
        )
        self.assertEqual(self.errors(body), [])

    def test_size_cap(self):
        errs = self.errors(GOOD_SECTION + "x\n" * vcm.MAX_LINES)
        self.assertTrue(any("exceeds cap" in e for e in errs), errs)

    def test_main_exit_codes(self):
        (self.root / "docs/engineering").mkdir(parents=True)
        (self.root / vcm.DEFAULT_MAP).write_text(GOOD_SECTION, encoding="utf-8")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        self.assertEqual(vcm.main(["--root", str(self.root)]), 0)
        (self.root / vcm.DEFAULT_MAP).write_text(GOOD_SECTION.replace("a_test", "gone_test"), encoding="utf-8")
        self.assertEqual(vcm.main(["--root", str(self.root)]), 1)


class RealMapTest(unittest.TestCase):
    def test_repository_map_is_clean(self):
        root = Path(__file__).resolve().parents[2]
        map_path = root / vcm.DEFAULT_MAP
        if not map_path.is_file():
            self.skipTest("no codebase map in this checkout")
        self.assertEqual(vcm.check(root, map_path), [])


if __name__ == "__main__":
    unittest.main()
