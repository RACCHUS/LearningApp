"""Tests for the report-only Python tooling coverage summary (plan §12)."""
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
import summarize_python_coverage as spc  # noqa: E402


def cov(files):
    return {"files": {p: {"summary": {"num_statements": t, "covered_lines": c}} for p, (c, t) in files.items()}}


DATA = cov({
    "tool/ci/a.py": (90, 100),
    "tool/ci/b.py": (10, 10),
    r"tool\software_learning\w.py": (5, 50),
    "tool/catalog_intake.py": (30, 40),
    "tool/curriculum_clep_psychology/domain.py": (0, 5),
})


class PythonCoverageTest(unittest.TestCase):
    def test_subsystem_grouping(self):
        self.assertEqual(spc.subsystem("tool/ci/a.py"), "ci")
        self.assertEqual(spc.subsystem(r"tool\software_learning\w.py"), "software_learning")
        self.assertEqual(spc.subsystem("tool/catalog_intake.py"), spc.TOP_LEVEL)
        self.assertEqual(spc.subsystem("/home/runner/work/x/x/tool/ci/a.py"), "ci")

    def test_render_totals_groups_and_low_list(self):
        text = spc.render(DATA, top=5)
        # 90+10+5+30+0 = 135 of 100+10+50+40+5 = 205
        self.assertIn("**65.9%** (135/205 statements, 5 files)", text)
        self.assertIn("| `ci` | 2 | 100/110 | 90.9% |", text)
        self.assertIn("| `software_learning` | 1 | 5/50 | 10.0% |", text)
        self.assertIn(f"| `{spc.TOP_LEVEL}` | 1 | 30/40 | 75.0% |", text)
        low = text.split("Least-covered")[1]
        self.assertLess(low.index("software_learning/w.py"), low.index("catalog_intake.py"))
        self.assertNotIn("domain.py", low, "files under 20 statements are not listed")
        self.assertIn("No percentage gate", text)

    def test_cli_errors_and_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            good = Path(tmp) / "c.json"
            good.write_text(json.dumps(DATA), encoding="utf-8")
            empty = Path(tmp) / "e.json"
            empty.write_text(json.dumps({"files": {}}), encoding="utf-8")
            old = os.environ.pop("GITHUB_STEP_SUMMARY", None)
            try:
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(spc.main([str(good)]), 0)
                    self.assertEqual(spc.main([str(empty)]), 2)
                    self.assertEqual(spc.main([str(Path(tmp) / "missing.json")]), 2)
            finally:
                if old is not None:
                    os.environ["GITHUB_STEP_SUMMARY"] = old


if __name__ == "__main__":
    unittest.main()
