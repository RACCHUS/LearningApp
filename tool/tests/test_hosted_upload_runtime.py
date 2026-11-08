"""Isolated upload host: exclusive connections, limits and no Docker dependency."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.hosted_upload_runtime import (TrustedExcelUpload,
                                                      build_trusted_excel_upload_host)

ATTEMPT = "ba430000-0000-4000-8000-000000000001"
BLOB = b"PK\x03\x04" + b"test"


class Connection:
    autocommit = False
    def __init__(self):
        self.closed = 0
    def close(self):
        self.closed += 1


class UploadRuntimeTests(unittest.TestCase):
    def make_host(self):
        conns = []
        def connect():
            conn = Connection()
            conns.append(conn)
            return conn
        return TrustedExcelUpload(sessions=object(), storage=object(),
                                  connection_factory=connect), conns

    def test_exclusive_database_lifetime_for_every_upload(self):
        host, conns = self.make_host()
        with patch("software_learning.hosted_upload_runtime.accept_workbook",
                   return_value={"status": "accepted",
                                 "evidence_trust": "unverified_checker_only"}) as call:
            self.assertEqual(host("bearer", ATTEMPT, BLOB)["status"], "accepted")
            self.assertEqual(host("bearer", ATTEMPT, BLOB)["status"], "accepted")
        self.assertEqual([c.closed for c in conns], [1, 1])
        self.assertIsNot(conns[0], conns[1])
        self.assertEqual(call.call_count, 2)
        self.assertTrue(call.call_args.kwargs["now"].tzinfo is not None)

    def test_error_redacted_and_connection_closed(self):
        host, conns = self.make_host()
        with patch("software_learning.hosted_upload_runtime.accept_workbook",
                   side_effect=RuntimeError("database private credential")):
            result = host("secret bearer", ATTEMPT, BLOB)
        self.assertEqual(result["status"], "rejected")
        self.assertNotIn("credential", str(result))
        self.assertEqual(conns[0].closed, 1)

    def test_bad_ids_and_oversized_bytes_do_not_open_connection(self):
        host, conns = self.make_host()
        for id_, blob in (("../bad", BLOB), (ATTEMPT.upper(), BLOB),
                          (ATTEMPT, b""), (ATTEMPT, b"x"*10485761)):
            with self.subTest(id=id_, size=len(blob)):
                self.assertEqual(host("bearer", id_, blob)["status"], "rejected")
        self.assertEqual(conns, [])

    def test_concurrency_limit_fails_closed_without_db(self):
        host, conns = self.make_host()
        self.assertTrue(host._slots.acquire(blocking=False))
        self.assertTrue(host._slots.acquire(blocking=False))
        try:
            self.assertEqual(host("bearer", ATTEMPT, BLOB)["status"], "rejected")
            self.assertEqual(conns, [])
        finally:
            host._slots.release()
            host._slots.release()

    def test_factory_scopes_upload_network_methods_without_delete(self):
        with patch("software_learning.hosted_upload_runtime.SupabaseUserGateway"), \\
             patch("software_learning.hosted_upload_runtime.SupabasePrivateWorkbookStore") as store:
            host = build_trusted_excel_upload_host(
                project_ref="xzvkdwebtbxlrxagtzlv",
                publishable_key="sb_publishable_mock",
                private_storage_key="sb_secret_mock",
                connection_factory=lambda: Connection(),
            )
            self.assertIsInstance(host, TrustedExcelUpload)
            self.assertEqual(store.call_args.kwargs["allowed_methods"],
                             frozenset({"GET", "POST"}))
            self.assertNotIn("DELETE", store.call_args.kwargs["allowed_methods"])

    def test_invalid_configuration_and_no_docker_reference(self):
        for x in (0, -1, True, 9):
            with self.subTest(x=x), self.assertRaises(ValueError):
                TrustedExcelUpload(sessions=object(), storage=object(),
                                   connection_factory=lambda: Connection(), max_inflight=x)
        src = (ROOT / "tool/software_learning/hosted_upload_runtime.py").read_text()
        self.assertNotIn("DockerXlsxWorker", src)
        self.assertNotIn("subprocess", src)


if __name__ == "__main__":
    unittest.main()
