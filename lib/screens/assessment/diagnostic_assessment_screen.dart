import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/assessment/diagnostic_assessment.dart';
import '../../providers/diagnostic_assessment_provider.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/assessment/assessment_item_renderer.dart';
import 'diagnostic_report_screen.dart';

class DiagnosticAssessmentScreen extends ConsumerStatefulWidget {
  final String targetId;
  final String targetVersionId;

  const DiagnosticAssessmentScreen({
    super.key,
    required this.targetId,
    required this.targetVersionId,
  });

  @override
  ConsumerState<DiagnosticAssessmentScreen> createState() =>
      _DiagnosticAssessmentScreenState();
}

class _DiagnosticAssessmentScreenState
    extends ConsumerState<DiagnosticAssessmentScreen> {
  bool _initialized = false;

  DiagnosticSessionKey get _sessionKey => (
        targetId: widget.targetId,
        targetVersionId: widget.targetVersionId,
      );

  @override
  Widget build(BuildContext context) {
    final targetAsync = ref.watch(targetDetailProvider(widget.targetId));
    final itemsAsync =
        ref.watch(diagnosticItemsProvider(widget.targetVersionId));
    final session = ref.watch(diagnosticSessionProvider(_sessionKey));
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ref
                    .read(diagnosticSessionProvider(_sessionKey).notifier)
                    .initialize(items);
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
                            ref
                                .read(
                                  diagnosticSessionProvider(_sessionKey)
                                      .notifier,
                                )
                                .recordResponse(current.item.id, value);
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
                                  : () => ref
                                      .read(
                                        diagnosticSessionProvider(_sessionKey)
                                            .notifier,
                                      )
                                      .previousQuestion(),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Previous'),
                            ),
                          const Spacer(),
                          if (session.currentIndex < session.items.length - 1)
                            FilledButton.icon(
                              onPressed: response == null ||
                                      session.isSubmitting
                                  ? null
                                  : () => ref
                                      .read(
                                        diagnosticSessionProvider(_sessionKey)
                                            .notifier,
                                      )
                                      .nextQuestion(),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Next'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: !session.isCompleted ||
                                      session.isSubmitting
                                  ? null
                                  : () async {
                                      final learnerId =
                                          ref.read(learnerIdProvider);
                                      try {
                                        final report = await ref
                                            .read(
                                              diagnosticSessionProvider(
                                                _sessionKey,
                                              ).notifier,
                                            )
                                            .submitAssessment(
                                              userId: learnerId,
                                              targetTitle: target.title,
                                            );
                                        if (!context.mounted) return;
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DiagnosticReportScreen(
                                              report: report,
                                            ),
                                          ),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) return;
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
