import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_pwa/models/daily_plan.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/daily_plan_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Card displayed on the Progress screen rendering today's Daily Study Plan,
/// time budget split, load-aware pacing, and exam date target countdown.
class DailyPlanCard extends ConsumerWidget {
  final LearningContext context;

  const DailyPlanCard({super.key, required this.context});

  @override
  Widget build(BuildContext contextRef, WidgetRef ref) {
    final theme = Theme.of(contextRef);
    final planAsync = ref.watch(dailyPlanProvider);

    return planAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.space4),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (plan) => Card(
        margin: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title and Policy Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: DesignTokens.space2),
                      Text(
                        'Daily Study Plan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _buildEmphasisChip(plan.reviewEmphasis, theme),
                ],
              ),
              const SizedBox(height: DesignTokens.space2),

              // Rationale text
              Text(
                plan.rationale,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.space3),

              // Workload Split Bar
              _buildWorkloadBar(plan, theme),
              const SizedBox(height: DesignTokens.space3),

              // Targets Summary
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'New Material',
                      value: '${plan.newMinutesBudget} min',
                      subtitle: plan.recommendedNewCount > 0
                          ? '~${plan.recommendedNewCount} lesson${plan.recommendedNewCount == 1 ? '' : 's'}'
                          : 'Paused',
                      icon: Icons.school_outlined,
                      color: theme.colorScheme.primary,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space2),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Reviews',
                      value: '${plan.reviewMinutesBudget} min',
                      subtitle: '${plan.dueItemsCount} due',
                      icon: Icons.replay,
                      color: plan.isReviewUrgent
                          ? Colors.amber.shade800
                          : theme.colorScheme.secondary,
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space3),

              // Exam-Date Workload & Countdown Section
              const Divider(height: 1),
              const SizedBox(height: DesignTokens.space2),
              _buildExamDateSection(contextRef, ref, plan, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmphasisChip(ReviewEmphasis emphasis, ThemeData theme) {
    final (label, icon) = switch (emphasis) {
      ReviewEmphasis.balanced => ('Balanced', Icons.balance),
      ReviewEmphasis.prioritiseReviews => ('Reviews First', Icons.replay),
      ReviewEmphasis.prioritiseNew => ('Forward Focus', Icons.arrow_forward),
    };

    return Chip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildWorkloadBar(DailyPlan plan, ThemeData theme) {
    final total = plan.targetDailyMinutes;
    if (total <= 0) return const SizedBox.shrink();

    final reviewRatio = plan.reviewTimeRatio;
    final newRatio = plan.newTimeRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (newRatio > 0)
              Expanded(
                flex: (newRatio * 100).round(),
                child: Container(color: theme.colorScheme.primary),
              ),
            if (reviewRatio > 0)
              Expanded(
                flex: (reviewRatio * 100).round(),
                child: Container(
                  color: plan.isReviewUrgent
                      ? Colors.amber.shade700
                      : theme.colorScheme.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: DesignTokens.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExamDateSection(
    BuildContext contextRef,
    WidgetRef ref,
    DailyPlan plan,
    ThemeData theme,
  ) {
    final examDate = plan.examDate;
    final days = plan.daysUntilExam;

    if (examDate != null && days != null) {
      final formattedDate = DateFormat('yMMMd').format(examDate);
      final isUrgent = days <= 7;

      return Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_amber_rounded : Icons.event_available,
            color: isUrgent ? Colors.orange : theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: DesignTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  days == 0
                      ? 'Target Exam: Today ($formattedDate)'
                      : 'Target Exam: $formattedDate ($days days remaining)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? Colors.orange.shade800 : null,
                  ),
                ),
                Text(
                  isUrgent
                      ? 'Consolidation phase: reviews prioritized for exam retention.'
                      : 'Workload paced toward your target date.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar, size: 18),
            tooltip: 'Change exam date',
            onPressed: () => _pickExamDate(contextRef, ref, examDate),
          ),
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            tooltip: 'Clear exam date',
            onPressed: () => _clearExamDate(ref),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.event_outlined, color: theme.colorScheme.onSurfaceVariant, size: 20),
        const SizedBox(width: DesignTokens.space2),
        Expanded(
          child: Text(
            'No exam date set. Set a target date to pace your study.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Set date'),
          onPressed: () => _pickExamDate(contextRef, ref, null),
        ),
      ],
    );
  }

  Future<void> _pickExamDate(
    BuildContext contextRef,
    WidgetRef ref,
    DateTime? currentDate,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: contextRef,
      initialDate: currentDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (picked != null) {
      final newConfig = Map<String, dynamic>.from(context.scopeConfig);
      newConfig['examDate'] = picked.toIso8601String();
      await ref
          .read(learningContextsProvider.notifier)
          .updateScopeConfig(context.id, newConfig);
      ref.invalidate(dailyPlanProvider);
    }
  }

  Future<void> _clearExamDate(WidgetRef ref) async {
    final newConfig = Map<String, dynamic>.from(context.scopeConfig);
    newConfig.remove('examDate');
    newConfig.remove('targetDate');
    await ref
        .read(learningContextsProvider.notifier)
        .updateScopeConfig(context.id, newConfig);
    ref.invalidate(dailyPlanProvider);
  }
}

