"""Restricted private workbook Storage API adapter tests (mocked HTTPS)."""
from __future__ import annotations

import io
import json
from pathlib import Path
import sys
import unittest
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.supabase_private_storage import (
    SupabasePrivateWorkbookStore, StorageFailure,
)
from software_learning.storage_retention import PRIVATE_BUCKET

REF = "xzvkdwebtbxlrxagtzlv"
OWNER = "ba410000-0000-4000-8000-000000000001"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"
PATH = f"{OWNER}/{ATTEMPT}/workbook.xlsx"
VERSION = "object-version-1"
MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


class Response:
    def __init__(self, url, payload, status=200, content_type="application/json"):
        self.url = url
        self.status = status
        self.headers = {
            "Content-Type": content_type,
            "Content-Length": str(len(payload)),
        }
        self._stream = io.BytesIO(payload)
        self.was_read = False

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def geturl(self):
        return self.url

    def read(self, limit):
        self.was_read = True
        return self._stream.read(limit)


class FakeAPI:
    def __init__(self, *, blob=b"test workbook",
                 info=None, redirected=False, not_found=False,
                 failure=None, content_type=MIME):
        self.blob = blob
        self.info = info if info is not None else {
            "version": VERSION, "bucket_id": PRIVATE_BUCKET,
            "name": PATH, "metadata": {"size": len(blob)},
        }
        self.redirected = redirected
        self.not_found = not_found
        self.failure = failure
        self.content_type = content_type
        self.requests = []

    def __call__(self, request, timeout):
        self.requests.append((request, timeout))
        if self.failure is not None:
            raise self.failure
        if self.not_found:
            raise HTTPError(request.full_url, 404, "not found", {}, None)
        response_url = "https://evil.invalid/redirect" if self.redirected else request.full_url
        if "/object/info/" in request.full_url:
            return Response(response_url, json.dumps(self.info).encode())
        if request.get_method() == "DELETE":
            self.not_found = True
            return Response(response_url, b"", 204)
        if request.get_method() == "GET":
            return Response(response_url, self.blob, content_type=self.content_type)
        raise RuntimeError("unrecognized request")


