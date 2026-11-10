"""Read-only owner-prefix probe. An empty result is NOT account-erasure proof.

Restricted to the dedicated private Excel bucket, and only callable from an
authorized, separately deployed erasure coordinator after session revocation.
"""
from __future__ import annotations

import json
from urllib.request import Request
from uuid import UUID

from .storage_retention import PRIVATE_BUCKET
from .supabase_private_storage import StorageFailure, _REF, _safe_fetch


def _canonical(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (ValueError, TypeError, AttributeError):
        return False


class SupabaseExcelOwnerInventory:
    """One-entry, bounded private Storage list query. Never deletes files."""

    def __init__(self, *, project_ref: str, secret_key: str, execute=None):
        if not isinstance(project_ref, str) or _REF.fullmatch(project_ref) is None:
            raise ValueError("Invalid inventory project")
        if (not isinstance(secret_key, str) or
            not secret_key.startswith("sb_secret_") or len(secret_key) > 512):
            raise ValueError("A privately held inventory secret is required")
        self._url = (f"https://{project_ref}.supabase.co/storage/v1/"
                     f"object/list/{PRIVATE_BUCKET}")
        self._key = secret_key
        self._execute = execute if execute is not None else _safe_fetch

    def probe(self, owner_id: str) -> str:
        """'objects_visible' blocks erasure; 'empty_observed' is inconclusive."""
        if not _canonical(owner_id):
            raise ValueError("Invalid inventory owner")
        body = json.dumps(
            {"prefix": owner_id + "/", "limit": 1, "offset": 0,
             "sortBy": {"column": "name", "order": "asc"}},
            separators=(",", ":"),
        ).encode()
        request = Request(
            self._url, data=body, method="POST",
            headers={
                "Authorization": "Bearer " + self._key, "apikey": self._key,
                "Content-Type": "application/json", "Accept": "application/json",
                "Cache-Control": "no-store",
            },
        )
        try:
            with self._execute(request, timeout=5) as response:
                if response.status != 200 or response.geturl() != self._url:
                    raise StorageFailure("Inventory temporarily unavailable")
                content_type = response.headers.get("Content-Type", "")
                if content_type.split(";", 1)[0].strip().lower() != "application/json":
                    raise StorageFailure("Inventory temporarily unavailable")
                length = response.headers.get("Content-Length")
                if length is not None and not 0 <= int(length) <= 4096:
                    raise StorageFailure("Inventory temporarily unavailable")
                payload = response.read(4097)
                if len(payload) > 4096:
                    raise StorageFailure("Inventory temporarily unavailable")
            records = json.loads(payload.decode("utf-8", errors="strict"))
            if not isinstance(records, list) or len(records) > 1:
                raise StorageFailure("Inventory temporarily unavailable")
            if not records:
                return "empty_observed"
            obj = records[0]
            name = obj.get("name") if isinstance(obj, dict) else None
            if (not isinstance(name, str) or not 0 < len(name) <= 256
                or any(ord(char) < 32 for char in name)):
                raise StorageFailure("Inventory temporarily unavailable")
            # Folder entries (id=None) also block account erasure.
            return "objects_visible"
        except Exception:
            raise StorageFailure("Inventory temporarily unavailable") from None
