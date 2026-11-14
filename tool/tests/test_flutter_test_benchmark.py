"""Tests for the advisory Flutter test concurrency benchmark (plan PR-5)."""
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
import flutter_test_benchmark as bench  # noqa: E402


def report_lines(test_names, fail=None, done=True):
    out = [{"type": "start", "time": 0},
           {"type": "suite", "suite": {"id": 0, "path": "/repo/test/a_test.dart"}, "time": 1}]
    tid = 0
    for i, name in enumerate(test_names):
        tid += 1
        out.append({"type": "testStart", "test": {"id": tid, "suiteID": 0, "name": name}, "time": 10 * i})
        result = "failure" if name == fail else "success"
        out.append({"type": "testDone", "testID": tid, "result": result, "hidden": False,
                    "skipped": False, "time": 10 * i + 5})
    if done:
        out.append({"type": "done", "success": fail is None, "time": 4000})
    return "\n".join(json.dumps(e) for e in out) + "\n"


class BenchmarkTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.results = self.dir / "results"

    def tearDown(self):
        self.tmp.cleanup()

    def _record(self, label, trial, names, *, wall=100.0, exit_code=0, fail=None, done=True,
                mem_samples=None, write_report=True):
        report = self.dir / f"r_{label}_{trial}.json"
        if write_report:
            report.write_text(report_lines(names, fail=fail, done=done), encoding="utf-8")
        argv = ["record", "--report", str(report), "--concurrency", label, "--trial", str(trial),
                "--wall-seconds", str(wall), "--exit-code", str(exit_code), "--root", "/repo",
                "--out", str(self.results / f"{label}-{trial}.json")]
        if mem_samples is not None:
            log = self.dir / f"mem_{label}_{trial}.log"
            log.write_text("\n".join(mem_samples) + "\n", encoding="utf-8")
            argv += ["--memory-log", str(log)]
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(bench.main(argv), 0)
        return json.loads((self.results / f"{label}-{trial}.json").read_text(encoding="utf-8"))

    def _summarize(self):
        out = io.StringIO()
        old = os.environ.pop("GITHUB_STEP_SUMMARY", None)
        try:
            with contextlib.redirect_stdout(out):
                code = bench.main(["summarize", str(self.results)])
        finally:
            if old is not None:
                os.environ["GITHUB_STEP_SUMMARY"] = old
        return code, out.getvalue()

    def test_record_counts_inventory_and_peak_memory(self):
        r = self._record("4", 1, ["a", "b"], mem_samples=["900", "x", "1500", "1200", ""])
        self.assertEqual((r["passed"], r["failed"], r["skipped"]), (2, 0, 0))
        self.assertTrue(r["success"] and r["completed"])
        self.assertEqual(r["peak_memory_used_mib"], 1500)
        self.assertEqual(r["concurrency"], "4")

    def test_inventory_hash_ignores_order_but_not_names(self):
        a = self._record("2", 1, ["x", "y"])["inventory"]
        b = self._record("2", 2, ["y", "x"])["inventory"]
        c = self._record("2", 3, ["x", "z"])["inventory"]
        self.assertEqual(a, b)
        self.assertNotEqual(a, c)

    def test_valid_benchmark_reports_p50_and_delta(self):
        for t, wall in enumerate([200, 210, 190], 1):
            self._record("default", t, ["a", "b"], wall=wall)
        for t, wall in enumerate([150, 160, 140], 1):
            self._record("4", t, ["a", "b"], wall=wall)
        code, text = self._summarize()
        self.assertEqual(code, 0)
        self.assertIn("| `default` | 3 | 200s |", text)
        self.assertIn("| `4` | 3 | 150s (-25%) |", text)
        self.assertIn("identical test inventory", text)
        self.assertLess(text.index("`default`"), text.index("`4`"))

    def test_inventory_drift_invalidates_benchmark(self):
        self._record("default", 1, ["a", "b"])
        self._record("6", 1, ["a"])  # one test silently not collected
        code, text = self._summarize()
        self.assertEqual(code, 1)
        self.assertIn("inventory differs", text)
        self.assertIn("Benchmark invalid", text)

    def test_failure_or_interruption_invalidates_benchmark(self):
        self._record("default", 1, ["a", "b"])
        self._record("6", 1, ["a", "b"], fail="b", exit_code=1)
        self._record("8", 1, ["a", "b"], done=False)
        code, text = self._summarize()
        self.assertEqual(code, 1)
        self.assertIn("concurrency=6 trial=1: test run failed", text)
        self.assertIn("concurrency=8 trial=1: report has no `done` event", text)

    def test_missing_report_and_empty_dir_are_errors(self):
        self.results.mkdir(parents=True)
        code, text = self._summarize()
        self.assertEqual(code, 1)
        self.assertIn("no benchmark results found", text)
        r = self._record("3", 1, [], write_report=False, exit_code=1)
        self.assertFalse(r["report_found"])
        code, text = self._summarize()
        self.assertEqual(code, 1)
        self.assertIn("no JSON report", text)

    def test_summary_is_appended_to_step_summary(self):
        self._record("default", 1, ["a"])
        summary = self.dir / "summary.md"
        old = os.environ.get("GITHUB_STEP_SUMMARY")
        os.environ["GITHUB_STEP_SUMMARY"] = str(summary)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                bench.main(["summarize", str(self.results)])
        finally:
            if old is None:
                del os.environ["GITHUB_STEP_SUMMARY"]
            else:
                os.environ["GITHUB_STEP_SUMMARY"] = old
        self.assertIn("Flutter test concurrency benchmark", summary.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
