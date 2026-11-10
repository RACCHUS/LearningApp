"""Dry-run-first bounded retention coordinator for the Excel pilot.

This is NOT a cron service or production entrypoint. The calling host must
supply an isolated privileged DB connection, a private Storage API adapter,
authorization to perform system expiry cleanup and auditable scheduling.
It cannot issue upload grants, read workbook contents, grade, or award skills.
"""
from __future__ import annotations

from uuid import UUID
from .storage_retention import erase_owned_attempt


def _uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (TypeError, ValueError, AttributeError):
        return False


def sweep_expired_attempts(
    *, repository, storage, max_results: int = 20, execute: bool = False,
) -> dict[str, int | bool]:
    """Count eligible rows, or explicitly erase them with bounded work.

    Database list_expired must return only eligible expired rows (never
    processing). Erasure rechecks account ID and attempt ownership and freezes
    uploads. Object deletion MUST precede metadata deletion.
    """
    if type(max_results) is not int or not 1 <= max_results <= 100:
        raise ValueError("A safe retention batch size is required")
    if type(execute) is not bool:
        raise ValueError("Execution mode must be explicit")

    rows = repository.list_expired(max_results=max_results)
    if not isinstance(rows, list) or len(rows) > max_results:
        raise ValueError("Unexpected retention candidate batch")

    distinct: set[tuple[str, str]] = set()
    for row in rows:
        owner = getattr(row, "owner_id", None)
        attempt = getattr(row, "attempt_id", None)
        if not _uuid(owner) or not _uuid(attempt):
            raise ValueError("Malformed retention candidate")
        distinct.add((owner, attempt))
    output: dict[str, int | bool] = {
        "candidates": len(distinct), "erased": 0, "retry": 0,
        "dry_run": not execute,
    }
    if not execute:
        return output

    for owner, attempt in sorted(distinct):
        outcome = erase_owned_attempt(
            owner_id=owner, attempt_id=attempt,
            repository=repository, storage=storage,
        )
        if outcome == "erased":
            output["erased"] = int(output["erased"]) + 1
        elif outcome == "retry":
            output["retry"] = int(output["retry"]) + 1
        elif outcome != "not_found":
            # Malformed/outdated candidates are not success.
            output["retry"] = int(output["retry"]) + 1
    return output
