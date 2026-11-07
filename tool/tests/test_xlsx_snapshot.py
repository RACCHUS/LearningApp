"""Adversarial tests for a restricted XLSX reader (actual ZIP/XML bytes)."""
from __future__ import annotations

import io
import sys
import unittest
import warnings
import zipfile
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.xlsx_snapshot import WorkbookRejected, extract_budget_snapshot

MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
DOCREL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKGREL = "http://schemas.openxmlformats.org/package/2006/relationships"
TYPES = b'''<?xml version="1.0"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>'''
ROOT_RELS = f'''<Relationships xmlns="{PKGREL}">
<Relationship Id="rIdOffice" Type="{DOCREL}/officeDocument" Target="xl/workbook.xml"/>
</Relationships>'''.encode()
BOOK = f'''<workbook xmlns="{MAIN}" xmlns:r="{DOCREL}"><sheets>
<sheet name="Budget" sheetId="1" r:id="rId1"/></sheets></workbook>'''.encode()
BOOK_RELS = f'''<Relationships xmlns="{PKGREL}">
<Relationship Id="rId1" Type="{DOCREL}/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>'''.encode()


def sheet(formula="SUM(C2:C9)", cached="999999", amounts=None, extra=""):
    amounts = amounts or {}
    rows = []
    for i in range(2, 10):
        value = amounts.get(i, i * 10)
        if isinstance(value, str) and value.startswith("="):
            rows.append(f'<row r="{i}"><c r="C{i}"><f>{value[1:]}</f><v>0</v></c></row>')
        elif value is not None:
            rows.append(f'<row r="{i}"><c r="C{i}"><v>{value}</v></c></row>')
    rows.append(f'<row r="10"><c r="C10"><f>{formula}</f><v>{cached}</v></c></row>')
    return (f'<worksheet xmlns="{MAIN}"><sheetData>' + "".join(rows) + extra +
            '</sheetData></worksheet>').encode()


def zip_bytes(replacements=None, extra=()):
    files = {
        "[Content_Types].xml": TYPES, "_rels/.rels": ROOT_RELS,
        "xl/workbook.xml": BOOK, "xl/_rels/workbook.xml.rels": BOOK_RELS,
        "xl/worksheets/sheet1.xml": sheet(),
    }
    files.update(replacements or {})
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path, data in files.items():
            archive.writestr(path, data)
        for path, data in extra:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                archive.writestr(path, data)
    return output.getvalue()


