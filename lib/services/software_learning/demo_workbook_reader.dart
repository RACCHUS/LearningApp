import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Restricted preview reader, not the authoritative isolated upload worker.
class DemoWorkbookReader {
  static const maxEntries = 20;
  static const maxPartBytes = 64 * 1024;
  static const maxExpandedBytes = 256 * 1024;
  static const _sheetNs =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _relNs =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const _docRelNs =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static Map<String, ({String? formula, double? value})> read(
    Uint8List bytes,
    String fileName,
  ) {
    final parts = _readParts(bytes, fileName);
    final rootRels = _document(parts, '_rels/.rels', 'Relationships', _relNs)
        .findElements('Relationship', namespace: _relNs)
        .where((rel) => rel.getAttribute('Type') == '$_docRelNs/officeDocument')
        .toList();
    if (rootRels.length != 1 ||
        ![
          'xl/workbook.xml',
          '/xl/workbook.xml',
        ].contains(rootRels.single.getAttribute('Target')) ||
        ![
          null,
          'Internal',
        ].contains(rootRels.single.getAttribute('TargetMode'))) {
      throw const FormatException('Invalid package workbook relationship.');
    }
    final workbook = _document(parts, 'xl/workbook.xml', 'workbook', _sheetNs);
    final sheets = workbook
        .findElements('sheets', namespace: _sheetNs)
        .single
        .findElements('sheet', namespace: _sheetNs)
        .where(
          (sheet) =>
              sheet.getAttribute('name')?.trim().toLowerCase() == 'budget',
        )
        .toList();
    if (sheets.length != 1) {
      throw const FormatException('Expected exactly one Budget worksheet.');
    }
    final id = sheets.single.getAttribute('id', namespace: _docRelNs);
    final rels = _document(
      parts,
      'xl/_rels/workbook.xml.rels',
      'Relationships',
      _relNs,
    );
    final ids = <String>{};
    String? target;
    for (final rel in rels.findElements('Relationship', namespace: _relNs)) {
      final relId = rel.getAttribute('Id');
      if (relId == null ||
          !ids.add(relId) ||
          ![null, 'Internal'].contains(rel.getAttribute('TargetMode'))) {
        throw const FormatException('Invalid workbook relationship.');
      }
      if (relId == id) {
        if (rel.getAttribute('Type') != '$_docRelNs/worksheet') {
          throw const FormatException('Budget is not a worksheet.');
        }
        target = rel.getAttribute('Target');
      }
    }
    if (target == null ||
        !RegExp(
          r'^/?(?:xl/)?worksheets/sheet[1-9][0-9]*\.xml$',
        ).hasMatch(target)) {
      throw const FormatException('Missing or unsafe Budget relationship.');
    }
    final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final sheet = _document(parts, path, 'worksheet', _sheetNs);
    final cells = <String, ({String? formula, double? value})>{};
    final data = sheet.findElements('sheetData', namespace: _sheetNs).single;
    for (final row in data.findElements('row', namespace: _sheetNs)) {
      for (final cell in row.findElements('c', namespace: _sheetNs)) {
        final ref = cell.getAttribute('r');
        if (ref == null || cells.containsKey(ref)) {
          throw const FormatException('Missing or duplicate cell reference.');
        }
        final formulas = cell.findElements('f', namespace: _sheetNs).toList();
        final values = cell.findElements('v', namespace: _sheetNs).toList();
        if (formulas.length > 1 || values.length > 1) {
          throw const FormatException('Ambiguous cell contents.');
        }
        final numeric =
            cell.getAttribute('t') == null || cell.getAttribute('t') == 'n';
        final value = numeric && values.length == 1
            ? double.tryParse(values.single.innerText)
            : null;
        cells[ref] = (
          formula: numeric && formulas.length == 1
              ? formulas.single.innerText
              : null,
          value: value != null && value.isFinite ? value : null,
        );
      }
    }
    return cells;
  }

  static XmlElement _document(
    Map<String, String> parts,
    String path,
    String name,
    String namespace,
  ) {
    final content = parts[path];
    if (content == null) {
      throw const FormatException('Missing required workbook part.');
    }
    final root = XmlDocument.parse(content).rootElement;
    if (root.name.local != name || root.namespaceUri != namespace) {
      throw const FormatException('Invalid workbook XML root.');
    }
    return root;
  }

