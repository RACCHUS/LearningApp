"""Fail-closed, service-only Excel workbook upload sealing.

A trusted upload broker verifies a permanent Supabase session, holds an
exclusive database row lock throughout Storage creation + read-back, then
commits a SHA-256 and immutable object version in one transaction.

This is NOT an HTTP endpoint. Do not install it on a public-facing host with
privileged credentials or a Docker socket. Only a separately reviewed upload
gateway may use it. Direct learner Storage policies must remain DENIED.

A database lock protects concurrent compliant brokers and processing claims.
Ambiguous failed writes are never deleted inline: without version-conditional
Storage deletion, a timeout or lost DB commit acknowledgement could otherwise
cause a valid sealed workbook to be erased. Expiry/account retention handles
orphan cleanup separately. Live-provider race tests remain mandatory.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import hashlib
import hmac
from typing import Protocol
from uuid import UUID

from .private_assessment import VerifiedIdentity
from .storage_retention import PRIVATE_BUCKET

_MAX_BYTES = 10 * 1024 * 1024


@dataclass(frozen=True)
class UploadPermit:
    owner_id: str
    session_id: str
    attempt_id: str
    expires_at: datetime


class SessionGateway(Protocol):
    def verify(self, bearer_token: str) -> VerifiedIdentity: ...


class UploadRepository(Protocol):
    def begin(self, owner_id: str, session_id: str, attempt_id: str,
              at: datetime) -> UploadPermit | None: ...
    def seal(self, permit: UploadPermit, digest: str, version: str) -> bool: ...
    def abort(self, permit: UploadPermit) -> None: ...


class PrivateUploadStorage(Protocol):
    def stat(self, bucket: str, path: str) -> str | None: ...
    def create_only(self, bucket: str, path: str, blob: bytes) -> None: ...
    def download_limited(self, bucket: str, path: str, limit: int) -> bytes: ...


def _uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (ValueError, TypeError, AttributeError):
        return False


def _deny() -> dict[str, str]:
    return {"status": "rejected", "evidence_trust": "unverified_checker_only"}


def _eligible(permit: object, user: VerifiedIdentity,
              attempt_id: str, at: datetime) -> bool:
    return (
        isinstance(permit, UploadPermit)
        and all(_uuid(v) for v in (
            permit.owner_id, permit.session_id, permit.attempt_id))
        and permit.owner_id == user.owner_id
        and permit.session_id == user.session_id
        and permit.attempt_id == attempt_id
        and isinstance(permit.expires_at, datetime)
        and permit.expires_at.tzinfo is not None
        and permit.expires_at > at
    )


def accept_workbook(
    *, bearer_token: str, attempt_id: str, blob: bytes, now: datetime,
    sessions: SessionGateway, repository: UploadRepository,
    storage: PrivateUploadStorage,
) -> dict[str, str]:
    """Seal one non-overwritable workbook without issuing mastery evidence.

    The repository MUST use the same exclusively owned DB transaction and
    SELECT FOR UPDATE NOWAIT, holding the row lock until seal or abort.
    Any caller-supplied owner/session/object path is ignored. The storage
    adapter MUST reject redirects and never use signed URLs or upsert.
    """
    if (
        not isinstance(bearer_token, str) or not bearer_token
        or not _uuid(attempt_id) or
        not isinstance(now, datetime) or now.tzinfo is None or
        not isinstance(blob, bytes) or not 4 <= len(blob) <= _MAX_BYTES or
        not blob.startswith(b"PK\x03\x04")
    ):
        return _deny()

    try:
        identity = sessions.verify(bearer_token)
    except Exception:
        return _deny()
    if (
        not isinstance(identity, VerifiedIdentity) or
        identity.permanent is not True or
        not _uuid(identity.owner_id) or not _uuid(identity.session_id)
    ):
        return _deny()

    try:
        permit = repository.begin(identity.owner_id, identity.session_id,
                                  attempt_id, now)
    except Exception:
        return _deny()
    if permit is None:
        return _deny()

    sealed = False
    path = f"{identity.owner_id}/{attempt_id}/workbook.xlsx"
    try:
        if not _eligible(permit, identity, attempt_id, now):
            return _deny()

        # Refuse any existing object; never "fix" a conflict by overwriting
        # or deleting a pre-existing workbook.
        if storage.stat(PRIVATE_BUCKET, path) is not None:
            return _deny()

        storage.create_only(PRIVATE_BUCKET, path, blob)
        revision = storage.stat(PRIVATE_BUCKET, path)
        if (not isinstance(revision, str) or not 1 <= len(revision) <= 256
            or not revision.isascii()):
            return _deny()
        readback = storage.download_limited(PRIVATE_BUCKET, path, _MAX_BYTES + 1)
        if (not isinstance(readback, bytes) or len(readback) != len(blob) or
            not hmac.compare_digest(
                hashlib.sha256(readback).digest(),
                hashlib.sha256(blob).digest(),
            ) or storage.stat(PRIVATE_BUCKET, path) != revision):
            return _deny()

        digest = hashlib.sha256(readback).hexdigest()
        if repository.seal(permit, digest, revision) is not True:
            return _deny()
        sealed = True
        return {"status": "accepted", "evidence_trust": "unverified_checker_only"}
    except Exception:
        return _deny()
    finally:
        if not sealed:
            # NEVER perform an unversioned Storage DELETE on this path.
            # A create-only conflict after a stale stat, timeout-after-write,
            # or lost DB commit acknowledgement is ambiguous; deletion could
            # remove another or already-sealed object. Preserve any bytes and
            # leave the attempt metadata for the separate Storage-first
            # expiration/account-erasure coordinator. A failed upload may
            # require a newly issued attempt; no inline retries or overwrites.
            try:
                repository.abort(permit)
            except Exception:
                pass
