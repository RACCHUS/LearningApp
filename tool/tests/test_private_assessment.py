"""Fail-closed server-only admission and workbook grading tests.

Test doubles intentionally model trusted hosted components that have NOT been
deployed; a fake principal or a fake claim cannot be trusted in production.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
from pathlib import Path
import sys
import unittest
from uuid import UUID

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.private_assessment import (
    AssessmentLease,
    VerifiedIdentity,
    assess_private_workbook,
)
from software_learning.xlsx_worker import run_worker
from test_xlsx_snapshot import zip_bytes

OWNER = "ba410000-0000-4000-8000-000000000001"
OTHER = "ba410000-0000-4000-8000-000000000002"
SESSION = "ba420000-0000-4000-8000-000000000001"
OTHER_SESSION = "ba420000-0000-4000-8000-000000000002"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"
LEASE_ID = "ba440000-0000-4000-8000-000000000001"
NOW = datetime(2026, 11, 7, 20, 0, tzinfo=timezone.utc)
EXPECTED = {f"C{i}": i * 10 for i in range(2, 10)}
PRIVATE_PATH = f"{OWNER}/{ATTEMPT}/workbook.xlsx"


class SessionGateway:
    def __init__(self, identity=None):
        self.identity = identity or VerifiedIdentity(OWNER, SESSION, permanent=True)
        self.calls = []

    def verify(self, bearer):
        self.calls.append(bearer)
        if bearer != "valid server bearer":
            raise PermissionError("invalid token")
        return self.identity


class Repository:
    def __init__(self, lease=None):
        self.lease = lease if lease is not None else AssessmentLease(
            lease_id=LEASE_ID, owner_id=OWNER, session_id=SESSION,
            attempt_id=ATTEMPT, exercise_id="excel-budget-total-v1",
            checker_version=1, expires_at=NOW + timedelta(minutes=4),
            expected_inputs=EXPECTED,
        )
        self.claimed = False
        self.receipts = []
        self.failures = []
        self.calls = []

    def claim(self, owner, session, attempt_id, at):
        self.calls.append(("claim", owner, session, attempt_id))
        if self.claimed or self.lease is None:
            return None
        if owner != self.lease.owner_id or session != self.lease.session_id:
            return None
        if attempt_id != self.lease.attempt_id:
            return None
        if at >= self.lease.expires_at:
            return None
        self.claimed = True
        return self.lease

    def complete(self, lease_id, digest, status, feedback):
        self.calls.append(("complete", lease_id, status))
        if not self.claimed or lease_id != LEASE_ID or self.receipts:
            return False
        self.receipts.append((digest, status, feedback))
        return True

    def fail(self, lease_id):
        self.calls.append(("fail", lease_id))
        self.failures.append(lease_id)


class Store:
    def __init__(self, blob=None, before="v1", after="v1"):
        self.blob = zip_bytes() if blob is None else blob
        self.before, self.after = before, after
        self.seen = []
        self.stats = 0

    def stat(self, bucket, path):
        self.seen.append(("stat", bucket, path))
        self.stats += 1
        return self.before if self.stats == 1 else self.after

    def download_limited(self, bucket, path, limit):
        self.seen.append(("download", bucket, path, limit))
        return self.blob


class Runner:
    def __init__(self, fail=False):
        self.called = []
        self.fail = fail

    def parse(self, blob):
        self.called.append(blob)
        if self.fail:
            raise TimeoutError("worker timeout")
        return run_worker(io.BytesIO(blob), filename="budget.xlsx")


def assess(*, repo=None, store=None, runner=None, gateway=None,
           owner=OWNER, attempt=ATTEMPT, bearer="valid server bearer",
           now=NOW):
    repo = repo if repo is not None else Repository()
    store = store if store is not None else Store()
    runner = runner if runner is not None else Runner()
    gateway = gateway if gateway is not None else SessionGateway()
    result = assess_private_workbook(
        bearer_token=bearer, attempt_id=attempt, now=now, sessions=gateway,
        repository=repo, storage=store, runner=runner
    )
    return result, repo, store, runner, gateway


class PrivateAssessmentTests(unittest.TestCase):
    def test_valid_workbook_is_provisional_and_digest_bound(self):
        result, repo, store, runner, gateway = assess()
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["evidence_trust"], "unverified_checker_only")
        self.assertEqual(result["skill_award_enabled"], False)
        self.assertNotIn("cells", result)
        self.assertNotIn("expected_inputs", result)
        self.assertEqual(len(repo.receipts), 1)
        self.assertEqual(repo.receipts[0][0], hashlib.sha256(store.blob).hexdigest())
        self.assertEqual(store.seen, [
            ("stat", "learningapp-excel-private", PRIVATE_PATH),
            ("download", "learningapp-excel-private", PRIVATE_PATH, 10485761),
            ("stat", "learningapp-excel-private", PRIVATE_PATH),
        ])

    def test_invalid_token_causes_no_claim_or_storage(self):
        result, repo, store, runner, gateway = assess(bearer="forged")
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(repo.calls, [])
        self.assertEqual(store.seen, [])
        self.assertEqual(runner.called, [])

    def test_anonymous_identity_fails_closed(self):
        gate = SessionGateway(VerifiedIdentity(OWNER, SESSION, permanent=False))
        result, repo, store, runner, _ = assess(gateway=gate)
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(repo.calls, [])
        self.assertEqual(store.seen, [])

    def test_cross_account_attempt_cannot_read_file(self):
        gate = SessionGateway(VerifiedIdentity(OTHER, OTHER_SESSION, permanent=True))
        result, repo, store, runner, _ = assess(gateway=gate)
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(store.seen, [])
        self.assertEqual(runner.called, [])

    def test_malformed_attempt_rejected_before_claim(self):
        for attack in ("../" + ATTEMPT, ATTEMPT.upper(), "bad", "", " " + ATTEMPT):
            with self.subTest(attempt=attack):
                result, repo, store, runner, gate = assess(attempt=attack)
                self.assertEqual(result["status"], "rejected")
                self.assertEqual(repo.calls, [])
                self.assertEqual(store.seen, [])

    def test_wrong_session_cannot_access_issued_attempt(self):
        gate = SessionGateway(VerifiedIdentity(OWNER, OTHER_SESSION, permanent=True))
        result, repo, store, runner, _ = assess(gateway=gate)
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(store.seen, [])

    def test_replay_cannot_grant_second_receipt(self):
        repo = Repository()
        first, _, _, _, _ = assess(repo=repo)
        second, _, store, runner, _ = assess(repo=repo)
        self.assertEqual(first["status"], "pass")
        self.assertEqual(second["status"], "rejected")
        self.assertEqual(len(repo.receipts), 1)
        self.assertEqual(store.seen, [])
        self.assertEqual(runner.called, [])

    def test_expired_lease_is_rejected_before_download(self):
        result, repo, store, runner, _ = assess(now=NOW + timedelta(minutes=5))
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(store.seen, [])

    def test_object_replacement_fails_before_grading(self):
        result, repo, store, runner, _ = assess(store=Store(before="v1", after="v2"))
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(repo.receipts, [])
        self.assertEqual(len(runner.called), 0)
        self.assertEqual(repo.failures, [LEASE_ID])

    def test_missing_object_version_rejected(self):
        result, repo, store, runner, _ = assess(store=Store(before=None))
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(len(runner.called), 0)

    def test_oversized_download_rejected_before_worker(self):
        result, repo, store, runner, _ = assess(store=Store(blob=b"X" * (10 * 1024 * 1024 + 1)))
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(runner.called, [])
        self.assertEqual(repo.receipts, [])

    def test_worker_timeout_is_redacted_and_not_recorded(self):
        result, repo, store, runner, _ = assess(runner=Runner(fail=True))
        self.assertEqual(result["status"], "rejected")
        self.assertNotIn("timeout", json.dumps(result))
        self.assertEqual(repo.receipts, [])
        self.assertEqual(repo.failures, [LEASE_ID])

    def test_unsupported_workbook_cannot_record_success(self):
        result, repo, store, runner, _ = assess(store=Store(blob=b"malicious workbook"))
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(repo.receipts, [])

    def test_forged_incorrect_checker_version_is_rejected(self):
        repo = Repository()
        lease = repo.lease
        repo.lease = AssessmentLease(lease.lease_id, lease.owner_id, lease.session_id,
                                     lease.attempt_id, lease.exercise_id, 2,
                                     lease.expires_at, lease.expected_inputs)
        result, _, store, runner, _ = assess(repo=repo)
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(store.seen, [])

    def test_complete_failure_never_claims_success(self):
        class BrokenRepo(Repository):
            def complete(self, lease_id, digest, status, feedback):
                return False
        result, repo, store, runner, _ = assess(repo=BrokenRepo())
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(repo.receipts, [])

    def test_malformed_worker_claiming_verified_is_rejected(self):
        class ForgedRunner(Runner):
            def parse(self, blob):
                value = super().parse(blob)
                value["evidence_trust"] = "server_verified"
                return value
        result, repo, store, runner, _ = assess(runner=ForgedRunner())
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(repo.receipts, [])

if __name__ == "__main__":
    unittest.main()
