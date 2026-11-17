import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:learning_pwa/models/software_learning_attempt.dart';
import 'package:learning_pwa/services/software_learning/demo_workbook_reader.dart';

// Moved unchanged from widgets/software_learning/excel_upload_card.dart
// (code-efficiency plan §14, Pilot B). This is the browser-side practice
// rubric. It is NOT the authoritative upload checker (the Python worker),
// and DemoWorkbookReader stays a separate, restricted preview reader.
/// Evaluator that synthesizes and inspects genuine OOXML (.xlsx) archives
/// for the Excel budget practice rubric.
class SoftwareLearningWorkbookEvaluator {
  static const String expectedSheetName = 'Budget';
  static const int expectedTransactionCount = 8;
  static const int sourceStartRow = 2;
  static const int sourceEndRow = 9;

  /// Default synthetic transactions for monthly budget: (row -> amount)
  static const Map<int, double> defaultTransactions = {
    2: 20.0,
    3: 30.0,
    4: 40.0,
    5: 50.0,
    6: 60.0,
    7: 70.0,
    8: 80.0,
    9: 90.0,
  };

  static double get defaultSum =>
      defaultTransactions.values.reduce((a, b) => a + b);

  /// Synthesizes valid OOXML (.xlsx) bytes containing genuine package parts:
  /// - [Content_Types].xml
  /// - _rels/.rels
  /// - xl/workbook.xml (with sheet named [sheetName])
  /// - xl/_rels/workbook.xml.rels
  /// - xl/worksheets/sheet1.xml (with rows C2:C9 and formula in C10)
  static Uint8List createSampleWorkbookBytes({
    String sheetName = expectedSheetName,
    Map<int, double>? transactions,
    String? formula = 'SUM(C2:C9)',
    double? calculatedTotal,
    bool corruptZip = false,
  }) {
    if (corruptZip) {
      return Uint8List.fromList([
        0x50,
        0x4B,
        0x03,
        0x04,
        0xFF,
        0xFF,
        0x00,
        0x00,
      ]);
    }

    final tx = transactions ?? defaultTransactions;
    final total = calculatedTotal ?? tx.values.reduce((a, b) => a + b);

    const typesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';

    const rootRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

    final workbookXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="$sheetName" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

    const bookRelsXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';

    final rowsBuffer = StringBuffer();
    for (int r = sourceStartRow; r <= sourceEndRow; r++) {
      final val = tx[r];
      if (val != null) {
        rowsBuffer.write('<row r="$r"><c r="C$r"><v>$val</v></c></row>');
      }
    }

    if (formula != null && formula.isNotEmpty) {
      rowsBuffer.write(
        '<row r="10"><c r="C10"><f>$formula</f><v>$total</v></c></row>',
      );
    } else {
      rowsBuffer.write('<row r="10"><c r="C10"><v>$total</v></c></row>');
    }

    final sheetXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    $rowsBuffer
  </sheetData>
</worksheet>''';

    final archive = Archive();
    void addFile(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addFile('[Content_Types].xml', typesXml);
    addFile('_rels/.rels', rootRelsXml);
    addFile('xl/workbook.xml', workbookXml);
    addFile('xl/_rels/workbook.xml.rels', bookRelsXml);
    addFile('xl/worksheets/sheet1.xml', sheetXml);

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded!);
  }

  /// Parses the OOXML (.xlsx) archive and evaluates the 4 deterministic criteria:
  /// 1. Worksheet Name: Sheet is named "Budget" (case-insensitive)
  /// 2. Transaction Inputs: Original fixed demo values in C2:C9
  /// 3. SUM Formula Construction: C10 contains =SUM(C2:C9) or equivalent addition
  /// 4. Calculated Budget Total: C10 has a finite matching numeric cache
  static SoftwareLearningResult evaluateWorkbook({
    required String attemptId,
    required String exerciseId,
    required String fileName,
    required Uint8List bytes,
  }) {
    Map<String, ({String? formula, double? value})>? cells;
    String? rejection;
    try {
      cells = DemoWorkbookReader.read(bytes, fileName);
    } on FormatException catch (error) {
      rejection = error.message;
    } on RangeError {
      rejection = 'Truncated ZIP data.';
    } on StateError {
      rejection = 'Missing or ambiguous worksheet structure.';
    }

    if (cells == null) {
      return SoftwareLearningResult(
        attemptId: attemptId,
        exerciseId: exerciseId,
        overallPassed: false,
        evidenceTrust: 'unverified_checker_only',
        canAwardSkill: false,
        feedback: 'Corrupt or unreadable Excel archive. $rejection',
        criteria: const [
          SoftwareLearningCriterion(
            id: 'sheet_name',
            title: 'Worksheet Name',
            description: 'Worksheet is named "Budget" (case-insensitive)',
            passed: false,
            feedback: 'Could not read archive contents.',
          ),
          SoftwareLearningCriterion(
            id: 'inputs_intact',
            title: 'Transaction Inputs',
            description:
                'Original numeric transaction inputs in C2:C9 are intact',
            passed: false,
            feedback: 'Could not inspect transaction rows.',
          ),
          SoftwareLearningCriterion(
            id: 'formula_syntax',
            title: 'SUM Formula Construction',
            description: 'Cell C10 contains formula summing range C2:C9',
            passed: false,
            feedback: 'Could not locate total cell C10.',
          ),
          SoftwareLearningCriterion(
            id: 'total_calculation',
            title: 'Calculated Budget Total',
            description: 'Cell C10 computed value matches expected sum',
            passed: false,
            feedback: 'Could not verify calculated total.',
          ),
        ],
      );
    }

    final c10Formula = cells['C10']?.formula;
    final c10Value = cells['C10']?.value;

    // Check transaction inputs C2:C9
    int foundTransactions = 0;
    for (int r = sourceStartRow; r <= sourceEndRow; r++) {
      final cell = cells['C$r'];
      if (cell?.formula == null && cell?.value == defaultTransactions[r]) {
        foundTransactions++;
      }
    }
    final expectedSum = defaultSum;
    final dataPassed = foundTransactions == expectedTransactionCount;

    // Check formula syntax for C10
    bool formulaPassed = false;
    if (c10Formula != null && c10Formula.isNotEmpty) {
      var norm = c10Formula.trim();
      if (norm.startsWith('=')) {
        norm = norm.substring(1).trim();
      }
      norm = norm.replaceAll(' ', '').toUpperCase();
      final isSumRange = RegExp(r'^SUM\(\$?C\$?2:\$?C\$?9\)$').hasMatch(norm);
      bool isDirectAddition = false;
      if (norm.contains('+')) {
        final parts = norm
            .split('+')
            .map((s) => s.replaceAll(r'$', ''))
            .toList();
        final expectedParts = List.generate(8, (i) => 'C${i + 2}');
        if (parts.length == 8 &&
            parts.toSet().length == 8 &&
            parts.toSet().containsAll(expectedParts)) {
          isDirectAddition = true;
        }
      }
      formulaPassed = isSumRange || isDirectAddition;
    }

    // Check calculated total
    bool totalPassed = false;
    if (dataPassed && formulaPassed) {
      if (c10Value != null) {
        totalPassed = (c10Value - expectedSum).abs() < 0.01;
      }
    }

    final allPassed = dataPassed && formulaPassed && totalPassed;

    return SoftwareLearningResult(
      attemptId: attemptId,
      exerciseId: exerciseId,
      overallPassed: allPassed,
      evidenceTrust: 'unverified_checker_only',
      canAwardSkill: false,
      feedback: allPassed
          ? 'Worksheet Budget correctly calculates the sum of the eight transaction rows using =SUM(C2:C9).'
          : 'The workbook does not satisfy all practice criteria. Ensure worksheet is named Budget and C10 contains =SUM(C2:C9).',
      criteria: [
        SoftwareLearningCriterion(
          id: 'sheet_name',
          title: 'Worksheet Name',
          description: 'Worksheet is named "Budget" (case-insensitive)',
          passed: true,
          feedback: 'Resolved the Budget worksheet through its relationship.',
        ),
        SoftwareLearningCriterion(
          id: 'inputs_intact',
          title: 'Transaction Inputs',
          description:
              'Original numeric transaction inputs in C2:C9 are intact',
          passed: dataPassed,
          feedback: dataPassed
              ? 'All 8 synthetic transactions verified in C2:C9'
              : 'Found $foundTransactions of $expectedTransactionCount unchanged numeric transactions in C2:C9.',
        ),
        SoftwareLearningCriterion(
          id: 'formula_syntax',
          title: 'SUM Formula Construction',
          description: 'Cell C10 contains formula summing range C2:C9',
          passed: formulaPassed,
          feedback: formulaPassed
              ? 'Formula verified: ${c10Formula != null ? (c10Formula.startsWith('=') ? c10Formula : "=$c10Formula") : "=SUM(C2:C9)"}'
              : (c10Formula != null
                    ? 'Cell C10 contains "$c10Formula", which does not sum range C2:C9.'
                    : 'Cell C10 does not contain a formula.'),
        ),
        SoftwareLearningCriterion(
          id: 'total_calculation',
          title: 'Calculated Budget Total',
          description: 'Cell C10 computed value matches expected sum',
          passed: totalPassed,
          feedback: totalPassed
              ? 'Calculated total (${c10Value?.toStringAsFixed(2) ?? expectedSum.toStringAsFixed(2)}) matches transaction sum'
              : 'Total is missing, nonnumeric, or does not match the original transaction sum. Recalculate and save the workbook.',
        ),
      ],
    );
  }
}

/// Accessible learner-facing Excel practice upload and evaluation card.
///
/// Implements the Excel pilot unverified practice interface:
/// - Prominent unverified/practice-only badge and privacy notice
/// - Single-use attempt state indicator
/// - 45-minute countdown timer with automatic lockout on expiry
/// - File selection zone validating .xlsx and <= 10 MiB limits
/// - Deterministic criterion result display with unverified evidence stamp
///
/// When [onUpload] is null, this card operates in prototype demonstration mode,
/// displaying sample scenarios and rubric checks without claiming container
/// execution or server-backed verification.
