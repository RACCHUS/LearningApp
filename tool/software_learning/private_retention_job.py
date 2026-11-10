"""Disabled-by-default, one-shot Excel retention service composition.

No scheduler, listener, secret loader, auth-user deletion, or file content
processing lives here. An independently authorized internal controller must
supply a fresh exclusive non-autocommit DB connection and a privileged Storage
DELETE adapter. Dry-run is the default; the caller must affirm authorization
before any destructive work. Never use from a learner-facing process.
"""
from __future__ import annotations

from typing import Callable

from .private_retention_db import DbApiRetentionRepository
from .retention_batch import sweep_expired_attempts


def run_retention_once(
    *, connection_factory: Callable, storage,
    authorized: bool = False, execute: bool = False,
    max_results: int = 20, prune_limit: int = 20,
) -> dict[str, object]:
    """Bounded cleanup and quota-log pruning; redacted counters only.

    This function intentionally cannot schedule itself or certify deletion.
    Any failed deletion leaves its DB metadata for a subsequent authorized
    sweep, and must be surfaced to an external alerting controller.
    A full batch is not proof of exhaustion; dry-runs are previews only.
    """
    if (type(authorized) is not bool or type(execute) is not bool
        or (execute and not authorized)
        or type(max_results) is not int or not 1 <= max_results <= 100
        or type(prune_limit) is not int or not 1 <= prune_limit <= 100
        or not callable(connection_factory)):
        raise ValueError("Invalid private retention job configuration")
    result: dict[str, object] = {
        "status": "unavailable",
        "dry_run": not execute,
        "candidates": 0,
        "erased": 0,
        "retry": 0,
        "issuance_records_pruned": 0,
        "account_erasure_confirmed": False,
    }
    conn = None
    try:
        conn = connection_factory()
        if (conn is None or not hasattr(conn, "close")
            or getattr(conn, "autocommit", None) is not False):
            return result
        repository = DbApiRetentionRepository(conn)
        counts = sweep_expired_attempts(
            repository=repository, storage=storage,
            max_results=max_results, execute=execute,
        )
        for key in ("candidates", "erased", "retry"):
            value = counts[key]
            if type(value) is not int or not 0 <= value <= max_results:
                return result
            result[key] = value
        if execute:
            # Never prune issuance quota logs if the expiry sweep could not
            # even enumerate candidates. These logs preserve the 24h quota.
            pruned = repository.prune_issuance_log(max_results=prune_limit)
            if type(pruned) is not int or not 0 <= pruned <= prune_limit:
                raise ValueError("Invalid issuance prune count")
            result["issuance_records_pruned"] = pruned
            if result["retry"]:
                result["status"] = "retry_required"
            elif result["candidates"] == max_results or pruned == prune_limit:
                # Reaching either page limit means another page may exist.
                # Never report full completion from a truncated scan.
                result["status"] = "more_pending"
            else:
                result["status"] = "complete"
        else:
            # No files or quota records were deleted in a dry run.
            result["status"] = "preview_only"
    except Exception:
        # Database errors, credentials, owner IDs and file names never appear
        # in outputs. Keep any prior retry counts; this is not a success.
        result["status"] = "unavailable"
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                result["status"] = "unavailable"
    return result
