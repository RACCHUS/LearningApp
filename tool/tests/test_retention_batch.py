"""Bounded, dry-run-first Excel retention sweep tests.

The service supplies a privileged DB repository and private Storage adapter.
No scheduler, cloud credentials, external I/O or production data is used here.
"""
from __future__ import annotations

import sys
import unittest
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))

from software_learning.retention_batch import sweep_expired_attempts

OWNER = "ba410000-0000-4000-8000-000000000001"
ATTEMPT_1 = "ba430000-0000-4000-8000-000000000001"
ATTEMPT_2 = "ba430000-0000-4000-8000-000000000002"

@dataclass
class Record:
    owner_id: str
    attempt_id: str

class Repo:
    def __init__(self, rows):
        self.rows = list(rows)
        self.records = {(r.owner_id, r.attempt_id): r for r in rows}
        self.calls = []
        self.fail_freeze = False
    def list_expired(self, *, max_results):
        self.calls.append(("list", max_results))
        return self.rows[:max_results]
    def find_owned(self, owner_id, attempt_id):
        self.calls.append(("find", owner_id, attempt_id))
        return self.records.get((owner_id, attempt_id))
    def freeze_upload(self, owner_id, attempt_id):
        self.calls.append(("freeze", owner_id, attempt_id))
        return not self.fail_freeze
    def delete_attempt(self, owner_id, attempt_id):
        self.calls.append(("delete", owner_id, attempt_id))
        return self.records.pop((owner_id, attempt_id), None) is not None

class Store:
    def __init__(self, *, fail=False):
        self.fail = fail
        self.calls = []
    def remove(self, bucket, path):
        self.calls.append(("remove", path))
        if self.fail:
            raise OSError("private failure")
    def exists(self, bucket, path):
        self.calls.append(("exists", path))
        return False


class RetentionBatchTests(unittest.TestCase):
    def rows(self):
        return [Record(OWNER, ATTEMPT_1), Record(OWNER, ATTEMPT_2)]

    def test_default_is_dry_run_and_never_deletes(self):
        repo, store = Repo(self.rows()), Store()
        summary = sweep_expired_attempts(repository=repo, storage=store)
        self.assertEqual(summary, {"candidates": 2, "erased": 0,
                                  "retry": 0, "dry_run": True})
        self.assertEqual(store.calls, [])
        self.assertEqual(repo.calls, [("list", 20)])

    def test_explicit_execute_cleans_exact_candidates_only(self):
        repo, store = Repo(self.rows()), Store()
        result = sweep_expired_attempts(repository=repo, storage=store,
                                        max_results=1, execute=True)
        self.assertEqual(result, {"candidates": 1, "erased": 1,
                                  "retry": 0, "dry_run": False})
        self.assertEqual(len(repo.records), 1)
        self.assertEqual(store.calls, [
            ("remove", f"{OWNER}/{ATTEMPT_1}/workbook.xlsx"),
            ("exists", f"{OWNER}/{ATTEMPT_1}/workbook.xlsx")])

    def test_storage_failure_is_counted_and_keeps_metadata(self):
        repo, store = Repo(self.rows()), Store(fail=True)
        result = sweep_expired_attempts(repository=repo, storage=store,
                                        execute=True)
        self.assertEqual(result["retry"], 2)
        self.assertEqual(result["erased"], 0)
        self.assertEqual(len(repo.records), 2)

    def test_invalid_batch_limit_fails_closed(self):
        repo, store = Repo(self.rows()), Store()
        for n in (0, 101, True, -1):
            with self.subTest(n=n), self.assertRaises(ValueError):
                sweep_expired_attempts(repository=repo,storage=store,max_results=n)
        self.assertEqual(repo.calls, [])

    def test_duplicate_stale_rows_never_award_or_report_success_twice(self):
        repo, store = Repo([Record(OWNER, ATTEMPT_1), Record(OWNER, ATTEMPT_1)]), Store()
        result = sweep_expired_attempts(repository=repo, storage=store, execute=True)
        self.assertEqual(result["erased"], 1)
        self.assertEqual(result["retry"], 0)
        self.assertEqual(len(repo.records), 0)

    def test_no_principal_or_file_contents_in_summary(self):
        repo, store = Repo(self.rows()), Store()
        result = sweep_expired_attempts(repository=repo,storage=store)
        self.assertNotIn(OWNER, str(result))
        self.assertNotIn("workbook.xlsx", str(result))

if __name__ == "__main__":
    unittest.main()
