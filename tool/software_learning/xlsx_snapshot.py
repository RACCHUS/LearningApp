"""Bounded XLSX snapshot reader for the draft Excel pilot.

This is NOT an upload endpoint or an OS sandbox. Invoke only inside a
network-disabled, resource-limited worker after authenticating the attempt.
It cannot execute workbook formulas, award skills, or write learning evidence.
A valid workbook using unsupported features is intentionally rejected.
"""
from __future__ import annotations

from decimal import Decimal, InvalidOperation
import io
import re
import zipfile
from pathlib import PurePosixPath
from xml.etree import ElementTree as ET


class WorkbookRejected(ValueError):
    """Unsafe, malformed, or unsupported workbook."""


MAX_UPLOAD_BYTES = 10 * 1024 * 1024
_MAX_EXPANDED_BYTES = 8 * 1024 * 1024
_MAX_PART_BYTES = 2 * 1024 * 1024
_MAX_PARTS = 20
_MAX_RATIO = 100
_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
_DOC_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
_PKG_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
_TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"
_WS = "xl/worksheets/sheet1.xml"
_REQUIRED = frozenset({
    "[Content_Types].xml", "_rels/.rels", "xl/workbook.xml",
    "xl/_rels/workbook.xml.rels", _WS,
})
_OPTIONAL = frozenset({
    "docProps/core.xml", "docProps/app.xml", "xl/styles.xml",
    "xl/sharedStrings.xml", "xl/theme/theme1.xml", "xl/calcChain.xml",
})
_ALLOWED = _REQUIRED | _OPTIONAL
_ALLOWED_NAME = re.compile(r"\A[a-zA-Z0-9_./\[\]-]+\Z")
_CELL_REF = re.compile(r"\A([A-C])([1-9]|10)\Z")
_INPUTS = frozenset(f"C{i}" for i in range(2, 10))


def _untrusted(message: str = "Unsupported or unsafe workbook") -> WorkbookRejected:
    return WorkbookRejected(message)


def _xml(data: bytes) -> ET.Element:
    # XML entities and DTDs are out of scope; never resolve external entities.
    # UTF-16 can hide a DOCTYPE from a raw byte search. Support UTF-8
    # only, and explicitly reject DTD/entities before the XML parser runs.
    try:
        decoded = data.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise _untrusted("Unsupported workbook XML encoding") from exc
    lower = decoded.casefold()
    if ("\x00" in decoded or "<!doctype" in lower or "<!entity" in lower
        or "<![cdata[" in lower):
        raise _untrusted()
    try:
        return ET.fromstring(data)
    except ET.ParseError as exc:
        raise _untrusted("Malformed workbook XML") from exc


def _read_safe_parts(blob: bytes, filename: str) -> dict[str, ET.Element]:
    if not isinstance(filename, str) or not filename.lower().endswith(".xlsx"):
        raise _untrusted("Only .xlsx workbooks are supported")
    if not isinstance(blob, bytes) or not blob or len(blob) > MAX_UPLOAD_BYTES:
        raise _untrusted("Workbook exceeds the accepted size or is empty")
    if not blob.startswith(b"PK\x03\x04"):
        raise _untrusted("Not a valid XLSX container")
    parts: dict[str, ET.Element] = {}
    try:
        with zipfile.ZipFile(io.BytesIO(blob), "r") as archive:
            infos = archive.infolist()
            if len(infos) > _MAX_PARTS:
                raise _untrusted("Too many workbook parts")
            expanded = 0
            seen: set[str] = set()
            for item in infos:
                name = item.filename
                if (not _ALLOWED_NAME.fullmatch(name) or name not in _ALLOWED
                    or ".." in PurePosixPath(name).parts or name.startswith("/")
                    or item.is_dir() or name.casefold() in seen):
                    raise _untrusted("Unexpected workbook part")
                seen.add(name.casefold())
                if item.flag_bits & 1:
                    raise _untrusted("Encrypted workbook parts not supported")
                if item.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                    raise _untrusted("Unsupported ZIP compression")
                if (item.create_system == 3 and
                    (item.external_attr >> 16) & 0o170000 == 0o120000):
                    raise _untrusted("ZIP symlink not supported")
                if item.file_size > _MAX_PART_BYTES or item.file_size < 1:
                    raise _untrusted("Workbook part size invalid")
                if item.file_size > item.compress_size * _MAX_RATIO:
                    raise _untrusted("Excessive ZIP compression ratio")
                expanded += item.file_size
                if expanded > _MAX_EXPANDED_BYTES:
                    raise _untrusted("Workbook decompressed size too large")
                with archive.open(item, "r") as entry:
                    content = entry.read(_MAX_PART_BYTES + 1)
                    if len(content) != item.file_size or entry.read(1):
                        raise _untrusted("Archive metadata mismatch")
                parts[name] = _xml(content)
    except (zipfile.BadZipFile, OSError, EOFError, RuntimeError, NotImplementedError) as exc:
        raise _untrusted("Invalid or unsupported XLSX archive") from exc
    if not _REQUIRED.issubset(parts.keys()):
        raise _untrusted("Missing required workbook components")
    return parts


