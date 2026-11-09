import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/learning_target.dart';
import '../../providers/assessment_engine_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/design_tokens.dart';

/// Student-facing launch card for authoritative, full-length timed simulation exams
/// (e.g., CLEP College Algebra).
///
/// Discloses:
/// - Official blueprint specifications (question count, time limit, domain weighting).
/// - Tool policies (built-in scientific calculator permitted exclusively when blueprint allows).
/// - Single-attempt policy to protect question bank security.
/// - Clear registered account requirement (rejecting anonymous guest accounts).
/// - Attempt recovery banner and button when an active unexpired attempt is in progress.
class SimulationExamLaunchCard extends ConsumerStatefulWidget {
  final TargetVersion targetVersion;
  final String targetId;
  final String targetTitle;

  const SimulationExamLaunchCard({
    super.key,
    required this.targetVersion,
    required this.targetId,
    required this.targetTitle,
  });

  @override
  ConsumerState<SimulationExamLaunchCard> createState() =>
      _SimulationExamLaunchCardState();
}

class _SimulationExamLaunchCardState extends ConsumerState<SimulationExamLaunchCard> {
  bool _hasActiveAttempt = false;
  int? _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _checkActiveAttempt();
  }

  Future<void> _checkActiveAttempt() async {
    final authState = ref.read(authProvider);
    if (authState is! AuthSuccess || authState.user.isAnonymous) {
      return;
    }

    if (!widget.targetVersion.isSimulationExamEligible) {
      return;
    }

    try {
      final res = await ref
          .read(clepSimulationServiceProvider)
          .getActiveSimulationAttempt(widget.targetVersion.id);
      if (mounted) {
        setState(() {
          _hasActiveAttempt = res.hasActiveAttempt;
          _secondsRemaining = res.secondsRemaining;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.targetVersion.isSimulationExamEligible) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final meta = widget.targetVersion.metadata;
    final examCode = meta['exam_code'] as String? ?? 'CLEP-ALG';
    final timeLimit = (meta['time_limit_minutes'] as num?)?.toInt() ?? 90;
    final questionCount = (meta['default_question_count'] as num?)?.toInt() ??
        (meta['question_count_approx'] as num?)?.toInt() ??
        60;
    final allowsCalculator = widget.targetVersion.allowsCalculator;

    return Card(
      key: const Key('simulation-exam-launch-card'),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _hasActiveAttempt
              ? theme.colorScheme.error.withValues(alpha: 0.5)
              : theme.colorScheme.primary.withValues(alpha: 0.35),
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
                    color: _hasActiveAttempt
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _hasActiveAttempt ? Icons.timelapse : Icons.assignment_outlined,
                    color: _hasActiveAttempt
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
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
                            _hasActiveAttempt
                                ? 'Active Simulation in Progress'
                                : 'Official Simulation Exam',
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
                        _hasActiveAttempt
                          ? 'You have an ongoing examination attempt with remaining time.'
                          : 'Psychometrically balanced practice under full testing conditions',
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
              'Complete $questionCount questions across all official blueprint domains in $timeLimit minutes. '
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
                  label: _hasActiveAttempt && _secondsRemaining != null
                      ? '${(_secondsRemaining! / 60).ceil()} min remaining'
                      : '$timeLimit Minutes',
                  highlight: _hasActiveAttempt,
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
                key: _hasActiveAttempt
                    ? const Key('resume-simulation-exam-button')
                    : const Key('start-simulation-exam-button'),
                onPressed: () => _handleLaunchSimulation(context, ref),
                icon: Icon(_hasActiveAttempt
                    ? Icons.replay_outlined
                    : Icons.play_circle_filled_outlined),
                label: Text(_hasActiveAttempt
                    ? 'Resume Official Simulation (${(_secondsRemaining != null ? (_secondsRemaining! / 60).ceil() : timeLimit)} min remaining)'
                    : 'Take Official Simulation ($timeLimit min)'),
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
    final isGuestOrAnonymous = authState is! AuthSuccess || authState.user.isAnonymous;

    if (isGuestOrAnonymous) {
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
            'Official timed CLEP simulation exams enforce a single-attempt security policy and '
            'require a verified, registered learner account (not a guest session) to ensure attempt '
            'integrity and maintain official scoring records.\n\n'
            'Please sign in or register with Google to access your official simulation examination.',
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
              child: const Text('Sign In / Register'),
            ),
          ],
        ),
      );
      return;
    }

    // Authenticated & Registered: navigate to simulation launcher screen
    context.push('/target/${widget.targetId}/simulation/${widget.targetVersion.id}');
  }
}
