import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/exam_part_progress_provider.dart';
import '../../providers/learning_context_provider.dart';
import '../../theme/design_tokens.dart';
import '../../screens/assessment/diagnostic_assessment_screen.dart';

/// Explicitly selected, practice-only exam-part knowledge/progress view.
/// Unlike the global LearningContext, choosing a part here never silently
/// changes the user's curriculum focus or primary Learn next action.
class ExamPartProgressCard extends ConsumerStatefulWidget {
  final String targetId;
  final String targetVersionId;

  const ExamPartProgressCard({
    super.key,
    required this.targetId,
    required this.targetVersionId,
  });

  @override
  ConsumerState<ExamPartProgressCard> createState() =>
      _ExamPartProgressCardState();
}

class _ExamPartProgressCardState extends ConsumerState<ExamPartProgressCard> {
  String? _selectedPartKey;

  @override
  void didUpdateWidget(covariant ExamPartProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId ||
        oldWidget.targetVersionId != widget.targetVersionId) {
      _selectedPartKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final learnerId = ref.watch(learnerIdProvider);
    final profileKey = (
      targetId: widget.targetId,
      targetVersionId: widget.targetVersionId,
    );
    final profileAsync = ref.watch(examPartProfileProvider(profileKey));

    return profileAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.space4),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Exam-part progress is unavailable for this version.'),
              TextButton(
                onPressed: () => ref.invalidate(examPartProfileProvider(profileKey)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final chosen = profile.findPart(_selectedPartKey ?? '');
        // Stale local selection after profile revision is never interpreted
        // as the entire target or another part.
        final selectedKey = chosen?.key;
        return Card(
          key: const Key('exam-part-progress-card'),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exam-part knowledge progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DesignTokens.space1),
                const Text(
                  'Choose a part to view its knowledge evidence separately '
                  'from target-wide progress. This is not an exam score.',
                ),
                const SizedBox(height: DesignTokens.space3),
                DropdownButtonFormField<String>(
                  key: const Key('exam-part-progress-select'),
                  value: selectedKey,
                  decoration: const InputDecoration(
                    labelText: 'Practice exam part',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select a part'),
                  items: [
                    for (final part in profile.examParts)
                      DropdownMenuItem<String>(
                        value: part.key,
                        child: Text(part.displayName),
                      ),
                  ],
                  onChanged: (value) => setState(() => _selectedPartKey = value),
                ),
                if (selectedKey != null) ...[
                  const SizedBox(height: DesignTokens.space3),
                  _SelectedExamPartProgress(
                    key: ValueKey('part:$learnerId:${widget.targetVersionId}:$selectedKey'),
                    partKey: selectedKey,
                    targetId: widget.targetId,
                    targetVersionId: widget.targetVersionId,
                    learnerId: learnerId,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectedExamPartProgress extends ConsumerWidget {
  final String targetId;
  final String targetVersionId;
  final String partKey;
  final String learnerId;

  const _SelectedExamPartProgress({
    super.key,
    required this.targetId,
    required this.targetVersionId,
    required this.partKey,
    required this.learnerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (
      targetId: targetId,
      targetVersionId: targetVersionId,
      examPartKey: partKey,
      learnerId: learnerId,
    );
    final progressAsync = ref.watch(examPartProgressProvider(key));
    final theme = Theme.of(context);
    return progressAsync.when(
      loading: () => const Center(
        key: Key('exam-part-progress-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected part progress is unavailable. '
            'No target-wide results were substituted.',
            key: Key('exam-part-progress-unavailable'),
          ),
          TextButton(
            onPressed: () => ref.invalidate(examPartProgressProvider(key)),
            child: const Text('Retry part progress'),
          ),
        ],
      ),
      data: (progress) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Knowledge coverage: ${progress.knowledge.band.displayName}',
            key: const Key('exam-part-knowledge-band'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: DesignTokens.space1),
          Text(
            '${progress.knowledge.assessedConceptsCount} of '
            '${progress.knowledge.totalCoreConcepts} part core concepts assessed',
            key: const Key('exam-part-knowledge-count'),
          ),
          const SizedBox(height: DesignTokens.space2),
          const Text(
            'Concept knowledge may be shared with other parts. '
            'It does not prove part-specific exam performance.',
          ),
          const Divider(),
          const Text(
            'Part-specific practice attempt history is not yet available. '
            'These counts are concept evidence, not saved exam attempts.',
            key: Key('exam-part-history-limit'),
          ),
          const SizedBox(height: DesignTokens.space2),
          Text(
            'Suggested next step',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            progress.nextStep.title,
            key: const Key('exam-part-next-step'),
          ),
          Text(progress.nextStep.rationale),
          const SizedBox(height: DesignTokens.space2),
          if (progress.nextStep.canLaunchDiagnostic &&
              progress.diagnostic.isAvailable)
            FilledButton.tonalIcon(
              key: const Key('exam-part-start-diagnostic'),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => DiagnosticAssessmentScreen(
                    targetId: targetId,
                    targetVersionId: targetVersionId,
                    examPartKey: partKey,
                  ),
                ));
              },
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Start part practice diagnostic'),
            )
          else
            OutlinedButton.icon(
              key: const Key('exam-part-view-outline'),
              onPressed: () => context.push('/target/$targetId/outline'),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('View full target outline'),
            ),
        ],
      ),
    );
  }
}