def _validate_content_types(root: ET.Element) -> None:
    if root.tag != f"{{{_TYPES_NS}}}Types":
        raise _untrusted()
    overrides = {}
    for item in root:
        if item.tag == f"{{{_TYPES_NS}}}Override":
            name = item.attrib.get("PartName", "")
            if name in overrides:
                raise _untrusted("Duplicate content type")
            overrides[name] = item.attrib.get("ContentType", "")
        elif item.tag != f"{{{_TYPES_NS}}}Default":
            raise _untrusted()
        if any(token in str(v).lower() for v in item.attrib.values()
               for token in ("macroenabled", "vba", "activex", "external", "oleobject")):
            raise _untrusted("Active or external workbook content not supported")
    if overrides.get("/xl/workbook.xml") != (
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"
    ) or overrides.get("/xl/worksheets/sheet1.xml") != (
        "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"
    ):
        raise _untrusted("Incorrect workbook content types")
    if any(path.lstrip("/") not in _ALLOWED for path in overrides):
        raise _untrusted("Unexpected workbook content type")


def _check_relationships(root: ET.Element, required_type: str,
                         expected_target: str, expected_id: str | None = None) -> None:
    if root.tag != f"{{{_PKG_REL_NS}}}Relationships":
        raise _untrusted()
    matching = 0
    ids = set()
    accepted_target = {expected_target}
    if expected_target == "worksheets/sheet1.xml":
        accepted_target.add("/xl/worksheets/sheet1.xml")
    allowed_other = {
        ("styles", "styles.xml"), ("styles", "/xl/styles.xml"),
        ("sharedStrings", "sharedStrings.xml"),
        ("sharedStrings", "/xl/sharedStrings.xml"),
        ("theme", "theme/theme1.xml"), ("theme", "/xl/theme/theme1.xml"),
        ("core-properties", "docProps/core.xml"),
        ("extended-properties", "docProps/app.xml"),
    }
    for rel in root:
        if rel.tag != f"{{{_PKG_REL_NS}}}Relationship":
            raise _untrusted()
        if rel.attrib.get("TargetMode", "Internal") != "Internal":
            raise _untrusted("External relationship rejected")
        if rel.attrib.get("Id") in ids:
            raise _untrusted("Duplicate relationship")
        ids.add(rel.attrib.get("Id"))
        target = rel.attrib.get("Target")
        kind = rel.attrib.get("Type")
        if (kind == required_type and target in accepted_target
            and (expected_id is None or rel.attrib.get("Id") == expected_id)):
            matching += 1
        elif kind == required_type:
            raise _untrusted("Wrong workbook relationship")
        elif not kind or not target or ".." in target or ":" in target:
            raise _untrusted("Unsafe relationship")
        elif (kind.rsplit("/", 1)[-1], target) not in allowed_other:
            raise _untrusted("Unexpected relationship kind or target")
    if matching != 1:
        raise _untrusted("Worksheet relationship missing")


