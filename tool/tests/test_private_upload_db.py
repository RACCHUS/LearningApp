"""Database upload transaction tests; no Supabase or Storage connection."""
from __future__ import annotations

import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))

from software_learning.brokered_upload import UploadPermit
from software_learning.private_upload_db import DbApiUploadRepository

OWNER = "ba410000-0000-4000-8000-000000000001"
SESSION = "ba420000-0000-4000-8000-000000000001"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"
AT = datetime(2026, 11, 7, 20, tzinfo=timezone.utc)
EXPIRES = AT + timedelta(minutes=20)


class Cursor:
    def __init__(self, connection):
        self.c = connection
    def execute(self, sql, args):
        self.c.queries.append((sql, args))
        if self.c.fail_on == len(self.c.queries):
            raise RuntimeError("private connection error")
    def fetchone(self):
        return self.c.responses.pop(0)
    def close(self):
        self.c.closed_cursors += 1


class Connection:
    def __init__(self, *responses, autocommit=False, fail_on=None):
        self.autocommit = autocommit
        self.responses = list(responses)
        self.fail_on = fail_on
        self.queries = []
        self.commits = 0
        self.rollbacks = 0
        self.closed_cursors = 0
    def cursor(self):
        return Cursor(self)
    def commit(self):
        self.commits += 1
    def rollback(self):
        self.rollbacks += 1


PERMIT = {"owner_id":OWNER, "session_id":SESSION, "attempt_id":ATTEMPT, "expires_at":EXPIRES.isoformat()}
ROW = (PERMIT,)


class UploadDbTests(unittest.TestCase):
    def test_begin_holds_row_lock_until_sealed_commit(self):
        conn = Connection(ROW, (ATTEMPT,))
        repo = DbApiUploadRepository(conn)
        permit = repo.begin(OWNER, SESSION, ATTEMPT, AT)
        self.assertEqual(permit, UploadPermit(OWNER, SESSION, ATTEMPT, EXPIRES))
        self.assertEqual(conn.commits, 0)
        sql, args = conn.queries[0]
        self.assertIn("software_learning_private.sl_lock_excel_upload", sql)
        self.assertNotIn("auth.sessions", sql)
        self.assertEqual(args, (ATTEMPT, OWNER, SESSION))
        self.assertNotIn(OWNER, sql)
        self.assertTrue(repo.seal(permit, "b"*64, "version-1"))
        self.assertEqual(conn.commits, 1)
        self.assertEqual(conn.rollbacks, 0)
        sql2, args2 = conn.queries[1]
        self.assertIn("software_learning_private.sl_seal_excel_upload", sql2)
        self.assertEqual(args2, (ATTEMPT, OWNER, SESSION, "b"*64, "version-1"))
        self.assertEqual(conn.closed_cursors, 2)

    def test_missing_attempt_and_invalid_record_fail_closed(self):
        for result in ((None,),
                       ({**PERMIT, "owner_id": "wrong"},),
                       ({**PERMIT, "expires_at": "not-datetime"},),
                       ({**PERMIT, "expires_at": (AT-timedelta(seconds=1)).isoformat()},)):
            with self.subTest(result=result):
                conn = Connection(result)
                repo = DbApiUploadRepository(conn)
                if result == (None,):
                    self.assertIsNone(repo.begin(OWNER, SESSION, ATTEMPT, AT))
                else:
                    with self.assertRaises(ValueError):
                        repo.begin(OWNER, SESSION, ATTEMPT, AT)
                self.assertEqual(conn.commits, 0)
                self.assertEqual(conn.rollbacks, 1)

    def test_autocommit_connection_rejected_without_sql(self):
        conn = Connection(ROW, autocommit=True)
        with self.assertRaises(ValueError):
            DbApiUploadRepository(conn)
        self.assertEqual(conn.queries, [])

    def test_lock_conflict_is_rolled_back(self):
        conn = Connection(fail_on=1)
        repo = DbApiUploadRepository(conn)
        with self.assertRaises(RuntimeError):
            repo.begin(OWNER, SESSION, ATTEMPT, AT)
        self.assertEqual(conn.rollbacks, 1)
        self.assertEqual(conn.commits, 0)

    def test_seal_requires_held_same_permit(self):
        conn = Connection(ROW)
        repo = DbApiUploadRepository(conn)
        other = UploadPermit(OWNER, SESSION, "ba430000-0000-4000-8000-000000000099", EXPIRES)
        self.assertFalse(repo.seal(other, "a"*64, "v1"))
        self.assertEqual(conn.queries, [])
        p = repo.begin(OWNER, SESSION, ATTEMPT, AT)
        self.assertFalse(repo.seal(other, "a"*64, "v1"))
        self.assertFalse(repo.seal(p, "wrong", "v1"))
        self.assertFalse(repo.seal(p, "a"*64, "v/../2"))
        self.assertEqual(conn.commits, 0)
        repo.abort(p)
        self.assertEqual(conn.rollbacks, 1)

    def test_seal_db_failure_rolls_back(self):
        conn = Connection(ROW, fail_on=2)
        repo = DbApiUploadRepository(conn)
        p = repo.begin(OWNER, SESSION, ATTEMPT, AT)
        with self.assertRaises(RuntimeError):
            repo.seal(p, "a"*64, "v1")
        self.assertEqual(conn.rollbacks, 1)
        self.assertEqual(conn.commits, 0)

    def test_retry_after_abort_starts_fresh_lock(self):
        conn = Connection(ROW, ROW)
        repo = DbApiUploadRepository(conn)
        first = repo.begin(OWNER, SESSION, ATTEMPT, AT)
        repo.abort(first)
        second = repo.begin(OWNER, SESSION, ATTEMPT, AT)
        self.assertEqual(first, second)
        self.assertEqual(conn.rollbacks, 1)
        self.assertEqual(conn.commits, 0)

    def test_seal_row_missing_rolls_back(self):
        conn = Connection(ROW, None)
        repo = DbApiUploadRepository(conn)
        p = repo.begin(OWNER, SESSION, ATTEMPT, AT)
        self.assertFalse(repo.seal(p, "a"*64, "v1"))
        self.assertEqual(conn.rollbacks, 1)
        self.assertEqual(conn.commits, 0)


if __name__ == "__main__":
    unittest.main()
