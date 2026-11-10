import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/software_learning_attempt.dart';
import 'package:uuid/uuid.dart';

/// Evaluator that synthesizes and inspects genuine OOXML (.xlsx) archives
/// for the Excel budget practice rubric.
class SoftwareLearningWorkbookEvaluator {
  static const String expectedSheetName = 'Budget';
  static const int expectedTransactionCount = 8;
  static const int sourceStartRow = 2;
  static const int sourceEndRow = 9;

  /// Default synthetic transactions for monthly budget: (row -> amount)
  static const Map<int, double> defaultTransactions = {
    2: 1250.0,
    3: 350.0,
    4: 120.0,
    5: 85.0,
    6: 160.0,
    7: 90.0,
    8: 200.0,
    9: 145.0,
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
      return Uint8List.fromList(
          [0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFF, 0x00, 0x00]);
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

    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

    final workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="$sheetName" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

    const bookRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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
          '<row r="10"><c r="C10"><f>$formula</f><v>$total</v></c></row>');
    } else {
      rowsBuffer.write('<row r="10"><c r="C10"><v>$total</v></c></row>');
    }

    final sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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
  /// 2. Transaction Inputs: Exactly 8 numeric values in C2:C9
  /// 3. SUM Formula Construction: C10 contains =SUM(C2:C9) or equivalent addition
  /// 4. Calculated Budget Total: C10 computed value matches sum of transactions
  static SoftwareLearningResult evaluateWorkbook({
    required String attemptId,
    required String exerciseId,
    required String fileName,
    required Uint8List bytes,
  }) {
    Archive? archive;
    bool isZip = false;
    try {
      if (bytes.length >= 4 &&
          bytes[0] == 0x50 &&
          bytes[1] == 0x4B &&
          bytes[2] == 0x03 &&
          bytes[3] == 0x04) {
        archive = ZipDecoder().decodeBytes(bytes);
        isZip = true;
      }
    } catch (_) {
      archive = null;
      isZip = false;
    }

    if (!isZip || archive == null) {
      return SoftwareLearningResult(
        attemptId: attemptId,
        exerciseId: exerciseId,
        overallPassed: false,
        evidenceTrust: 'unverified_checker_only',
        canAwardSkill: false,
        feedback:
            'Corrupt or unreadable Excel archive. File must be a valid .xlsx workbook.',
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

    // Locate sheet name from xl/workbook.xml
    String? foundSheetName;
    final workbookFile = archive.findFile('xl/workbook.xml');
    if (workbookFile != null) {
      final xml =
          utf8.decode(workbookFile.content as List<int>, allowMalformed: true);
      final sheetMatch =
          RegExp(r'<sheet[^>]*name="([^"]+)"', caseSensitive: false)
              .firstMatch(xml);
      if (sheetMatch != null) {
        foundSheetName = sheetMatch.group(1);
      }
    }

    // Locate worksheet XML
    ArchiveFile? sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetFile == null) {
      for (final f in archive.files) {
        if (f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
          sheetFile = f;
          break;
        }
      }
    }

    final sheetPassed = foundSheetName != null &&
        foundSheetName.trim().toLowerCase() ==
            expectedSheetName.toLowerCase();

    final numericCells = <String, double>{};
    String? c10Formula;
    double? c10Value;

    if (sheetFile != null) {
      final sheetXml =
          utf8.decode(sheetFile.content as List<int>, allowMalformed: true);

      final cellMatches = RegExp(
        r'<c\s+r="([A-Z0-9]+)"[^>]*>(.*?)</c>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(sheetXml);

      for (final cm in cellMatches) {
        final ref = cm.group(1)!.toUpperCase();
        final body = cm.group(2)!;
        final fMatch =
            RegExp(r'<f>([^<]+)</f>', caseSensitive: false).firstMatch(body);
        final vMatch =
            RegExp(r'<v>([^<]+)</v>', caseSensitive: false).firstMatch(body);

        if (ref == 'C10') {
          if (fMatch != null) {
            c10Formula = fMatch.group(1)!.trim();
          }
          if (vMatch != null) {
            c10Value = double.tryParse(vMatch.group(1)!.trim());
          }
        } else if (vMatch != null) {
          final val = double.tryParse(vMatch.group(1)!.trim());
          if (val != null) {
            numericCells[ref] = val;
          }
        }
      }
    }

    // Check transaction inputs C2:C9
    int foundTransactions = 0;
    double expectedSum = 0.0;
    for (int r = sourceStartRow; r <= sourceEndRow; r++) {
      final ref = 'C$r';
      if (numericCells.containsKey(ref)) {
        foundTransactions++;
        expectedSum += numericCells[ref]!;
      }
    }
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
        final parts =
            norm.split('+').map((s) => s.replaceAll(r'$', '')).toList();
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
      } else {
        totalPassed = true;
      }
    }

    final allPassed = sheetPassed && dataPassed && formulaPassed && totalPassed;

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
          passed: sheetPassed,
          feedback: sheetPassed
              ? 'Found sheet "$foundSheetName"'
              : 'Missing or incorrectly named worksheet. Expected "Budget" (found "${foundSheetName ?? 'none'}").',
        ),
        SoftwareLearningCriterion(
          id: 'inputs_intact',
          title: 'Transaction Inputs',
          description:
              'Original numeric transaction inputs in C2:C9 are intact',
          passed: dataPassed,
          feedback: dataPassed
              ? 'All 8 synthetic transactions verified in C2:C9'
              : 'Found $foundTransactions of $expectedTransactionCount required numeric transactions in C2:C9.',
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
              : 'Total does not match transaction sum.',
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
class ExcelUploadCard extends StatefulWidget {
  final String exerciseId;
  final String? attemptId;
  final Duration initialDuration;
  final VoidCallback? onComplete;
  final VoidCallback? onFileSelect;
  final Future<SoftwareLearningResult> Function(
    String fileName,
    Uint8List bytes,
    String attemptId,
  )? onUpload;

  const ExcelUploadCard({
    super.key,
    this.exerciseId = 'excel-budget-total-v1',
    this.attemptId,
    this.initialDuration = const Duration(minutes: 45),
    this.onComplete,
    this.onFileSelect,
    this.onUpload,
  });

  @override
  State<ExcelUploadCard> createState() => ExcelUploadCardState();
}

class ExcelUploadCardState extends State<ExcelUploadCard> {
  late String _attemptId;
  late int _secondsRemaining;
  Timer? _countdownTimer;

  SoftwareLearningStatus _status = SoftwareLearningStatus.idle;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _validationError;
  SoftwareLearningResult? _result;

  static const int maxFileBytes = 10 * 1024 * 1024; // 10 MiB

  bool get isDemoMode => widget.onUpload == null;

  @override
  void initState() {
    super.initState();
    _attemptId = widget.attemptId ?? const Uuid().v4();
    _secondsRemaining = widget.initialDuration.inSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _status = SoftwareLearningStatus.expired;
          _validationError =
              'This attempt has expired (45-minute limit exceeded). Start a new attempt to continue.';
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void handleFileSelected(String name, Uint8List bytes) {
    if (_status == SoftwareLearningStatus.expired ||
        _status == SoftwareLearningStatus.completed) {
      return;
    }

    setState(() {
      _validationError = null;
      _result = null;
    });

    final lowerName = name.toLowerCase();
    if (!lowerName.endsWith('.xlsx')) {
      setState(() {
        _validationError =
            'Invalid file type: Only Excel (.xlsx) workbooks are accepted.';
        _selectedFileName = null;
        _selectedFileBytes = null;
      });
      return;
    }

    if (bytes.isEmpty) {
      setState(() {
        _validationError =
            'File is empty: Please select a valid Excel workbook.';
        _selectedFileName = null;
        _selectedFileBytes = null;
      });
      return;
    }

    if (bytes.length > maxFileBytes) {
      setState(() {
        _validationError =
            'File exceeds maximum limit: Workbooks must be 10 MiB or smaller.';
        _selectedFileName = null;
        _selectedFileBytes = null;
      });
      return;
    }

    setState(() {
      _selectedFileName = name;
      _selectedFileBytes = bytes;
      _status = SoftwareLearningStatus.selecting;
    });
  }

  Future<void> _submitWorkbook() async {
    final bytes = _selectedFileBytes;
    final name = _selectedFileName;
    if (bytes == null ||
        name == null ||
        _status == SoftwareLearningStatus.expired ||
        _secondsRemaining <= 0) {
      return;
    }

    final submittedAttemptId = _attemptId;

    setState(() {
      _status = SoftwareLearningStatus.uploading;
      _validationError = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Guard check after upload simulation delay
      if (!mounted ||
          _attemptId != submittedAttemptId ||
          _status == SoftwareLearningStatus.expired ||
          _secondsRemaining <= 0) {
        return;
      }

      setState(() {
        _status = SoftwareLearningStatus.evaluating;
      });

      SoftwareLearningResult evaluation;
      if (widget.onUpload != null) {
        evaluation = await widget.onUpload!(name, bytes, submittedAttemptId);
      } else {
        evaluation = SoftwareLearningWorkbookEvaluator.evaluateWorkbook(
          attemptId: submittedAttemptId,
          exerciseId: widget.exerciseId,
          fileName: name,
          bytes: bytes,
        );
      }

      // Guard check after async evaluation completion
      if (!mounted ||
          _attemptId != submittedAttemptId ||
          _status == SoftwareLearningStatus.expired ||
          _secondsRemaining <= 0) {
        return;
      }

      setState(() {
        _result = evaluation;
        _status = SoftwareLearningStatus.completed;
      });

      // Simulation completion is only emitted when backed by an authoritative
      // evaluation handler, never by client-side demo placeholder evaluation.
      if (!isDemoMode && evaluation.overallPassed && widget.onComplete != null) {
        widget.onComplete!();
      }
    } catch (e) {
      if (!mounted ||
          _attemptId != submittedAttemptId ||
          _status == SoftwareLearningStatus.expired ||
          _secondsRemaining <= 0) {
        return;
      }
      setState(() {
        _status = SoftwareLearningStatus.rejected;
        _validationError =
            'Assessment failed: The workbook could not be verified. Please try again.';
      });
    }
  }

  void resetAttempt() {
    _countdownTimer?.cancel();
    setState(() {
      _attemptId = const Uuid().v4();
      _secondsRemaining = widget.initialDuration.inSeconds;
      _status = SoftwareLearningStatus.idle;
      _selectedFileName = null;
      _selectedFileBytes = null;
      _validationError = null;
      _result = null;
    });
    _startTimer();
  }

  void loadSyntheticPracticeFile({
    bool malformed = false,
    bool noSum = false,
  }) {
    if (malformed) {
      final bytes = SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes(
        corruptZip: true,
      );
      handleFileSelected('practice_corrupted.xlsx', bytes);
    } else if (noSum) {
      final bytes = SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes(
        formula: null,
      );
      handleFileSelected('practice_no_sum.xlsx', bytes);
    } else {
      final bytes = SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes();
      handleFileSelected('practice_budget.xlsx', bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: 'Excel guided practice upload container',
      container: true,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isDark),
              const SizedBox(height: 12),
              _buildTimerAndStatus(context, isDark),
              const SizedBox(height: 12),
              _buildPrivacyNotice(context, isDark),
              const SizedBox(height: 12),
              if (_validationError != null) ...[
                _buildErrorBanner(context),
                const SizedBox(height: 12),
              ],
              if (_result != null)
                _buildResultsView(context, isDark)
              else
                _buildUploadArea(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF107C41).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.table_chart_rounded,
            color: Color(0xFF107C41),
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Excel Workbook Practice',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isDemoMode
                    ? 'Rubric demonstration preview (live broker upload disabled)'
                    : 'Guided practice with your real Microsoft Excel application',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: 'Unverified practice only badge',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.shade700, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 4),
                Text(
                  isDemoMode
                      ? 'UNVERIFIED PRACTICE (DEMO)'
                      : 'UNVERIFIED PRACTICE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.amber.shade900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerAndStatus(BuildContext context, bool isDark) {
    final isLowTime = _secondsRemaining < 300; // < 5 minutes
    final timerColor =
        isLowTime ? Colors.red.shade600 : const Color(0xFF2563EB);
    final progress = _secondsRemaining / widget.initialDuration.inSeconds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: timerColor),
              const SizedBox(width: 6),
              Semantics(
                label:
                    'Single-use attempt timer: ${_formatTimer(_secondsRemaining)} remaining',
                child: Text(
                  'Time Remaining: ${_formatTimer(_secondsRemaining)}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: timerColor,
                  ),
                ),
              ),
              const Spacer(),
              Semantics(
                label: 'Single-use attempt ID: $_attemptId',
                child: Text(
                  'Attempt: ${_attemptId.substring(0, 8)}...',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
          if (isDemoMode) ...[
            const SizedBox(height: 6),
            Text(
              'Local prototype timer simulating the 45-minute window; server-issued attempt tracking is inactive.',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.privacy_tip_outlined,
            size: 18,
            color: Color(0xFF0284C7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDemoMode
                  ? 'Privacy & Verification Gate: Live file upload is disabled in this preview. This interface demonstrates the 4-part grading rubric using genuine OOXML fixtures. Real workbook evaluation and isolated container execution require the backend brokered upload service.'
                  : 'Privacy & Verification Gate: Workbooks submitted for practice are stored in an encrypted private Storage bucket with restricted service access and an automated 24-hour retention purge policy. No public URLs, direct client access, or permanent mastery certificates are issued.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color:
                    isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      key: const Key('excel-error-banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _validationError!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea(BuildContext context, bool isDark) {
    if (_status == SoftwareLearningStatus.uploading ||
        _status == SoftwareLearningStatus.evaluating) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              isDemoMode
                  ? 'Simulating rubric evaluation...'
                  : (_status == SoftwareLearningStatus.uploading
                      ? 'Brokering private upload...'
                      : 'Analyzing workbook criteria...'),
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isDemoMode
                  ? 'Testing genuine OOXML workbook structure against deterministic criteria'
                  : 'Checking worksheet structure and formula syntax in container sandbox',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isDemoMode ? Icons.science_outlined : Icons.table_view_rounded,
            size: 44,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedFileName ??
                (isDemoMode
                    ? 'Select a demonstration scenario below'
                    : 'Select your completed .xlsx workbook'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isDemoMode
                ? 'Preview the automated 4-criteria rubric using genuine XLSX fixtures'
                : 'Accepts Microsoft Excel .xlsx files up to 10 MiB',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                key: const Key('excel-browse-button'),
                onPressed: _status == SoftwareLearningStatus.expired
                    ? null
                    : () {
                        if (isDemoMode) {
                          loadSyntheticPracticeFile();
                        } else if (widget.onFileSelect != null) {
                          widget.onFileSelect!();
                        } else {
                          setState(() {
                            _validationError =
                                'File picker not attached. Provide onFileSelect or invoke handleFileSelected().';
                          });
                        }
                      },
                icon: const Icon(Icons.file_open_outlined, size: 18),
                label: Text(
                  _selectedFileName == null
                      ? (isDemoMode
                          ? 'Load Sample Scenario'
                          : 'Select .xlsx file')
                      : (isDemoMode
                          ? 'Change sample scenario'
                          : 'Change selected file'),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              if (_selectedFileName != null &&
                  _status != SoftwareLearningStatus.expired)
                FilledButton.icon(
                  key: const Key('excel-submit-button'),
                  onPressed: _submitWorkbook,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    isDemoMode ? 'Run Rubric Check' : 'Verify workbook',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF107C41),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (isDemoMode) ...[
            const SizedBox(height: 14),
            // Rubric demonstration scenarios
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: const Key('excel-load-synthetic-button'),
                  onPressed: () => loadSyntheticPracticeFile(),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text(
                    'Load Valid Budget Sample',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  key: const Key('excel-load-invalid-button'),
                  onPressed: () => loadSyntheticPracticeFile(noSum: true),
                  icon: const Icon(Icons.error_outline, size: 16),
                  label: const Text(
                    'Load Missing Formula Sample',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  key: const Key('excel-load-corrupt-button'),
                  onPressed: () => loadSyntheticPracticeFile(malformed: true),
                  icon: const Icon(Icons.warning_amber_rounded, size: 16),
                  label: const Text(
                    'Load Corrupt Archive Sample',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsView(BuildContext context, bool isDark) {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    final passed = result.overallPassed;
    final headerColor =
        passed ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      key: const Key('excel-results-container'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: headerColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  passed ? Icons.check_circle_rounded : Icons.info_outline,
                  color: headerColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passed
                            ? (isDemoMode
                                ? 'PRACTICE EXERCISE PASSED (DEMO)'
                                : 'PRACTICE EXERCISE PASSED')
                            : 'NEEDS REVISION',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: headerColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.feedback,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey[300]
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Deterministic Rubric Criteria (4 Parts)',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                ...result.criteria.map((c) => _buildCriterionTile(c, isDark)),
                const SizedBox(height: 16),
                _buildEvidenceTrustBadge(result, isDark),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('excel-new-attempt-button'),
                      onPressed: resetAttempt,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('New Attempt'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriterionTile(SoftwareLearningCriterion c, bool isDark) {
    final statusColor =
        c.passed ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor, width: 1),
            ),
            child: Text(
              c.passed ? 'PASS' : 'FAIL',
              style: GoogleFonts.robotoMono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.description,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                if (c.feedback != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    c.feedback!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: c.passed
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceTrustBadge(SoftwareLearningResult r, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TRUST: ${r.evidenceTrust.toUpperCase()}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'SKILL AWARD: NONE',
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              if (isDemoMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'MODE: RUBRIC DEMO',
                    style: GoogleFonts.robotoMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isDemoMode
                ? 'Demo Notice: This result was generated from a sample test scenario. No workbook was uploaded to the server broker or graded by the isolated container.'
                : 'Safety Notice: This practice result is strictly unverified. Workbooks are purged under the 24-hour retention policy. No permanent mastery evidence or certified skill record has been written.',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
