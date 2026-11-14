"""Tests for the pgTAP scenario parity guard used by the database job (plan PR-6)."""
import contextlib
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path

CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))
import check_pgtap_parity as parity  # noqa: E402

SCENARIOS = ["incremental", "backfill", "clean-slate", "post-ingestion"]


def pg_prove_log(files=71, tests=1793, result="PASS", secs=5):
    return (
        "Connecting to local database...\n"
        "./a_test.sql .............. ok\n"
        "./b_test.sql .............. ok\n"
        "All tests successful.\n"
        f"Files={files}, Tests={tests},  {secs} wallclock secs ( 0.27 usr  0.12 sys +  0.64 cusr  0.30 csys =  1.33 CPU)\n"
        f"Result: {result}\n"
    )


class PgtapParityTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self._old = os.environ.pop("GITHUB_STEP_SUMMARY", None)

    def tearDown(self):
        if self._old is not None:
            os.environ["GITHUB_STEP_SUMMARY"] = self._old
        self.tmp.cleanup()

    def write(self, name, text):
        (self.dir / f"{name}.log").write_text(text, encoding="utf-8")

    def run_check(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = parity.main([str(self.dir)])
        return code, out.getvalue()

    def test_identical_passing_scenarios_pass(self):
        for name in SCENARIOS:
            self.write(name, pg_prove_log())
        code, text = self.run_check()
        self.assertEqual(code, 0)
        self.assertIn("| incremental | 71 | 1793 | 5 | PASS |", text)
        self.assertIn("All 4 scenarios passed the identical pgTAP suite.", text)

    def test_scenario_running_fewer_tests_fails(self):
        for name in SCENARIOS:
            self.write(name, pg_prove_log())
        self.write("backfill", pg_prove_log(files=70, tests=1780))
        code, text = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("different pgTAP totals", text)
        self.assertIn("backfill=70/1780", text)

    def test_missing_scenario_fails(self):
        for name in SCENARIOS[:-1]:
            self.write(name, pg_prove_log())
        code, text = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("post-ingestion: no pgTAP log", text)

    def test_failed_result_fails(self):
        for name in SCENARIOS:
            self.write(name, pg_prove_log())
        self.write("clean-slate", pg_prove_log(result="FAIL"))
        code, text = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("clean-slate: result is FAIL", text)

    def test_truncated_log_without_totals_fails(self):
        for name in SCENARIOS:
            self.write(name, pg_prove_log())
        self.write("incremental", "Connecting to local database...\n./a_test.sql .. ok\n")
        code, text = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("incremental: no `Files=…, Tests=…` totals", text)

    def test_writes_step_summary(self):
        for name in SCENARIOS:
            self.write(name, pg_prove_log())
        summary = self.dir / "summary.md"
        os.environ["GITHUB_STEP_SUMMARY"] = str(summary)
        try:
            self.run_check()
        finally:
            del os.environ["GITHUB_STEP_SUMMARY"]
        self.assertIn("pgTAP scenario parity", summary.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
