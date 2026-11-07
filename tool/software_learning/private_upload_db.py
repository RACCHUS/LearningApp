"""Single-upload PostgreSQL transaction via role-scoped private broker RPCs.

service_role does not ordinarily have direct SELECT on auth.sessions.
The private SECURITY DEFINER lock function checks the live session and takes
a row lock, which remains held by this exclusive non-autocommit connection
through Storage creation, readback, seal and commit (or rollback on failure).

Never share this connection across requests or expose the private RPCs to
learner roles. The privileged connection is closed by the upload host.
"""
from __future__ import annotations

from datetime import datetime
import json
import re
from typing import Mapping
from uuid import UUID

from .brokered_upload import UploadPermit

_HASH = re.compile(r"\A[a-f0-9]{64}\Z")
_VERSION = re.compile(r"\A[a-zA-Z0-9._:-]{1,256}\Z")


def _uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (ValueError, TypeError, AttributeError):
        return False


def _strict_permit(raw: object, owner: str, session: str,
                   attempt: str, now: datetime) -> UploadPermit | None:
    if raw is None:
        return None
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except ValueError:
            raise ValueError("Invalid private upload permit") from None
    if not isinstance(raw, Mapping) or set(raw) != {
        "owner_id", "session_id", "attempt_id", "expires_at"
    }:
        raise ValueError("Untrusted upload permit")
    if (raw["owner_id"] != owner or raw["session_id"] != session or
        raw["attempt_id"] != attempt):
        raise ValueError("Upload permit identity mismatch")
    try:
        expires_at = datetime.fromisoformat(raw["expires_at"])
    except (TypeError, ValueError):
        raise ValueError("Invalid permit expiry") from None
    if expires_at.tzinfo is None or expires_at <= now:
        raise ValueError("Expired upload permit")
    return UploadPermit(owner, session, attempt, expires_at)


class DbApiUploadRepository:
    """Commit only after backend-confirmed create-only Storage readback."""

    def __init__(self, connection):
        if (connection is None or
            getattr(connection, "autocommit", True) is not False):
            raise ValueError("Exclusive non-autocommit DB connection required")
        self._conn = connection
        self._held: UploadPermit | None = None

    def _one(self, sql: str, args: tuple):
        cursor = self._conn.cursor()
        try:
            cursor.execute(sql, args)
            row = cursor.fetchone()
            return row[0] if isinstance(row, (tuple, list)) and len(row) == 1 else None
        finally:
            cursor.close()

    def begin(self, owner_id: str, session_id: str,
              attempt_id: str, at: datetime) -> UploadPermit | None:
        if self._held is not None:
            return None
        if (not all(_uuid(v) for v in (owner_id, session_id, attempt_id))
            or not isinstance(at, datetime) or at.tzinfo is None):
            return None
        try:
            raw = self._one(
                "SELECT software_learning_private.sl_lock_excel_upload(%s,%s,%s)",
                (attempt_id, owner_id, session_id),
            )
            permit = _strict_permit(raw, owner_id, session_id, attempt_id, at)
            if permit is None:
                self._conn.rollback()
                return None
            self._held = permit
            return permit
        except Exception:
            self._conn.rollback()
            self._held = None
            raise

    def seal(self, permit: UploadPermit, digest: str, version: str) -> bool:
        if (not isinstance(permit, UploadPermit) or self._held != permit or
            not isinstance(digest, str) or _HASH.fullmatch(digest) is None or
            not isinstance(version, str) or _VERSION.fullmatch(version) is None):
            return False
        try:
            success = self._one(
                "SELECT software_learning_private.sl_seal_excel_upload(%s,%s,%s,%s,%s)",
                (permit.attempt_id, permit.owner_id, permit.session_id, digest, version),
            )
            if success is not True:
                self._conn.rollback()
                self._held = None
                return False
            self._conn.commit()
            self._held = None
            return True
        except Exception:
            self._conn.rollback()
            self._held = None
            raise

    def abort(self, permit: UploadPermit) -> None:
        if self._held == permit:
            try:
                self._conn.rollback()
            finally:
                self._held = None
