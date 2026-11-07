"""Server-brokered Excel admission: authentication, file sealing, and failure tests."""
from __future__ import annotations

import hashlib
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.brokered_upload import accept_workbook, UploadPermit
from software_learning.private_assessment import VerifiedIdentity
from test_xlsx_snapshot import zip_bytes

OWNER = "ba410000-0000-4000-8000-000000000001"
SESSION = "ba420000-0000-4000-8000-000000000001"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"
AT = datetime(2026, 11, 7, 20, tzinfo=timezone.utc)
BLOB = zip_bytes()
PATH = f"{OWNER}/{ATTEMPT}/workbook.xlsx"


class Sessions:
    def __init__(self, identity=None):
        self.identity = identity if identity is not None else VerifiedIdentity(OWNER, SESSION, True)
        self.calls = []
    def verify(self, bearer):
        self.calls.append(bearer)
        if bearer != "valid token":
            raise ValueError("private bearer content")
        return self.identity


class Repository:
    def __init__(self, *, permit=None, denied=False, seal=False):
        self.permit = permit or UploadPermit(OWNER, SESSION, ATTEMPT, AT+timedelta(minutes=20))
        self.denied = denied
        self.seal_failed = seal
        self.held = False
        self.sealed = False
        self.calls = []
    def begin(self, owner, session, attempt, now):
        self.calls.append(("begin", owner, session, attempt))
        if self.denied or self.held or self.sealed:
            return None
        self.held = True
        return self.permit
    def seal(self, permit, sha256, version):
        self.calls.append(("seal", sha256, version))
        if self.seal_failed:
            raise RuntimeError("secret DB exception")
        assert self.held
        self.sealed = True
        self.held = False
        return True
    def abort(self, permit):
        self.calls.append(("abort",))
        self.held = False


class Storage:
    def __init__(self, *, conflict=False, tamper=False, fail_write=False, fail_remove=False):
        self.conflict, self.tamper = conflict, tamper
        self.fail_write, self.fail_remove = fail_write, fail_remove
        self.blob = None
        self.calls = []
    def stat(self, bucket, path):
        self.calls.append(("stat", bucket, path))
        return "revision-1" if self.conflict or self.blob is not None else None
    def create_only(self, bucket, path, blob):
        self.calls.append(("create", bucket, path))
        if self.fail_write:
            raise RuntimeError("failed write")
        if self.conflict or self.blob is not None:
            raise ValueError("conflict")
        self.blob = blob
        return None
    def download_limited(self, bucket, path, limit):
        self.calls.append(("download", bucket, path, limit))
        if self.blob is None:
            raise ValueError("missing")
        return b"modified" if self.tamper else self.blob
    def remove(self, bucket, path):
        self.calls.append(("remove", bucket, path))
        if self.fail_remove:
            raise RuntimeError("remove failed")
        self.blob = None


def do(*, repo=None, store=None, sessions=None, data=BLOB, token="valid token",
       now=AT, attempt=ATTEMPT):
    repo = repo or Repository()
    store = store or Storage()
    sessions = sessions or Sessions()
    result = accept_workbook(bearer_token=token, attempt_id=attempt,
        blob=data, now=now, sessions=sessions, repository=repo, storage=store)
    return result, repo, store, sessions


