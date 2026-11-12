"""Regression tests for the Flutter test log-noise ratchet guard (no network)."""
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
import check_test_log_noise as noise  # noqa: E402


def report(prints, extra_suites=()):
    """Build a JSON reporter stream: prints is [(file, message)]."""
    files = sorted({f for f, _ in prints} | set(extra_suites))
    events = [{"type": "start", "time": 0}]
    for i, f in enumerate(files):
        events.append({"type": "suite", "suite": {"id": i, "path": f"/x/LearningAppClaude/{f}"}, "time": 1})
        events.append({"type": "testStart", "test": {"id": 100 + i, "suiteID": i, "name": "t"}, "time": 1})
    for f, message in prints:
        events.append({"type": "print", "testID": 100 + files.index(f), "message": message, "time": 2})
    events.append({"type": "done", "success": True, "time": 3})
    return [json.dumps(e) for e in events]


class LogNoiseTest(unittest.TestCase):
    def setUp(self):
        self._env = dict(os.environ)
        os.environ.pop("GITHUB_STEP_SUMMARY", None)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._env)

    def run_main(self, lines, *args):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "r.json"
            path.write_text("\n".join(lines), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                return noise.main([str(path), *args])

    def test_each_setup_gap_signature_is_detected(self):
        messages = {
            "missing-plugin": "Error: MissingPluginException(No implementation found for method x)",
            "missing-mock-stub": "MissingStubError: 'initialize'",
            "late-init": "LateInitializationError: Field 'hive' has not been initialized.",
            "supabase-uninitialized": "Failed assertion: You must initialize the supabase instance before calling",
            "binding-uninitialized": "Failed assertion: '_binaryMessenger != null || BindingBase.debugBindingType() != null'",
        }
        for kind, message in messages.items():
            hits, _, _ = noise.scan(report([("test/a_test.dart", message)]))
            self.assertEqual(dict(hits["test/a_test.dart"]), {kind: 1}, kind)

    def test_intentional_negative_path_logging_is_not_noise(self):
        lines = report([
            ("test/a_test.dart", "Failed to flush batch: Exception: Simulated network timeout"),
            ("test/a_test.dart", "Error fetching: PostgrestException(message: Simulated RPC failure)"),
            ("test/a_test.dart", "Error: SocketException: offline"),
        ])
        hits, _, _ = noise.scan(lines)
        self.assertEqual(dict(hits), {})
        self.assertEqual(self.run_main(lines), 0)

    def test_new_noise_fails_and_known_noise_warns(self):
        known_file = next(iter(noise.KNOWN_NOISE))
        lines = report([
            ("test/new_test.dart", "MissingPluginException(No implementation)"),
            (known_file, "MissingStubError: 'from'"),
        ])
        hits, ran, _ = noise.scan(lines)
        failures, warnings = noise.evaluate(hits, ran, noise.KNOWN_NOISE, strict=False)
        self.assertEqual([f for f, _ in failures], ["test/new_test.dart"])
        self.assertEqual([f for f, _ in warnings], [known_file])
        self.assertEqual(self.run_main(lines), 1)

    def test_only_known_noise_passes_ratchet_but_fails_strict(self):
        lines = report([(f, "MissingStubError: 'x'") for f in noise.KNOWN_NOISE])
        self.assertEqual(self.run_main(lines), 0)
        self.assertEqual(self.run_main(lines, "--strict"), 1)

    def test_known_file_that_ran_clean_is_stale(self):
        clean_known = next(iter(noise.KNOWN_NOISE))
        others = [(f, "MissingStubError: 'x'") for f in noise.KNOWN_NOISE if f != clean_known]
        lines = report(others, extra_suites=[clean_known])
        hits, ran, _ = noise.scan(lines)
        failures, _ = noise.evaluate(hits, ran, noise.KNOWN_NOISE, strict=False)
        self.assertEqual(failures, [(clean_known, "listed in KNOWN_NOISE but now clean; remove the entry")])

    def test_known_file_absent_from_run_is_not_stale(self):
        # e.g. a sharded run that did not include the file
        lines = report([], extra_suites=["test/unrelated_test.dart"])
        self.assertEqual(self.run_main(lines), 0)

    def test_unreadable_or_empty_report_fails_closed(self):
        self.assertEqual(self.run_main(['{"type":"start","time":0}']), 2)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(noise.main(["/nonexistent/report.json"]), 2)

    def test_every_known_entry_has_a_reason(self):
        for file, reason in noise.KNOWN_NOISE.items():
            self.assertTrue(file.startswith("test/") and file.endswith("_test.dart"), file)
            self.assertGreater(len(reason), 60, file)


if __name__ == "__main__":
    unittest.main()
