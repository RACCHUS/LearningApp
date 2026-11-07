"""Server-only private XLSX assessment handoff: never a public upload API.

This coordinates a *trusted* session verifier, a database-backed atomic,
single-use claim, a private Storage API adapter, and a confined parser runner.
It must run only in trusted hosted infrastructure. This package provides
neither an HTTP endpoint nor these production adapters, and thus cannot
enable uploads or issue verified learning evidence on its own.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import hashlib
from typing import Mapping, Protocol
from uuid import UUID

from .pilot_pipeline import grade_parsed_snapshot
from .storage_retention import PRIVATE_BUCKET

_MAX_BYTES = 10 * 1024 * 1024
_EXERCISE = "excel-budget-total-v1"


@dataclass(frozen=True)
class VerifiedIdentity:
    """Must originate from a server-side verified JWT and live session."""
    owner_id: str
    session_id: str
    permanent: bool


@dataclass(frozen=True)
class AssessmentLease:
    """Must originate from a serialized, server-only DB claim operation."""
    lease_id: str
    owner_id: str
    session_id: str
    attempt_id: str
    exercise_id: str
    checker_version: int
    expires_at: datetime
    expected_inputs: Mapping[str, object]
    expected_sha256: str | None = None
    object_version: str | None = None


class SessionGateway(Protocol):
    def verify(self, bearer_token: str) -> VerifiedIdentity: ...


class AttemptRepository(Protocol):
    def claim(self, owner_id: str, session_id: str,
              attempt_id: str, at: datetime) -> AssessmentLease | None: ...
    def complete(self, lease_id: str, digest: str,
                 status: str, feedback: str) -> bool: ...
    def fail(self, lease_id: str) -> None: ...


class PrivateObjectStore(Protocol):
    def stat(self, bucket: str, path: str) -> str | None: ...
    def download_limited(self, bucket: str, path: str, limit: int) -> bytes: ...


class WorkerRunner(Protocol):
    def parse(self, blob: bytes) -> Mapping[str, object]: ...


def _uuid_canonical(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (TypeError, ValueError, AttributeError):
        return False


def _rejected() -> dict[str, object]:
    # Intentionally does not distinguish a missing, foreign or malformed
    # attempt; never includes a token, path, workbook, or learner input.
    return {
        "status": "rejected",
        "feedback": "This workbook could not be assessed. Try the exercise again.",
        "evidence_trust": "unverified_checker_only",
        "skill_award_enabled": False,
    }


def _eligible(lease: AssessmentLease, user: VerifiedIdentity,
              requested_attempt: str, at: datetime) -> bool:
    if not isinstance(lease, AssessmentLease):
        return False
    if not all(_uuid_canonical(x) for x in (
        lease.lease_id, lease.owner_id, lease.session_id, lease.attempt_id
    )):
        return False
    if (lease.owner_id != user.owner_id or
        lease.session_id != user.session_id or
        lease.attempt_id != requested_attempt or
        lease.exercise_id != _EXERCISE or
        type(lease.checker_version) is not int or
        lease.checker_version != 1 or
        lease.expires_at.tzinfo is None or
        lease.expires_at <= at or
        not isinstance(lease.expected_sha256, str) or
        len(lease.expected_sha256) != 64 or
        any(v not in "0123456789abcdef" for v in lease.expected_sha256) or
        not isinstance(lease.object_version, str) or
        not 1 <= len(lease.object_version) <= 256):
        return False
    return True


def assess_private_workbook(
    *, bearer_token: str, attempt_id: str, now: datetime,
    sessions: SessionGateway, repository: AttemptRepository,
    storage: PrivateObjectStore, runner: WorkerRunner,
) -> dict[str, object]:
    """Run at most one provisional, checksum-bound grading operation.

    The repository CLAIM must atomically test permanent account/session
    validity, owner, unexpired attempt, upload_enabled, and not-yet-claimed
    state, then disable further uploads and pin a unique lease. An adapter
    that simply returns a client-provided object is NOT secure.

    A production Storage adapter must enforce size *during streaming* and
    return object revision (ETag/version) using authenticated Storage API.
    Even with double stat, an in-flight upload race remains a release gate.
    """
    if (not isinstance(bearer_token, str) or not bearer_token or
        not _uuid_canonical(attempt_id) or
        not isinstance(now, datetime) or now.tzinfo is None):
        return _rejected()

    try:
        identity = sessions.verify(bearer_token)
    except Exception:
        return _rejected()
    if (not isinstance(identity, VerifiedIdentity)
        or not identity.permanent
        or not _uuid_canonical(identity.owner_id)
        or not _uuid_canonical(identity.session_id)):
        return _rejected()

    try:
        lease = repository.claim(identity.owner_id, identity.session_id, attempt_id, now)
    except Exception:
        return _rejected()
    if lease is None:
        return _rejected()

    completed = False
    try:
        if not _eligible(lease, identity, attempt_id, now):
            return _rejected()

        object_name = f"{identity.owner_id}/{attempt_id}/workbook.xlsx"
        before = storage.stat(PRIVATE_BUCKET, object_name)
        if before != lease.object_version:
            return _rejected()

        blob = storage.download_limited(PRIVATE_BUCKET, object_name, _MAX_BYTES + 1)
        if (not isinstance(blob, bytes) or not blob or len(blob) > _MAX_BYTES
            or hashlib.sha256(blob).hexdigest() != lease.expected_sha256):
            return _rejected()

        after = storage.stat(PRIVATE_BUCKET, object_name)
        if after != before:
            return _rejected()

        structured = runner.parse(blob)
        result = grade_parsed_snapshot(structured, lease.expected_inputs)
        if result["status"] not in ("pass", "fail", "inconclusive"):
            return _rejected()

        # The repository must implement an atomic CAS against the live lease.
        # No consumer may turn this status into a verified skill award.
        digest = hashlib.sha256(blob).hexdigest()
        if repository.complete(lease.lease_id, digest, result["status"],
                               result["feedback"]) is not True:
            return _rejected()
        completed = True
        return {
            "status": result["status"],
            "feedback": result["feedback"],
            "evidence_trust": "unverified_checker_only",
            "skill_award_enabled": False,
        }
    except Exception:
        return _rejected()
    finally:
        # Only failed claims are marked failed, never successful results.
        # The repository must atomically guard against a claim lease race and
        # never reopen the original upload window.
        if not completed:
            try:
                repository.fail(lease.lease_id)
            except Exception:
                pass
