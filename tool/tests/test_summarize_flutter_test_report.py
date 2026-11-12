"""Regression tests for the report-only Flutter JSON test summarizer."""
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
import summarize_flutter_test_report as summ  # noqa: E402

ROOT = Path("/repo")


def events(include_done=True):
    out = [
        {"type": "start", "time": 0},
        {"type": "suite", "suite": {"id": 0, "path": "/repo/test/a_test.dart"}, "time": 1},
        {"type": "suite", "suite": {"id": 1, "path": "/repo/test/b_test.dart"}, "time": 1},
        # hidden loading placeholder for suite 0
        {"type": "testStart", "test": {"id": 1, "suiteID": 0, "name": "loading a"}, "time": 2},
        {"type": "testDone", "testID": 1, "result": "success", "hidden": True, "skipped": False, "time": 900},
        {"type": "testStart", "test": {"id": 2, "suiteID": 0, "name": "adds | numbers"}, "time": 900},
        {"type": "testDone", "testID": 2, "result": "success", "hidden": False, "skipped": False, "time": 1400},
        {"type": "testStart", "test": {"id": 3, "suiteID": 0, "name": "skipped one"}, "time": 1400},
        {"type": "testDone", "testID": 3, "result": "success", "hidden": False, "skipped": True, "time": 1401},
        {"type": "testStart", "test": {"id": 4, "suiteID": 1, "name": "breaks"}, "time": 10},
        {"type": "testDone", "testID": 4, "result": "failure", "hidden": False, "skipped": False, "time": 60},
        {"type": "testStart", "test": {"id": 5, "suiteID": 1, "name": "errors"}, "time": 60},
        {"type": "testDone", "testID": 5, "result": "error", "hidden": False, "skipped": False, "time": 70},
    ]
    if include_done:
        out.append({"type": "done", "success": False, "time": 1500})
    return [json.dumps(e) for e in out]


class SummarizerTest(unittest.TestCase):
    def setUp(self):
        self._env = dict(os.environ)
        os.environ.pop("GITHUB_STEP_SUMMARY", None)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._env)

    def test_counts_exclude_hidden_and_split_outcomes(self):
        report = summ.parse(events(), ROOT)
        self.assertEqual((report.passed, report.failed, report.skipped), (1, 2, 1))
        self.assertIs(report.success, False)
        self.assertEqual(report.end_ms, 1500)
        self.assertEqual(report.skipped_names, ["test/a_test.dart: skipped one"])

    def test_suite_span_includes_loading_but_summed_time_does_not(self):
        report = summ.parse(events(), ROOT)
        a = report.suites[0]
        self.assertEqual(a.path, "test/a_test.dart")
        self.assertEqual(a.span_ms, 1399)
        self.assertEqual(a.test_ms, 501)
        self.assertEqual(a.tests, 2)

    def test_render_escapes_pipes_and_lists_failures(self):
        text = summ.render(summ.parse(events(), ROOT), top=5, label="L", note=None)
        self.assertIn("| 1 / 2 / 1 / 4 |", text)
        self.assertIn("adds \\| numbers", text)
        self.assertIn("- test/b_test.dart: breaks", text)
        self.assertIn("FAILED", text)

    def test_truncated_report_is_marked_incomplete_and_still_exits_zero(self):
        lines = events(include_done=False) + ['{"type": "testStart", "tes']
        report = summ.parse(lines, ROOT)
        self.assertIsNone(report.success)
        self.assertEqual(report.malformed_lines, 1)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "r.json"
            path.write_text("\n".join(lines), encoding="utf-8")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(summ.main([str(path), "--root", str(ROOT)]), 0)
            self.assertIn("interrupted", out.getvalue())

    def test_missing_report_is_noted_not_fatal(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(summ.main(["/nonexistent/report.json"]), 0)
        self.assertIn("No report file", out.getvalue())

    def test_writes_github_step_summary_when_set(self):
        with tempfile.TemporaryDirectory() as tmp:
            report_path = Path(tmp) / "r.json"
            report_path.write_text("\n".join(events()), encoding="utf-8")
            summary = Path(tmp) / "summary.md"
            os.environ["GITHUB_STEP_SUMMARY"] = str(summary)
            with contextlib.redirect_stdout(io.StringIO()):
                summ.main([str(report_path), "--root", str(ROOT), "--label", "Flutter suite"])
            self.assertIn("## Flutter suite", summary.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
