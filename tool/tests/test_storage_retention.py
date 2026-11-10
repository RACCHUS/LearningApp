"""Service-only Excel workbook retention: order, ownership, and fail-closed tests."""
from __future__ import annotations
import unittest
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.storage_retention import erase_owned_attempt, PRIVATE_BUCKET

OWNER = "ba410000-0000-4000-8000-000000000001"
OTHER = "ba410000-0000-4000-8000-000000000002"
ATTEMPT = "ba420000-0000-4000-8000-000000000001"
PATH = f"{OWNER}/{ATTEMPT}/workbook.xlsx"

@dataclass(frozen=True)
class _Record:
    owner_id: str
    attempt_id: str

class _Repository:
    def __init__(self, *, owner=OWNER, freeze=True, delete=True):
        self.record = _Record(owner, ATTEMPT)
        self.freeze_ok = freeze
        self.delete_ok = delete
        self.calls = []

    def find_owned(self, owner_id, attempt_id):
        self.calls.append("find")
        if self.record and self.record.owner_id == owner_id and self.record.attempt_id == attempt_id:
            return self.record
        return None

    def freeze_upload(self, owner_id, attempt_id):
        self.calls.append("freeze")
        return self.freeze_ok

    def delete_attempt(self, owner_id, attempt_id):
        self.calls.append("delete")
        if self.delete_ok:
            self.record = None
        return self.delete_ok

class _Storage:
    def __init__(self, *, present=True, fail=False, sticky=False):
        self.present, self.fail, self.sticky = present, fail, sticky
        self.calls = []

    def exists(self, bucket, path):
        self.calls.append(("exists", bucket, path))
        return self.present

    def remove(self, bucket, path):
        self.calls.append(("remove", bucket, path))
        if self.fail:
            raise OSError("Storage temporarily unavailable; do not reveal file metadata")
        if not self.sticky:
            self.present = False

class _FalseNegativeBeforeDelete(_Storage):
    def exists(self, bucket, path):
        self.calls.append(("exists", bucket, path))
        return False

class RetentionTests(unittest.TestCase):
    def call(self, repo, store, *, owner=OWNER, attempt=ATTEMPT):
        return erase_owned_attempt(
            owner_id=owner, attempt_id=attempt, repository=repo, storage=store)

    def test_file_removed_before_attempt_metadata(self):
        repo, store = _Repository(), _Storage()
        self.assertEqual(self.call(repo, store), "erased")
        self.assertEqual(repo.calls, ["find", "freeze", "delete"])
        self.assertEqual(store.calls, [
            ("remove", PRIVATE_BUCKET, PATH),
            ("exists", PRIVATE_BUCKET, PATH)])
        self.assertIsNone(repo.record)

    def test_cross_account_does_not_access_private_objects(self):
        repo, store = _Repository(), _Storage()
        self.assertEqual(self.call(repo, store, owner=OTHER), "not_found")
        self.assertEqual(store.calls, [])
        self.assertEqual(repo.calls, ["find"])

    def test_noncanonical_or_traversal_path_rejected_before_access(self):
        for attempt in ("../" + ATTEMPT, ATTEMPT.upper(), "bad", ""):
            repo, store = _Repository(), _Storage()
            self.assertEqual(self.call(repo, store, attempt=attempt), "invalid")
            self.assertEqual(repo.calls, [])
            self.assertEqual(store.calls, [])

    def test_failed_upload_freeze_never_touches_storage(self):
        repo, store = _Repository(freeze=False), _Storage()
        self.assertEqual(self.call(repo, store), "retry")
        self.assertEqual(repo.calls, ["find", "freeze"])
        self.assertEqual(store.calls, [])

    def test_storage_failure_preserves_database(self):
        repo, store = _Repository(), _Storage(fail=True)
        self.assertEqual(self.call(repo, store), "retry")
        self.assertIsNotNone(repo.record)
        self.assertNotIn("delete", repo.calls)

    def test_list_false_negative_does_not_skip_storage_api_delete(self):
        repo, store = _Repository(), _FalseNegativeBeforeDelete()
        self.assertEqual(self.call(repo, store), "erased")
        self.assertIn(("remove", PRIVATE_BUCKET, PATH), store.calls)
        self.assertFalse(store.present)

    def test_sticky_object_prevents_database_erasure(self):
        repo, store = _Repository(), _Storage(sticky=True)
        self.assertEqual(self.call(repo, store), "retry")
        self.assertIsNotNone(repo.record)
        self.assertNotIn("delete", repo.calls)

    def test_already_missing_file_can_erase_owned_metadata(self):
        repo, store = _Repository(), _Storage(present=False)
        self.assertEqual(self.call(repo, store), "erased")
        self.assertEqual(store.calls, [
            ("remove", PRIVATE_BUCKET, PATH),
            ("exists", PRIVATE_BUCKET, PATH)])

    def test_failed_metadata_delete_returns_retry(self):
        repo, store = _Repository(delete=False), _Storage()
        self.assertEqual(self.call(repo, store), "retry")
        self.assertIsNotNone(repo.record)

    def test_repeated_cleanup_is_idempotent(self):
        repo, store = _Repository(), _Storage()
        self.assertEqual(self.call(repo, store), "erased")
        self.assertEqual(self.call(repo, store), "not_found")

if __name__ == "__main__":
    unittest.main()
