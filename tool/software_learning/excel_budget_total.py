"""Deterministic, non-executing checker for the Excel budget-sum pilot.

This module accepts only a *structured snapshot* produced by a future isolated
XLSX ingestion worker. It intentionally never opens uploaded files, executes
macros, evaluates arbitrary Excel expressions, calls network services, or writes
learning events. The authoritative expected values MUST come from the server.
"""
from __future__ import annotations

import re
from decimal import Decimal, InvalidOperation
from typing import Mapping

_SOURCE_CELLS = tuple(f"C{row}" for row in range(2, 10))
_SUM_RANGE = re.compile(
    r"^=\s*SUM\s*\(\s*\$?C\$?2\s*:\s*\$?C\$?9\s*\)\s*$",
    re.IGNORECASE,
)
_SINGLE_REFERENCE = re.compile(r"\$?C\$?([2-9])", re.IGNORECASE)


def _result(status: str, feedback: str) -> dict[str, str]:
    return {
        "criterion_id": "excel-budget-total-v1",
        "status": status,
        "feedback": feedback,
        "evidence_trust": "unverified_checker_only",
    }


def _numeric(value: object) -> Decimal:
    if isinstance(value, bool) or not isinstance(value, (int, float, Decimal)):
        raise ValueError("Not a numeric Excel cell")
    try:
        number = Decimal(str(value))
    except (InvalidOperation, ValueError) as error:
        raise ValueError("Invalid numeric cell") from error
    if not number.is_finite():
        raise ValueError("Non-finite numeric cell")
    return number


def _is_supported_sum_formula(formula: str) -> bool:
    """Allow only an exact SUM range or each required term added once.

    This is deliberately not an Excel formula evaluator.
    """
    if _SUM_RANGE.fullmatch(formula):
        return True
    if not formula.startswith("="):
        return False
    terms = formula[1:].split("+")
    if len(terms) != len(_SOURCE_CELLS):
        return False
    matched = []
    for term in terms:
        m = _SINGLE_REFERENCE.fullmatch(term.strip())
        if m is None:
            return False
        matched.append(f"C{m.group(1)}")
    return set(matched) == set(_SOURCE_CELLS) and len(set(matched)) == len(matched)


def check_budget_total(
    cells: Mapping[str, object],
    server_expected_inputs: Mapping[str, object],
) -> dict[str, str]:
    """Check one bounded criterion; never award skills or mark trusted evidence.

    Contract:
    - cells are an isolated-worker snapshot of the `Budget` sheet.
    - server_expected_inputs are server-controlled, not client-provided.
    - the worker rejects malformed XLSX, macros, links, size violations and
      decompression attacks *before* calling this function.
    - this function does not trust cached formula results.
    """
    if set(server_expected_inputs) != set(_SOURCE_CELLS):
        raise ValueError("Incomplete or unexpected server-owned exercise inputs")
    try:
        expected = {cell: _numeric(server_expected_inputs[cell]) for cell in _SOURCE_CELLS}
    except ValueError as error:
        raise ValueError("Invalid server-owned exercise inputs") from error

    if not isinstance(cells, Mapping):
        return _result("rejected", "The submitted worksheet could not be checked.")

    for cell in _SOURCE_CELLS:
        if cell not in cells:
            return _result("fail", "Check that every transaction row contains data.")
        try:
            actual = _numeric(cells[cell])
        except ValueError:
            return _result("rejected", "The transaction cells must contain finite numbers.")
        if actual != expected[cell]:
            return _result("fail", "Review the transaction data before calculating the total.")

    formula = cells.get("C10")
    if not isinstance(formula, str) or not formula.strip():
        return _result("fail", "Enter a formula in the total cell.")

    if any(marker in formula for marker in ("[", "]", "!")):
        return _result("rejected", "External references are not accepted for this exercise.")

    if not _is_supported_sum_formula(formula.strip()):
        return _result(
            "inconclusive",
            "Review how the total includes each transaction row exactly once. "
            "This exercise supports only a simple range sum or direct addition.",
        )

    # Both supported formula forms reference each verified server-issued
    # numeric source cell once. No workbook cache or client score is trusted.
    return _result("pass", "Your transaction total uses the required rows correctly.")
