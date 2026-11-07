"""Account erasure is privileged and incomplete until independent inventory."""
from __future__ import annotations

import sys
import unittest
from dataclasses import dataclass
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.account_erasure import sweep_owner_workbooks

OWNER = "ba410000-0000-4000-8000-000000000001"
OTHER = "ba410000-0000-4000-8000-000000000002"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"

@dataclass
class Record:
    owner_id: str
    attempt_id: str

class Repository:
    def __init__(self, records, *, blocked=False):
        self.records = list(records)
        self.blocked = blocked
        self.calls = []
    def list_owner_attempts(self, *, owner_id, max_results):
        self.calls.append(("list", owner_id, max_results))
        return self.records[:max_results]
    def find_owned(self, owner_id, attempt_id):
        self.calls.append(("find", owner_id, attempt_id))
        if self.blocked:
            return None
        return next((x for x in self.records
                     if x.owner_id == owner_id and x.attempt_id == attempt_id), None)
    def freeze_upload(self, owner_id, attempt_id):
        self.calls.append(("freeze", owner_id, attempt_id))
        return True
    def delete_attempt(self, owner_id, attempt_id):
        self.calls.append(("delete", owner_id, attempt_id))
        self.records = [r for r in self.records if not
                        (r.owner_id == owner_id and r.attempt_id == attempt_id)]
        return True

class Storage:
    def __init__(self, *, fail=False):
        self.calls = []
        self.fail = fail
    def remove(self, bucket, path):
        self.calls.append(("remove", bucket, path))
        if self.fail:
            raise OSError("private Storage failure")
    def exists(self, bucket, path):
        self.calls.append(("exists", bucket, path))
        return False


class AccountErasureTests(unittest.TestCase):
    def test_no_revocation_cannot_access_records(self):
        repo, storage = Repository([Record(OWNER, ATTEMPT)]), Storage()
        with self.assertRaises(ValueError):
            sweep_owner_workbooks(owner_id=OWNER, repository=repo, storage=storage)
        self.assertEqual(repo.calls, [])
        self.assertEqual(storage.calls, [])

    def test_dry_run_is_default_and_never_claims_global_erasure(self):
        repo, storage = Repository([Record(OWNER, ATTEMPT)]), Storage()
        result = sweep_owner_workbooks(
            owner_id=OWNER,repository=repo,storage=storage,
            revocation_confirmed=True)
        self.assertEqual(result, {
            "candidates": 1, "erased": 0, "blocked": 0,
            "dry_run": True, "account_erasure_confirmed": False,
        })
        self.assertEqual(storage.calls, [])

    def test_explicit_cleanup_uses_storage_before_db_and_stays_partial(self):
        repo, storage = Repository([Record(OWNER, ATTEMPT)]), Storage()
        result = sweep_owner_workbooks(
            owner_id=OWNER,repository=repo,storage=storage,
            revocation_confirmed=True,execute=True)
        self.assertEqual(result["erased"], 1)
        self.assertFalse(result["account_erasure_confirmed"])
        self.assertEqual([c[0] for c in repo.calls], ["list","find","freeze","delete"])
        self.assertEqual([c[0] for c in storage.calls], ["remove", "exists"])

    def test_processing_claim_blocks_deletion(self):
        repo, storage = Repository([Record(OWNER, ATTEMPT)], blocked=True), Storage()
        result = sweep_owner_workbooks(
            owner_id=OWNER,repository=repo,storage=storage,
            revocation_confirmed=True,execute=True)
        self.assertEqual(result["blocked"], 1)
        self.assertEqual(result["erased"], 0)
        self.assertEqual(storage.calls, [])

    def test_storage_error_does_not_delete_metadata(self):
        repo, storage = Repository([Record(OWNER, ATTEMPT)]), Storage(fail=True)
        result = sweep_owner_workbooks(
            owner_id=OWNER,repository=repo,storage=storage,
            revocation_confirmed=True,execute=True)
        self.assertEqual(result["blocked"], 1)
        self.assertEqual(len(repo.records), 1)
        self.assertFalse(result["account_erasure_confirmed"])

    def test_foreign_record_is_rejected_without_deleting(self):
        repo, storage = Repository([Record(OTHER, ATTEMPT)]), Storage()
        with self.assertRaises(ValueError):
            sweep_owner_workbooks(
                owner_id=OWNER,repository=repo,storage=storage,
                revocation_confirmed=True,execute=True)
        self.assertEqual(storage.calls, [])
        self.assertNotIn("delete", [x[0] for x in repo.calls])

    def test_duplicate_candidates_count_only_once(self):
        repo, storage = Repository([Record(OWNER, ATTEMPT),Record(OWNER, ATTEMPT)]), Storage()
        result = sweep_owner_workbooks(
            owner_id=OWNER,repository=repo,storage=storage,
            revocation_confirmed=True,execute=True)
        self.assertEqual(result["candidates"], 1)
        self.assertEqual(result["erased"], 1)
        self.assertEqual([x[0] for x in storage.calls].count("remove"), 1)

    def test_empty_batch_does_not_assert_account_erasure(self):
        repo, storage = Repository([]), Storage()
        result = sweep_owner_workbooks(
            owner_id=OWNER,repository=repo,storage=storage,
            revocation_confirmed=True,execute=True)
        self.assertFalse(result["account_erasure_confirmed"])
        self.assertEqual(storage.calls, [])

    def test_batch_limits_and_invalid_owner(self):
        repo, storage = Repository([]), Storage()
        for owner, max_results in ((OWNER, 0),(OWNER, 101),
                                   (OWNER, True),("not-a-uuid",20)):
            with self.subTest(owner=owner,limit=max_results), self.assertRaises(ValueError):
                sweep_owner_workbooks(
                    owner_id=owner, repository=repo, storage=storage,
                    revocation_confirmed=True,max_results=max_results)


if __name__ == "__main__":
    unittest.main()
