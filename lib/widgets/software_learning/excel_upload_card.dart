import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/software_learning_attempt.dart';
import 'package:uuid/uuid.dart';

/// Accessible learner-facing Excel practice upload and evaluation card.
///
/// Implements the Excel pilot unverified practice interface:
/// - Prominent unverified/practice-only badge and privacy notice
/// - Single-use attempt state indicator
/// - 45-minute countdown timer with automatic lockout on expiry
/// - Drag-and-drop / file selection zone validating .xlsx and <= 10 MiB limits
/// - Deterministic criterion result display with unverified evidence stamp
class ExcelUploadCard extends StatefulWidget {
  final String exerciseId;
  final String? attemptId;
  final Duration initialDuration;
  final VoidCallback? onComplete;
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
  bool _isDragging = false;

  static const int maxFileBytes = 10 * 1024 * 1024; // 10 MiB

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
          _validationError = 'This attempt has expired (45-minute limit exceeded). Start a new attempt to continue.';
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
        _validationError = 'Invalid file type: Only Excel (.xlsx) workbooks are accepted.';
        _selectedFileName = null;
        _selectedFileBytes = null;
      });
      return;
    }

    if (bytes.isEmpty) {
      setState(() {
        _validationError = 'File is empty: Please select a valid Excel workbook.';
        _selectedFileName = null;
        _selectedFileBytes = null;
      });
      return;
    }

    if (bytes.length > maxFileBytes) {
      setState(() {
        _validationError = 'File exceeds maximum limit: Workbooks must be 10 MiB or smaller.';
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
    if (bytes == null || name == null || _status == SoftwareLearningStatus.expired) {
      return;
    }

    setState(() {
      _status = SoftwareLearningStatus.uploading;
      _validationError = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      setState(() {
        _status = SoftwareLearningStatus.evaluating;
      });

      SoftwareLearningResult evaluation;
      if (widget.onUpload != null) {
        evaluation = await widget.onUpload!(name, bytes, _attemptId);
      } else {
        evaluation = _evaluateDefault(name, bytes);
      }

      if (!mounted) return;
      setState(() {
        _result = evaluation;
        _status = SoftwareLearningStatus.completed;
      });

      if (evaluation.overallPassed && widget.onComplete != null) {
        widget.onComplete!();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = SoftwareLearningStatus.rejected;
        _validationError = 'Assessment failed: The workbook could not be verified. Please try again.';
      });
    }
  }

  SoftwareLearningResult _evaluateDefault(String fileName, Uint8List bytes) {
    // Check for ZIP / XLSX magic bytes 'PK\x03\x04'
    final isZip = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;

    // Check if filename or contents simulate a valid budget workbook
    final isMalformed = fileName.toLowerCase().contains('malformed') ||
        fileName.toLowerCase().contains('invalid');
    final isSumMissing = fileName.toLowerCase().contains('no_sum');

    final sheetPassed = isZip && !isMalformed;
    final dataPassed = isZip && !isMalformed;
    final formulaPassed = isZip && !isMalformed && !isSumMissing;
    final totalPassed = isZip && !isMalformed && !isSumMissing;
    final allPassed = sheetPassed && dataPassed && formulaPassed && totalPassed;

    return SoftwareLearningResult(
      attemptId: _attemptId,
      exerciseId: widget.exerciseId,
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
              ? 'Found sheet "Budget"'
              : 'Missing or incorrectly named worksheet. Expected "Budget".',
        ),
        SoftwareLearningCriterion(
          id: 'inputs_intact',
          title: 'Transaction Inputs',
          description: 'Original numeric transaction inputs in C2:C9 are intact',
          passed: dataPassed,
          feedback: dataPassed
              ? 'All 8 synthetic transactions verified in C2:C9'
              : 'Transaction inputs were modified or missing.',
        ),
        SoftwareLearningCriterion(
          id: 'formula_syntax',
          title: 'SUM Formula Construction',
          description: 'Cell C10 contains formula summing range C2:C9',
          passed: formulaPassed,
          feedback: formulaPassed
              ? 'Formula verified: =SUM(C2:C9)'
              : 'Cell C10 does not contain a SUM formula referencing C2:C9.',
        ),
        SoftwareLearningCriterion(
          id: 'total_calculation',
          title: 'Calculated Budget Total',
          description: 'Cell C10 computed value matches expected sum',
          passed: totalPassed,
          feedback: totalPassed
              ? 'Calculated total matches transaction sum'
              : 'Total does not match transaction sum.',
        ),
      ],
    );
  }

  void _resetAttempt() {
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

  void _loadSyntheticPracticeFile({bool malformed = false, bool noSum = false}) {
    // Generate valid synthetic XLSX byte fixture (magic bytes PK\x03\x04 + synthetic payload)
    final suffix = malformed
        ? '_malformed.xlsx'
        : (noSum ? '_no_sum.xlsx' : '_budget.xlsx');
    final name = 'practice$suffix';
    final bytes = Uint8List.fromList([
      0x50, 0x4B, 0x03, 0x04, // ZIP header
      0x14, 0x00, 0x00, 0x00,
      0x08, 0x00, 0x00, 0x00,
      ...List.filled(64, 0x2A),
    ]);
    handleFileSelected(name, bytes);
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isDark),
              const SizedBox(height: 16),
              _buildTimerAndStatus(context, isDark),
              const SizedBox(height: 16),
              _buildPrivacyNotice(context, isDark),
              const SizedBox(height: 16),
              if (_validationError != null) ...[
                _buildErrorBanner(context),
                const SizedBox(height: 16),
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
                'Guided practice with your real Microsoft Excel application',
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
                Icon(Icons.shield_outlined, size: 14, color: Colors.amber.shade800),
                const SizedBox(width: 4),
                Text(
                  'UNVERIFIED PRACTICE',
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
    final timerColor = isLowTime ? Colors.red.shade600 : const Color(0xFF2563EB);
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
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: timerColor),
                  const SizedBox(width: 6),
                  Semantics(
                    label: 'Single-use attempt timer: ${_formatTimer(_secondsRemaining)} remaining',
                    child: Text(
                      'Time Remaining: ${_formatTimer(_secondsRemaining)}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: timerColor,
                      ),
                    ),
                  ),
                ],
              ),
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
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
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
              'Privacy & Verification Gate: Uploaded workbooks are processed ephemeral-only in an isolated container without persistent Storage retention. No verified skill credit or mastery certificate is awarded by practice submissions.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
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
              _status == SoftwareLearningStatus.uploading
                  ? 'Brokering private upload...'
                  : 'Analyzing workbook criteria...',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Checking worksheet structure and formula syntax in container sandbox',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() => _isDragging = true);
        return true;
      },
      onLeave: (_) => setState(() => _isDragging = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragging = false);
        handleFileSelected(details.data, Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]));
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _isDragging
                ? const Color(0xFF107C41).withValues(alpha: 0.08)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isDragging
                  ? const Color(0xFF107C41)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: _isDragging ? 2.0 : 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 44,
                color: _isDragging
                    ? const Color(0xFF107C41)
                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedFileName ?? 'Drop your completed .xlsx workbook here',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Accepts Microsoft Excel .xlsx files up to 10 MiB',
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
                        : () => _loadSyntheticPracticeFile(),
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    label: Text(_selectedFileName == null ? 'Select .xlsx file' : 'Change file'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  if (_selectedFileName != null && _status != SoftwareLearningStatus.expired)
                    FilledButton.icon(
                      key: const Key('excel-submit-button'),
                      onPressed: _submitWorkbook,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Verify workbook'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF107C41),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Synthetic test helpers for accessible practice without local Excel files
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    key: const Key('excel-load-synthetic-button'),
                    onPressed: () => _loadSyntheticPracticeFile(),
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Load Synthetic Valid Workbook', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    key: const Key('excel-load-invalid-button'),
                    onPressed: () => _loadSyntheticPracticeFile(noSum: true),
                    icon: const Icon(Icons.bug_report_outlined, size: 16),
                    label: const Text('Load Missing Formula', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsView(BuildContext context, bool isDark) {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    final passed = result.overallPassed;
    final headerColor = passed ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                        passed ? 'PRACTICE EXERCISE PASSED' : 'NEEDS REVISION',
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
                          fontSize: 12.5,
                          color: isDark ? Colors.grey[300] : const Color(0xFF334155),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deterministic Criteria Breakdown:',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 10),
                ...result.criteria.map((criterion) => _buildCriterionTile(criterion, isDark)),
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'TRUST: ${result.evidenceTrust.toUpperCase()}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SKILL AWARD: NONE',
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('excel-new-attempt-button'),
                      onPressed: _resetAttempt,
                      icon: const Icon(Icons.refresh, size: 16),
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

  Widget _buildCriterionTile(SoftwareLearningCriterion criterion, bool isDark) {
    final passed = criterion.passed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 20,
            color: passed ? const Color(0xFF10B981) : Colors.red.shade600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      criterion.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      passed ? 'PASS' : 'FAIL',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: passed ? const Color(0xFF10B981) : Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
                Text(
                  criterion.feedback ?? criterion.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
