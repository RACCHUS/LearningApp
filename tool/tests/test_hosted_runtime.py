"""Trusted-host factory tests: exclusive DB lifetimes and bounded work."""
from __future__ import annotations

import sys
import threading
import unittest
from unittest.mock import patch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.hosted_runtime import TrustedExcelAssessment, build_trusted_excel_host

ATTEMPT = "ba430000-0000-4000-8000-000000000001"


class Conn:
    def __init__(self):
        self.closed = 0
    def close(self):
        self.closed += 1


class Sessions:
    pass


class Storage:
    pass


class Runner:
    pass


class RuntimeTests(unittest.TestCase):
    def test_every_request_gets_exclusive_connection_and_closes_it(self):
        conns = []
        def connect():
            conn = Conn()
            conns.append(conn)
            return conn
        host = TrustedExcelAssessment(sessions=Sessions(), storage=Storage(),
                                      runner=Runner(), connection_factory=connect)
        with patch("software_learning.hosted_runtime.assess_private_workbook",
                   return_value={"status": "rejected", "evidence_trust":
                                 "unverified_checker_only", "skill_award_enabled": False,
                                 "feedback": "Try again"}) as assess:
            host("secret.bearer.token", ATTEMPT)
            host("secret.bearer.token", ATTEMPT)
        self.assertEqual(len(conns), 2)
        self.assertIsNot(conns[0], conns[1])
        self.assertEqual([conn.closed for conn in conns], [1, 1])
        self.assertEqual(assess.call_count, 2)
        self.assertTrue(assess.call_args.kwargs["now"].tzinfo is not None)

    def test_bad_data_and_exception_never_leak_or_leave_open_connection(self):
        conns = []
        def connect():
            x = Conn()
            conns.append(x)
            return x
        host = TrustedExcelAssessment(sessions=Sessions(), storage=Storage(),
                                      runner=Runner(), connection_factory=connect)
        with patch("software_learning.hosted_runtime.assess_private_workbook",
                   side_effect=RuntimeError("private host secret")):
            result = host("private secret bearer", ATTEMPT)
        self.assertEqual(result["status"], "rejected")
        self.assertNotIn("secret", str(result))
        self.assertEqual(conns[0].closed, 1)

    def test_invalid_attempt_never_opens_database(self):
        opened = []
        host = TrustedExcelAssessment(
            sessions=Sessions(), storage=Storage(), runner=Runner(),
            connection_factory=lambda: opened.append(Conn()))
        result = host("bearer.jwt.claim", "wrong/path")
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(opened, [])

    def test_bounded_inflight_work_is_fail_closed(self):
        conns = []
        host = TrustedExcelAssessment(
            sessions=Sessions(), storage=Storage(), runner=Runner(),
            connection_factory=lambda: conns.append(Conn()) or conns[-1],
            max_inflight=1,
        )
        self.assertTrue(host._slots.acquire(blocking=False))
        try:
            result = host("bearer.jwt.value", ATTEMPT)
        finally:
            host._slots.release()
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(conns, [])

    def test_factory_scopes_grading_storage_to_read_only(self):
        with patch("software_learning.hosted_runtime.SupabaseUserGateway"), \\
             patch("software_learning.hosted_runtime.SupabasePrivateWorkbookStore") as store, \\
             patch("software_learning.hosted_runtime.DockerXlsxWorker"):
            host = build_trusted_excel_host(
                project_ref="xzvkdwebtbxlrxagtzlv",
                publishable_key="sb_publishable_mock",
                private_storage_key="sb_secret_mock",
                pinned_worker_image="test@sha256:" + "a" * 64,
                connection_factory=lambda: Conn(),
            )
            self.assertIsInstance(host, TrustedExcelAssessment)
            self.assertEqual(store.call_args.kwargs["allowed_methods"],
                             frozenset({"GET"}))

    def test_invalid_constructor_configuration_refused(self):
        for n in (0, -1, True, 10000):
            with self.subTest(max_inflight=n), self.assertRaises(ValueError):
                TrustedExcelAssessment(
                    sessions=Sessions(), storage=Storage(), runner=Runner(),
                    connection_factory=lambda: Conn(), max_inflight=n)


if __name__ == "__main__":
    unittest.main()
