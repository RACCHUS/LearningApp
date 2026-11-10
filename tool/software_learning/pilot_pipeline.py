"""Draft worker-output adapter for a deterministic, unverified Excel grade.

Caller MUST provide a trusted server-issued dataset and authenticated worker
provenance. This utility does not verify those properties, persist results,
write learning events, or award competency. Never accept client JSON directly.
"""
from __future__ import annotations

from decimal import Decimal, InvalidOperation
import re
from typing import Mapping

from .excel_budget_total import check_budget_total

_INPUTS = frozenset(f'C{i}' for i in range(2, 10))
_CELLS = _INPUTS | {'C10'}
_DECIMAL = re.compile(r'-?(?:0|[1-9][0-9]{0,11})(?:\.[0-9]{1,6})?\Z')


def _rejected() -> dict[str, str]:
    return {
        'criterion_id': 'excel-budget-total-v1',
        'status': 'rejected',
        'feedback': 'The submitted workbook could not be checked.',
        'evidence_trust': 'unverified_checker_only',
    }


def grade_parsed_snapshot(
    worker_result: Mapping[str, object],
    server_expected_inputs: Mapping[str, object],
) -> dict[str, str]:
    """Grade trusted-source worker output without giving it evidence authority."""
    if not isinstance(server_expected_inputs, Mapping) or set(server_expected_inputs) != _INPUTS:
        raise ValueError('Incomplete or unexpected server-owned exercise inputs')
    if not isinstance(worker_result, Mapping):
        return _rejected()
    if (worker_result.get('status') != 'parsed_unverified'
        or worker_result.get('sheet') != 'Budget'
        or worker_result.get('evidence_trust') != 'unverified_checker_only'
        or worker_result.get('can_award_skill') is not False):
        return _rejected()
    cells = worker_result.get('cells')
    if not isinstance(cells, Mapping) or set(cells) != _CELLS:
        return _rejected()
    structured: dict[str, object] = {}
    for ref in _INPUTS:
        cell = cells.get(ref)
        if (not isinstance(cell, Mapping) or cell.get('kind') != 'decimal'
            or set(cell) != {'kind', 'value'}):
            return _rejected()
        value = cell.get('value')
        if not isinstance(value, str) or not _DECIMAL.fullmatch(value):
            return _rejected()
        try:
            parsed = Decimal(value)
        except InvalidOperation:
            return _rejected()
        if not parsed.is_finite():
            return _rejected()
        structured[ref] = parsed
    total = cells['C10']
    if (not isinstance(total, Mapping) or total.get('kind') != 'formula'
        or set(total) != {'kind', 'value'}):
        return _rejected()
    formula = total.get('value')
    if not isinstance(formula, str) or len(formula) > 160:
        return _rejected()
    structured['C10'] = formula
    return check_budget_total(structured, server_expected_inputs)
