import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/assessment_engine/adaptive_practice_state.dart';
import '../../models/assessment_item.dart';
import '../../providers/assessment_engine_provider.dart';
import '../../widgets/assessment/assessment_item_renderer.dart';

class AdaptivePracticeScreen extends ConsumerStatefulWidget {
  final String userId;
  final String targetVersionId;
  final String targetTitle;
  final List<AssessmentItem> candidatePool;

  const AdaptivePracticeScreen({
    super.key,
    required this.userId,
    required this.targetVersionId,
    required this.targetTitle,
    required this.candidatePool,
  });

  @override
  ConsumerState<AdaptivePracticeScreen> createState() => _AdaptivePracticeScreenState();
}

class _AdaptivePracticeScreenState extends ConsumerState<AdaptivePracticeScreen> {
  AssessmentItem? _currentItem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adaptivePracticeProvider.notifier).startSession(
            userId: widget.userId,
            targetVersionId: widget.targetVersionId,
          );
      _pickNextQuestion();
    });
  }

  void _pickNextQuestion() {
    final state = ref.read(adaptivePracticeProvider);
    if (state == null || state.isSessionComplete) {
      setState(() => _currentItem = null);
      return;
    }

    final service = ref.read(adaptivePracticeServiceProvider);
    final next = service.selectNextItem(
      state: state,
      pool: widget.candidatePool,
    );

    setState(() => _currentItem = next);
  }

  void _onAnswerSubmitted(bool isCorrect, double score) {
    if (_currentItem == null) return;

    ref.read(adaptivePracticeProvider.notifier).submitResponse(
          item: _currentItem!,
          userResponse: isCorrect ? 'correct' : 'incorrect',
          isCorrect: isCorrect,
          scoreEarned: score,
        );

    final updatedState = ref.read(adaptivePracticeProvider);
    if (updatedState != null && updatedState.isSessionComplete) {
      _showCompletionDialog(updatedState);
    }
  }

  void _showCompletionDialog(AdaptivePracticeState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Adaptive Practice Complete',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The adaptive practice engine has converged on your current practice baseline.',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${state.estimatedReadinessPercentage.toStringAsFixed(0)}%',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    Text(
                      'Practice Readiness Baseline',
                      style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Accuracy: ${(state.accuracy * 100).toStringAsFixed(0)}% across ${state.itemCount} items',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Return to Study'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adaptivePracticeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final readinessPct = state.estimatedReadinessPercentage;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adaptive Practice Mode',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.targetTitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          // Live Adaptive Metric Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_graph_rounded, size: 16, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Text(
                  '${readinessPct.toStringAsFixed(0)}% Est.',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Question Progress Bar
            LinearProgressIndicator(
              value: (state.itemCount / state.maxItems).clamp(0.0, 1.0),
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              minHeight: 3.5,
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _currentItem != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Question Count & Dynamic Difficulty Banner
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Adaptive Question ${state.itemCount + 1}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Targeting: ${_currentItem!.difficulty.toUpperCase()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Question Renderer with Instant Active Recall Feedback
                              Expanded(
                                child: AssessmentItemRenderer(
                                  key: ValueKey(_currentItem!.id),
                                  item: _currentItem!,
                                  onAnswerSubmitted: _onAnswerSubmitted,
                                  onCompleted: _pickNextQuestion,
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Text('No further adaptive items available in pool.'),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