  static Map<String, String> _readParts(Uint8List bytes, String fileName) {
    if (!fileName.toLowerCase().endsWith('.xlsx') ||
        bytes.length < 22 ||
        bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('Invalid workbook size or extension.');
    }
    // The preview supports ordinary single-disk ZIPs without archive comments.
    // Bound the directory before archive allocates headers or reads any parts.
    final end = ByteData.sublistView(bytes, bytes.length - 22);
    final entries = end.getUint16(10, Endian.little);
    final directorySize = end.getUint32(12, Endian.little);
    final directoryOffset = end.getUint32(16, Endian.little);
    if (end.getUint32(0, Endian.little) != 0x06054b50 ||
        end.getUint16(4, Endian.little) != 0 ||
        end.getUint16(6, Endian.little) != 0 ||
        end.getUint16(8, Endian.little) != entries ||
        end.getUint16(20, Endian.little) != 0 ||
        entries == 0 ||
        entries > maxEntries ||
        directorySize > 16 * 1024 ||
        directoryOffset + directorySize != bytes.length - 22) {
      throw const FormatException('Unsupported or over-limit ZIP directory.');
    }
    final directory = ZipDirectory.read(InputStream(bytes));
    if (directory.fileHeaders.length != entries) {
      throw const FormatException('ZIP entry count mismatch.');
    }
    final parts = <String, String>{};
    var expanded = 0;
    for (final header in directory.fileHeaders) {
      final file = header.file!;
      final size = header.uncompressedSize!;
      final compressed = header.compressedSize!;
      final name = header.filename;
      expanded += size;
      if (parts.containsKey(name) ||
          !_allowedPart(name) ||
          header.generalPurposeBitFlag & 1 != 0 ||
          file.flags & 1 != 0 ||
          header.compressionMethod != file.compressionMethod ||
          (header.externalFileAttributes! >> 16) & 0xf000 == 0xa000 ||
          ![0, 8].contains(file.compressionMethod) ||
          size < 1 ||
          size > maxPartBytes ||
          expanded > maxExpandedBytes ||
          size > compressed * 100 ||
          file.uncompressedSize != size ||
          file.compressedSize != compressed) {
        throw const FormatException('Unsafe or over-limit workbook part.');
      }
      final output = _BoundedOutput(size);
      if (file.compressionMethod == 8) {
        Inflate.stream(file.rawContent!, output);
      } else {
        output.writeInputStream(file.rawContent!);
      }
      final content = output.getBytes();
      if (content.length != size || getCrc32(content) != header.crc32) {
        throw const FormatException('Workbook part size or checksum mismatch.');
      }
      final xml = utf8.decode(content);
      final lower = xml.toLowerCase();
      if (xml.contains('\x00') ||
          lower.contains('<!doctype') ||
          lower.contains('<!entity') ||
          lower.contains('<![cdata[')) {
        throw const FormatException('Unsupported XML declarations.');
      }
      // Validate every part, not just the sheet selected for the rubric.
      XmlDocument.parse(xml);
      parts[name] = xml;
    }
    if (!parts.keys.toSet().containsAll({
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/_rels/workbook.xml.rels',
    })) {
      throw const FormatException('Missing required package components.');
    }
    return parts;
  }

  static bool _allowedPart(String name) =>
      const {
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/sharedStrings.xml',
        'docProps/core.xml',
        'docProps/app.xml',
      }.contains(name) ||
      RegExp(r'^xl/worksheets/sheet[1-9][0-9]*\.xml$').hasMatch(name);
}

/// Enforces the limit while inflating, even when ZIP metadata lies.
class _BoundedOutput extends OutputStream {
  final int limit;

  _BoundedOutput(this.limit) : super(size: limit);

  void _check(int additional) {
    if (length + additional > limit) {
      throw const FormatException('Expanded workbook part exceeds its limit.');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, [int? len]) {
    _check(len ?? bytes.length);
    super.writeBytes(bytes, len);
  }

  @override
  void writeInputStream(InputStreamBase stream) {
    _check(stream.length);
    super.writeInputStream(stream);
  }
}
