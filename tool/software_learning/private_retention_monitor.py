"""Read-only, source-only Excel retention backlog monitor.

No network listener, scheduler, notifications, Auth deletion or workbook
read/write. A separately reviewed private operator must inject a fresh
exclusive read-capable PostgreSQL connection and route alert_required to
durable operations monitoring. Output is aggregate-only and cannot prove
actual Storage-byte deletion or global account erasure.
"""
from __future__ import annotations

from typing import Callable


def inspect_excel_retention_backlog(*, connection_factory: Callable) -> dict[str, object]:
    """Conservative pending-attempt indicators, not a compliance certificate.

    Target for raw workbook removal is *proposed* 24 hours after attempt
    expiry; a database attempt surviving beyond that point merits operator
    review even if Storage might already be empty. For processing leases,
    both expiry and claim time must exceed the 30-minute safety grace.
    """
    if not callable(connection_factory):
        raise ValueError("Private retention monitoring connection required")
    report: dict[str, object] = {
        "status": "unavailable",
        "overdue_attempt_records": 0,
        "stale_processing_leases": 0,
        "alert_required": True,
        "account_erasure_confirmed": False,
    }
    conn = None
    cursor = None
    try:
        conn = connection_factory()
        if (conn is None or not hasattr(conn, "close")
            or getattr(conn, "autocommit", True) is not False):
            return report
        cursor = conn.cursor()
        cursor.execute(
            "SELECT "
            "count(*) FILTER (WHERE expires_at < "
            "now() - interval '24 hours')::bigint, "
            "count(*) FILTER (WHERE status='processing' "
            "AND expires_at < now() - interval '30 minutes' "
            "AND processing_claimed_at < now() - interval '30 minutes')::bigint "
            "FROM public.software_learning_attempts",
            (),
        )
        row = cursor.fetchone()
        if (not isinstance(row, (tuple, list)) or len(row) != 2
            or any(type(v) is not int or v < 0 for v in row)):
            return report
        report["overdue_attempt_records"], report["stale_processing_leases"] = row
        overdue = row[0] > 0 or row[1] > 0
        report["status"] = "attention_required" if overdue else "clear_observed"
        report["alert_required"] = overdue
    except Exception:
        # Never return database messages, file names, tokens or IDs.
        report["status"] = "unavailable"
        report["alert_required"] = True
    finally:
        if cursor is not None:
            try:
                cursor.close()
            except Exception:
                report["status"] = "unavailable"
                report["alert_required"] = True
        if conn is not None:
            try:
                conn.close()
            except Exception:
                report["status"] = "unavailable"
                report["alert_required"] = True
    return report