class UploadTests(unittest.TestCase):
    def test_sealed_upload_has_digest_only_from_readback(self):
        result, repo, store, _ = do()
        self.assertEqual(result, {"status": "accepted", "evidence_trust": "unverified_checker_only"})
        self.assertTrue(repo.sealed)
        self.assertEqual(repo.calls, [
            ("begin", OWNER, SESSION, ATTEMPT),
            ("seal", hashlib.sha256(BLOB).hexdigest(), "revision-1")
        ])
        self.assertEqual(store.blob, BLOB)
        self.assertEqual([x[0] for x in store.calls],
                         ["stat", "create", "stat", "download", "stat"])
        self.assertNotIn("workbook.xlsx", str(result))

    def test_invalid_bearer_and_anonymous_never_access_storage(self):
        for token, identity in (("fake", None), ("valid token", VerifiedIdentity(OWNER, SESSION, False))):
            repo, store = Repository(), Storage()
            result, _, _, _ = do(repo=repo, store=store,
                sessions=Sessions(identity) if identity else Sessions(), token=token)
            self.assertEqual(result["status"], "rejected")
            self.assertEqual(repo.calls, [])
            self.assertEqual(store.calls, [])

    def test_invalid_file_and_path_rejected_before_claim(self):
        for data, attempt in ((b"Not an XLSX", ATTEMPT), (b"", ATTEMPT),
                              (BLOB, "../../../fake"), (BLOB, ATTEMPT.upper()),
                              (b"PK\x03\x04" + b"x"*10485760, ATTEMPT)):
            repo, store = Repository(), Storage()
            result, _, _, _ = do(repo=repo, store=store, data=data, attempt=attempt)
            self.assertEqual(result["status"], "rejected")
            self.assertEqual(repo.calls, [])
            self.assertEqual(store.calls, [])

    def test_cross_owner_wrong_session_and_expiry_rejected(self):
        permits = [
            UploadPermit(OWNER, SESSION, ATTEMPT, AT-timedelta(seconds=1)),
            UploadPermit("ba410000-0000-4000-8000-000000000002", SESSION, ATTEMPT, AT+timedelta(minutes=10)),
            UploadPermit(OWNER, "ba420000-0000-4000-8000-000000000002", ATTEMPT, AT+timedelta(minutes=10)),
        ]
        for permit in permits:
            with self.subTest(permit=permit):
                repo, store = Repository(permit=permit), Storage()
                result, _, _, _ = do(repo=repo, store=store)
                self.assertEqual(result["status"], "rejected")
                self.assertEqual(repo.calls[-1], ("abort",))
                self.assertEqual(store.calls, [])

    def test_preexisting_object_never_overwritten(self):
        repo, store = Repository(), Storage(conflict=True)
        result, _, _, _ = do(repo=repo, store=store)
        self.assertEqual(result["status"], "rejected")
        self.assertFalse(repo.sealed)
        self.assertEqual([x[0] for x in store.calls], ["stat"])
        self.assertEqual(repo.calls[-1], ("abort",))

    def test_failed_storage_write_preserves_unsealed_attempt(self):
        repo, store = Repository(), Storage(fail_write=True)
        result, _, _, _ = do(repo=repo, store=store)
        self.assertEqual(result["status"], "rejected")
        self.assertFalse(repo.sealed)
        self.assertFalse(repo.held)
        self.assertEqual(repo.calls[-1], ("abort",))

    def test_tampered_readback_never_seals(self):
        repo, store = Repository(), Storage(tamper=True)
        result, _, _, _ = do(repo=repo, store=store)
        self.assertEqual(result["status"], "rejected")
        self.assertFalse(repo.sealed)
        self.assertIn(("remove", "learningapp-excel-private", PATH), store.calls)
        self.assertEqual(repo.calls[-1], ("abort",))

    def test_seal_failure_compensates_storage_before_rollback(self):
        repo, store = Repository(seal=True), Storage()
        result, _, _, _ = do(repo=repo, store=store)
        self.assertEqual(result["status"], "rejected")
        self.assertIsNone(store.blob)
        self.assertEqual(repo.calls[-1], ("abort",))
        self.assertFalse(repo.sealed)

    def test_cleanup_failure_does_not_claim_success(self):
        repo, store = Repository(seal=True), Storage(fail_remove=True)
        result, _, _, _ = do(repo=repo, store=store)
        self.assertEqual(result["status"], "rejected")
        self.assertFalse(repo.sealed)
        self.assertEqual(repo.calls[-1], ("abort",))

    def test_replay_denied_at_repository_even_if_object_removed(self):
        repo, store = Repository(), Storage()
        self.assertEqual(do(repo=repo, store=store)[0]["status"], "accepted")
        store.blob = None
        self.assertEqual(do(repo=repo, store=store)[0]["status"], "rejected")
        self.assertEqual(sum(1 for c in store.calls if c[0] == "create"), 1)

    def test_concurrent_request_lock_denial_has_no_storage_effect(self):
        repo, store = Repository(), Storage()
        repo.held = True
        result, _, _, _ = do(repo=repo, store=store)
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(store.calls, [])

    def test_cleanup_not_called_for_conflicting_preexisting_object(self):
        repo, store = Repository(), Storage(conflict=True)
        do(repo=repo, store=store)
        self.assertNotIn("remove", [x[0] for x in store.calls])


if __name__ == "__main__":
    unittest.main()