class PrivateStorageTests(unittest.TestCase):
    def store(self, http=None):
        http = http or FakeAPI()
        return SupabasePrivateWorkbookStore(
            project_ref=REF, secret_key="sb_secret_test", execute=http,
        ), http

    def test_private_metadata_download_and_api_deletion(self):
        store, http = self.store()
        self.assertEqual(store.stat(PRIVATE_BUCKET, PATH), VERSION)
        self.assertEqual(store.download_limited(PRIVATE_BUCKET, PATH, 10485761),
                         b"test workbook")
        store.remove(PRIVATE_BUCKET, PATH)
        self.assertIsNone(store.stat(PRIVATE_BUCKET, PATH))
        self.assertEqual([r.get_method() for r, t in http.requests],
                         ["GET", "GET", "DELETE", "GET"])
        self.assertTrue(all(t == 5 for r, t in http.requests))
        self.assertTrue(all(r.full_url.startswith(f"https://{REF}.supabase.co/storage/v1/")
                            for r, t in http.requests))
        self.assertEqual(http.requests[0][0].get_header("Authorization"),
                         "Bearer sb_secret_test")

    def test_create_only_post_has_no_upsert_and_forced_xlsx_mime(self):
        class UploadHTTP(FakeAPI):
            def __call__(self, request, timeout):
                if request.get_method() == "POST":
                    self.requests.append((request, timeout))
                    self.blob = request.data
                    self.info["metadata"]["size"] = len(self.blob)
                    return Response(request.full_url, b'{"Key":"accepted"}',
                                    status=201)
                return super().__call__(request, timeout)

        store, http = self.store(UploadHTTP())
        store.create_only(PRIVATE_BUCKET, PATH, b"PK\x03\x04" + b"safe")
        request = http.requests[0][0]
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(request.get_header("Content-type"), MIME)
        self.assertEqual(request.get_header("X-upsert"), "false")
        self.assertEqual(request.data, b"PK\\x03\\x04safe")
        self.assertEqual(store.stat(PRIVATE_BUCKET, PATH), VERSION)

    def test_create_only_rejects_oversized_or_bad_paths_without_network(self):
        store, http = self.store()
        for path, payload in (
            (PATH, b""),
            (PATH, b"x" * (10 * 1024 * 1024 + 1)),
            (f"{OWNER}/../{ATTEMPT}/workbook.xlsx", b"PK\x03\x04"),
        ):
            with self.subTest(path=path, size=len(payload)), self.assertRaises(StorageFailure):
                store.create_only(PRIVATE_BUCKET, path, payload)
        self.assertEqual(http.requests, [])

    def test_create_only_does_not_retry_conflicts_or_redirects(self):
        store, http = self.store(FakeAPI(failure=HTTPError("https://host",409,"exists",{},None)))
        with self.assertRaises(StorageFailure):
            store.create_only(PRIVATE_BUCKET, PATH, b"PK\\x03\\x04okay")
        self.assertEqual(len(http.requests), 1)

    def test_foreign_bucket_and_path_rejected_before_network(self):
        store, http = self.store()
        for bucket, path in (
            ("public", PATH), (PRIVATE_BUCKET, "../" + PATH),
            (PRIVATE_BUCKET, f"{OWNER}/{ATTEMPT}/other.xlsx"),
            (PRIVATE_BUCKET, f"{OWNER.upper()}/{ATTEMPT}/workbook.xlsx"),
            (PRIVATE_BUCKET, "http://evil/workbook.xlsx"),
            (PRIVATE_BUCKET, ""),
        ):
            with self.subTest(path=path), self.assertRaises(StorageFailure):
                store.stat(bucket, path)
        self.assertEqual(http.requests, [])

    def test_missing_objects_allow_idempotent_cleanup(self):
        store, http = self.store(FakeAPI(not_found=True))
        self.assertIsNone(store.stat(PRIVATE_BUCKET, PATH))
        store.remove(PRIVATE_BUCKET, PATH)
        with self.assertRaises(StorageFailure):
            store.download_limited(PRIVATE_BUCKET, PATH, 100)
        self.assertEqual(len(http.requests), 3)

    def test_unrecognized_or_oversized_object_metadata_rejected(self):
        for info in (
            {"version": "v1", "bucket_id": "elsewhere", "name": PATH,
             "metadata": {"size": 10}},
            {"version": "", "bucket_id": PRIVATE_BUCKET, "name": PATH,
             "metadata": {"size": 10}},
            {"version": VERSION, "bucket_id": PRIVATE_BUCKET, "name": PATH,
             "metadata": {"size": 10485761}},
            {"version": VERSION, "bucket_id": PRIVATE_BUCKET, "name": PATH,
             "metadata": {"size": -1}},
            {"version": VERSION, "bucket_id": PRIVATE_BUCKET,
             "name": "wrong.xlsx", "metadata": {"size": 10}},
        ):
            with self.subTest(info=info):
                store, _ = self.store(FakeAPI(info=info))
                with self.assertRaises(StorageFailure):
                    store.stat(PRIVATE_BUCKET, PATH)

    def test_bounded_download_rejects_payload_and_mime_variants(self):
        for blob, mime in (
            (b"X" * 102, MIME),
            (b"abc", "text/html"),
            (b"abc", "application/octet-stream"),
        ):
            store, _ = self.store(FakeAPI(blob=blob, content_type=mime))
            with self.subTest(size=len(blob),mime=mime), self.assertRaises(StorageFailure):
                store.download_limited(PRIVATE_BUCKET, PATH, 101)

    def test_redirect_and_transport_exception_do_not_reveal_secrets(self):
        for http in (FakeAPI(redirected=True),
                     FakeAPI(failure=RuntimeError("private sb_secret_test leak"))):
            store, _ = self.store(http)
            with self.assertRaises(StorageFailure) as cm:
                store.download_limited(PRIVATE_BUCKET, PATH, 100)
            self.assertNotIn("sb_secret_test", str(cm.exception))

    def test_untrusted_project_or_key_rejected(self):
        for ref in ("http://evil", "fake.invalid", REF.upper(), ""):
            with self.assertRaises(ValueError):
                SupabasePrivateWorkbookStore(
                    project_ref=ref,secret_key="sb_secret_test",execute=FakeAPI())
        with self.assertRaises(ValueError):
            SupabasePrivateWorkbookStore(
                project_ref=REF,secret_key="sb_publishable_test",execute=FakeAPI())

if __name__ == "__main__":
    unittest.main()
