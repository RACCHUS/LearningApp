"""Full synthetic XLSX lifecycle: broker -> sealed lease -> real parser -> provisional grade.

No network, live credentials, cloud files, persistence, or learner data.
The real ZIP reader/checker are used; only Auth, DB transaction and Storage
implementations are replaced by strict in-memory doubles.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import io
import sys
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))

from software_learning.brokered_upload import accept_workbook, UploadPermit
from software_learning.private_assessment import (
    assess_private_workbook, AssessmentLease, VerifiedIdentity,
)
from software_learning.xlsx_worker import run_worker
from test_xlsx_snapshot import zip_bytes

OWNER = "ba410000-0000-4000-8000-000000000001"
SESSION = "ba420000-0000-4000-8000-000000000001"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"
LEASE = "ba440000-0000-4000-8000-000000000001"
AT = datetime(2026, 11, 7, 20, tzinfo=timezone.utc)
FILE = zip_bytes()
INPUTS = {f"C{i}": i * 10 for i in range(2, 10)}
PATH = f"{OWNER}/{ATTEMPT}/workbook.xlsx"


class Sessions:
    def verify(self, token):
        if token != "valid synthetic token":
            raise PermissionError("invalid token")
        return VerifiedIdentity(OWNER, SESSION, True)


class Store:
    def __init__(self):
        self.blob = None
        self.version = "opaque-version-1"
        self.tamper = False
        self.calls = []

    def stat(self, bucket, path):
        if path != PATH or bucket != "learningapp-excel-private":
            raise ValueError("foreign object")
        self.calls.append("stat")
        return self.version if self.blob is not None else None

    def create_only(self, bucket, path, blob):
        if self.stat(bucket, path) is not None:
            raise ValueError("already exists")
        self.calls.append("create")
        self.blob = blob

    def download_limited(self, bucket, path, limit):
        self.calls.append("download")
        self.stat(bucket, path)
        return b"tampered" if self.tamper else self.blob

    def remove(self, bucket, path):
        self.calls.append("remove")
        self.blob = None


class State:
    def __init__(self):
        self.status = "issued"
        self.digest = None
        self.version = None
        self.upload_frozen = False
        self.claimed = False
        self.completed = None

    def begin(self, owner, session, attempt, at):
        if (owner, session, attempt) != (OWNER, SESSION, ATTEMPT):
            return None
        if self.status != "issued" or self.digest is not None:
            return None
        return UploadPermit(OWNER, SESSION, ATTEMPT, at+timedelta(minutes=15))

    def seal(self, permit, digest, version):
        if self.status != "issued" or self.digest is not None:
            return False
        self.digest = digest
        self.version = version
        return True

    def abort(self, permit):
        pass

    def claim(self, owner, session, attempt, at):
        if ((owner, session, attempt) != (OWNER, SESSION, ATTEMPT)
            or self.claimed or self.digest is None or self.status != "issued"):
            return None
        self.claimed = True
        self.upload_frozen = True
        self.status = "processing"
        return AssessmentLease(
            lease_id=LEASE, owner_id=OWNER, session_id=SESSION,
            attempt_id=ATTEMPT, exercise_id="excel-budget-total-v1",
            checker_version=1, expires_at=at+timedelta(minutes=10),
            expected_inputs=INPUTS, expected_sha256=self.digest,
            object_version=self.version,
        )

    def complete(self, lease, digest, status, feedback):
        if (lease != LEASE or self.status != "processing" or
            digest != self.digest):
            return False
        self.status = "processed"
        self.completed = (status, feedback)
        return True

    def fail(self, lease):
        if self.status == "processing" and lease == LEASE:
            self.status = "failed"


class Parser:
    def parse(self, blob):
        return run_worker(io.BytesIO(blob), filename="budget.xlsx")


class LifecycleTests(unittest.TestCase):
    def test_accepted_file_is_checked_once_and_never_awards_a_skill(self):
        state, storage, sessions = State(), Store(), Sessions()
        upload = accept_workbook(
            bearer_token="valid synthetic token", attempt_id=ATTEMPT,
            blob=FILE, now=AT, sessions=sessions, repository=state, storage=storage)
        self.assertEqual(upload["status"], "accepted")
        self.assertEqual(state.digest, hashlib.sha256(FILE).hexdigest())
        result = assess_private_workbook(
            bearer_token="valid synthetic token", attempt_id=ATTEMPT,
            now=AT, sessions=sessions, repository=state, storage=storage,
            runner=Parser())
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["evidence_trust"], "unverified_checker_only")
        self.assertIs(result["skill_award_enabled"], False)
        self.assertEqual(state.status, "processed")
        self.assertEqual(state.completed[0], "pass")
        replay = assess_private_workbook(
            bearer_token="valid synthetic token", attempt_id=ATTEMPT,
            now=AT, sessions=sessions, repository=state, storage=storage,
            runner=Parser())
        self.assertEqual(replay["status"], "rejected")
        self.assertEqual(accept_workbook(
            bearer_token="valid synthetic token", attempt_id=ATTEMPT,
            blob=FILE, now=AT, sessions=sessions, repository=state,
            storage=storage)["status"], "rejected")

    def test_modified_storage_after_seal_rejects_without_grading(self):
        state, storage, sessions = State(), Store(), Sessions()
        self.assertEqual(accept_workbook(
            bearer_token="valid synthetic token", attempt_id=ATTEMPT,
            blob=FILE, now=AT, sessions=sessions, repository=state,
            storage=storage)["status"], "accepted")
        storage.tamper = True
        result = assess_private_workbook(
            bearer_token="valid synthetic token", attempt_id=ATTEMPT,
            now=AT, sessions=sessions, repository=state, storage=storage,
            runner=Parser())
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(state.status, "failed")
        self.assertIsNone(state.completed)

    def test_wrong_user_cannot_trigger_upload_or_assessment(self):
        state, storage = State(), Store()
        for operation in ("upload", "assess"):
            with self.subTest(operation=operation):
                if operation == "upload":
                    result = accept_workbook(
                        bearer_token="forged token", attempt_id=ATTEMPT,
                        blob=FILE, now=AT, sessions=Sessions(), repository=state,
                        storage=storage)
                else:
                    result = assess_private_workbook(
                        bearer_token="forged token", attempt_id=ATTEMPT,
                        now=AT, sessions=Sessions(), repository=state,
                        storage=storage, runner=Parser())
                self.assertEqual(result["status"], "rejected")
        self.assertEqual(storage.calls, [])


if __name__ == "__main__":
    unittest.main()
