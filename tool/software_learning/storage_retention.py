"""Service-only, default-off Excel workbook erasure coordination.

The caller MUST authenticate the user or use an authorized retention worker.
Repository and Storage interfaces are trusted adapters supplied by the host.
This module has no network, cloud credentials, UI, evidence writer or AI client.

Order: freeze uploads, remove bytes using the Storage API, verify absence,
then delete database metadata. Never delete storage.objects rows with SQL.

Release blocker: hosted orchestration must drain in-flight uploads and avoid
signed upload URLs before this can guarantee no object reappears after cleanup.
"""
from __future__ import annotations

from typing import Protocol
from uuid import UUID

PRIVATE_BUCKET = "learningapp-excel-private"


class AttemptInfo(Protocol):
    owner_id: str
    attempt_id: str


class AttemptRepository(Protocol):
    def find_owned(self, owner_id: str, attempt_id: str) -> AttemptInfo | None: ...
    def freeze_upload(self, owner_id: str, attempt_id: str) -> bool: ...
    def delete_attempt(self, owner_id: str, attempt_id: str) -> bool: ...


class PrivateObjectStore(Protocol):
    def exists(self, bucket: str, path: str) -> bool: ...
    def remove(self, bucket: str, path: str) -> None: ...


def _canonical_uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (TypeError, ValueError, AttributeError):
        return False


def erase_owned_attempt(
    *, owner_id: str, attempt_id: str,
    repository: AttemptRepository, storage: PrivateObjectStore,
) -> str:
    """Return erased, not_found, invalid, or retry; never expose file data.

    owner_id MUST come from verified auth or a privileged scheduled job,
    not from a client's arbitrary request field. A repository lookup MUST
    bind the exact owner and attempt and must not trust client-supplied paths.
    """
    if not _canonical_uuid(owner_id) or not _canonical_uuid(attempt_id):
        return "invalid"
    try:
        owned = repository.find_owned(owner_id, attempt_id)
    except Exception:
        return "retry"
    if owned is None:
        return "not_found"
    if owned.owner_id != owner_id or owned.attempt_id != attempt_id:
        return "retry"

    try:
        if not repository.freeze_upload(owner_id, attempt_id):
            return "retry"
        path = f"{owner_id}/{attempt_id}/workbook.xlsx"
        if storage.exists(PRIVATE_BUCKET, path):
            storage.remove(PRIVATE_BUCKET, path)
            if storage.exists(PRIVATE_BUCKET, path):
                return "retry"
        if not repository.delete_attempt(owner_id, attempt_id):
            return "retry"
    except Exception:
        return "retry"
    return "erased"
