"""Tests for the advisory change-aware early feedback planner (plan PR-8)."""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))
import early_feedback as ef  # noqa: E402


class EarlyFeedbackTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        for rel, text in {
            "test/widgets/app_shell_test.dart": "",
            "test/services/lesson/lesson_service_test.dart": "",
            "tool/tests/test_catalog_intake.py": "import unittest\n",
            "tool/tests/test_clep_algebra_math_accuracy.py": "import pytest\n",
        }.items():
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        self._old = os.environ.pop("GITHUB_STEP_SUMMARY", None)

    def tearDown(self):
        if self._old is not None:
            os.environ["GITHUB_STEP_SUMMARY"] = self._old
        self.tmp.cleanup()

    def plan(self, *paths):
        return ef.build_plan(list(paths), self.root)

    def names(self, plan):
        return [c["name"] for c in plan.commands]

    def test_categories(self):
        cases = {
            ".github/workflows/flutter-ci.yml": "ci-and-dependencies",
            "tool/ci/check_test_inventory.py": "ci-and-dependencies",
            "pubspec.lock": "ci-and-dependencies",
            "requirements-e2e.txt": "ci-and-dependencies",
            "supabase/migrations/20261113000000_x.sql": "database",
            "supabase/tests/x_test.sql": "database",
            "content/clep_college_algebra.yaml": "content",
            "lib/services/auth/auth_service.dart": "dart-high-risk",
            "lib/services/assessment/grader.dart": "dart-high-risk",
            "lib/widgets/app_shell.dart": "dart",
            "test/widgets/app_shell_test.dart": "dart",
            "tool/catalog_intake.py": "python-tooling",
            "docs/guide.md": "docs",
            "README.md": "docs",
            "Dockerfile": "unknown",
        }
        for path, expected in cases.items():
            self.assertEqual(ef.categorize(path), expected, path)

    def test_docs_only_runs_nothing(self):
        plan = self.plan("README.md", "docs/a.md")
        self.assertEqual(plan.commands, [])
        self.assertFalse(plan.needs_flutter)
        self.assertTrue(any("Documentation only" in n for n in plan.notes))

    def test_unknown_path_gets_every_early_check(self):
        plan = self.plan("Dockerfile")
        names = self.names(plan)
        for expected in ["Test inventory guard (strict)", "Flutter analyze", "Append-only migration history",
                         "Curriculum manifest lint", "Feature registry contract"]:
            self.assertIn(expected, names)
        self.assertTrue(plan.needs_flutter)

    def test_ui_change_maps_to_its_tests(self):
        plan = self.plan("lib/widgets/app_shell.dart")
        self.assertIn("Flutter analyze", self.names(plan))
        cmd = [c["cmd"] for c in plan.commands if c["name"].startswith("Related Flutter tests")][0]
        self.assertIn("test/widgets/app_shell_test.dart", cmd)
        self.assertNotIn("Append-only migration history", self.names(plan))

    def test_nested_lib_file_found_by_basename(self):
        plan = self.plan("lib/services/lesson_service.dart")
        cmd = [c["cmd"] for c in plan.commands if c["name"].startswith("Related Flutter tests")][0]
        self.assertIn("test/services/lesson/lesson_service_test.dart", cmd)

    def test_unmapped_dart_change_says_so(self):
        plan = self.plan("lib/widgets/brand_new_widget.dart")
        self.assertTrue(any("No test file maps" in n for n in plan.notes))

    def test_high_risk_dart_adds_contract_checks(self):
        names = self.names(self.plan("lib/services/auth/session.dart"))
        self.assertIn("Schema contract (client to migrations)", names)
        self.assertIn("Feature registry contract", names)

    def test_migration_change_runs_history_and_schema_checks(self):
        plan = self.plan("supabase/migrations/20261113000000_x.sql")
        names = self.names(plan)
        self.assertIn("Append-only migration history", names)
        self.assertIn("Schema contract (client to migrations)", names)
        self.assertNotIn("Flutter analyze", names)

    def test_python_tool_runs_its_unittest_suite_but_not_venv_suites(self):
        names = self.names(self.plan("tool/catalog_intake.py", "tool/tests/test_clep_algebra_math_accuracy.py"))
        self.assertIn("Python suite test_catalog_intake.py", names)
        self.assertFalse(any("math_accuracy" in n for n in names))

    def test_too_many_related_tests_defers_to_required_job(self):
        for i in range(ef.MAX_TARGETED_DART_TESTS + 1):
            p = self.root / f"test/w{i}_test.dart"
            p.write_text("", encoding="utf-8")
        plan = self.plan(*[f"test/w{i}_test.dart" for i in range(ef.MAX_TARGETED_DART_TESTS + 1)])
        self.assertFalse(any(n.startswith("Related Flutter tests") for n in self.names(plan)))
        self.assertTrue(any("too many" in n for n in plan.notes))

    def test_commands_are_deduplicated(self):
        names = self.names(self.plan("supabase/migrations/a.sql", "lib/services/auth/x.dart"))
        self.assertEqual(names.count("Schema contract (client to migrations)"), 1)

    def test_run_reports_every_failure_and_exits_nonzero(self):
        plan_file = self.root / "plan.json"
        ok = f'"{sys.executable}" -c "pass"'
        bad = f'"{sys.executable}" -c "raise SystemExit(3)"'
        plan_file.write_text(json.dumps({"commands": [
            {"name": "bad", "cmd": bad}, {"name": "ok", "cmd": ok}]}), encoding="utf-8")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ef.main(["run", str(plan_file)])
        self.assertEqual(code, 1)
        text = out.getvalue()
        self.assertIn("| bad | **FAIL** (exit 3) |", text)
        self.assertIn("| ok | pass |", text)

    def test_plan_cli_writes_json_and_output(self):
        changed = self.root / "changed.txt"
        changed.write_text("lib/widgets/app_shell.dart\nREADME.md\n", encoding="utf-8")
        gh_out = self.root / "gh_out.txt"
        old = os.environ.get("GITHUB_OUTPUT")
        os.environ["GITHUB_OUTPUT"] = str(gh_out)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                ef.main(["plan", str(changed), "--out", str(self.root / "plan.json"), "--root", str(self.root)])
        finally:
            if old is None:
                del os.environ["GITHUB_OUTPUT"]
            else:
                os.environ["GITHUB_OUTPUT"] = old
        data = json.loads((self.root / "plan.json").read_text(encoding="utf-8"))
        self.assertTrue(data["needs_flutter"])
        self.assertEqual(gh_out.read_text(encoding="utf-8"), "needs_flutter=true\n")


if __name__ == "__main__":
    unittest.main()
