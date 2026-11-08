"""No-network retention host method isolation and dry-run gates."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.private_retention_host import run_trusted_excel_retention_once

REF = "xzvkdwebtbxlrxagtzlv"
KEY = "sb_secret_synthetic"

class RetentionHostTests(unittest.TestCase):
    def test_factory_grants_only_read_and_delete_not_object_creation(self):
        with patch("software_learning.private_retention_host.SupabasePrivateWorkbookStore") as storage, \
             patch("software_learning.private_retention_host.run_retention_once",
                   return_value={"status": "preview_only"}) as job:
            result = run_trusted_excel_retention_once(
                project_ref=REF, private_storage_key=KEY,
                connection_factory=lambda: None,
            )
        self.assertEqual(result["status"], "preview_only")
        methods = storage.call_args.kwargs["allowed_methods"]
        self.assertEqual(methods, frozenset({"GET", "DELETE"}))
        self.assertNotIn("POST", methods)
        self.assertFalse(job.call_args.kwargs["execute"])
        self.assertFalse(job.call_args.kwargs["authorized"])

    def test_explicit_execution_only_passes_to_authorized_private_job(self):
        with patch("software_learning.private_retention_host.SupabasePrivateWorkbookStore"), \
             patch("software_learning.private_retention_host.run_retention_once",
                   return_value={"status": "retry_required"}) as job:
            result = run_trusted_excel_retention_once(
                project_ref=REF, private_storage_key=KEY,
                connection_factory=lambda: None, authorized=True,
                execute=True, max_results=3, prune_limit=4,
            )
        self.assertEqual(result["status"], "retry_required")
        self.assertEqual(job.call_args.kwargs["max_results"], 3)
        self.assertEqual(job.call_args.kwargs["prune_limit"], 4)
        self.assertTrue(job.call_args.kwargs["execute"])
        self.assertTrue(job.call_args.kwargs["authorized"])

    def test_unapproved_deletion_and_malformed_flags_refuse_before_storage(self):
        with patch("software_learning.private_retention_host.SupabasePrivateWorkbookStore") as storage:
            for values in ({"execute": True}, {"execute": 1},
                           {"authorized": "yes"}, {"authorized": None, "execute": True}):
                with self.subTest(values=values), self.assertRaises(ValueError):
                    run_trusted_excel_retention_once(
                        project_ref=REF, private_storage_key=KEY,
                        connection_factory=lambda: None, **values)
            storage.assert_not_called()

    def test_invalid_secrets_fail_before_job_execution(self):
        with patch("software_learning.private_retention_host.run_retention_once") as job:
            for key in ("sb_publishable_not_secret", "not-a-secret", ""):
                with self.subTest(key=key), self.assertRaises(ValueError):
                    run_trusted_excel_retention_once(
                        project_ref=REF, private_storage_key=key,
                        connection_factory=lambda: None)
            job.assert_not_called()

    def test_host_source_never_imports_worker_upload_or_network_listener(self):
        source = (ROOT / "tool/software_learning/private_retention_host.py").read_text()
        for forbidden in ("DockerXlsxWorker", "run_worker(", "accept_workbook(",
                          "socket.", "uvicorn", "subprocess"):
            self.assertNotIn(forbidden, source)

if __name__ == "__main__":
    unittest.main()
