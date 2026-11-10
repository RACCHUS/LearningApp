"""Dedicated, disabled-by-default trusted upload host composition.

The upload broker MUST be a different internal process from the Docker parser
and workbook assessment host. It receives limited bytes, verifies a permanent
session, holds a private DB transaction across create-only Storage upload and
readback, then commits a one-time SHA/version seal.

No socket listener, credential source, public route or scheduler is created.
"""
from __future__ import annotations

import threading
from typing import Callable
from uuid import UUID

from .brokered_upload import accept_workbook
from .private_upload_db import DbApiUploadRepository
from .supabase_auth_gateway import SupabaseUserGateway
from .supabase_private_storage import SupabasePrivateWorkbookStore


def _canonical_uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (TypeError, ValueError, AttributeError):
        return False


def _rejected() -> dict[str, str]:
    return {"status": "rejected", "evidence_trust": "unverified_checker_only"}


class TrustedExcelUpload:
    """Broker holds a separate exclusive DB connection for every request."""

    def __init__(self, *, sessions, storage, connection_factory: Callable,
                 max_inflight: int = 2) -> None:
        if (not callable(connection_factory) or type(max_inflight) is not int or
            not 1 <= max_inflight <= 8):
            raise ValueError("Invalid broker configuration")
        self._sessions = sessions
        self._storage = storage
        self._connect = connection_factory
        self._slots = threading.BoundedSemaphore(max_inflight)

    def __call__(self, bearer_token: str, attempt_id: str, blob: bytes):
        if (not isinstance(bearer_token, str) or not bearer_token or
            not _canonical_uuid(attempt_id) or
            not isinstance(blob, bytes) or
            not 4 <= len(blob) <= 10 * 1024 * 1024):
            return _rejected()
        if not self._slots.acquire(blocking=False):
            return _rejected()
        conn = None
        try:
            from datetime import datetime, timezone
            conn = self._connect()
            if conn is None or not hasattr(conn, "close"):
                return _rejected()
            return accept_workbook(
                bearer_token=bearer_token, attempt_id=attempt_id,
                blob=blob, now=datetime.now(timezone.utc),
                sessions=self._sessions,
                repository=DbApiUploadRepository(conn),
                storage=self._storage,
            )
        except Exception:
            return _rejected()
        finally:
            if conn is not None:
                try:
                    conn.close()
                except Exception:
                    pass
            self._slots.release()


def build_trusted_excel_upload_host(
    *, project_ref: str, publishable_key: str,
    private_storage_key: str, connection_factory: Callable,
    max_inflight: int = 2,
) -> TrustedExcelUpload:
    """Only pass credentials from a reviewed private secret store.

    This factory intentionally DOES NOT import Docker or the worker runner.
    The storage and database capabilities must never enter a public HTTP
    process, user client or image parser.
    """
    return TrustedExcelUpload(
        sessions=SupabaseUserGateway(project_ref=project_ref,
                                     publishable_key=publishable_key),
        storage=SupabasePrivateWorkbookStore(
            project_ref=project_ref, secret_key=private_storage_key,
            allowed_methods=frozenset({"GET", "POST"}),
        ),
        connection_factory=connection_factory, max_inflight=max_inflight,
    )
