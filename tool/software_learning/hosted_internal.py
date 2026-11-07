"""Disabled-by-default ASGI ingress for a private Excel assessment processor.

This is NOT a learner-facing upload endpoint. Production requires a separate
reviewed authenticated ingress that injects a server-held internal capability,
private TLS network routing, request limits, no public exposure, and a
privileged processor isolated from any Docker socket accessible by web code.

This transport does not receive or emit workbook bytes and never awards skills.
The trusted assessor must validate the learner JWT through Supabase Auth and
atomically claim the server-issued processing lease before reading Storage.
"""
from __future__ import annotations

import asyncio
import hmac
import json
import re
from typing import Callable, Mapping
from uuid import UUID

_MAX_REQUEST_BYTES = 1024
_MAX_MESSAGES = 8
_HOST = re.compile(r"\A[a-z0-9][a-z0-9.-]{0,252}\Z")
_GENERIC = {
    "status": "rejected",
    "feedback": "This assessment is temporarily unavailable.",
    "evidence_trust": "unverified_checker_only",
    "skill_award_enabled": False,
}


def _canonical_uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (TypeError, ValueError, AttributeError):
        return False


def _no_duplicate_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate request key")
        result[key] = value
    return result


class ExcelInternalASGI:
    """Small ASGI HTTP bridge; safe default is OFF.

    The assessor callable is provided by a separately reviewed host. It must
    create an exclusive DB connection, verify the bearer on the Auth server,
    and use the private single-use lease and sandboxed parser.
    """

    def __init__(
        self, *, assessor: Callable[[str, str], Mapping[str, object]],
        internal_key: str, allowed_host: str, enabled: bool = False,
    ) -> None:
        if not callable(assessor):
            raise ValueError("A trusted internal assessor is required")
        if (not isinstance(internal_key, str) or
            len(internal_key) < 24 or len(internal_key) > 512 or
            not internal_key.isascii()):
            raise ValueError("Internal gateway configuration required")
        if (not isinstance(allowed_host, str) or
            _HOST.fullmatch(allowed_host) is None or
            "." not in allowed_host or ".." in allowed_host):
            raise ValueError("A private expected host is required")
        if type(enabled) is not bool:
            raise ValueError("Enabled flag must be explicit")
        self._assessor = assessor
        self._key = internal_key
        self._host = allowed_host
        self._enabled = enabled

    async def _send(self, send, status: int, data: Mapping[str, object]) -> None:
        body = json.dumps(data, separators=(",", ":")).encode("utf-8")
        await send({
            "type": "http.response.start", "status": status,
            "headers": [
                (b"content-type", b"application/json"),
                (b"content-length", str(len(body)).encode()),
                (b"cache-control", b"no-store"),
                (b"x-content-type-options", b"nosniff"),
            ],
        })
        await send({"type": "http.response.body", "body": body})

    async def __call__(self, scope, receive, send):
        if scope.get("type") != "http":
            # No WebSocket or lifespan exposure from this surface.
            return
        if not self._enabled:
            await self._send(send, 503, _GENERIC)
            return
        if (scope.get("method") != "POST" or
            scope.get("path") != "/internal/v1/excel/assess"):
            await self._send(send, 404, _GENERIC)
            return

        raw_headers = scope.get("headers", ())
        if not isinstance(raw_headers, (list, tuple)) or len(raw_headers) > 48:
            await self._send(send, 403, _GENERIC)
            return
        headers = {}
        for name, value in raw_headers:
            if (not isinstance(name, bytes) or not isinstance(value, bytes) or
                len(name) > 128 or len(value) > 8192):
                await self._send(send, 403, _GENERIC)
                return
            lower = name.lower()
            if lower in headers:
                await self._send(send, 403, _GENERIC)
                return
            headers[lower] = value

        try:
            host = headers[b"host"].decode("ascii")
            key = headers[b"x-learningapp-internal-key"].decode("ascii")
            auth = headers[b"authorization"].decode("ascii")
        except (KeyError, UnicodeError):
            await self._send(send, 403, _GENERIC)
            return

        if (scope.get("scheme") != "https"
            or scope.get("query_string", b"") != b""
            or host != self._host
            or not hmac.compare_digest(key, self._key)
            or b"origin" in headers or b"cookie" in headers):
            await self._send(send, 403, _GENERIC)
            return
        if headers.get(b"content-type") != b"application/json":
            await self._send(send, 400, _GENERIC)
            return
        if not auth.startswith("Bearer ") or len(auth) > 8200:
            await self._send(send, 401, _GENERIC)
            return
        token = auth[7:]
        if not token or any(c.isspace() for c in token):
            await self._send(send, 401, _GENERIC)
            return

        raw_length = headers.get(b"content-length")
        if raw_length is not None:
            if (not raw_length.isdigit() or
                int(raw_length) > _MAX_REQUEST_BYTES):
                await self._send(send, 413, _GENERIC)
                return
        data = bytearray()
        for _ in range(_MAX_MESSAGES):
            message = await receive()
            if message.get("type") != "http.request":
                await self._send(send, 400, _GENERIC)
                return
            part = message.get("body", b"")
            if not isinstance(part, bytes) or len(data) + len(part) > _MAX_REQUEST_BYTES:
                await self._send(send, 413, _GENERIC)
                return
            data.extend(part)
            if message.get("more_body") is not True:
                break
        else:
            await self._send(send, 413, _GENERIC)
            return
        if raw_length is not None and int(raw_length) != len(data):
            await self._send(send, 400, _GENERIC)
            return

        try:
            parsed = json.loads(data.decode("utf-8", errors="strict"),
                                object_pairs_hook=_no_duplicate_pairs)
        except (ValueError, UnicodeError):
            await self._send(send, 400, _GENERIC)
            return
        if (not isinstance(parsed, dict) or
            set(parsed) != {"attempt_id"} or
            not _canonical_uuid(parsed["attempt_id"])):
            await self._send(send, 400, _GENERIC)
            return

        try:
            outcome = await asyncio.to_thread(
                self._assessor, token, parsed["attempt_id"],
            )
            if (not isinstance(outcome, Mapping) or
                outcome.get("status") not in ("pass", "fail", "inconclusive", "rejected")
                or outcome.get("evidence_trust") != "unverified_checker_only"
                or outcome.get("skill_award_enabled") is not False
                or not isinstance(outcome.get("feedback"), str)
                or len(outcome["feedback"]) > 300
                or set(outcome) != {
                    "status", "feedback", "evidence_trust", "skill_award_enabled"
                }):
                raise ValueError("Untrusted assessment outcome")
        except Exception:
            # Never leak bearer, internal key, workbook, DB or worker errors.
            await self._send(send, 503, _GENERIC)
            return
        await self._send(send, 200, dict(outcome))
