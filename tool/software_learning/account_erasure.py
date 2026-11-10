"""Service-only account-erasure continuation, always dry-run first.

Never initiate Auth-user deletion from here. A privileged controller must first
revoke every learner session and suspend new issuance. This function deletes
known owner-bound workbooks through the existing Storage-first coordinator.
It deliberately never reports that account erasure is globally complete:
a separate authoritative Storage prefix inventory and Auth deletion workflow
must confirm that no orphan objects or active leases remain.
"""
from __future__ import annotations

from uuid import UUID

from .storage_retention import erase_owned_attempt


def _uuid(raw: object) -> bool:
    if not isinstance(raw, str):
        return False
    try:
        return str(UUID(raw)) == raw
    except (ValueError, TypeError, AttributeError):
        return False


def sweep_owner_workbooks(
    *, owner_id: str, repository, storage,
    revocation_confirmed: bool = False,
    max_results: int = 20, execute: bool = False,
) -> dict[str, object]:
    """Purge known attempts after verified revocation, not an Auth delete API."""
    if not _uuid(owner_id):
        raise ValueError("Invalid account erasure subject")
    if revocation_confirmed is not True:
        raise ValueError("Authentication revocation must be confirmed")
    if type(max_results) is not int or not 1 <= max_results <= 100:
        raise ValueError("Account erasure batch size must be 1..100")
    if type(execute) is not bool:
        raise ValueError("Execution mode must be explicit")
    records = repository.list_owner_attempts(owner_id=owner_id, max_results=max_results)
    if not isinstance(records, list) or len(records) > max_results:
        raise ValueError("Invalid account erasure candidates")
    seen = set()
    for record in records:
        owner = getattr(record, "owner_id", None)
        attempt = getattr(record, "attempt_id", None)
        if owner != owner_id or not _uuid(attempt):
            raise ValueError("Foreign or malformed account erasure record")
        seen.add(attempt)
    results = {
        "candidates": len(seen), "erased": 0, "blocked": 0,
        "dry_run": not execute,
        "account_erasure_confirmed": False,
    }
    if not execute:
        return results
    for attempt in sorted(seen):
        status = erase_owned_attempt(
            owner_id=owner_id, attempt_id=attempt,
            repository=repository, storage=storage,
        )
        if status == "erased":
            results["erased"] += 1
        else:
            # A live processing lease, missing row, failed Storage delete,
            # or orphan requires investigation; never claim global erasure.
            results["blocked"] += 1
    return results


def probe_owner_workbook_objects(
    *, owner_id: str, inventory, revocation_confirmed: bool = False,
) -> dict[str, object]:
    """Observe owner Storage prefix after revocation, never declare deletion."""
    if not _uuid(owner_id):
        raise ValueError("Invalid inventory owner")
    if revocation_confirmed is not True:
        raise ValueError("Authentication revocation must be confirmed")
    try:
        result = inventory.probe(owner_id)
    except Exception:
        result = "unavailable"
    if result not in ("objects_visible", "empty_observed"):
        result = "unavailable"
    return {"owner_prefix_inventory": result, "account_erasure_confirmed": False}
