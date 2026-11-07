"""Worker contract tests do not simulate OS isolation (separate release gate)."""
from __future__ import annotations

import io
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.xlsx_worker import run_worker
from test_xlsx_snapshot import zip_bytes, sheet


class WorkerContractTests(unittest.TestCase):
    def test_isolated_python_cli_accepts_stdin_without_extra_output(self):
        entry = ROOT / "tool/software_learning/xlsx_worker.py"
        process = subprocess.run(
            [sys.executable, "-I", "-S", str(entry), "budget.xlsx"],
            input=zip_bytes(), capture_output=True, timeout=8,
        )
        self.assertEqual(process.returncode, 0, process.stderr.decode())
        self.assertEqual(process.stderr, b"")
        result = json.loads(process.stdout.decode())
        self.assertEqual(result["status"], "parsed_unverified")
        self.assertEqual(result["cells"]["C10"]["value"], "=SUM(C2:C9)")

    def test_valid_workbook_returns_unverified_typed_cells(self):
        result = run_worker(io.BytesIO(zip_bytes()), filename="budget.xlsx")
        self.assertEqual(result["status"], "parsed_unverified")
        self.assertEqual(result["sheet"], "Budget")
        self.assertEqual(result["cells"]["C2"], {"kind": "decimal", "value": "20"})
        self.assertEqual(result["cells"]["C10"], {"kind": "formula", "value": "=SUM(C2:C9)"})
        self.assertNotIn("999999", json.dumps(result))
        self.assertEqual(result["evidence_trust"], "unverified_checker_only")
        self.assertFalse(result["can_award_skill"])

    def test_rejects_zip_without_echoing_payload(self):
        result = run_worker(io.BytesIO(b"my secret personal workbook"), filename="budget.xlsx")
        self.assertEqual(result, {"status": "rejected", "reason": "unsupported_or_unsafe_workbook"})
        self.assertNotIn("secret", json.dumps(result))

    def test_rejects_macro_enabled_name(self):
        result = run_worker(io.BytesIO(zip_bytes()), filename="budget.xlsm")
        self.assertEqual(result["status"], "rejected")

    def test_rejects_oversized_stream_without_reading_whole_payload(self):
        stream = io.BytesIO(b"X" * (10 * 1024 * 1024 + 2))
        result = run_worker(stream, filename="budget.xlsx")
        self.assertEqual(result["status"], "rejected")
        self.assertLessEqual(stream.tell(), 10 * 1024 * 1024 + 1)

    def test_rejects_hidden_formula(self):
        extra = '<row r="11"><c r="A11"><f>HYPERLINK("http://outside")</f></c></row>'
        blob = zip_bytes({"xl/worksheets/sheet1.xml": sheet(extra=extra)})
        result = run_worker(io.BytesIO(blob), filename="budget.xlsx")
        self.assertEqual(result["status"], "rejected")


if __name__ == "__main__":
    unittest.main()
