"""Privileged DB-API transaction for one sealed Excel upload.

The connection must be exclusively owned, have autocommit disabled, and must
NOT be shared with any request. SELECT FOR UPDATE NOWAIT holds the attempt
lock while a separate Storage API writes and verifies bytes. Seal commits
that same transaction; abort rolls back. The host MUST close the connection.

This is not a public RPC, upload URL signer, or deployed service. It requires
a separately authenticated ingress and reviewed privileged DB access.
"""
from __future__ import annotations

from datetime import datetime
import re
from uuid import UUID

from .brokered_upload import UploadPermit

_HASH = re.compile(r"\A[a-f0-9]{64}\Z")
_VERSION = re.compile(r"\A[a-zA-Z0-9._:-]{1,256}\Z")


def _canonical_uuid(v: object) -> bool:
    if not isinstance(v, str):
        return False
    try:
        return str(UUID(v)) == v
    except (TypeError, ValueError, AttributeError):
        return False


class DbApiUploadRepository:
    """Rows remain locked until the one allowed commit/rollback."""

    def __init__(self, connection):
        if connection is None or getattr(connection, "autocommit", True) is not False:
            raise ValueError("Upload transactions require an exclusive non-autocommit DB connection")
        self._conn = connection
        self._held: UploadPermit | None = None

    def _one(self, sql: str, args: tuple):
        cursor = self._conn.cursor()
        try:
            cursor.execute(sql, args)
            return cursor.fetchone()
        finally:
            cursor.close()

    def begin(self, owner_id: str, session_id: str,
              attempt_id: str, at: datetime) -> UploadPermit | None:
        if self._held is not None:
            return None
        if (
            not all(_canonical_uuid(v) for v in (owner_id, session_id, attempt_id)) or
            not isinstance(at, datetime) or at.tzinfo is None
        ):
            return None
        try:
            raw = self._one(
                "SELECT a.owner_id::text, a.issued_session_id::text, "
                "a.id::text, a.expires_at "
                "FROM public.software_learning_attempts a "
                "WHERE a.id=%s::uuid AND a.owner_id=%s::uuid "
                "AND a.issued_session_id=%s::uuid "
                "AND a.status='issued' AND a.expires_at>now() + interval '2 minutes' "
                "AND a.upload_enabled=false "
                "AND a.upload_committed_at IS NULL "
                "AND a.upload_sha256 IS NULL AND a.upload_object_version IS NULL "
                "AND EXISTS (SELECT 1 FROM auth.sessions s "
                "WHERE s.id=a.issued_session_id AND s.user_id=a.owner_id "
                "AND (s.not_after IS NULL OR s.not_after>now())) "
                "FOR UPDATE OF a NOWAIT",
                (attempt_id, owner_id, session_id),
            )
            if (
                not isinstance(raw, (list, tuple)) or len(raw) != 4 or
                raw[:3] != (owner_id, session_id, attempt_id) or
                not isinstance(raw[3], datetime) or
                raw[3].tzinfo is None or raw[3] <= at
            ):
                self._conn.rollback()
                return None
            permit = UploadPermit(owner_id, session_id, attempt_id, raw[3])
            self._held = permit
            return permit
        except Exception:
            self._conn.rollback()
            self._held = None
            raise

    def seal(self, permit: UploadPermit, digest: str, version: str) -> bool:
        if (
            not isinstance(permit, UploadPermit) or
            self._held != permit or
            not isinstance(digest, str) or _HASH.fullmatch(digest) is None or
            not isinstance(version, str) or _VERSION.fullmatch(version) is None
        ):
            return False
        try:
            row = self._one(
                "UPDATE public.software_learning_attempts "
                "SET upload_sha256=%s, upload_object_version=%s, "
                "upload_committed_at=now(), upload_enabled=true "
                "WHERE owner_id=%s::uuid AND issued_session_id=%s::uuid "
                "AND id=%s::uuid AND status='issued' "
                "AND upload_enabled=false AND upload_committed_at IS NULL "
                "AND expires_at>now() "
                "RETURNING id::text",
                (digest, version, permit.owner_id,
                 permit.session_id, permit.attempt_id),
            )
            if row != (permit.attempt_id,):
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
