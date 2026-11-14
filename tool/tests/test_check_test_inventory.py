"""Regression tests for the tool/tests CI inventory guard (no network)."""
import contextlib
import io
import os
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))
import check_test_inventory as inv  # noqa: E402

UNITTEST_SRC = textwrap.dedent(
    """
    import unittest

    class AlphaTest(unittest.TestCase):
        def test_one(self):
            self.assertTrue(True)

        def test_two(self):
            self.assertTrue(True)
    """
)
PYTEST_SRC = textwrap.dedent(
    """
    def test_alpha():
        assert 1 + 1 == 2

    class TestGroup:
        def test_beta(self):
            assert True
    """
)
EMPTY_SRC = "import unittest\n\nclass Nothing(unittest.TestCase):\n    pass\n"


def workflow(*commands: str) -> str:
    steps = "\n".join(f"      - run: {c}" for c in commands)
    return f"jobs:\n  verify:\n    steps:\n{steps}\n"


class InventoryTest(unittest.TestCase):
    def setUp(self):
        # Keep main() from writing into a real CI job summary.
        self._env = dict(os.environ)
        os.environ.pop("GITHUB_STEP_SUMMARY", None)
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "tool/tests").mkdir(parents=True)
        (self.root / ".github/workflows").mkdir(parents=True)

    def tearDown(self):
        self._tmp.cleanup()
        os.environ.clear()
        os.environ.update(self._env)

    def run_main(self, *args: str) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return inv.main(["--root", str(self.root), *args])

    def add_test(self, name: str, source: str) -> None:
        (self.root / "tool/tests" / name).write_text(source, encoding="utf-8")

    def set_workflow(self, *commands: str) -> None:
        (self.root / ".github/workflows/ci.yml").write_text(workflow(*commands), encoding="utf-8")

    def problems(self, known=None):
        files = inv.build_inventory(self.root)
        return files, inv.find_problems(files, known or {})

    def kinds(self, problems):
        return sorted((p.kind, p.file) for p in problems)

    def test_registered_unittest_and_pytest_suites_pass(self):
        self.add_test("test_a.py", UNITTEST_SRC)
        self.add_test("test_b.py", PYTEST_SRC)
        self.set_workflow(
            "python3 -m unittest discover -s tool/tests -p 'test_a.py' -v",
            "PYTHONPATH=. python3 -m pytest tool/tests/test_b.py -q",
        )
        files, problems = self.problems()
        self.assertEqual(problems, [])
        self.assertEqual((files["test_a.py"].framework, files["test_a.py"].test_count), ("unittest", 2))
        self.assertEqual((files["test_b.py"].framework, files["test_b.py"].test_count), ("pytest", 2))

    def test_synthetic_new_unregistered_file_fails(self):
        self.add_test("test_a.py", UNITTEST_SRC)
        self.set_workflow("python3 -m unittest discover -s tool/tests -p 'test_a.py' -v")
        self.add_test("test_new_feature.py", UNITTEST_SRC)
        _, problems = self.problems()
        self.assertEqual(self.kinds(problems), [("unregistered", "test_new_feature.py")])
        self.assertEqual(self.run_main(), 1)

    def test_pytest_module_run_only_by_unittest_is_a_mismatch(self):
        self.add_test("test_b.py", PYTEST_SRC)
        self.set_workflow("python3 -m unittest discover -s tool/tests -p 'test_b.py' -v")
        _, problems = self.problems()
        self.assertEqual(self.kinds(problems), [("runner_mismatch", "test_b.py")])

    def test_glob_pattern_registers_matching_files(self):
        self.add_test("test_a.py", UNITTEST_SRC)
        self.add_test("test_c.py", UNITTEST_SRC)
        self.set_workflow("python3 -m unittest discover -s tool/tests -p 'test_*.py'")
        _, problems = self.problems()
        self.assertEqual(problems, [])

    def test_other_discovery_directory_does_not_count(self):
        self.add_test("test_a.py", UNITTEST_SRC)
        self.set_workflow("python3 -m unittest discover -s other/tests -p 'test_a.py'")
        _, problems = self.problems()
        self.assertEqual(self.kinds(problems), [("unregistered", "test_a.py")])

    def test_zero_tests_and_duplicates_are_reported(self):
        self.add_test("test_empty.py", EMPTY_SRC)
        self.add_test("test_a.py", UNITTEST_SRC)
        self.set_workflow(
            "python3 -m unittest discover -s tool/tests -p 'test_empty.py'",
            "python3 -m unittest discover -s tool/tests -p 'test_a.py'",
            "python3 -m unittest discover -s tool/tests -p 'test_a.py'",
        )
        _, problems = self.problems()
        self.assertEqual(self.kinds(problems), [("duplicate", "test_a.py"), ("zero_tests", "test_empty.py")])

    def test_rerun_in_a_separate_workflow_is_not_a_duplicate(self):
        self.add_test("test_a.py", UNITTEST_SRC)
        self.add_test("test_b.py", PYTEST_SRC)
        self.set_workflow(
            "python3 -m unittest discover -s tool/tests -p 'test_a.py'",
            "python3 -m pytest tool/tests/test_b.py",
        )
        # e.g. a weekly coverage audit re-running everything on purpose
        (self.root / ".github/workflows/audit.yml").write_text(
            workflow("python3 -m pytest tool/tests --ignore=tool/tests/test_skip.py -q"), encoding="utf-8")
        _, problems = self.problems()
        self.assertEqual(problems, [])

    def test_pytest_ignore_excludes_a_file_from_directory_registration(self):
        self.add_test("test_b.py", PYTEST_SRC)
        self.add_test("test_c.py", PYTEST_SRC)
        self.set_workflow("python3 -m pytest tool/tests --ignore=tool/tests/test_c.py")
        _, problems = self.problems()
        self.assertEqual(self.kinds(problems), [("unregistered", "test_c.py")])
        self.set_workflow("python3 -m pytest tool/tests --ignore tool/tests/test_c.py")
        _, problems = self.problems()
        self.assertEqual(self.kinds(problems), [("unregistered", "test_c.py")])

    def test_known_gap_is_tolerated_in_ratchet_mode_but_fails_strict(self):
        self.add_test("test_a.py", UNITTEST_SRC)
        self.add_test("test_b.py", PYTEST_SRC)
        self.set_workflow("python3 -m unittest discover -s tool/tests -p 'test_a.py'")
        _, problems = self.problems({"test_b.py": "pending"})
        self.assertEqual([(p.kind, p.known) for p in problems], [("unregistered", True)])
        original = dict(inv.KNOWN_GAPS)
        try:
            inv.KNOWN_GAPS.clear()
            inv.KNOWN_GAPS["test_b.py"] = "pending"
            self.assertEqual(self.run_main(), 0)
            self.assertEqual(self.run_main("--strict"), 1)
        finally:
            inv.KNOWN_GAPS.clear()
            inv.KNOWN_GAPS.update(original)

    def test_stale_known_gap_fails(self):
        self.add_test("test_a.py", UNITTEST_SRC)
        self.set_workflow("python3 -m unittest discover -s tool/tests -p 'test_a.py'")
        _, problems = self.problems({"test_a.py": "was pending"})
        self.assertEqual([(p.kind, p.known) for p in problems], [("stale_known_gap", False)])

    def test_syntax_error_fails_closed_not_zero_tests(self):
        self.add_test("test_broken.py", "def test_x(:\n    pass\n")
        self.set_workflow("python3 -m unittest discover -s tool/tests -p 'test_broken.py'")
        with self.assertRaises(inv.InventoryError):
            inv.build_inventory(self.root)
        self.assertEqual(self.run_main(), 2)

    def test_missing_workflows_fail_closed(self):
        self.add_test("test_a.py", UNITTEST_SRC)
        self.assertEqual(self.run_main(), 2)

    def test_dart_script_registered_by_direct_invocation(self):
        (self.root / "tool/tests/thing_test.dart").write_text(
            "void main() { require(true, 'ok'); }\n", encoding="utf-8"
        )
        self.set_workflow("dart tool/tests/thing_test.dart")
        files, problems = self.problems()
        self.assertEqual(problems, [])
        self.assertEqual(files["thing_test.dart"].framework, "dart")


class RepositoryInventoryTest(unittest.TestCase):
    """The real repository must pass the guard in its configured mode."""

    def test_repository_has_no_unknown_gaps(self):
        root = Path(__file__).resolve().parents[2]
        files = inv.build_inventory(root)
        problems = inv.find_problems(files, inv.KNOWN_GAPS)
        unexpected = [p for p in problems if not p.known]
        self.assertEqual(unexpected, [], inv.render_markdown(files, problems, strict=False))


if __name__ == "__main__":
    unittest.main()
