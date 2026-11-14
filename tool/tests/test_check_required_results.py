"""Tests for the fail-closed required gate (plan §9 E1)."""
import contextlib
import io
import json
import os
import sys
import unittest
from pathlib import Path
from unittest import mock

CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))
import check_required_results as gate  # noqa: E402

JOBS = ["verify", "web-builds"]


def run(needs, required=JOBS):
    env = {"NEEDS_JSON": needs if isinstance(needs, str) else json.dumps(needs)}
    out, err = io.StringIO(), io.StringIO()
    with mock.patch.dict(os.environ, env, clear=False), \
            contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        os.environ.pop("GITHUB_STEP_SUMMARY", None)
        code = gate.main(list(required))
    return code, out.getvalue() + err.getvalue()


def needs(**results):
    return {job: {"result": result, "outputs": {}} for job, result in results.items()}


class GateTest(unittest.TestCase):
    def test_all_success_passes(self):
        code, text = run(needs(verify="success", **{"web-builds": "success"}))
        self.assertEqual(code, 0)
        self.assertIn("All required jobs succeeded.", text)

    def test_every_non_success_result_fails(self):
        for bad in ("failure", "cancelled", "skipped"):
            code, text = run(needs(verify="success", **{"web-builds": bad}))
            self.assertEqual(code, 1, bad)
            self.assertIn(f"| `web-builds` | **{bad}** |", text)

    def test_missing_job_fails(self):
        code, text = run(needs(verify="success"))
        self.assertEqual(code, 1)
        self.assertIn("| `web-builds` | **missing** |", text)

    def test_empty_or_null_result_counts_as_missing(self):
        code, _ = run({"verify": {"result": ""}, "web-builds": None})
        self.assertEqual(code, 1)

    def test_bad_input_is_an_error_not_a_pass(self):
        self.assertEqual(run("not json")[0], 2)
        self.assertEqual(run("[]")[0], 2)
        self.assertEqual(run(needs(verify="success"), required=[])[0], 2)

    def test_extra_jobs_in_needs_are_ignored(self):
        code, _ = run(needs(verify="success", other="failure", **{"web-builds": "success"}))
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
