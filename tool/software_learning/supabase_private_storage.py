"""Restricted Supabase Storage REST adapter for one private XLSX exercise.

Only the privileged backend may create this adapter; the Docker parser must
not receive the key, URL, or Storage network access. The endpoint, bucket,
object naming, response bounds, and methods are fixed. Never generate signed
upload/download links or expose the secret to a learner client.
"""
from __future__ import annotations

import json
import re
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener
from uuid import UUID

from .storage_retention import PRIVATE_BUCKET
from .xlsx_snapshot import MAX_UPLOAD_BYTES

_REF = re.compile(r"\A[a-z0-9]{20}\Z")
_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
_MAX_INFO_BYTES = 16 * 1024


class StorageFailure(RuntimeError):
    """Non-sensitive, caller-safe failure to access a private workbook."""


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _safe_fetch(request: Request, timeout: int):
    return build_opener(_NoRedirect()).open(request, timeout=timeout)


def _uuid(value: str) -> bool:
    try:
        return str(UUID(value)) == value
    except (TypeError, ValueError, AttributeError):
        return False


def _path(bucket: str, name: str) -> str:
    if bucket != PRIVATE_BUCKET or not isinstance(name, str):
        raise StorageFailure("Workbook storage unavailable")
    pieces = name.split("/")
    if (len(pieces) != 3 or pieces[2] != "workbook.xlsx" or
        not _uuid(pieces[0]) or not _uuid(pieces[1])):
        raise StorageFailure("Workbook storage unavailable")
    return name


class SupabasePrivateWorkbookStore:
    """Supabase Storage REST adapter, with fixed private bucket and path.

    Reads require a server-held secret key. Before production, independently
    verify Storage API version/ETag behavior on the deployed provider and
    ensure object versions are immutable during any in-flight signed upload.
    """

    def __init__(self, *, project_ref: str, secret_key: str,
                 execute=None, allowed_methods: frozenset[str] | None = None) -> None:
        if not isinstance(project_ref, str) or _REF.fullmatch(project_ref) is None:
            raise ValueError("Invalid configured Supabase project reference")
        if (not isinstance(secret_key, str) or
            not secret_key.startswith("sb_secret_") or
            len(secret_key) > 512):
            raise ValueError("A server-held Supabase secret key is required")
        if allowed_methods is None:
            # Cleanup jobs may use all operations, but upload and grading
            # hosts MUST explicitly pass their narrower method grants.
            allowed_methods = frozenset({"GET", "POST", "DELETE"})
        if (type(allowed_methods) is not frozenset or not allowed_methods
            or not allowed_methods.issubset({"GET", "POST", "DELETE"})):
            raise ValueError("Invalid private Storage operation scope")
        self._allowed_methods = allowed_methods
        self._base = f"https://{project_ref}.supabase.co/storage/v1"
        self._key = secret_key
        self._execute = execute if execute is not None else _safe_fetch

    def _url(self, method: str, bucket: str, name: str) -> str:
        fixed_path = _path(bucket, name)
        if method == "info":
            return f"{self._base}/object/info/{bucket}/{fixed_path}"
        if method == "object":
            return f"{self._base}/object/{bucket}/{fixed_path}"
        raise StorageFailure("Workbook storage unavailable")

    def _request(self, url: str, method: str, *,
                 allow_missing: bool = False, max_read: int = 0,
                 expected_mime: str | None = None,
                 data: bytes | None = None):
        if method not in self._allowed_methods:
            raise StorageFailure("Workbook storage unavailable")
        headers = {
            "Authorization": f"Bearer {self._key}",
            "apikey": self._key,
            "Accept": "application/json" if expected_mime is None else _MIME,
        }
        if method == "POST":
            if not isinstance(data, bytes):
                raise StorageFailure("Workbook storage unavailable")
            # Supabase Storage standard upload. No signed URL, no upsert.
            headers.update({"Content-Type": _MIME,
                            "Cache-Control": "no-store"})
            # Never send x-upsert at all: some Storage servers treat header
            # presence (even the string "false") as an upsert request.
        elif data is not None:
            raise StorageFailure("Workbook storage unavailable")
        request = Request(url, headers=headers, data=data, method=method)
        try:
            with self._execute(request, timeout=5) as response:
                if (response.geturl() != url or
                    response.status not in (
                    (200, 204) if method == "DELETE" else
                    (200, 201) if method == "POST" else (200,)
                )):
                    raise StorageFailure("Workbook storage unavailable")
                if expected_mime is not None:
                    content_type = response.headers.get("Content-Type", "")
                    if content_type.split(";", 1)[0].strip().lower() != expected_mime:
                        raise StorageFailure("Workbook storage unavailable")
                if max_read:
                    content_length = response.headers.get("Content-Length", "")
                    if content_length:
                        try:
                            if int(content_length) < 0 or int(content_length) > max_read:
                                raise StorageFailure("Workbook storage unavailable")
                        except ValueError:
                            raise StorageFailure("Workbook storage unavailable") from None
                    payload = response.read(max_read + 1)
                    if len(payload) > max_read:
                        raise StorageFailure("Workbook storage unavailable")
                    return payload
                return b""
        except HTTPError as exc:
            if allow_missing and exc.code == 404:
                return None
            raise StorageFailure("Workbook storage unavailable") from None
        except Exception:
            # Never expose backend credentials, request headers, object name,
            # raw workbook content, HTTP status body, or redirect destination.
            raise StorageFailure("Workbook storage unavailable") from None

    def stat(self, bucket: str, path: str) -> str | None:
        url = self._url("info", bucket, path)
        response = self._request(url, "GET", allow_missing=True,
                                 max_read=_MAX_INFO_BYTES)
        if response is None:
            return None
        try:
            data = json.loads(response.decode("utf-8", errors="strict"))
            metadata = data["metadata"]
            version = data["version"]
            size = metadata["size"]
            if (not isinstance(data, dict) or
                data.get("name") != path or
                data.get("bucket_id") != bucket or
                not isinstance(metadata, dict) or
                type(size) is not int or size < 0 or size > MAX_UPLOAD_BYTES or
                not isinstance(version, str) or not 1 <= len(version) <= 256 or
                not version.isascii()):
                raise StorageFailure("Workbook storage unavailable")
        except Exception:
            raise StorageFailure("Workbook storage unavailable") from None
        return version

    def download_limited(self, bucket: str, path: str, limit: int) -> bytes:
        url = self._url("object", bucket, path)
        if type(limit) is not int or not 0 < limit <= MAX_UPLOAD_BYTES + 1:
            raise StorageFailure("Workbook storage unavailable")
        return self._request(url, "GET", max_read=limit, expected_mime=_MIME)

    def create_only(self, bucket: str, path: str, blob: bytes) -> None:
        """Create one fixed-path XLSX using service credentials, with no upsert.

        Only a trusted broker holding a DB row lock may call this method.
        It intentionally does not retry ambiguous transport errors; the
        broker must preserve ambiguous bytes for later Storage-first
        retention recovery, never perform an unversioned inline DELETE.
        """
        url = self._url("object", bucket, path)
        if (not isinstance(blob, bytes) or
            not 4 <= len(blob) <= MAX_UPLOAD_BYTES or
            not blob.startswith(b"PK\x03\x04")):
            raise StorageFailure("Workbook storage unavailable")
        self._request(url, "POST", data=blob)

    def exists(self, bucket: str, path: str) -> bool:
        return self.stat(bucket, path) is not None

    def remove(self, bucket: str, path: str) -> None:
        url = self._url("object", bucket, path)
        self._request(url, "DELETE", allow_missing=True)