def _validate_workbook(root: ET.Element) -> str:
    if root.tag != f"{{{_NS}}}workbook":
        raise _untrusted()
    sheets = root.find(f"{{{_NS}}}sheets")
    if sheets is None or len(sheets) != 1:
        raise _untrusted("Expected one budget worksheet")
    sheet = sheets[0]
    if (sheet.tag != f"{{{_NS}}}sheet" or sheet.get("name") != "Budget"
        or sheet.get(f"{{{_DOC_REL_NS}}}id") is None):
        raise _untrusted("Missing Budget worksheet")
    allowed_children = {
        f"{{{_NS}}}{t}" for t in (
            "sheets", "fileVersion", "workbookPr", "bookViews",
            "calcPr", "workbookProtection",
        )
    }
    for child in root:
        if child.tag == f"{{{_NS}}}definedNames" and len(child) == 0:
            continue
        if child.tag not in allowed_children:
            raise _untrusted("Unsupported workbook feature")
    return sheet.get(f"{{{_DOC_REL_NS}}}id")


def _extract_sheet(root: ET.Element) -> dict[str, object]:
    if root.tag != f"{{{_NS}}}worksheet":
        raise _untrusted("Invalid worksheet XML")
    sheet_data = root.find(f"{{{_NS}}}sheetData")
    if sheet_data is None:
        raise _untrusted("Worksheet missing data")
    allowed_sections = {
        f"{{{_NS}}}{n}" for n in (
            "dimension", "sheetViews", "sheetFormatPr", "cols", "sheetData",
            "pageMargins", "pageSetup", "printOptions", "sheetPr", "mergeCells",
            "conditionalFormatting", "autoFilter", "ignoredErrors",
        )
    }
    if any(child.tag not in allowed_sections for child in root):
        raise _untrusted("Unsupported worksheet feature")
    output: dict[str, object] = {}
    total_cells = 0
    for row in sheet_data:
        if row.tag != f"{{{_NS}}}row":
            raise _untrusted("Unsupported worksheet structure")
        for c in row:
            if c.tag != f"{{{_NS}}}c":
                raise _untrusted("Unsupported worksheet cell")
            total_cells += 1
            if total_cells > 500:
                raise _untrusted("Worksheet has too many cells")
            ref = c.get("r", "")
            m = _CELL_REF.fullmatch(ref)
            if m is None or ref in output:
                raise _untrusted("Unexpected or duplicate cell")
            if row.get("r") != m.group(2):
                raise _untrusted("Cell in unexpected row")
            output[ref] = None
            formula = c.find(f"{{{_NS}}}f")
            if formula is not None and ref != "C10":
                raise _untrusted("Formulas outside total cell not supported")
            if ref in _INPUTS:
                if c.get("t") not in (None, "n") or formula is not None:
                    raise _untrusted("Transaction amount must be numeric data")
                value = c.find(f"{{{_NS}}}v")
                if value is None or value.text is None:
                    raise _untrusted("Required transaction value missing")
                try:
                    number = Decimal(value.text)
                except InvalidOperation as exc:
                    raise _untrusted("Transaction value malformed") from exc
                if not number.is_finite():
                    raise _untrusted("Non-finite transaction")
                output[ref] = number
            elif ref == "C10":
                if formula is None or not formula.text or formula.attrib:
                    raise _untrusted("Total requires an ordinary formula")
                if len(formula.text) > 160 or any(x in formula.text for x in ("[", "]", "!")):
                    raise _untrusted("External or unsupported formula")
                output[ref] = "=" + formula.text
    if not _INPUTS.issubset(output) or not isinstance(output.get("C10"), str):
        raise _untrusted("Required budget cells are missing")
    return {cell: output[cell] for cell in (*sorted(_INPUTS), "C10")}


def extract_budget_snapshot(blob: bytes, *, filename: str) -> dict[str, object]:
    """Read Budget!C2:C10 as structured values, never authoritative evidence."""
    parts = _read_safe_parts(blob, filename)
    _validate_content_types(parts["[Content_Types].xml"])
    relationship_id = _validate_workbook(parts["xl/workbook.xml"])
    _check_relationships(parts["_rels/.rels"],
                         f"{_DOC_REL_NS}/officeDocument", "xl/workbook.xml")
    _check_relationships(parts["xl/_rels/workbook.xml.rels"],
                         f"{_DOC_REL_NS}/worksheet",
                         "worksheets/sheet1.xml", relationship_id)
    return _extract_sheet(parts[_WS])
