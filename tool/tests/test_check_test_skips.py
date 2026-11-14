"""Tests for the skipped-test registry ratchet (plan PR-9)."""
import contextlib
import datetime as dt
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))
import check_test_skips as cts  # noqa: E402

TODAY = dt.date(2026, 11, 14)
COND = {"file": "test/a_test.dart", "kind": "conditional", "reason": "needs db", "runs_in": "DB job"}


def quarantine(**over):
    entry = {"file": "test/q_test.dart", "kind": "quarantine", "reason": "flaky timer",
             "tracking": "issue 123", "protection": "service test x", "expires": "2026-11-30"}
    entry.update(over)
    return entry


class FindProblemsTest(unittest.TestCase):
    def test_registered_skips_pass(self):
        skipped = ["test/a_test.dart: works offline", "test/q_test.dart: ticks"]
        self.assertEqual(cts.find_problems(skipped, [COND, quarantine()], TODAY), [])

    def test_unregistered_skip_fails(self):
        problems = cts.find_problems(["test/new_test.dart: something"], [], TODAY)
        self.assertEqual(problems, ["unregistered skip: test/new_test.dart: something"])

    def test_stale_entry_fails(self):
        problems = cts.find_problems([], [COND], TODAY)
        self.assertIn("stale registry entry (no longer skipped): test/a_test.dart", problems)

    def test_name_filter_and_expected_count(self):
        entry = dict(COND, name_contains="offline", expected=2)
        problems = cts.find_problems(["test/a_test.dart: offline one", "test/a_test.dart: online"], [entry], TODAY)
        self.assertIn("unregistered skip: test/a_test.dart: online", problems)
        self.assertIn("test/a_test.dart [offline]: expected 2 skipped tests, found 1", problems)

    def test_expired_quarantine_fails(self):
        problems = cts.find_problems(["test/q_test.dart: t"], [quarantine(expires="2026-11-01")], TODAY)
        self.assertIn("test/q_test.dart: quarantine expired on 2026-11-01", problems)

    def test_quarantine_needs_tracking_protection_and_bounded_expiry(self):
        entry = quarantine(tracking="", protection="", expires="2027-06-01")
        problems = cts.find_problems(["test/q_test.dart: t"], [entry], TODAY)
        self.assertIn("test/q_test.dart: quarantine needs 'tracking'", problems)
        self.assertIn("test/q_test.dart: quarantine needs 'protection'", problems)
        self.assertIn("test/q_test.dart: quarantine longer than 30 days", problems)

    def test_conditional_needs_runs_in_and_valid_kind(self):
        problems = cts.find_problems(["test/a_test.dart: t"], [dict(COND, runs_in="")], TODAY)
        self.assertIn("test/a_test.dart: conditional skip must say where it runs (runs_in)", problems)
        problems = cts.find_problems(["test/a_test.dart: t"], [dict(COND, kind="maybe")], TODAY)
        self.assertIn("test/a_test.dart: kind must be 'conditional' or 'quarantine'", problems)

    def test_current_registry_is_well_formed(self):
        # Every live entry must satisfy the policy rules on its own.
        for entry in cts.SKIP_REGISTRY:
            fake = [f"{entry['file']}: x{i}" for i in range(entry.get("expected", 1))]
            self.assertEqual(cts.find_problems(fake, [entry], TODAY), [], entry["file"])


class CliTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self._old = os.environ.pop("GITHUB_STEP_SUMMARY", None)

    def tearDown(self):
        if self._old is not None:
            os.environ["GITHUB_STEP_SUMMARY"] = self._old
        self.tmp.cleanup()

    def report(self, skips, done=True):
        events = [{"type": "suite", "suite": {"id": 0, "path": str(self.dir / "test/x_test.dart")}, "time": 0}]
        for i, (name, skipped) in enumerate(skips):
            events.append({"type": "testStart", "test": {"id": i, "suiteID": 0, "name": name}, "time": i})
            events.append({"type": "testDone", "testID": i, "result": "success", "hidden": False,
                           "skipped": skipped, "time": i + 1})
        if done:
            events.append({"type": "done", "success": True, "time": 99})
        path = self.dir / "r.json"
        path.write_text("\n".join(json.dumps(e) for e in events), encoding="utf-8")
        return path

    def run_cli(self, path):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cts.main([str(path), "--root", str(self.dir), "--today", "2026-11-14"])
        return code, out.getvalue() + err.getvalue()

    def test_unregistered_skip_in_report_fails(self):
        code, text = self.run_cli(self.report([("runs", False), ("new skip", True)]))
        self.assertEqual(code, 1)
        self.assertIn("unregistered skip: test/x_test.dart: new skip", text)

    def test_interrupted_or_missing_report_is_an_error(self):
        self.assertEqual(self.run_cli(self.report([("a", False)], done=False))[0], 2)
        self.assertEqual(self.run_cli(self.dir / "missing.json")[0], 2)


if __name__ == "__main__":
    unittest.main()
