"""No-network retention-monitor privacy, overdue and fail-closed tests."""
from __future__ import annotations

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.private_retention_monitor import inspect_excel_retention_backlog

class Cursor:
    def __init__(self, owner):
        self.owner = owner
        self.closed = False
    def execute(self, sql, params):
        self.owner.queries.append((sql, params))
        if self.owner.failure:
            raise RuntimeError("secret DB credentials and learner filename")
    def fetchone(self):
        return self.owner.result
    def close(self):
        self.closed = True
        if self.owner.close_error == "cursor":
            raise RuntimeError("credential")

class Connection:
    def __init__(self, result=(0, 0), *, autocommit=False, failure=False,
                 close_error=None):
        self.result = result
        self.autocommit = autocommit
        self.failure = failure
        self.close_error = close_error
        self.queries = []
        self.cursor_obj = None
        self.closed = False
    def cursor(self):
        self.cursor_obj = Cursor(self)
        return self.cursor_obj
    def close(self):
        self.closed = True
        if self.close_error == "connection":
            raise RuntimeError("private bearer")

class RetentionMonitorTests(unittest.TestCase):
    def test_empty_database_is_observation_never_erasure_proof(self):
        conn = Connection()
        result = inspect_excel_retention_backlog(connection_factory=lambda: conn)
        self.assertEqual(result, {
            "status": "clear_observed", "overdue_attempt_records": 0,
            "stale_processing_leases": 0, "alert_required": False,
            "account_erasure_confirmed": False,
        })
        self.assertTrue(conn.closed)
        self.assertTrue(conn.cursor_obj.closed)
        sql, args = conn.queries[0]
        self.assertEqual(args, ())
        self.assertIn("expires_at < now() - interval '24 hours'", sql)
        self.assertIn("processing_claimed_at < now() - interval '30 minutes'", sql)
        self.assertNotIn("SELECT owner_id", sql)
        self.assertNotIn("workbook.xlsx", sql)

    def test_retention_backlog_or_stuck_claim_requests_operator_attention(self):
        for overdue, claims in ((1, 0), (0, 1), (5, 3)):
            with self.subTest(overdue=overdue, claims=claims):
                conn = Connection((overdue, claims))
                result = inspect_excel_retention_backlog(connection_factory=lambda: conn)
                self.assertEqual(result["status"], "attention_required")
                self.assertEqual(result["overdue_attempt_records"], overdue)
                self.assertEqual(result["stale_processing_leases"], claims)
                self.assertTrue(result["alert_required"])
                self.assertFalse(result["account_erasure_confirmed"])

    def test_invalid_connection_fails_closed_and_is_closed(self):
        for autocommit in (True, None):
            conn = Connection(autocommit=autocommit)
            result = inspect_excel_retention_backlog(connection_factory=lambda: conn)
            self.assertEqual(result["status"], "unavailable")
            self.assertTrue(result["alert_required"])
            self.assertEqual(conn.queries, [])
            self.assertTrue(conn.closed)

    def test_private_sql_error_never_leaks_details(self):
        conn = Connection(failure=True)
        result = inspect_excel_retention_backlog(connection_factory=lambda: conn)
        self.assertEqual(result["status"], "unavailable")
        self.assertTrue(result["alert_required"])
        self.assertNotIn("secret", str(result))
        self.assertNotIn("learner", str(result))
        self.assertTrue(conn.closed)
        self.assertTrue(conn.cursor_obj.closed)

    def test_malformed_counts_never_claim_clear(self):
        for raw in ((True, 0), (0, -1), ("0", 0), None, (0,), (0, 0, 0)):
            with self.subTest(raw=raw):
                result = inspect_excel_retention_backlog(
                    connection_factory=lambda: Connection(raw))
                self.assertEqual(result["status"], "unavailable")
                self.assertTrue(result["alert_required"])

    def test_cursor_or_connection_close_error_is_alertable(self):
        for source in ("cursor", "connection"):
            conn = Connection(close_error=source)
            result = inspect_excel_retention_backlog(connection_factory=lambda: conn)
            self.assertEqual(result["status"], "unavailable")
            self.assertTrue(result["alert_required"])
            self.assertTrue(conn.closed)

    def test_invalid_factory_refused(self):
        for bad in (None, True, 3):
            with self.assertRaises(ValueError):
                inspect_excel_retention_backlog(connection_factory=bad)

if __name__ == "__main__":
    unittest.main()
