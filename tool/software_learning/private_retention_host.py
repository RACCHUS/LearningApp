"""Source-only composition for an isolated private Excel retention runner.

No scheduler, HTTP endpoint, credential loader, Auth deletion, or external
side effects are enabled here. The calling internal scheduler must supply
its own identity, fresh DB connection, secrets, audit/alerting and network
policy after independent review. The workbook parser or upload broker must
never import or run this privileged deletion-only composition.
"""
from __future__ import annotations

from typing import Callable

from .private_retention_job import run_retention_once
from .supabase_private_storage import SupabasePrivateWorkbookStore


def run_trusted_excel_retention_once(
    *, project_ref: str, private_storage_key: str,
    connection_factory: Callable,
    authorized: bool = False, execute: bool = False,
    max_results: int = 20, prune_limit: int = 20,
) -> dict[str, object]:
    """One bounded sweep with GET/DELETE Storage capability, never POST.

    Explicit authorization is an internal host assertion, not a public
    request field. The underlying job validates the non-autocommit connection
    and reports only redacted counters, never global erasure completion.
    """
    # Reject invalid caller intent before even assembling the privileged
    # storage adapter. This does not substitute for hosting/secret isolation.
    if (type(authorized) is not bool or type(execute) is not bool
        or (execute and not authorized)):
        raise ValueError("Invalid retention execution intent")
    storage = SupabasePrivateWorkbookStore(
        project_ref=project_ref,
        secret_key=private_storage_key,
        allowed_methods=frozenset({"GET", "DELETE"}),
    )
    return run_retention_once(
        connection_factory=connection_factory, storage=storage,
        authorized=authorized, execute=execute, max_results=max_results,
        prune_limit=prune_limit,
    )
