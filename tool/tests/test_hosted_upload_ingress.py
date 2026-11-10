"""Internal binary ingress test: disabled, size-bound, no direct public upload."""
from __future__ import annotations

import asyncio
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.hosted_upload_ingress import ExcelUploadASGI

HOST = "upload-broker.internal.example"
KEY = "test-private-capability-long-enough"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"
BLOB = b"PK\x03\x04" + b"synthetic workbook"
MIME = b"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


class Uploader:
    def __init__(self, *, fail=False, forge=False):
        self.calls = []
        self.fail, self.forge = fail, forge
    def __call__(self, token, attempt, data):
        self.calls.append((token, attempt, data))
        if self.fail:
            raise RuntimeError("secret upload URL")
        if self.forge:
            return {"status": "accepted", "evidence_trust": "server_verified"}
        return {"status": "accepted", "evidence_trust": "unverified_checker_only"}


def call(app, *, path="/internal/v1/excel/upload", method="POST",
         scheme="https", body=BLOB, key=KEY, host=HOST,
         token="user.valid.jwt", headers=(), chunks=None):
    standard = [
        (b"host", host.encode()),
        (b"x-learningapp-internal-key", key.encode()),
        (b"authorization", ("Bearer " + token).encode()),
        (b"x-upload-attempt-id", ATTEMPT.encode()),
        (b"content-type", MIME),
        (b"content-length", str(len(body)).encode()),
    ]
    standard.extend(headers)
    if chunks is None:
        messages = [{"type": "http.request", "body": body, "more_body": False}]
    else:
        messages = [
            {"type": "http.request", "body": piece,
             "more_body": i < len(chunks)-1}
            for i, piece in enumerate(chunks)
        ]
    sent = []
    async def receive():
        return messages.pop(0) if messages else {"type": "http.disconnect"}
    async def send(x):
        sent.append(x)
    scope = {
        "type": "http", "method": method, "path": path, "scheme": scheme,
        "query_string": b"", "headers": standard,
    }
    asyncio.run(app(scope, receive, send))
    status = next(x["status"] for x in sent if x["type"] == "http.response.start")
    raw = b"".join(x.get("body", b"") for x in sent if x["type"]=="http.response.body")
    return status, json.loads(raw)


def build(uploader=None, enabled=True):
    worker = uploader or Uploader()
    return ExcelUploadASGI(uploader=worker, allowed_host=HOST,
                           internal_key=KEY, enabled=enabled), worker


class UploadIngressTests(unittest.TestCase):
    def test_disabled_by_default_does_not_receive_or_process(self):
        worker = Uploader()
        gateway = ExcelUploadASGI(uploader=worker, allowed_host=HOST, internal_key=KEY)
        status, payload = call(gateway)
        self.assertEqual(status, 503)
        self.assertEqual(worker.calls, [])

    def test_valid_streamed_request_calls_only_one_broker(self):
        gateway, worker = build()
        status, payload = call(gateway, chunks=[BLOB[:4],BLOB[4:]])
        self.assertEqual(status, 200)
        self.assertEqual(payload, {"status":"accepted",
                                  "evidence_trust":"unverified_checker_only"})
        self.assertEqual(worker.calls, [("user.valid.jwt", ATTEMPT, BLOB)])

    def test_wrong_host_key_scheme_route_and_method_deny(self):
        gateway, worker = build()
        for options in ({"key":"bad"}, {"host":"evil.example"},
                        {"scheme":"http"}, {"method":"PUT"},
                        {"path":"/public/upload"}):
            with self.subTest(options=options):
                code, _ = call(gateway, **options)
                self.assertIn(code,(403,404))
        self.assertEqual(worker.calls, [])

    def test_cookies_origins_duplicates_and_transfer_encoding_denied(self):
        gateway, worker = build()
        for header in (
            (b"cookie",b"session=x"),(b"origin",b"https://attacker.invalid"),
            (b"authorization",b"Bearer forged"),(b"content-length",b"3"),
            (b"transfer-encoding",b"chunked"),
        ):
            with self.subTest(header=header):
                status, _ = call(gateway, headers=[header])
                self.assertEqual(status, 403)
        self.assertEqual(worker.calls, [])

    def test_malformed_asgi_header_and_body_event_never_invoke_broker(self):
        gateway, worker = build()
        async def exercise(header_bad=False):
            headers = [
                (b"host", HOST.encode()), (b"x-learningapp-internal-key",KEY.encode()),
                (b"authorization",b"Bearer jwt.token"),
                (b"x-upload-attempt-id",ATTEMPT.encode()),
                (b"content-type",MIME),
                (b"content-length",str(len(BLOB)).encode()),
            ]
            if header_bad:
                headers.append((b"broken",))
            sent=[]
            async def receive():
                return None
            async def send(x):
                sent.append(x)
            await gateway({
                "type":"http","method":"POST","path":"/internal/v1/excel/upload",
                "scheme":"https","query_string":b"","headers":headers,
            },receive,send)
            return next(x["status"] for x in sent if x["type"]=="http.response.start")
        self.assertEqual(asyncio.run(exercise(header_bad=True)),403)
        self.assertEqual(asyncio.run(exercise(header_bad=False)),400)
        self.assertEqual(worker.calls, [])

    def test_oversize_body_rejected_before_reading(self):
        gateway, worker = build()
        status, _ = call(gateway, body=b"x"* (10*1024*1024 + 1))
        self.assertEqual(status, 413)
        self.assertEqual(worker.calls, [])

    def test_malformed_or_truncated_body_never_calls_broker(self):
        gateway, worker = build()
        for data in (b"x"*len(BLOB), BLOB[:5], b""):
            with self.subTest(data=data):
                status, _ = call(gateway, body=BLOB,
                                 chunks=[data])
                self.assertIn(status,(400,413))
        self.assertEqual(worker.calls, [])

    def test_broker_errors_and_forged_verification_redacted(self):
        for worker in (Uploader(fail=True),Uploader(forge=True)):
            gateway, _ = build(worker)
            code, payload = call(gateway)
            self.assertEqual(code, 503)
            self.assertEqual(payload["status"], "rejected")
            self.assertNotIn("server_verified", str(payload))
            self.assertNotIn("secret upload", str(payload))

    def test_inflight_memory_limit_before_body_read(self):
        gateway, worker = build()
        self.assertTrue(gateway._slots.acquire(blocking=False))
        self.assertTrue(gateway._slots.acquire(blocking=False))
        try:
            code, _ = call(gateway)
        finally:
            gateway._slots.release()
            gateway._slots.release()
        self.assertEqual(code, 503)
        self.assertEqual(worker.calls, [])

    def test_bad_gateway_configuration_fails_closed(self):
        for kwargs in (
            {"internal_key": "", "allowed_host": HOST},
            {"internal_key": KEY, "allowed_host": "https://external.example"},
            {"internal_key": KEY, "allowed_host": HOST, "max_inflight": 1000},
        ):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                ExcelUploadASGI(uploader=Uploader(), enabled=True, **kwargs)


if __name__ == "__main__":
    unittest.main()
