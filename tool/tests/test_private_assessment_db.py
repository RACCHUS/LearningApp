"""DB-API adapter contract tests: private leases, parameterization, redaction."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.private_assessment import AssessmentLease
from software_learning.private_assessment_db import DbApiAttemptRepository

OWNER = "ba410000-0000-4000-8000-000000000001"
SESSION = "ba420000-0000-4000-8000-000000000001"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"
LEASE_ID = "ba440000-0000-4000-8000-000000000001"

def lease_json():
    return {
        "lease_id": LEASE_ID,
        "owner_id": OWNER, "session_id": SESSION, "attempt_id": ATTEMPT,
        "exercise_id": "excel-budget-total-v1",
        "checker_version": 1,
        "expires_at": "2026-11-07T20:05:00+00:00",
        "expected_inputs": {f"C{i}": i*10 for i in range(2, 10)},
        "evidence_trust": "unverified_checker_only",
        "can_award_skill": False,
    }

class Cursor:
    def __init__(self, connection):
        self.connection = connection
    def execute(self, sql, params):
        self.connection.calls.append(("execute", sql, params))
        if self.connection.fail_execute:
            raise RuntimeError("secret database exception")
    def fetchone(self):
        self.connection.calls.append(("fetchone",))
        return self.connection.response
    def close(self):
        self.connection.calls.append(("close",))

class Connection:
    def __init__(self, response, fail_execute=False):
        self.response = response
        self.fail_execute = fail_execute
        self.calls = []
    def cursor(self):
        self.calls.append(("cursor",))
        return Cursor(self)
    def commit(self):
        self.calls.append(("commit",))
    def rollback(self):
        self.calls.append(("rollback",))

class DbAdapterTests(unittest.TestCase):
    def test_claim_uses_private_function_and_parameter_binding(self):
        conn = Connection((lease_json(),))
        result = DbApiAttemptRepository(conn).claim(
            OWNER, SESSION, ATTEMPT, None)
        self.assertIsInstance(result, AssessmentLease)
        self.assertEqual(result.lease_id, LEASE_ID)
        self.assertEqual(result.expected_inputs["C9"], 90)
        self.assertEqual(result.expires_at.utcoffset().total_seconds(), 0)
        query = [x for x in conn.calls if x[0] == "execute"][0]
        self.assertIn("software_learning_private.sl_claim_excel_processing", query[1])
        self.assertIn("%s", query[1])
        self.assertEqual(query[2], (ATTEMPT, OWNER, SESSION))
        self.assertIn(("commit",), conn.calls)

    def test_no_claim_returns_none_and_commits(self):
        conn = Connection((None,))
        self.assertIsNone(DbApiAttemptRepository(conn).claim(
            OWNER, SESSION, ATTEMPT, None))
        self.assertIn(("commit",), conn.calls)

    def test_invalid_server_payload_rejected_without_leaking_secrets(self):
        for bad in (
            {**lease_json(), "evidence_trust": "server_verified"},
            {**lease_json(), "can_award_skill": True},
            {**lease_json(), "owner_id": "wrong"},
            {**lease_json(), "checker_version": 2},
            {**lease_json(), "expires_at": "tomorrow"},
            {**lease_json(), "expected_inputs": {"C2": 5}},
            {**lease_json(), "expected_inputs": {f"C{i}": True for i in range(2,10)}},
            {**lease_json(), "extra_answer": "secret"},
        ):
            with self.subTest(bad=bad):
                conn = Connection((bad,))
                with self.assertRaises(ValueError):
                    DbApiAttemptRepository(conn).claim(OWNER, SESSION, ATTEMPT, None)
                self.assertIn(("rollback",), conn.calls)

    def test_db_exception_triggers_rollback(self):
        conn = Connection((None,), fail_execute=True)
        with self.assertRaises(RuntimeError):
            DbApiAttemptRepository(conn).claim(OWNER, SESSION, ATTEMPT, None)
        self.assertIn(("rollback",), conn.calls)

    def test_complete_and_fail_are_parameterized(self):
        for op, params, response in (
            ("complete", (LEASE_ID, "a"*64, "pass", "Good work"), (True,)),
            ("fail", (LEASE_ID,), (False,)),
        ):
            with self.subTest(op=op):
                conn = Connection(response)
                repo = DbApiAttemptRepository(conn)
                result = repo.complete(*params) if op=="complete" else repo.fail(*params)
                self.assertEqual(result, response[0] if op=="complete" else None)
                queries = [x for x in conn.calls if x[0]=="execute"]
                self.assertEqual(queries[0][2], params)
                self.assertIn("software_learning_private.sl_", queries[0][1])
                self.assertIn(("commit",), conn.calls)

if __name__ == "__main__":
    unittest.main()
