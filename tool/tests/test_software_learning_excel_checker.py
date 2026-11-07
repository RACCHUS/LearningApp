"""Security-conscious core tests for the Excel sum exercise.

Only structured cell snapshots enter the checker. Uploaded XLSX parsing must
be implemented separately in an isolated worker before this can ship.
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))

from software_learning.excel_budget_total import check_budget_total

EXPECTED = {f"C{i}": i * 10 for i in range(2, 10)}
CELLS = {**EXPECTED, "C10": "=SUM(C2:C9)"}


class ExcelBudgetTotalCheckerTests(unittest.TestCase):
    def test_supported_sum_range_passes(self):
        result = check_budget_total(CELLS, EXPECTED)
        self.assertEqual(result["status"], "pass")
        self.assertNotIn("expected_total", str(result))

    def test_equivalent_addition_in_different_order_passes(self):
        formula = "=" + "+".join(f"C{i}" for i in range(9, 1, -1))
        self.assertEqual(
            check_budget_total({**CELLS, "C10": formula}, EXPECTED)["status"],
            "pass",
        )

    def test_absolute_references_and_case_are_accepted(self):
        self.assertEqual(
            check_budget_total({**CELLS, "C10": "=sum($C$2:$C$9)"}, EXPECTED)["status"],
            "pass",
        )

    def test_modified_input_never_passes(self):
        changed = {**CELLS, "C4": 999}
        result = check_budget_total(changed, EXPECTED)
        self.assertEqual(result["status"], "fail")
        self.assertNotIn("999", result["feedback"])

    def test_missing_input_never_passes(self):
        changed = {k: v for k, v in CELLS.items() if k != "C7"}
        self.assertEqual(check_budget_total(changed, EXPECTED)["status"], "fail")

    def test_constant_instead_of_formula_never_passes(self):
        result = check_budget_total({**CELLS, "C10": sum(EXPECTED.values())}, EXPECTED)
        self.assertNotEqual(result["status"], "pass")

    def test_wrong_range_is_not_accepted(self):
        result = check_budget_total({**CELLS, "C10": "=SUM(C2:C8)"}, EXPECTED)
        self.assertEqual(result["status"], "inconclusive")

    def test_duplicate_references_cannot_pass(self):
        expr = "=" + "+".join(["C2"] * 8)
        self.assertNotEqual(
            check_budget_total({**CELLS, "C10": expr}, EXPECTED)["status"], "pass"
        )

    def test_external_workbook_formula_is_rejected(self):
        result = check_budget_total(
            {**CELLS, "C10": "='[Other.xlsx]Sheet1'!C2"}, EXPECTED
        )
        self.assertEqual(result["status"], "rejected")

    def test_nonfinite_numeric_input_is_rejected(self):
        result = check_budget_total({**CELLS, "C5": float("inf")}, EXPECTED)
        self.assertEqual(result["status"], "rejected")

    def test_boolean_numeric_input_is_rejected(self):
        result = check_budget_total({**CELLS, "C5": True}, EXPECTED)
        self.assertEqual(result["status"], "rejected")

    def test_untrusted_expected_values_cannot_be_omitted(self):
        with self.assertRaises(ValueError):
            check_budget_total(CELLS, {"C2": 20})

    def test_formula_is_required(self):
        result = check_budget_total({**CELLS, "C10": ""}, EXPECTED)
        self.assertEqual(result["status"], "fail")

    def test_feedback_does_not_reveal_expected_formula(self):
        result = check_budget_total({**CELLS, "C10": "=SUM(C2:C8)"}, EXPECTED)
        self.assertNotIn("C2:C9", result["feedback"])


if __name__ == "__main__":
    unittest.main()
