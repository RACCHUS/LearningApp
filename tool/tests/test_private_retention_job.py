"""No-network, no-production tests for the gated one-shot retention job."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.private_retention_job import run_retention_once

class Connection:
    def __init__(self, autocommit=False):
        self.autocommit = autocommit
        self.closed = 0
    def close(self): self.closed += 1

class Factory:
    def __init__(self, connection=None):
        self.connection = Connection() if connection is None else connection
        self.calls = 0
    def __call__(self):
        self.calls += 1
        return self.connection

class RetentionJobTests(unittest.TestCase):
    def test_dry_run_never_prunes_or_performs_deletes(self):
        factory = Factory()
        with patch("software_learning.private_retention_job.sweep_expired_attempts",
                   return_value={"candidates": 4, "erased": 0, "retry": 0}) as scan, \
             patch("software_learning.private_retention_job.DbApiRetentionRepository") as adapter:
            result = run_retention_once(connection_factory=factory, storage=object())
        self.assertEqual(result, {
            "status": "complete", "dry_run": True, "candidates": 4,
            "erased": 0, "retry": 0, "issuance_records_pruned": 0,
            "account_erasure_confirmed": False,
        })
        self.assertFalse(scan.call_args.kwargs["execute"])
        adapter.return_value.prune_issuance_log.assert_not_called()
        self.assertEqual(factory.connection.closed, 1)

    def test_execute_requires_privileged_authorization_before_db_connection(self):
        factory = Factory()
        for authorized in (False, None, 1, "yes"):
            with self.subTest(authorized=authorized), self.assertRaises(ValueError):
                run_retention_once(connection_factory=factory, storage=object(),
                                   authorized=authorized, execute=True)
        self.assertEqual(factory.calls, 0)

    def test_authorized_execute_prunes_after_bounded_storage_cleanup(self):
        factory = Factory()
        with patch("software_learning.private_retention_job.sweep_expired_attempts",
                   return_value={"candidates": 5, "erased": 4, "retry": 1}) as scan, \
             patch("software_learning.private_retention_job.DbApiRetentionRepository") as adapter:
            adapter.return_value.prune_issuance_log.return_value = 9
            result = run_retention_once(
                connection_factory=factory, storage=object(), authorized=True,
                execute=True, max_results=5, prune_limit=9)
        self.assertEqual(result["status"], "retry_required")
        self.assertEqual((result["candidates"], result["erased"], result["retry"]),
                         (5, 4, 1))
        self.assertEqual(result["issuance_records_pruned"], 9)
        self.assertFalse(result["account_erasure_confirmed"])
        self.assertEqual(scan.call_args.kwargs["max_results"], 5)
        self.assertTrue(scan.call_args.kwargs["execute"])
        adapter.return_value.prune_issuance_log.assert_called_once_with(max_results=9)
        self.assertEqual(factory.connection.closed, 1)

    def test_failed_scan_never_prunes_and_hides_private_errors(self):
        factory = Factory()
        with patch("software_learning.private_retention_job.sweep_expired_attempts",
                   side_effect=RuntimeError("private sb_secret_abc")) as scan, \
             patch("software_learning.private_retention_job.DbApiRetentionRepository") as adapter:
            result = run_retention_once(connection_factory=factory, storage=object(),
                                        authorized=True, execute=True)
        self.assertEqual(result["status"], "unavailable")
        self.assertNotIn("sb_secret_", str(result))
        adapter.return_value.prune_issuance_log.assert_not_called()
        self.assertEqual(factory.connection.closed, 1)

    def test_nonexclusive_connection_refused_without_running_cleanup(self):
        for conn in (Connection(autocommit=True), Connection(autocommit=None)):
            factory = Factory(conn)
            with patch("software_learning.private_retention_job.sweep_expired_attempts") as scan:
                result = run_retention_once(connection_factory=factory, storage=object(),
                                            authorized=True, execute=True)
            self.assertEqual(result["status"], "unavailable")
            self.assertEqual(conn.closed, 1)
            scan.assert_not_called()

    def test_bad_limits_and_flags_rejected_before_connection(self):
        factory = Factory()
        for arguments in ({"max_results": 0}, {"max_results": 101},
                          {"max_results": True}, {"prune_limit": -1},
                          {"prune_limit": True}, {"execute": "yes"},
                          {"authorized": "yes"}):
            with self.subTest(arguments=arguments), self.assertRaises(ValueError):
                run_retention_once(connection_factory=factory, storage=object(),
                                   **arguments)
        self.assertEqual(factory.calls, 0)

    def test_close_error_never_claims_complete(self):
        class BrokenClose(Connection):
            def close(self):
                raise RuntimeError("secret connection")
        factory = Factory(BrokenClose())
        with patch("software_learning.private_retention_job.sweep_expired_attempts",
                   return_value={"candidates": 0, "erased": 0, "retry": 0}):
            result = run_retention_once(connection_factory=factory, storage=object())
        self.assertEqual(result["status"], "unavailable")
        self.assertFalse(result["account_erasure_confirmed"])

if __name__ == "__main__":
    unittest.main()
