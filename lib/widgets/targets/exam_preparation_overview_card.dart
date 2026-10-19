import 'package:flutter/material.dart';

import '../../models/assessment_engine/exam_reference_manifest.dart';
import '../../models/learning_target.dart';

/// A truthful, in-context overview: no parallel navigation, no speculative
/// regulator claims, and no dated reference checklist without an approved
/// manifest for the learner's administration date.
class ExamPreparationOverviewCard extends StatelessWidget {
  final TargetVersion targetVersion;

  const ExamPreparationOverviewCard({
    super.key,
    required this.targetVersion,
  });

  @override
  Widget build(BuildContext context) {
    ExamPreparationProfile? profile;
    try {
      profile = ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: targetVersion.id,
        metadata: targetVersion.metadata,
      );
    } on FormatException {
      return const SizedBox.shrink();
    }

    if (profile == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card(
      key: const Key('exam-preparation-overview'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exam preparation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose what to study in Learn or Library. '
              'Exam parts below organize practice; they do not verify '
              'your eligibility or predict a passing result.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final part in profile.examParts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.book_outlined, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(part.displayName),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Official reference lists, permitted book editions, '
              'room rules, and exam-time limits are not verified here. '
              'A dated checklist will appear only for an independently '
              'reviewed manifest covering your actual exam date.',
              key: const Key('exam-reference-unknown-notice'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
