"""DB-API service retention adapter tests (no network, no hosted mutation)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.private_retention_db import DbApiRetentionRepository
from software_learning.storage_retention import erase_owned_attempt

OWNER = "ba410000-0000-4000-8000-000000000001"
OTHER = "ba410000-0000-4000-8000-000000000002"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"
FILE = f"{OWNER}/{ATTEMPT}/workbook.xlsx"


class Cursor:
    def __init__(self, conn):
        self.conn = conn
    def execute(self, sql, args):
        self.conn.statements.append((sql, args))
        if self.conn.fail_at is not None and len(self.conn.statements) == self.conn.fail_at:
            raise RuntimeError("private SQL failure: pretend secret")
    def fetchone(self):
        return self.conn.outputs.pop(0)
    def fetchall(self):
        return self.conn.outputs.pop(0)
    def close(self):
        self.conn.closed += 1

class Connection:
    def __init__(self, *outputs, fail_at=None):
        self.outputs = list(outputs)
        self.fail_at = fail_at
        self.statements = []
        self.commits = 0
        self.rollbacks = 0
        self.closed = 0
    def cursor(self):
        return Cursor(self)
    def commit(self):
        self.commits += 1
    def rollback(self):
        self.rollbacks += 1

class Storage:
    def __init__(self, *, failure=False, remaining=False):
        self.calls = []
        self.failure = failure
        self.remaining = remaining
    def remove(self, bucket, path):
        self.calls.append(("remove", bucket, path))
        if self.failure:
            raise OSError("secret storage error")
    def exists(self, bucket, path):
        self.calls.append(("exists", bucket, path))
        return self.remaining

class DbRetentionTests(unittest.TestCase):
    def test_owner_bound_lookup_and_parameterized_sql(self):
        conn = Connection((OWNER, ATTEMPT))
        repo = DbApiRetentionRepository(conn)
        found = repo.find_owned(OWNER, ATTEMPT)
        self.assertEqual((found.owner_id, found.attempt_id), (OWNER, ATTEMPT))
        sql, args = conn.statements[0]
        self.assertIn("owner_id", sql)
        self.assertIn("status", sql)
        self.assertIn("%s", sql)
        self.assertEqual(args, (OWNER, ATTEMPT))
        self.assertNotIn(OWNER, sql)
        self.assertEqual(conn.closed, 1)

    def test_foreign_and_processing_attempt_never_erase(self):
        for record in (None,):
            conn = Connection(record)
            store = Storage()
            result = erase_owned_attempt(owner_id=OWNER, attempt_id=ATTEMPT,
                                         repository=DbApiRetentionRepository(conn),storage=store)
            self.assertEqual(result, "not_found")
            self.assertEqual(store.calls, [])
            self.assertEqual(len(conn.statements), 1)

    def test_freeze_then_delete_only_after_storage_api_remove(self):
        conn = Connection((OWNER, ATTEMPT), (ATTEMPT,), (ATTEMPT,))
        store = Storage()
        result = erase_owned_attempt(owner_id=OWNER, attempt_id=ATTEMPT,
                                     repository=DbApiRetentionRepository(conn),storage=store)
        self.assertEqual(result, "erased")
        self.assertEqual([v[0].split()[0] for v in conn.statements],
                         ["SELECT", "UPDATE", "DELETE"])
        self.assertEqual(conn.commits, 2)
        self.assertEqual(store.calls, [
            ("remove", "learningapp-excel-private", FILE),
            ("exists", "learningapp-excel-private", FILE),
        ])
        self.assertIn("upload_enabled=false",conn.statements[1][0])
        self.assertIn("status=CASE WHEN status='issued' THEN 'failed' ELSE status END",
                      conn.statements[1][0])
        self.assertIn("status IN",conn.statements[1][0])
        self.assertEqual(conn.statements[1][1], (OWNER, ATTEMPT))

    def test_unsealed_cleanup_freeze_cannot_reopen_issued_upload(self):
        conn = Connection((ATTEMPT,))
        repo = DbApiRetentionRepository(conn)
        self.assertTrue(repo.freeze_upload(OWNER, ATTEMPT))
        sql, args = conn.statements[0]
        self.assertIn("status=CASE WHEN status='issued' THEN 'failed' ELSE status END", sql)
        self.assertIn("SET upload_enabled=false", sql)
        self.assertEqual(args, (OWNER, ATTEMPT))
        self.assertEqual(conn.commits, 1)
        self.assertEqual(conn.rollbacks, 0)

    def test_missing_freeze_row_never_claims_a_successful_freeze(self):
        conn = Connection(None)
        self.assertFalse(DbApiRetentionRepository(conn).freeze_upload(OWNER, ATTEMPT))
        self.assertEqual(conn.commits, 1)

    def test_storage_failed_keeps_metadata_after_freeze(self):
        conn = Connection((OWNER, ATTEMPT), (ATTEMPT,))
        store = Storage(failure=True)
        result = erase_owned_attempt(owner_id=OWNER, attempt_id=ATTEMPT,
                                     repository=DbApiRetentionRepository(conn),storage=store)
        self.assertEqual(result, "retry")
        self.assertEqual(len(conn.statements), 2)
        self.assertEqual(conn.commits, 1)

    def test_inflight_processing_disallows_freeze(self):
        conn = Connection((OWNER, ATTEMPT), None)
        store = Storage()
        result = erase_owned_attempt(owner_id=OWNER, attempt_id=ATTEMPT,
                                     repository=DbApiRetentionRepository(conn),storage=store)
        self.assertEqual(result, "retry")
        self.assertEqual(store.calls, [])

    def test_sql_error_fails_closed_and_rolls_back(self):
        conn = Connection((OWNER, ATTEMPT), fail_at=2)
        store = Storage()
        result = erase_owned_attempt(owner_id=OWNER, attempt_id=ATTEMPT,
                                     repository=DbApiRetentionRepository(conn),storage=store)
        self.assertEqual(result, "retry")
        self.assertEqual(conn.rollbacks, 1)
        self.assertEqual(store.calls, [])

    def test_expired_attempt_scan_is_bounded_and_owner_scoped(self):
        rows = [(OWNER, ATTEMPT)]
        conn = Connection(rows)
        repo = DbApiRetentionRepository(conn)
        found = repo.list_expired(max_results=20)
        self.assertEqual([(x.owner_id,x.attempt_id) for x in found], rows)
        sql, args = conn.statements[0]
        self.assertIn("expires_at", sql)
        self.assertIn("LIMIT %s", sql)
        self.assertEqual(args, (20,))
        with self.assertRaises(ValueError):
            repo.list_expired(max_results=10000)

    def test_stuck_processing_is_eligible_only_after_both_grace_guards(self):
        conn = Connection((OWNER, ATTEMPT), (ATTEMPT,), (ATTEMPT,))
        repo = DbApiRetentionRepository(conn)
        self.assertEqual(repo.find_owned(OWNER, ATTEMPT).attempt_id, ATTEMPT)
        self.assertTrue(repo.freeze_upload(OWNER, ATTEMPT))
        self.assertTrue(repo.delete_attempt(OWNER, ATTEMPT))
        for sql, args in conn.statements:
            self.assertIn("status='processing'", sql)
            self.assertIn("expires_at < now() - interval '30 minutes'", sql)
            self.assertIn("processing_claimed_at < now() - interval '30 minutes'", sql)
            self.assertEqual(args, (OWNER, ATTEMPT))

    def test_expiry_scan_uses_same_processing_lease_grace(self):
        conn = Connection([(OWNER, ATTEMPT)])
        repo = DbApiRetentionRepository(conn)
        self.assertEqual(len(repo.list_expired()), 1)
        sql, _ = conn.statements[0]
        self.assertIn("status='processing'", sql)
        self.assertIn("expires_at < now() - interval '30 minutes'", sql)
        self.assertIn("processing_claimed_at < now() - interval '30 minutes'", sql)

    def test_account_inventory_includes_processing_rows_by_owner(self):
        conn = Connection([(OWNER, ATTEMPT)])
        repo = DbApiRetentionRepository(conn)
        found = repo.list_owner_attempts(owner_id=OWNER,max_results=20)
        self.assertEqual([(x.owner_id,x.attempt_id) for x in found],[(OWNER,ATTEMPT)])
        sql, args = conn.statements[0]
        self.assertIn("WHERE owner_id=%s::uuid", sql)
        self.assertNotIn("status IN", sql)
        self.assertIn("LIMIT %s", sql)
        self.assertEqual(args, (OWNER,20))

    def test_account_inventory_rejects_foreign_or_malformed_rows(self):
        conn = Connection([(OTHER, ATTEMPT)])
        with self.assertRaises(ValueError):
            DbApiRetentionRepository(conn).list_owner_attempts(owner_id=OWNER)

    def test_account_inventory_invalid_requests_never_query(self):
        conn = Connection([])
        repo = DbApiRetentionRepository(conn)
        for owner, count in (("bad",20),(OWNER,0),(OWNER,101),(OWNER,True)):
            with self.subTest(owner=owner,count=count),self.assertRaises(ValueError):
                repo.list_owner_attempts(owner_id=owner,max_results=count)
        self.assertEqual(conn.statements, [])

    def test_private_issue_log_only_prunes_older_than_48_hours(self):
        conn = Connection((5,))
        repo = DbApiRetentionRepository(conn)
        self.assertEqual(repo.prune_issuance_log(max_results=20), 5)
        self.assertEqual(conn.commits, 1)
        sql, args = conn.statements[0]
        self.assertIn("software_learning_private.excel_issuance_log", sql)
        self.assertIn("issued_at < now() - interval '48 hours'", sql)
        self.assertIn("FOR UPDATE SKIP LOCKED", sql)
        self.assertIn("LIMIT %s", sql)
        self.assertEqual(args, (20,))
        for invalid in (0, -1, 101, True):
            with self.assertRaises(ValueError):
                repo.prune_issuance_log(max_results=invalid)

    def test_issue_log_prune_error_rolls_back(self):
        conn = Connection(fail_at=1)
        repo = DbApiRetentionRepository(conn)
        with self.assertRaises(RuntimeError):
            repo.prune_issuance_log(max_results=2)
        self.assertEqual(conn.rollbacks, 1)
        self.assertEqual(conn.commits, 0)

    def test_scan_rejects_malformed_database_rows(self):
        conn = Connection([("not-a-uuid", ATTEMPT)])
        with self.assertRaises(ValueError):
            DbApiRetentionRepository(conn).list_expired()

if __name__ == "__main__":
    unittest.main()
