import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/learning_target.dart';
import '../../providers/auth_provider.dart';
import '../../theme/design_tokens.dart';

/// Student-facing launch card for authoritative, full-length timed simulation exams
/// (e.g., CLEP College Algebra).
///
/// Discloses:
/// - Official blueprint specifications (question count, time limit, domain weighting).
/// - Tool policies (built-in scientific calculator permitted for College Algebra).
/// - Single-attempt policy to protect question bank security.
/// - Clear authentication requirements before initiation.
class SimulationExamLaunchCard extends ConsumerWidget {
  final TargetVersion targetVersion;
  final String targetId;
  final String targetTitle;

  const SimulationExamLaunchCard({
    super.key,
    required this.targetVersion,
    required this.targetId,
    required this.targetTitle,
  });

  bool get _isSimulationEligible {
    final meta = targetVersion.metadata;
    return meta['exam_code'] != null ||
        meta['role'] == 'blueprint_authority' ||
        meta['bank'] == 'simulation_exam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isSimulationEligible) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final meta = targetVersion.metadata;
    final examCode = meta['exam_code'] as String? ?? 'CLEP-ALG';
    final timeLimit = (meta['time_limit_minutes'] as num?)?.toInt() ?? 90;
    final questionCount = (meta['default_question_count'] as num?)?.toInt() ??
        (meta['question_count_approx'] as num?)?.toInt() ??
        60;
    final allowedTools = (meta['allowed_tools'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toSet() ??
        const {'calculator'};
    final allowsCalculator = allowedTools.contains('calculator');

    return Card(
      key: const Key('simulation-exam-launch-card'),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Official Simulation Exam',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              examCode,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Psychometrically balanced practice under full testing conditions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),
            Text(
              'Complete 60 questions across all 4 official blueprint domains in 90 minutes. '
              'Server-side grading provides diagnostic scores, domain mastery analysis, '
              'and recommended remediation topics upon submission.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: DesignTokens.space3),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  context,
                  icon: Icons.quiz_outlined,
                  label: '$questionCount Questions',
                ),
                _buildInfoChip(
                  context,
                  icon: Icons.timer_outlined,
                  label: '$timeLimit Minutes',
                ),
                if (allowsCalculator)
                  _buildInfoChip(
                    context,
                    icon: Icons.calculate_outlined,
                    label: 'Scientific Calculator Permitted',
                    highlight: true,
                  ),
                _buildInfoChip(
                  context,
                  icon: Icons.verified_outlined,
                  label: 'ACE Passing: 50 / 80',
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),
            Container(
              padding: const EdgeInsets.all(DesignTokens.space2),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Single Attempt Security: Exactly one official timed simulation attempt is permitted per learner. Questions are protected to prevent answer key disclosure.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space3),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('start-simulation-exam-button'),
                onPressed: () => _handleLaunchSimulation(context, ref),
                icon: const Icon(Icons.play_circle_filled_outlined),
                label: Text('Take Official Simulation ($timeLimit min)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: highlight
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _handleLaunchSimulation(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authProvider);
    if (authState is! AuthSuccess) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_person_outlined),
              SizedBox(width: 8),
              Text('Sign In Required'),
            ],
          ),
          content: const Text(
            'Official timed CLEP simulation exams require an authenticated learner account '
            'to enforce server-side timing and maintain exam bank security.\n\n'
            'Please sign in or create an account to begin your 90-minute examination.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('simulation-auth-sign-in-button'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                context.push('/login');
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
      return;
    }

    // Authenticated: navigate to simulation launcher screen
    context.push('/target/$targetId/simulation/${targetVersion.id}');
  }
}
