"""End-to-end unverified Excel checker: isolated-worker format to criterion."""
from __future__ import annotations

import io
import sys
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
from software_learning.xlsx_worker import run_worker
from software_learning.pilot_pipeline import grade_parsed_snapshot
from test_xlsx_snapshot import zip_bytes, sheet

SERVER_INPUTS = {f'C{i}': i * 10 for i in range(2, 10)}


class PipelineTests(unittest.TestCase):
    def _worker(self, blob=None):
        return run_worker(io.BytesIO(blob if blob is not None else zip_bytes()),
                          filename='budget.xlsx')

    def test_end_to_end_correct_workbook_is_unverified_pass(self):
        result = grade_parsed_snapshot(self._worker(), SERVER_INPUTS)
        self.assertEqual(result['status'], 'pass')
        self.assertEqual(result['evidence_trust'], 'unverified_checker_only')
        self.assertNotIn('is_verified', result)

    def test_wrong_formula_gives_hint_not_answer(self):
        raw = zip_bytes({'xl/worksheets/sheet1.xml': sheet(formula='SUM(C2:C8)')})
        result = grade_parsed_snapshot(self._worker(raw), SERVER_INPUTS)
        self.assertEqual(result['status'], 'inconclusive')
        self.assertNotIn('C2:C9', result['feedback'])

    def test_failed_parser_cannot_be_graded(self):
        rejected = self._worker(b'not a workbook')
        self.assertEqual(grade_parsed_snapshot(rejected, SERVER_INPUTS)['status'], 'rejected')

    def test_rejects_forged_verified_worker_status(self):
        fake = self._worker()
        fake['evidence_trust'] = 'server_verified'
        self.assertEqual(grade_parsed_snapshot(fake, SERVER_INPUTS)['status'], 'rejected')

    def test_rejects_worker_claiming_award_permission(self):
        fake = self._worker()
        fake['can_award_skill'] = True
        self.assertEqual(grade_parsed_snapshot(fake, SERVER_INPUTS)['status'], 'rejected')

    def test_rejects_tampered_numeric_cell_representation(self):
        fake = self._worker()
        fake['cells']['C2'] = {'kind': 'formula', 'value': '=10+10'}
        self.assertEqual(grade_parsed_snapshot(fake, SERVER_INPUTS)['status'], 'rejected')

    def test_rejects_nonfinite_typed_number(self):
        fake = self._worker()
        fake['cells']['C2'] = {'kind': 'decimal', 'value': 'NaN'}
        self.assertEqual(grade_parsed_snapshot(fake, SERVER_INPUTS)['status'], 'rejected')

    def test_rejects_unexpected_cells(self):
        fake = self._worker()
        fake['cells']['D11'] = {'kind': 'decimal', 'value': '1'}
        self.assertEqual(grade_parsed_snapshot(fake, SERVER_INPUTS)['status'], 'rejected')

    def test_modified_number_fails_even_if_formula_correct(self):
        fake = self._worker()
        fake['cells']['C2'] = {'kind': 'decimal', 'value': '999'}
        self.assertEqual(grade_parsed_snapshot(fake, SERVER_INPUTS)['status'], 'fail')

    def test_rejects_missing_server_owned_inputs(self):
        with self.assertRaises(ValueError):
            grade_parsed_snapshot(self._worker(), {'C2': 20})


if __name__ == '__main__':
    unittest.main()
