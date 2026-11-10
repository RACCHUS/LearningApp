"""Private ASGI ingress contract: disabled unless explicitly configured.

This tests the HTTP boundary only. Trusted identity and one-time processing
lease are verified in the separately tested assessment service.
"""
from __future__ import annotations

import asyncio
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.hosted_internal import ExcelInternalASGI

ATTEMPT = "ba430000-0000-4000-8000-000000000001"
KEY = "test-internal-key-for-ingress-only"
HOST = "excel-worker.internal.example"


class Assessor:
    def __init__(self, *, forged=False, error=False):
        self.calls = []
        self.forged = forged
        self.error = error

    def __call__(self, token, attempt):
        self.calls.append((token, attempt))
        if self.error:
            raise RuntimeError("private credentials must not leak")
        return {
            "status": "pass", "feedback": "Well done",
            "evidence_trust": "server_verified" if self.forged else "unverified_checker_only",
            "skill_award_enabled": self.forged,
        }


def run(app, *, method="POST", path="/internal/v1/excel/assess",
        host=HOST, key=KEY, bearer="user.jwt.value",
        content_type="application/json", body=None, headers=()):
    body = json.dumps({"attempt_id": ATTEMPT}).encode() if body is None else body
    incoming = [
        (b"host", host.encode()),
        (b"x-learningapp-internal-key", key.encode()),
        (b"authorization", f"Bearer {bearer}".encode()),
        (b"content-type", content_type.encode()),
    ]
    incoming.extend(headers)
    scope = {
        "type": "http", "method": method, "path": path,
        "headers": incoming, "query_string": b"", "scheme": "https",
    }
    sent = []
    chunks = [{"type": "http.request", "body": body, "more_body": False}]
    async def receive():
        return chunks.pop(0) if chunks else {"type": "http.disconnect"}
    async def send(message):
        sent.append(message)
    asyncio.run(app(scope, receive, send))
    start = next(x for x in sent if x["type"] == "http.response.start")
    payload = b"".join(x.get("body", b"") for x in sent
                       if x["type"] == "http.response.body")
    return start["status"], json.loads(payload)


class HostedInternalTests(unittest.TestCase):
    def app(self, assessor=None, enabled=True):
        return ExcelInternalASGI(
            assessor=assessor or Assessor(),
            internal_key=KEY, allowed_host=HOST, enabled=enabled,
        )

    def test_disabled_by_default_refuses_even_valid_requests(self):
        assessor = Assessor()
        app = ExcelInternalASGI(assessor=assessor,
                                internal_key=KEY, allowed_host=HOST)
        status, payload = run(app)
        self.assertEqual(status, 503)
        self.assertEqual(assessor.calls, [])
        self.assertNotIn("Well done", str(payload))

    def test_valid_internal_request_is_provisional_only(self):
        assessor = Assessor()
        status, payload = run(self.app(assessor))
        self.assertEqual(status, 200)
        self.assertEqual(assessor.calls, [("user.jwt.value", ATTEMPT)])
        self.assertEqual(payload["status"], "pass")
        self.assertEqual(payload["evidence_trust"], "unverified_checker_only")
        self.assertIs(payload["skill_award_enabled"], False)

    def test_wrong_private_key_or_host_never_calls_assessor(self):
        assessor = Assessor()
        for kw in ({"key": "wrong"}, {"host": "public.example"},
                   {"host": "excel-worker.internal.example:4443"}):
            with self.subTest(kw=kw):
                status, _ = run(self.app(assessor), **kw)
                self.assertEqual(status, 403)
        self.assertEqual(assessor.calls, [])

    def test_unknown_route_method_and_query_string_denied(self):
        assessor = Assessor()
        for kw in ({"path": "/public/excel/assess"},
                   {"method": "GET"}, {"method": "PUT"}):
            with self.subTest(kw=kw):
                status, _ = run(self.app(assessor), **kw)
                self.assertEqual(status, 404)
        self.assertEqual(assessor.calls, [])

    def test_browser_origin_and_cookie_refused(self):
        assessor = Assessor()
        for headers in (((b"origin", b"https://evil.test"),),
                        ((b"cookie", b"access_token=secret"),)):
            status, _ = run(self.app(assessor), headers=headers)
            self.assertEqual(status, 403)
        self.assertEqual(assessor.calls, [])

    def test_duplicate_authorization_and_private_key_refused(self):
        assessor = Assessor()
        for headers in (((b"authorization", b"Bearer other.jwt.token"),),
                        ((b"x-learningapp-internal-key", b"other"),)):
            status, _ = run(self.app(assessor), headers=headers)
            self.assertEqual(status, 403)
        self.assertEqual(assessor.calls, [])

    def test_unexpected_content_and_duplicate_json_keys_refused(self):
        assessor = Assessor()
        for kw in (
            {"content_type": "text/plain"},
            {"body": b'{"attempt_id":"bad","attempt_id":"' + ATTEMPT.encode() + b'"}'},
            {"body": b'{"attempt_id":"' + ATTEMPT.encode() + b'","owner_id":"other"}'},
            {"body": b'{"attempt_id":"../../../foo"}'},
            {"body": b"not json"},
        ):
            with self.subTest(kw=str(kw)[:70]):
                status, _ = run(self.app(assessor), **kw)
                self.assertIn(status, (400, 403))
        self.assertEqual(assessor.calls, [])

    def test_oversize_body_rejected_without_processing(self):
        assessor = Assessor()
        status, _ = run(self.app(assessor), body=b"X" * 2048)
        self.assertEqual(status, 413)
        self.assertEqual(assessor.calls, [])

    def test_forged_verified_result_is_fail_closed(self):
        status, payload = run(self.app(Assessor(forged=True)))
        self.assertEqual(status, 503)
        self.assertNotIn("server_verified", str(payload))
        self.assertNotIn("pass", str(payload))

    def test_assessor_exception_does_not_expose_secret(self):
        status, payload = run(self.app(Assessor(error=True)))
        self.assertEqual(status, 503)
        self.assertNotIn("private credentials", str(payload))

    def test_invalid_ingress_setup_fails_before_serving(self):
        for kw in (
            {"internal_key": "", "allowed_host": HOST},
            {"internal_key": KEY, "allowed_host": "https://evil.test"},
            {"internal_key": KEY, "allowed_host": ""},
        ):
            with self.subTest(kw=kw), self.assertRaises(ValueError):
                ExcelInternalASGI(assessor=Assessor(), enabled=True, **kw)


if __name__ == "__main__":
    unittest.main()
