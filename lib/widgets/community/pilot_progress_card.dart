import 'package:flutter/material.dart';
import '../../models/community/family_abe_pilot.dart';

/// Card displaying the learner's active Family & ABE field pilot cohort,
/// milestone progress, and accessibility status (ECO-08, Phase 3).
class PilotProgressCard extends StatelessWidget {
  final PilotCohort cohort;
  final List<PilotParticipantSession> sessions;
  final VoidCallback? onContinueSession;
  final VoidCallback? onTakeAssessment;
  final VoidCallback? onChangeCohort;

  const PilotProgressCard({
    super.key,
    required this.cohort,
    this.sessions = const [],
    this.onContinueSession,
    this.onTakeAssessment,
    this.onChangeCohort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = sessions.where((s) => s.completedAt != null).length;
    final progress = cohort.estimatedSessions > 0
        ? (completedCount / cohort.estimatedSessions).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      key: Key('pilot_progress_card_${cohort.id}'),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Pilot badge & Change cohort action
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub,
                          size: 14, color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        'Active Field Pilot',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  cohort.shortTag,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (onChangeCohort != null)
                  TextButton(
                    onPressed: onChangeCohort,
                    child: const Text('Change'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Cohort Name & Target Milestone
            Text(
              cohort.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.flag, size: 14, color: theme.colorScheme.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Target: ${cohort.targetMilestone}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Session $completedCount of ${cohort.estimatedSessions} Completed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Accessibility & Target Skills Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up,
                          size: 12, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${(cohort.recommendedSpeechRate * 100).toInt()}% Audio Pacing',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ...cohort.targetSkills.take(3).map((skill) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      skill,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                if (onContinueSession != null)
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('continue_pilot_session_button'),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start Session'),
                      onPressed: onContinueSession,
                    ),
                  ),
                if (onContinueSession != null && onTakeAssessment != null)
                  const SizedBox(width: 12),
                if (onTakeAssessment != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('take_assessment_button'),
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('Evaluate Gain'),
                      onPressed: onTakeAssessment,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

