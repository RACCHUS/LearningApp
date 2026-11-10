"""No-network container worker entrypoint; NOT a public upload endpoint.

The orchestrator must enforce no-network OS isolation, resource limits,
read-only filesystem, authenticated attempt ownership and retention policy.
Reads one workbook from stdin, emits only a typed *unverified* JSON snapshot.
No database, HTTP client, external dependency or grading path is included.
"""
from __future__ import annotations

from decimal import Decimal
import json
from pathlib import Path
import sys
from typing import BinaryIO

if __package__:
    from .xlsx_snapshot import WorkbookRejected, MAX_UPLOAD_BYTES, extract_budget_snapshot
else:
    # Explicit local, read-only source directory for isolated (-I) Python mode.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from xlsx_snapshot import WorkbookRejected, MAX_UPLOAD_BYTES, extract_budget_snapshot

REJECTION = {"status": "rejected", "reason": "unsupported_or_unsafe_workbook"}


def run_worker(stream: BinaryIO, *, filename: str) -> dict[str, object]:
    """Returns only provisional parsed values, never trusted or scored output."""
    try:
        blob = stream.read(MAX_UPLOAD_BYTES + 1)
        snapshot = extract_budget_snapshot(blob, filename=filename)
        cells = {}
        for ref, value in snapshot.items():
            if isinstance(value, Decimal):
                cells[ref] = {"kind": "decimal", "value": str(value)}
            else:
                cells[ref] = {"kind": "formula", "value": value}
        return {
            "status": "parsed_unverified", "sheet": "Budget", "cells": cells,
            "evidence_trust": "unverified_checker_only", "can_award_skill": False,
        }
    except (WorkbookRejected, ValueError, TypeError):
        return dict(REJECTION)


def main() -> int:
    filename = sys.argv[1] if len(sys.argv) == 2 else "budget.xlsx"
    result = run_worker(sys.stdin.buffer, filename=filename)
    sys.stdout.write(json.dumps(result, separators=(",", ":")) + "\n")
    return 0 if result["status"] == "parsed_unverified" else 1


if __name__ == "__main__":
    sys.exit(main())
