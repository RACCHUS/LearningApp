"""Server-confirmed Supabase Auth user adapter for the Excel processing host.

The learner's JWT is checked against the project's Auth /user endpoint.
JWT claims are only treated as authenticated AFTER the Auth server confirms
the same user ID. Private processing claim additionally checks auth.sessions
for the original active session at processing time.

Never invoke this in the untrusted Docker parser; it requires network access.
"""
from __future__ import annotations

import base64
import json
import re
from typing import Callable
from urllib.request import HTTPRedirectHandler, Request, build_opener
from uuid import UUID

from .private_assessment import VerifiedIdentity

_REF = re.compile(r"\A[a-z0-9]{20}\Z")
_JWT = re.compile(r"\A[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\Z")
_MAX_RESPONSE = 16 * 1024
_MAX_JWT = 8192


def _uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (ValueError, TypeError, AttributeError):
        return False


def _claims(jwt: str) -> dict:
    if not isinstance(jwt, str) or not 10 <= len(jwt) <= _MAX_JWT:
        raise PermissionError("Authentication unavailable")
    if _JWT.fullmatch(jwt) is None:
        raise PermissionError("Authentication unavailable")
    payload = jwt.split(".")[1]
    try:
        data = json.loads(
            base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4))
        )
    except (UnicodeDecodeError, ValueError, base64.binascii.Error):
        raise PermissionError("Authentication unavailable") from None
    if not isinstance(data, dict):
        raise PermissionError("Authentication unavailable")
    if (not _uuid(data.get("sub"))
        or not _uuid(data.get("session_id"))
        or data.get("role") != "authenticated"
        or data.get("is_anonymous") is not False):
        raise PermissionError("Authentication unavailable")
    return data


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _safe_fetch(request: Request, timeout: int):
    # Redirects must never forward a learner bearer token to a new origin.
    return build_opener(_NoRedirect()).open(request, timeout=timeout)


class SupabaseUserGateway:
    """HTTP Auth verifier. Publishable API key only; never service-role key.

    project_ref is a trusted, configured Supabase project reference, not a
    request parameter. A custom self-host domain requires a separate reviewed
    adapter. The caller MUST still validate account/session for the claim in DB.
    """

    def __init__(
        self, *, project_ref: str, publishable_key: str,
        execute: Callable | None = None,
    ) -> None:
        if not isinstance(project_ref, str) or _REF.fullmatch(project_ref) is None:
            raise ValueError("Invalid configured Supabase project reference")
        if (not isinstance(publishable_key, str) or
            not publishable_key.startswith("sb_publishable_") or
            len(publishable_key) > 512):
            raise ValueError("A publishable project API key is required")
        self._url = f"https://{project_ref}.supabase.co/auth/v1/user"
        self._key = publishable_key
        self._execute = execute if execute is not None else _safe_fetch

    def verify(self, bearer_token: str) -> VerifiedIdentity:
        # Decode only for *syntactic* validation before the network call.
        # This is not signature validation, so never authorize on these
        # claims unless the Auth server confirms the token below.
        claims = _claims(bearer_token)
        request = Request(
            self._url,
            headers={
                "Authorization": f"Bearer {bearer_token}",
                "apikey": self._key,
                "Accept": "application/json",
            },
            method="GET",
        )
        try:
            with self._execute(request, timeout=5) as response:
                if response.geturl() != self._url or response.status != 200:
                    raise PermissionError("Authentication unavailable")
                data = response.read(_MAX_RESPONSE + 1)
            if len(data) > _MAX_RESPONSE:
                raise PermissionError("Authentication unavailable")
            user = json.loads(data.decode("utf-8", errors="strict"))
        except Exception:
            # Never include HTTP errors, response content, headers, or bearer.
            raise PermissionError("Authentication unavailable") from None

        if (not isinstance(user, dict) or
            not _uuid(user.get("id")) or
            user.get("id") != claims["sub"] or
            user.get("is_anonymous") is not False):
            raise PermissionError("Authentication unavailable")
        return VerifiedIdentity(
            owner_id=user["id"], session_id=claims["session_id"],
            permanent=True,
        )
