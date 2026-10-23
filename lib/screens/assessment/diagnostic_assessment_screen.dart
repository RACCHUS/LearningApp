import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/diagnostic_assessment_provider.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../providers/target_readiness_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/assessment/assessment_item_renderer.dart';
import 'diagnostic_report_screen.dart';
import 'secure_exam_part_practice_screen.dart';

class DiagnosticAssessmentScreen extends ConsumerStatefulWidget {
  final String targetId;
  final String targetVersionId;
  /// Explicitly selected curriculum practice part (never inferred).
  final String? examPartKey;

  const DiagnosticAssessmentScreen({
    super.key,
    required this.targetId,
    required this.targetVersionId,
    this.examPartKey,
  });

  @override
  ConsumerState<DiagnosticAssessmentScreen> createState() =>
      _DiagnosticAssessmentScreenState();
}

class _DiagnosticAssessmentScreenState
    extends ConsumerState<DiagnosticAssessmentScreen> {
  bool _initialized = false;
  String? _lastLearnerId;

  DiagnosticSessionKey get _sessionKey => (
        targetId: widget.targetId,
        targetVersionId: widget.targetVersionId,
      );

  ScopedDiagnosticSessionKey get _scopedSessionKey => (
        targetId: widget.targetId,
        targetVersionId: widget.targetVersionId,
        examPartKey: widget.examPartKey!,
        learnerId: ref.read(learnerIdProvider),
      );

  DiagnosticSessionNotifier _notifier() => widget.examPartKey == null
      ? ref.read(diagnosticSessionProvider(_sessionKey).notifier)
      : ref.read(scopedDiagnosticSessionProvider(_scopedSessionKey).notifier);

  @override
  void didUpdateWidget(covariant DiagnosticAssessmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId ||
        oldWidget.targetVersionId != widget.targetVersionId ||
        oldWidget.examPartKey != widget.examPartKey) {
      _initialized = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Explicit exam-part diagnostics use the protected issuer/scorer.
    // Never invoke legacy assessment_items SELECT('*') for this mode.
    // Whole-target diagnostics retain their independent legacy practice path.
    if (widget.examPartKey != null) {
      return SecureExamPartPracticeScreen(
        targetVersionId: widget.targetVersionId,
        examPartKey: widget.examPartKey!,
      );
    }
    final learnerId = ref.watch(learnerIdProvider);
    if (widget.examPartKey != null && _lastLearnerId != learnerId) {
      _initialized = false;
      _lastLearnerId = learnerId;
    }
    final targetAsync = ref.watch(targetDetailProvider(widget.targetId));
    final itemsAsync = widget.examPartKey == null
        ? ref.watch(diagnosticItemsProvider(_sessionKey))
        : ref.watch(examPartDiagnosticItemsProvider((
            targetId: widget.targetId,
            targetVersionId: widget.targetVersionId,
            examPartKey: widget.examPartKey!,
          )));
    final session = widget.examPartKey == null
        ? ref.watch(diagnosticSessionProvider(_sessionKey))
        : ref.watch(scopedDiagnosticSessionProvider(_scopedSessionKey));
    final theme = Theme.of(context);

    return targetAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Diagnostic Pre-Assessment')),
        body: Center(child: Text('Failed to load target: $error')),
      ),
      data: (target) {
        if (target == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Diagnostic Pre-Assessment')),
            body: const Center(child: Text('Target not found.')),
          );
        }

        return itemsAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text('${target.title} Diagnostic')),
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading reviewed diagnostic items...'),
                ],
              ),
            ),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: Text('${target.title} Diagnostic')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 40),
                    const SizedBox(height: DesignTokens.space3),
                    Text(
                      'Diagnostic not available yet',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DesignTokens.space2),
                    const Text(
                      'This target does not yet have enough reviewed, concept-mapped assessment content for a reliable diagnostic snapshot.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (items) {
            if (!_initialized) {
              final requestOwner = learnerId;
              final requestPart = widget.examPartKey;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted ||
                    ref.read(learnerIdProvider) != requestOwner ||
                    widget.examPartKey != requestPart) {
                  return;
                }
                _notifier().initialize(items);
                setState(() => _initialized = true);
              });
            }

            if (session.items.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: Text('${target.title} Diagnostic')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final current = session.items[session.currentIndex];
            final response = session.responses[current.item.id];
            final progress =
                (session.currentIndex + 1) / session.items.length;

            return Scaffold(
              appBar: AppBar(
                title: Text('${target.title} Diagnostic'),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(value: progress),
                ),
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Question ${session.currentIndex + 1} of ${session.items.length}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                current.primaryConcept.conceptName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.space3),
                      Expanded(
                        child: AssessmentItemRenderer(
                          key: ValueKey(current.item.id),
                          item: current.item,
                          isExamMode: true,
                          initialResponse: response,
                          onResponseChanged: (value) {
                            _notifier().recordResponse(current.item.id, value);
                          },
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space3),
                      Row(
                        children: [
                          if (session.currentIndex > 0)
                            OutlinedButton.icon(
                              onPressed: session.isSubmitting
                                  ? null
                                  : () => _notifier().previousQuestion(),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Previous'),
                            ),
                          const Spacer(),
                          if (session.currentIndex < session.items.length - 1)
                            FilledButton.icon(
                              onPressed: response == null ||
                                      session.isSubmitting
                                  ? null
                                  : () => _notifier().nextQuestion(),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Next'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: !session.isCompleted ||
                                      session.isSubmitting
                                  ? null
                                  : () async {
                                      final submittingLearner =
                                          ref.read(learnerIdProvider);
                                      final submittingPart = widget.examPartKey;
                                      try {
                                        final report = await _notifier()
                                            .submitAssessment(
                                              userId: submittingLearner,
                                              targetTitle: target.title,
                                            );
                                        if (!context.mounted ||
                                            ref.read(learnerIdProvider) !=
                                                submittingLearner ||
                                            widget.examPartKey !=
                                                submittingPart) {
                                          return;
                                        }
                                        ref.invalidate(
                                          targetReadinessProvider(
                                            widget.targetVersionId,
                                          ),
                                        );
                                        if (submittingPart != null) {
                                          ref.invalidate(examPartReadinessProvider((
                                            targetVersionId: widget.targetVersionId,
                                            examPartKey: submittingPart,
                                          )));
                                        }
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DiagnosticReportScreen(
                                              report: report,
                                            ),
                                          ),
                                        );
                                      } catch (error) {
                                        if (!context.mounted ||
                                            ref.read(learnerIdProvider) !=
                                                submittingLearner) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not submit diagnostic: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: session.isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text('Complete Diagnostic'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
