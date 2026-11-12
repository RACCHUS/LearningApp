"""Regression tests for the critical mutation seed runner (no Flutter needed)."""
import contextlib
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))
import mutation_seeds as ms  # noqa: E402

PASS = (ms.PYTHON, "-c", "raise SystemExit(0)")
# Fails only when the target file contains the mutated text.
FAILS_IF_MUTATED = (ms.PYTHON, "-c", "import sys; sys.exit('BAD' in open('target.txt').read())")


def seed(find="GOOD", replace="BAD", command=FAILS_IF_MUTATED, **kw):
    return ms.Seed(id="s", risk="r", file="target.txt", find=find, replace=replace, command=command, **kw)


class MutateTest(unittest.TestCase):
    def test_exact_snippet_must_occur_once(self):
        self.assertEqual(ms.mutate(seed(), "a GOOD b"), "a BAD b")
        with self.assertRaises(ms.SeedError):
            ms.mutate(seed(), "GOOD GOOD")
        with self.assertRaises(ms.SeedError):
            ms.mutate(seed(), "nothing here")

    def test_multiline_snippet_follows_file_newlines(self):
        s = seed(find="x\ny", replace="x\nz")
        self.assertEqual(ms.mutate(s, "x\r\ny\r\n"), "x\r\nz\r\n")
        self.assertEqual(ms.mutate(s, "x\ny\n"), "x\nz\n")

    def test_regex_seed(self):
        s = seed(find=r"(id: a\r?\n(?:[^\n]*\n)*?\s*key: )2", replace=r"\g<1>3", regex=True)
        text = "- id: a\n  p: q\n  key: 2\n- id: b\n  key: 2\n"
        self.assertEqual(ms.mutate(s, text), "- id: a\n  p: q\n  key: 3\n- id: b\n  key: 2\n")

    def test_no_op_mutation_is_rejected(self):
        with self.assertRaises(ms.SeedError):
            ms.mutate(seed(find="SAME", replace="SAME"), "SAME")


class ExecuteTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.target = self.root / "target.txt"
        self.target.write_bytes(b"value = GOOD\r\n")
        self._patches = [
            mock.patch.object(ms, "ROOT", self.root),
            mock.patch.object(ms, "is_dirty", lambda path: False),
            mock.patch.dict(os.environ, {"CI_TEST_PYTHON": sys.executable}),
        ]
        for p in self._patches:
            p.start()
        os.environ.pop("GITHUB_STEP_SUMMARY", None)

    def tearDown(self):
        for p in reversed(self._patches):
            p.stop()
        self._tmp.cleanup()

    def run_seeds(self, *seeds):
        with mock.patch.object(ms, "SEEDS", tuple(seeds)), contextlib.redirect_stdout(io.StringIO()):
            return ms.main([])

    def test_killed_seed_passes_and_file_is_restored_byte_for_byte(self):
        self.assertEqual(self.run_seeds(seed()), 0)
        self.assertEqual(self.target.read_bytes(), b"value = GOOD\r\n")

    def test_surviving_seed_fails_and_file_is_restored(self):
        self.assertEqual(self.run_seeds(seed(command=PASS)), 1)
        self.assertEqual(self.target.read_bytes(), b"value = GOOD\r\n")

    def test_failing_baseline_is_an_error_not_a_kill(self):
        always_fails = (ms.PYTHON, "-c", "raise SystemExit(1)")
        self.assertEqual(self.run_seeds(seed(command=always_fails)), 2)
        self.assertEqual(self.target.read_bytes(), b"value = GOOD\r\n")

    def test_file_is_restored_even_if_the_command_crashes(self):
        with mock.patch.object(ms, "run", side_effect=[(0, 0.0), KeyboardInterrupt()]):
            with self.assertRaises(KeyboardInterrupt):
                ms.execute([seed()], timeout=5)
        self.assertEqual(self.target.read_bytes(), b"value = GOOD\r\n")

    def test_dirty_target_is_refused(self):
        with mock.patch.object(ms, "is_dirty", lambda path: True):
            self.assertEqual(self.run_seeds(seed()), 2)
        self.assertEqual(self.target.read_bytes(), b"value = GOOD\r\n")

    def test_check_mode_reports_stale_seed(self):
        with mock.patch.object(ms, "SEEDS", (seed(find="MISSING"),)), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(ms.main(["--check"]), 2)


class RepositorySeedsTest(unittest.TestCase):
    def test_every_repository_seed_applies_exactly_once(self):
        self.assertEqual(ms.check(ms.SEEDS), [])

    def test_seed_ids_are_unique_and_documented(self):
        ids = [s.id for s in ms.SEEDS]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue(all(len(s.risk) > 30 for s in ms.SEEDS))


if __name__ == "__main__":
    unittest.main()
