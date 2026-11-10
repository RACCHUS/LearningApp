"""Synthetic-only, adversarial Storage account inventory probes."""
from __future__ import annotations

import io
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.private_owner_inventory import SupabaseExcelOwnerInventory
from software_learning.supabase_private_storage import StorageFailure

OWNER = "ba410000-0000-4000-8000-000000000001"
REF = "xzvkdwebtbxlrxagtzlv"
SECRET = "sb_secret_fixture"

class Response:
    def __init__(self, url, data, status=200, mime="application/json", length=None):
        self.url, self.status = url, status
        self.headers = {"Content-Type": mime, "Content-Length":
                        str(len(data)) if length is None else length}
        self.data = io.BytesIO(data)
    def __enter__(self): return self
    def __exit__(self, *args): return False
    def geturl(self): return self.url
    def read(self, n): return self.data.read(n)

class Fake:
    def __init__(self, data=b"[]", **kwargs):
        self.data, self.options, self.requests = data, kwargs, []
    def __call__(self, req, timeout):
        self.requests.append((req, timeout))
        if self.options.get("failure"):
            raise RuntimeError("private " + SECRET)
        url = "https://evil.invalid/" if self.options.get("redirect") else req.full_url
        return Response(url, self.data, self.options.get("status", 200),
                        self.options.get("mime", "application/json"),
                        self.options.get("length"))

class InventoryTests(unittest.TestCase):
    def client(self, backend):
        return SupabaseExcelOwnerInventory(project_ref=REF, secret_key=SECRET,
                                           execute=backend)

    def test_folder_entry_blocks_and_request_is_scoped_bounded_read_only(self):
        backend = Fake(json.dumps([{"name": "attempt-folder", "id": None}]).encode())
        status = self.client(backend).probe(OWNER)
        self.assertEqual(status, "objects_visible")
        self.assertNotIn("attempt-folder", status)
        req, timeout = backend.requests[0]
        self.assertEqual(timeout, 5)
        self.assertEqual(req.get_method(), "POST")
        self.assertEqual(req.full_url,
                         f"https://{REF}.supabase.co/storage/v1/object/list/learningapp-excel-private")
        self.assertEqual(json.loads(req.data), {
            "prefix": OWNER + "/", "limit": 1, "offset": 0,
            "sortBy": {"column": "name", "order": "asc"},
        })
        self.assertEqual(req.get_header("Authorization"), "Bearer " + SECRET)
        self.assertEqual(len(backend.requests), 1)

    def test_empty_is_observation_not_erasable_proof(self):
        self.assertEqual(self.client(Fake()).probe(OWNER), "empty_observed")

    def test_invalid_owners_never_trigger_http(self):
        backend = Fake()
        for owner in (None, "", "../bad", OWNER.upper(), "other/" + OWNER):
            with self.subTest(owner=owner), self.assertRaises(ValueError):
                self.client(backend).probe(owner)
        self.assertEqual(backend.requests, [])

    def test_failure_redirect_status_mime_size_are_fail_closed_and_redacted(self):
        for options in ({"failure": True}, {"redirect": True}, {"status": 201},
                        {"mime": "text/plain"}, {"length": "5000"}):
            with self.subTest(options=options), self.assertRaises(StorageFailure) as err:
                self.client(Fake(**options)).probe(OWNER)
            self.assertNotIn(SECRET, str(err.exception))
            self.assertNotIn(OWNER, str(err.exception))

    def test_malformed_or_oversized_provider_data_never_claims_empty(self):
        for data in (b"null", b"{}", b'{"error":"denied"}', b"[null]",
                     b'[{"id":null}]', b'[{"name":""}]',
                     b'[{"name":"a"},{"name":"b"}]',
                     b'[{"name":"bad\\nname"}]', b"\xff", b"x"*4097):
            with self.subTest(data=data[:30]), self.assertRaises(StorageFailure):
                self.client(Fake(data)).probe(OWNER)

    def test_invalid_ref_or_public_key_rejected(self):
        for ref,key in (("bad.example", SECRET), (REF.upper(),SECRET),
                        (REF,"sb_publishable_fake"), (REF,"")):
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                SupabaseExcelOwnerInventory(project_ref=ref, secret_key=key,
                                            execute=Fake())

if __name__ == "__main__":
    unittest.main()
