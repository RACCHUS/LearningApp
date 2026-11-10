"""Disabled-by-default, internal-only ASGI upload ingress (no Docker).

DO NOT route this directly to the Internet. A reviewed private TLS gateway
must authenticate the server-held internal credential and rate-limit requests.
This handler accepts exactly one binary XLSX and forwards it only to the
dedicated upload broker, never to the parser or a user-controlled Storage URL.
"""
from __future__ import annotations

import asyncio
import hmac
import json
import re
import threading
from typing import Callable, Mapping
from uuid import UUID

_MIME = b"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
_MAX_BYTES = 10 * 1024 * 1024
_HOST = re.compile(r"\A[a-z0-9][a-z0-9.-]{0,252}\Z")
_GENERIC = {"status": "rejected", "evidence_trust": "unverified_checker_only"}


def _uuid(x: object) -> bool:
    if not isinstance(x, str):
        return False
    try:
        return str(UUID(x)) == x
    except (TypeError, ValueError, AttributeError):
        return False


class ExcelUploadASGI:
    def __init__(self, *, uploader: Callable[[str, str, bytes], Mapping[str, str]],
                 internal_key: str, allowed_host: str,
                 enabled: bool = False, max_inflight: int = 2) -> None:
        if (not callable(uploader) or not isinstance(internal_key, str) or
            not 24 <= len(internal_key) <= 512 or not internal_key.isascii()
            or not isinstance(allowed_host, str) or
            _HOST.fullmatch(allowed_host) is None or
            "." not in allowed_host or ".." in allowed_host or
            type(enabled) is not bool or
            type(max_inflight) is not int or not 1 <= max_inflight <= 8):
            raise ValueError("Invalid internal upload gateway configuration")
        self._uploader = uploader
        self._key = internal_key
        self._host = allowed_host
        self._enabled = enabled
        self._slots = threading.BoundedSemaphore(max_inflight)

    async def _send(self, send, status: int, payload: Mapping[str, str]):
        blob = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        await send({
            "type": "http.response.start", "status": status,
            "headers": [
                (b"content-type", b"application/json"),
                (b"content-length", str(len(blob)).encode()),
                (b"cache-control", b"no-store"),
                (b"x-content-type-options", b"nosniff"),
            ],
        })
        await send({"type": "http.response.body", "body": blob})

    async def __call__(self, scope, receive, send):
        if scope.get("type") != "http":
            return
        if not self._enabled:
            await self._send(send, 503, _GENERIC)
            return
        if (scope.get("method") != "POST" or
            scope.get("path") != "/internal/v1/excel/upload"):
            await self._send(send, 404, _GENERIC)
            return
        if not self._slots.acquire(blocking=False):
            await self._send(send, 503, _GENERIC)
            return
        try:
            await self._handle(scope, receive, send)
        finally:
            self._slots.release()

    async def _handle(self, scope, receive, send):
        raw = scope.get("headers", ())
        if not isinstance(raw, (list, tuple)) or len(raw) > 48:
            await self._send(send, 403, _GENERIC)
            return
        headers = {}
        for item in raw:
            if not isinstance(item, (tuple, list)) or len(item) != 2:
                await self._send(send, 403, _GENERIC)
                return
            key, val = item
            if (not isinstance(key, bytes) or not isinstance(val, bytes) or
                len(key) > 128 or len(val) > 8192):
                await self._send(send, 403, _GENERIC)
                return
            key = key.lower()
            if key in headers:
                await self._send(send, 403, _GENERIC)
                return
            headers[key] = val
        try:
            host = headers[b"host"].decode("ascii")
            internal_key = headers[b"x-learningapp-internal-key"].decode("ascii")
            authorization = headers[b"authorization"].decode("ascii")
            attempt = headers[b"x-upload-attempt-id"].decode("ascii")
            declared = headers[b"content-length"].decode("ascii")
        except (KeyError, UnicodeError):
            await self._send(send, 403, _GENERIC)
            return
        if (scope.get("scheme") != "https" or
            scope.get("query_string", b"") != b"" or
            host != self._host or
            not hmac.compare_digest(internal_key, self._key) or
            b"origin" in headers or b"cookie" in headers or
            b"transfer-encoding" in headers or
            headers.get(b"content-type") != _MIME or
            not authorization.startswith("Bearer ") or
            len(authorization) > 8200 or
            any(c.isspace() for c in authorization[7:]) or
            not authorization[7:] or
            not _uuid(attempt)):
            await self._send(send, 403, _GENERIC)
            return
        if not declared.isascii() or not declared.isdecimal():
            await self._send(send, 400, _GENERIC)
            return
        size = int(declared)
        if not 4 <= size <= _MAX_BYTES:
            await self._send(send, 413, _GENERIC)
            return

        # Limit in-flight memory: the semaphore was acquired BEFORE body read.
        # A deployment must ALSO enforce upstream timeouts and connection limits.
        body = bytearray()
        for _ in range(1024):
            try:
                part = await asyncio.wait_for(receive(), timeout=15)
            except Exception:
                await self._send(send, 400, _GENERIC)
                return
            if not isinstance(part, dict) or part.get("type") != "http.request":
                await self._send(send, 400, _GENERIC)
                return
            data = part.get("body", b"")
            if not isinstance(data, bytes) or len(body) + len(data) > size:
                await self._send(send, 413, _GENERIC)
                return
            body.extend(data)
            if part.get("more_body") is not True:
                break
        else:
            await self._send(send, 413, _GENERIC)
            return
        if len(body) != size or not body.startswith(b"PK\x03\x04"):
            await self._send(send, 400, _GENERIC)
            return
        try:
            response = await asyncio.to_thread(
                self._uploader, authorization[7:], attempt, bytes(body))
            if (not isinstance(response, Mapping) or
                dict(response) != {
                    "status": "accepted",
                    "evidence_trust": "unverified_checker_only",
                }):
                raise ValueError("Upload not sealed")
        except Exception:
            await self._send(send, 503, _GENERIC)
            return
        await self._send(send, 200, {
            "status": "accepted", "evidence_trust": "unverified_checker_only",
        })
