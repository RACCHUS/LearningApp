"""DB-API retention repository for trusted, default-off Excel cleanup jobs.

Only construct this adapter with an exclusively owned privileged connection.
The host supplies authentication, the Storage API adapter, a bounded scheduler
and secret isolation. No HTTP endpoint, cron trigger or live service is created.

Two-phase cleanup is intentional: commit upload freeze *before* touching
Storage, then delete the metadata only after the Storage API confirms absence.
Processing claims are only reclaimed after both expiry and the processing
lease timestamp exceed a 30-minute grace; no active lease is deleted.
"""
from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID


# Fail-closed when processing_claimed_at is null. Completion RPC
# already requires an unexpired attempt, and the grace protects slow workers.
_ELIGIBLE = (
    "(status IN ('issued','processed','failed') "
    "OR (status='processing' "
    "AND expires_at < now() - interval '30 minutes' "
    "AND processing_claimed_at < now() - interval '30 minutes'))"
)


@dataclass(frozen=True)
class RetentionRecord:
    owner_id: str
    attempt_id: str


def _uuid(raw: object) -> bool:
    if not isinstance(raw, str):
        return False
    try:
        return str(UUID(raw)) == raw
    except (TypeError, ValueError, AttributeError):
        return False


def _record(raw: object, *, owner: str | None = None,
            attempt: str | None = None) -> RetentionRecord:
    if (not isinstance(raw, (tuple, list)) or len(raw) != 2
        or not all(_uuid(item) for item in raw)
        or (owner is not None and raw[0] != owner)
        or (attempt is not None and raw[1] != attempt)):
        raise ValueError("Invalid retention record")
    return RetentionRecord(owner_id=raw[0], attempt_id=raw[1])


class DbApiRetentionRepository:
    """Server-only owner-bound records. No user-controlled SQL identifiers."""

    def __init__(self, connection):
        self._connection = connection

    def _query_one(self, sql: str, values: tuple):
        cursor = self._connection.cursor()
        try:
            cursor.execute(sql, values)
            return cursor.fetchone()
        finally:
            cursor.close()

    def find_owned(self, owner_id: str, attempt_id: str) -> RetentionRecord | None:
        if not _uuid(owner_id) or not _uuid(attempt_id):
            return None
        try:
            raw = self._query_one(
                "SELECT owner_id::text, id::text "
                "FROM public.software_learning_attempts "
                "WHERE owner_id=%s::uuid AND id=%s::uuid "
                "AND " + _ELIGIBLE,
                (owner_id, attempt_id),
            )
        except Exception:
            self._connection.rollback()
            raise
        return None if raw is None else _record(raw, owner=owner_id, attempt=attempt_id)

    def freeze_upload(self, owner_id: str, attempt_id: str) -> bool:
        if not _uuid(owner_id) or not _uuid(attempt_id):
            return False
        try:
            raw = self._query_one(
                "UPDATE public.software_learning_attempts "
                "SET upload_enabled=false "
                "WHERE owner_id=%s::uuid AND id=%s::uuid "
                "AND " + _ELIGIBLE + " "
                "RETURNING id::text",
                (owner_id, attempt_id),
            )
            # The host must not reuse this connection concurrently.
            self._connection.commit()
            return raw == (attempt_id,)
        except Exception:
            self._connection.rollback()
            raise

    def delete_attempt(self, owner_id: str, attempt_id: str) -> bool:
        if not _uuid(owner_id) or not _uuid(attempt_id):
            return False
        try:
            raw = self._query_one(
                "DELETE FROM public.software_learning_attempts "
                "WHERE owner_id=%s::uuid AND id=%s::uuid "
                "AND upload_enabled=false "
                "AND " + _ELIGIBLE + " "
                "RETURNING id::text",
                (owner_id, attempt_id),
            )
            self._connection.commit()
            return raw == (attempt_id,)
        except Exception:
            # Orphan-delete database trigger forbids a successful DELETE if
            # Storage still contains workbook bytes. Never bypass it here.
            self._connection.rollback()
            raise

    def list_expired(self, *, max_results: int = 50) -> list[RetentionRecord]:
        """Bounded candidates, not an automatic deletion authority.

        Only expired, non-processing attempts are returned. Scheduled jobs
        must respect workload quotas and privacy deletion policy.
        """
        if type(max_results) is not int or not 1 <= max_results <= 100:
            raise ValueError("Retention batch must be 1..100")
        cursor = self._connection.cursor()
        try:
            cursor.execute(
                "SELECT owner_id::text, id::text "
                "FROM public.software_learning_attempts "
                "WHERE expires_at < now() "
                "AND " + _ELIGIBLE + " "
                "ORDER BY expires_at,id LIMIT %s",
                (max_results,),
            )
            rows = cursor.fetchall()
        except Exception:
            self._connection.rollback()
            raise
        finally:
            cursor.close()
        if not isinstance(rows, list) or len(rows) > max_results:
            raise ValueError("Invalid retention result batch")
        return [_record(row) for row in rows]

    def list_owner_attempts(
        self, *, owner_id: str, max_results: int = 50,
    ) -> list[RetentionRecord]:
        """Include active leases so account deletion cannot hide blockers.

        A separate Auth-admin controller MUST revoke sessions first. This
        method never deletes records; the erasure coordinator refuses to
        declare completion until independent Storage prefix enumeration.
        """
        if not _uuid(owner_id) or type(max_results) is not int or not 1 <= max_results <= 100:
            raise ValueError("Invalid owner erasure query")
        cursor = self._connection.cursor()
        try:
            cursor.execute(
                "SELECT owner_id::text, id::text "
                "FROM public.software_learning_attempts "
                "WHERE owner_id=%s::uuid "
                "ORDER BY issued_at,id LIMIT %s",
                (owner_id, max_results),
            )
            rows = cursor.fetchall()
        except Exception:
            self._connection.rollback()
            raise
        finally:
            cursor.close()
        if not isinstance(rows, list) or len(rows) > max_results:
            raise ValueError("Invalid owner erasure records")
        return [_record(row, owner=owner_id) for row in rows]

    def prune_issuance_log(self, *, max_results: int = 50) -> int:
        """Delete only issuance timestamps older than 48h in bounded batches.

        The rolling issuance quota checks 24h, so 48h retains that window.
        Does not delete workbooks, attempts, or learning events.
        """
        if type(max_results) is not int or not 1 <= max_results <= 100:
            raise ValueError("Issuance log batch must be 1..100")
        try:
            result = self._query_one(
                "WITH old AS ("
                " SELECT id FROM software_learning_private.excel_issuance_log"
                " WHERE issued_at < now() - interval '48 hours'"
                " ORDER BY issued_at,id LIMIT %s FOR UPDATE SKIP LOCKED"
                "), removed AS ("
                " DELETE FROM software_learning_private.excel_issuance_log l"
                " USING old WHERE l.id=old.id RETURNING l.id"
                ") SELECT count(*)::integer FROM removed",
                (max_results,),
            )
            if (not isinstance(result, (tuple, list)) or
                len(result) != 1 or type(result[0]) is not int or
                not 0 <= result[0] <= max_results):
                raise ValueError("Unexpected issuance log prune result")
            self._connection.commit()
            return result[0]
        except Exception:
            self._connection.rollback()
            raise

