"""Trusted-host composition for provisional Excel workbook assessment.

Use only inside a privately routed, reviewed backend service. It creates an
exclusive privileged DB connection per invocation, closes it on failure, and
limits concurrent requests in each process. No HTTP server, listener,
scheduler, secrets loader, file upload or skill awarding is installed here.

A production deployment MUST use a dedicated worker host/broker so public
web processes never gain Docker socket or privileged DB credentials.
"""
from __future__ import annotations

from datetime import datetime, timezone
import threading
from typing import Callable
from uuid import UUID

from .private_assessment import assess_private_workbook
from .private_assessment_db import DbApiAttemptRepository
from .supabase_auth_gateway import SupabaseUserGateway
from .supabase_private_storage import SupabasePrivateWorkbookStore
from .container_worker_runner import DockerXlsxWorker


def _uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (TypeError, ValueError, AttributeError):
        return False


def _unavailable():
    return {
        "status": "rejected",
        "feedback": "This assessment is temporarily unavailable.",
        "evidence_trust": "unverified_checker_only",
        "skill_award_enabled": False,
    }


class TrustedExcelAssessment:
    """Bounded host logic. Must not be callable from the public internet."""

    def __init__(
        self, *, sessions, storage, runner, connection_factory: Callable,
        max_inflight: int = 2,
    ) -> None:
        if (not callable(connection_factory) or
            type(max_inflight) is not int or not 1 <= max_inflight <= 8):
            raise ValueError("Invalid trusted-host configuration")
        self._sessions = sessions
        self._storage = storage
        self._runner = runner
        self._connect = connection_factory
        self._slots = threading.BoundedSemaphore(max_inflight)

    def __call__(self, bearer_token: str, attempt_id: str):
        if (not isinstance(bearer_token, str) or not bearer_token or
            not _uuid(attempt_id)):
            return _unavailable()
        if not self._slots.acquire(blocking=False):
            return _unavailable()
        conn = None
        try:
            conn = self._connect()
            if (conn is None or not hasattr(conn, "close") or
                getattr(conn, "autocommit", True) is not False):
                return _unavailable()
            return assess_private_workbook(
                bearer_token=bearer_token,
                attempt_id=attempt_id,
                now=datetime.now(timezone.utc),
                sessions=self._sessions,
                repository=DbApiAttemptRepository(conn),
                storage=self._storage,
                runner=self._runner,
            )
        except Exception:
            return _unavailable()
        finally:
            if conn is not None:
                try:
                    conn.close()
                except Exception:
                    pass
            self._slots.release()


def build_trusted_excel_host(
    *, project_ref: str, publishable_key: str, private_storage_key: str,
    pinned_worker_image: str, connection_factory: Callable,
    max_inflight: int = 2,
) -> TrustedExcelAssessment:
    """Assemble existing reviewed adapters from explicitly supplied secrets.

    Keys must be provided by a trusted secret manager, never a browser, CLI
    argument or workbook. An independent host infrastructure review is
    required before enabling the ASGI ingress. The Docker socket must not
    be present on any public-facing application host.
    """
    return TrustedExcelAssessment(
        sessions=SupabaseUserGateway(project_ref=project_ref,
                                     publishable_key=publishable_key),
        storage=SupabasePrivateWorkbookStore(
            project_ref=project_ref, secret_key=private_storage_key,
            allowed_methods=frozenset({"GET"}),
        ),
        runner=DockerXlsxWorker(pinned_worker_image),
        connection_factory=connection_factory,
        max_inflight=max_inflight,
    )
