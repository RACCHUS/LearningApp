"""DB-API backend adapter for one-time Excel workbook assessment leases.

Only create this class with a privileged, server-owned PostgreSQL connection
that can execute software_learning_private functions. The connection must
never be exposed to browsers, a learner upload handler, or a parser container.
No dependencies, secrets or network endpoints are owned by this module.
"""
from __future__ import annotations

from datetime import datetime
import json
import re
from typing import Mapping

from .private_assessment import AssessmentLease

_KEYS = frozenset({
    "lease_id", "owner_id", "session_id", "attempt_id", "exercise_id",
    "checker_version", "expires_at", "expected_inputs",
    "expected_sha256", "object_version",
    "evidence_trust", "can_award_skill",
})
_INPUT_KEYS = frozenset(f"C{i}" for i in range(2, 10))


def _strict_lease(raw: object, owner: str, session: str,
                  attempt: str) -> AssessmentLease:
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except ValueError:
            raise ValueError("Invalid private processing lease") from None
    if not isinstance(raw, Mapping) or set(raw) != _KEYS:
        raise ValueError("Unexpected private processing lease")
    if (raw["owner_id"] != owner or raw["session_id"] != session
        or raw["attempt_id"] != attempt
        or raw["exercise_id"] != "excel-budget-total-v1"
        or type(raw["checker_version"]) is not int
        or raw["checker_version"] != 1
        or raw["evidence_trust"] != "unverified_checker_only"
        or raw["can_award_skill"] is not False):
        raise ValueError("Untrusted processing lease")
    try:
        expires_at = datetime.fromisoformat(raw["expires_at"])
    except (TypeError, ValueError):
        raise ValueError("Invalid expiry") from None
    if expires_at.tzinfo is None:
        raise ValueError("Expiry timezone required")
    if (not isinstance(raw["expected_sha256"], str) or
        re.fullmatch(r"[a-f0-9]{64}", raw["expected_sha256"]) is None or
        not isinstance(raw["object_version"], str) or
        re.fullmatch(r"[a-zA-Z0-9._:-]{1,256}", raw["object_version"]) is None):
        raise ValueError("Unsealed or invalid private workbook source")
    inputs = raw["expected_inputs"]
    if (not isinstance(inputs, Mapping) or set(inputs) != _INPUT_KEYS or
        any(type(v) is not int or v < 10 or v > 99 for v in inputs.values())):
        raise ValueError("Invalid private workbook inputs")
    return AssessmentLease(
        lease_id=raw["lease_id"], owner_id=owner,
        session_id=session, attempt_id=attempt,
        exercise_id="excel-budget-total-v1", checker_version=1,
        expires_at=expires_at,
        expected_inputs={cell: inputs[cell] for cell in sorted(_INPUT_KEYS)},
        expected_sha256=raw["expected_sha256"],
        object_version=raw["object_version"],
    )


class DbApiAttemptRepository:
    """Synchronous server-only adapter; an owned connection per request.

    On a successful claim, commit BEFORE any Storage or worker operation so
    the upload permission is frozen in the authoritative database. On invalid
    response, rollback the claim to avoid storing a malformed lease. The host
    must provide a transaction-safe, exclusive connection, not a shared global.
    """

    def __init__(self, connection) -> None:
        if (connection is None or
            getattr(connection, "autocommit", True) is not False):
            raise ValueError("Exclusive non-autocommit DB connection required")
        self._connection = connection

    def _execute(self, sql: str, args: tuple):
        cursor = self._connection.cursor()
        try:
            cursor.execute(sql, args)
            record = cursor.fetchone()
            return record[0] if record else None
        finally:
            cursor.close()

    def claim(self, owner_id: str, session_id: str,
              attempt_id: str, at) -> AssessmentLease | None:
        try:
            raw = self._execute(
                "SELECT software_learning_private.sl_claim_excel_processing(%s,%s,%s)",
                (attempt_id, owner_id, session_id),
            )
            lease = None if raw is None else _strict_lease(
                raw, owner_id, session_id, attempt_id)
            self._connection.commit()
            return lease
        except Exception:
            self._connection.rollback()
            raise

    def complete(self, lease_id: str, digest: str,
                 status: str, feedback: str) -> bool:
        try:
            result = self._execute(
                "SELECT software_learning_private.sl_complete_excel_processing(%s,%s,%s,%s)",
                (lease_id, digest, status, feedback),
            )
            self._connection.commit()
            return result is True
        except Exception:
            self._connection.rollback()
            raise

    def fail(self, lease_id: str) -> None:
        try:
            self._execute(
                "SELECT software_learning_private.sl_fail_excel_processing(%s)",
                (lease_id,),
            )
            self._connection.commit()
        except Exception:
            self._connection.rollback()
            raise
