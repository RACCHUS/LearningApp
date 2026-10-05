import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/assessment_engine/mock_exam_session.dart';
import '../../providers/assessment_engine_provider.dart';
import '../../widgets/assessment/assessment_item_renderer.dart';
import 'exam_report_screen.dart';

class MockExamScreen extends ConsumerStatefulWidget {
  final MockExamSession initialSession;

  const MockExamScreen({
    super.key,
    required this.initialSession,
  });

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  int _currentIndex = 0;
  bool _isAutoSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(examSessionProvider.notifier).startSession(widget.initialSession);
    });
  }

  void _onAnswerChanged(String itemId, dynamic response) {
    ref.read(examSessionProvider.notifier).recordResponse(itemId, response);
  }

  void _toggleFlag(String itemId) {
    ref.read(examSessionProvider.notifier).toggleFlag(itemId);
  }

  void _nextQuestion(int totalQuestions) {
    if (_currentIndex < totalQuestions - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _jumpToQuestion(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _confirmFinishExam(MockExamSession session) async {
    final unanswered = session.unansweredCount;
    final flagged = session.flaggedCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Finish & Submit Exam?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to end your exam session?',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (unanswered > 0) ...[
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$unanswered unanswered question${unanswered == 1 ? '' : 's'}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (flagged > 0) ...[
                Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: Color(0xFF6366F1), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$flagged flagged question${flagged == 1 ? '' : 's'} for review',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Review Questions',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Submit Final Exam',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      _executeSubmission();
    }
  }

  void _executeSubmission() {
    final report = ref.read(examSessionProvider.notifier).submitExam();
    if (report != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExamReportScreen(report: report),
        ),
      );
    }
  }

  void _showQuestionMatrixSheet(BuildContext context, MockExamSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question Navigator',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Legend
              Wrap(
                spacing: 12,
                children: [
                  _buildLegendItem(const Color(0xFF10B981), 'Answered', isDark),
                  _buildLegendItem(const Color(0xFF6366F1), 'Flagged', isDark),
                  _buildLegendItem(const Color(0xFF3B82F6), 'Current', isDark),
                  _buildLegendItem(isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), 'Unanswered', isDark),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: session.items.length,
                  itemBuilder: (context, idx) {
                    final item = session.items[idx];
                    final isAnswered = session.isItemAnswered(item.id);
                    final isFlagged = session.isItemFlagged(item.id);
                    final isCurrent = idx == _currentIndex;

                    Color bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
                    Color textCol = isDark ? Colors.white : const Color(0xFF1E293B);
                    Border? border;

                    if (isCurrent) {
                      border = Border.all(color: const Color(0xFF3B82F6), width: 2.0);
                    }

                    if (isAnswered) {
                      bg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15);
                      textCol = const Color(0xFF10B981);
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _jumpToQuestion(idx);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: border,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${idx + 1}',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textCol,
                              ),
                            ),
                            if (isFlagged)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(Icons.flag_rounded, size: 13, color: Color(0xFF6366F1)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(examSessionProvider) ?? widget.initialSession;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Check timer expiration
    if (session.status == ExamSessionStatus.expired && !_isAutoSubmitting) {
      _isAutoSubmitting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Time has expired! Submitting your examination...'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        _executeSubmission();
      });
    }

    final totalQuestions = session.items.length;
    if (totalQuestions == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Simulation')),
        body: const Center(child: Text('No exam items generated.')),
      );
    }

    final currentItem = session.items[_currentIndex];
    final isFlagged = session.isItemFlagged(currentItem.id);
    final currentDomainCode = session.itemDomainMap[currentItem.id] ?? '1.0';
    final remainingTime = session.remainingDuration;
    final isCriticalTime = remainingTime.inMinutes < 2;
    final isWarningTime = remainingTime.inMinutes < 10 && !isCriticalTime;

    Color timerColor = theme.colorScheme.primary;
    if (isCriticalTime) {
      timerColor = const Color(0xFFEF4444);
    } else if (isWarningTime) {
      timerColor = const Color(0xFFF59E0B);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Exit Exam',
          onPressed: () => _confirmFinishExam(session),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.blueprint.examCode,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Domain $currentDomainCode',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          // Countdown Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: timerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: timerColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 16, color: timerColor),
                const SizedBox(width: 5),
                Text(
                  _formatDuration(remainingTime),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: timerColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Question Navigator Matrix Button
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Question Matrix',
            onPressed: () => _showQuestionMatrixSheet(context, session),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sub-header Progress Indicator
            LinearProgressIndicator(
              value: session.progressRatio,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              minHeight: 3.5,
            ),
            // Exam Item Body
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Question Header: Index & Flag Chip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question ${_currentIndex + 1} of $totalQuestions',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                              ),
                            ),
                            ActionChip(
                              avatar: Icon(
                                isFlagged ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                                size: 16,
                                color: isFlagged ? const Color(0xFF6366F1) : Colors.grey,
                              ),
                              label: Text(
                                isFlagged ? 'Flagged for Review' : 'Flag Question',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isFlagged ? const Color(0xFF6366F1) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                ),
                              ),
                              backgroundColor: isFlagged
                                  ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              side: BorderSide(
                                color: isFlagged
                                    ? const Color(0xFF6366F1)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              onPressed: () => _toggleFlag(currentItem.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Assessment Item Renderer in Exam Mode
                        Expanded(
                          child: AssessmentItemRenderer(
                            key: ValueKey(currentItem.id),
                            item: currentItem,
                            isExamMode: true,
                            initialResponse: session.userResponses[currentItem.id],
                            onResponseChanged: (res) => _onAnswerChanged(currentItem.id, res),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom Action Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous Question Button
                    OutlinedButton.icon(
                      onPressed: _currentIndex > 0 ? _previousQuestion : null,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Previous'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    // Submit Exam Button
                    ElevatedButton(
                      onPressed: () => _confirmFinishExam(session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Finish Exam',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Next Question Button
                    ElevatedButton.icon(
                      onPressed: _currentIndex < totalQuestions - 1
                          ? () => _nextQuestion(totalQuestions)
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Next'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