class XLSXSnapshotTests(unittest.TestCase):
    def _reject(self, blob, filename="budget.xlsx"):
        with self.assertRaises(WorkbookRejected):
            extract_budget_snapshot(blob, filename=filename)

    def test_valid_workbook_uses_formula_not_cached_result(self):
        cells = extract_budget_snapshot(zip_bytes(), filename="budget.xlsx")
        self.assertEqual(cells["C2"], Decimal("20"))
        self.assertEqual(cells["C9"], Decimal("90"))
        self.assertEqual(cells["C10"], "=SUM(C2:C9)")
        self.assertNotIn(Decimal("999999"), cells.values())

    def test_equivalent_formula_is_preserved_without_evaluation(self):
        alt = sheet(formula="C9+C8+C7+C6+C5+C4+C3+C2", cached="0")
        actual = extract_budget_snapshot(zip_bytes({"xl/worksheets/sheet1.xml": alt}),
                                         filename="budget.xlsx")
        self.assertEqual(actual["C10"], "=C9+C8+C7+C6+C5+C4+C3+C2")

    def test_real_excel_style_absolute_relationship_and_empty_names(self):
        book = BOOK.replace(b"</sheets>", b"</sheets><definedNames/>")
        rels = BOOK_RELS.replace(b'Target="worksheets/sheet1.xml"',
                                 b'Target="/xl/worksheets/sheet1.xml"')
        blob = zip_bytes({"xl/workbook.xml": book,
                          "xl/_rels/workbook.xml.rels": rels})
        self.assertEqual(extract_budget_snapshot(blob, filename="budget.xlsx")["C10"],
                         "=SUM(C2:C9)")

    def test_nonempty_named_formula_rejected(self):
        book = BOOK.replace(b"</sheets>",
            b'</sheets><definedNames><definedName name="Bad">[remote.xlsx]A!B2</definedName></definedNames>')
        self._reject(zip_bytes({"xl/workbook.xml": book}))

    def test_macro_enabled_extension_rejected(self):
        self._reject(zip_bytes(), filename="budget.xlsm")

    def test_missing_or_oversized_bytes_rejected(self):
        for blob in (b"", b"not zip", b"Z" * (10 * 1024 * 1024 + 1)):
            with self.subTest(length=len(blob)):
                self._reject(blob)

    def test_external_relationship_rejected(self):
        rels = BOOK_RELS.replace(b'Target="worksheets/sheet1.xml"',
                                 b'TargetMode="External" Target="https://example.org/file"')
        self._reject(zip_bytes({"xl/_rels/workbook.xml.rels": rels}))

    def test_macro_payload_hidden_inside_xlsx_rejected(self):
        self._reject(zip_bytes(extra=[("xl/vbaProject.bin", b"macro")]))

    def test_path_traversal_entry_rejected(self):
        self._reject(zip_bytes(extra=[("../passwd", b"bad")]))

    def test_duplicate_entry_rejected(self):
        self._reject(zip_bytes(extra=[("xl/workbook.xml", BOOK)]))

    def test_case_insensitive_duplicate_rejected(self):
        self._reject(zip_bytes(extra=[("XL/WORKBOOK.XML", BOOK)]))

    def test_embedded_object_rejected(self):
        self._reject(zip_bytes(extra=[("xl/embeddings/oleObject1.bin", b"bad")]))

    def test_doctype_rejected(self):
        book = BOOK.replace(b"<workbook", b'<!DOCTYPE workbook [<!ENTITY x "xx">]><workbook')
        self._reject(zip_bytes({"xl/workbook.xml": book}))

    def test_hidden_formula_rejected(self):
        extra = '<row r="11"><c r="A11"><f>WEBSERVICE("http://bad")</f></c></row>'
        self._reject(zip_bytes({"xl/worksheets/sheet1.xml": sheet(extra=extra)}))

    def test_input_formula_rejected(self):
        self._reject(zip_bytes({"xl/worksheets/sheet1.xml": sheet(amounts={3: "=1+29"})}))

    def test_other_worksheet_name_rejected(self):
        self._reject(zip_bytes({"xl/workbook.xml": BOOK.replace(b'name="Budget"',
                                                                b'name="Hidden"')}))

    def test_missing_input_cell_rejected(self):
        self._reject(zip_bytes({"xl/worksheets/sheet1.xml": sheet(amounts={5: None})}))

    def test_nonfinite_input_rejected(self):
        self._reject(zip_bytes({"xl/worksheets/sheet1.xml": sheet(amounts={5: "NaN"})}))

    def test_external_formula_rejected(self):
        self._reject(zip_bytes({"xl/worksheets/sheet1.xml":
                                sheet(formula="'[other.xlsx]Budget'!C3")}))

    def test_missing_sheet_link_rejected(self):
        rels = BOOK_RELS.replace(b"worksheets/sheet1.xml", b"worksheets/other.xml")
        self._reject(zip_bytes({"xl/_rels/workbook.xml.rels": rels}))

    def test_excessive_compression_rejected(self):
        huge = '<row r="11"><c r="A11"><v>' + "0" * 2_000_000 + '</v></c></row>'
        self._reject(zip_bytes({"xl/worksheets/sheet1.xml": sheet(extra=huge)}))

    def test_wrong_content_type_rejected(self):
        types = TYPES.replace(b"spreadsheetml.sheet.main+xml",
                              b"spreadsheetml.sheet.macroEnabled.main+xml")
        self._reject(zip_bytes({"[Content_Types].xml": types}))

    def test_bad_cell_coordinate_rejected(self):
        self._reject(zip_bytes({"xl/worksheets/sheet1.xml":
                                sheet(extra='<row r="11"><c r="ZZ999"><v>3</v></c></row>')}))

    def test_duplicate_cell_coordinate_rejected(self):
        self._reject(zip_bytes({"xl/worksheets/sheet1.xml":
                                sheet(extra='<row r="11"><c r="C2"><v>3</v></c></row>')}))


if __name__ == "__main__":
    unittest.main()
