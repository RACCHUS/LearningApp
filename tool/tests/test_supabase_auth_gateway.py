"""Live Supabase Auth validation adapter tests (all network responses mocked)."""
from __future__ import annotations

import base64
import io
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.supabase_auth_gateway import SupabaseUserGateway

OWNER = "ba410000-0000-4000-8000-000000000001"
SESSION = "ba420000-0000-4000-8000-000000000001"
REF = "xzvkdwebtbxlrxagtzlv"


def token(**overrides):
    claims = {
        "sub": OWNER, "session_id": SESSION,
        "role": "authenticated", "is_anonymous": False,
    }
    claims.update(overrides)
    head = base64.urlsafe_b64encode(b'{"alg":"HS256"}').rstrip(b"=").decode()
    payload = base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
    return f"{head}.{payload}.fakesignature"


class Response:
    def __init__(self, url, value, status=200):
        self.url = url
        self.payload = value
        self.status = status
        self.stream = io.BytesIO(value)
    def __enter__(self):
        return self
    def __exit__(self, exc_type, exc, tb):
        return False
    def read(self, n):
        return self.stream.read(n)
    def geturl(self):
        return self.url


class HTTP:
    def __init__(self, user=None, response=None, fail=None):
        self.calls = []
        self.fail = fail
        self.user = user if user is not None else {"id": OWNER, "is_anonymous": False}
        self.response = response
    def __call__(self, request, timeout):
        self.calls.append((request, timeout))
        if self.fail:
            raise self.fail
        payload = self.response if self.response is not None else json.dumps(self.user).encode()
        return Response(request.full_url, payload)


class SupabaseAuthTests(unittest.TestCase):
    def api(self, http=None):
        http = http or HTTP()
        return SupabaseUserGateway(project_ref=REF, publishable_key="sb_publishable_test", execute=http), http

    def test_server_confirmed_user_and_matching_verified_claims(self):
        api, http = self.api()
        jwt = token()
        principal = api.verify(jwt)
        self.assertEqual(principal.owner_id, OWNER)
        self.assertEqual(principal.session_id, SESSION)
        self.assertTrue(principal.permanent)
        req, timeout = http.calls[0]
        self.assertEqual(req.full_url, f"https://{REF}.supabase.co/auth/v1/user")
        self.assertEqual(req.get_method(), "GET")
        self.assertEqual(req.get_header("Authorization"), f"Bearer {jwt}")
        self.assertEqual(req.get_header("Apikey"), "sb_publishable_test")
        self.assertEqual(timeout, 5)

    def test_rejects_guest_user_even_with_claims(self):
        for unsafe in ({"id": OWNER, "is_anonymous": True},
                       {"id": OWNER}, {"id": "not_uuid", "is_anonymous": False}):
            api, _ = self.api(HTTP(user=unsafe))
            with self.assertRaises(PermissionError):
                api.verify(token())

    def test_rejects_sub_mismatch_and_guest_claim(self):
        for unsafe in (
            {"sub": "ba410000-0000-4000-8000-000000000002"},
            {"session_id": "bad"},
            {"is_anonymous": True},
            {"role": "service_role"},
        ):
            api, _ = self.api()
            with self.subTest(unsafe=unsafe), self.assertRaises(PermissionError):
                api.verify(token(**unsafe))

    def test_no_network_on_malformed_token(self):
        for malformed in ("", "apikey", "a.b", "abc.def.ghi", "a b.c.d",
                          "x" * 9000):
            api, http = self.api()
            with self.subTest(malformed=malformed[:20]), self.assertRaises(PermissionError):
                api.verify(malformed)
            self.assertEqual(http.calls, [])

    def test_does_not_accept_remote_failure_or_secret_in_exception(self):
        api, http = self.api(HTTP(fail=RuntimeError("secret bearer leaked")))
        with self.assertRaises(PermissionError) as cm:
            api.verify(token())
        self.assertNotIn("secret", str(cm.exception))

    def test_response_size_cap_and_malformed_response(self):
        for raw in (b"x" * 16385, b"null", b"[]", b"\xff", b"{"):
            api, _ = self.api(HTTP(response=raw))
            with self.subTest(size=len(raw)), self.assertRaises(PermissionError):
                api.verify(token())

    def test_custom_project_domains_not_accepted_as_endpoint(self):
        for ref in ("https://evil.example", "example.com", "test/a", "", "..", REF.upper()):
            with self.assertRaises(ValueError):
                SupabaseUserGateway(project_ref=ref,publishable_key="sb_publishable_test",
                                    execute=HTTP())

    def test_redirected_user_response_is_rejected(self):
        class RedirectHTTP(HTTP):
            def __call__(self, request, timeout):
                self.calls.append((request, timeout))
                return Response("https://evil.example/user", json.dumps(self.user).encode())
        api, _ = self.api(RedirectHTTP())
        with self.assertRaises(PermissionError):
            api.verify(token())

if __name__ == "__main__":
    unittest.main()
