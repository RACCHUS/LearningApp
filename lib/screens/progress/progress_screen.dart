import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/retrieval_state.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/providers/motivation_preferences_provider.dart';
import 'package:learning_pwa/screens/progress/progress_dashboard_screen.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Answers "How am I progressing?".
///
/// Order is not arbitrary — retention first, motivation last, because that is
/// the order of honesty. Sections 2-4 are collapsed on arrival; progressive
/// disclosure applies inside Progress too.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(dashboardProgressProvider);
    final retention = ref.watch(retentionSummaryProvider);
    final motivation = ref.watch(motivationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(dashboardProgressProvider);
              ref.invalidate(retentionSummaryProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          _RetentionSection(summary: retention),
          const SizedBox(height: DesignTokens.space3),
          progressAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(DesignTokens.space5),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _SectionError(
              onRetry: () => ref.invalidate(dashboardProgressProvider),
            ),
            data: (progress) => Column(
              children: [
                _CompletionSection(progress: progress),
                _ActivitySection(progress: progress),
                if (!motivation.isFullyQuiet)
                  _MotivationSection(
                    progress: progress,
                    preferences: motivation,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Concept-level retrieval bands for the signed-in learner.
final retentionSummaryProvider =
    FutureProvider<RetrievalSummary>((ref) async {
  try {
    final items = await ref.watch(spacedRepetitionServiceProvider).getAllReviewItems();
    return RetrievalSummary.from(items.map(_classify));
  } catch (_) {
    // Offline or signed out: an empty summary is the honest answer.
    return RetrievalSummary.from(const []);
  }
});

RetrievalState _classify(ReviewableItem item) => RetrievalState.classify(
      repetitionLevel: item.repetitionLevel,
      totalReviews: item.totalReviews,
      correctReviews: item.correctReviews,
      lastReviewedAt: item.lastReviewedAt,
    );

class _RetentionSection extends StatelessWidget {
  final AsyncValue<RetrievalSummary> summary;

  const _RetentionSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Retention', style: theme.textTheme.titleMedium),
            const SizedBox(height: DesignTokens.space1),
            Text(
              'What your retrieval history suggests you are holding on to.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: DesignTokens.space4),
            summary.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Text('Could not load retention.'),
              data: (data) {
                if (data.isEmpty) {
                  return Text(
                    'No retrieval evidence yet. Study something and it will '
                    'show up here.',
                    style: theme.textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final band in RetrievalBand.values)
                      _BandRow(
                        band: band,
                        count: data[band],
                        total: data.total,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  final RetrievalBand band;
  final int count;
  final int total;

  const _BandRow({
    required this.band,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(band.label, style: theme.textTheme.bodyMedium),
              Text(
                '$count',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space1),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _CollapsedSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          DesignTokens.space4,
          0,
          DesignTokens.space4,
          DesignTokens.space4,
        ),
        children: children,
      ),
    );
  }
}

class _CompletionSection extends StatelessWidget {
  final DashboardProgress progress;

  const _CompletionSection({required this.progress});

  @override
  Widget build(BuildContext context) {
    return _CollapsedSection(
      title: 'Completion',
      subtitle: 'How far through the material you have gone',
      children: [
        _MetricRow(
          label: 'Lessons',
          value: '${progress.completedLessons}/${progress.totalLessons}',
          fraction: progress.lessonProgress,
        ),
        _MetricRow(
          label: 'Courses',
          value: '${progress.completedCourses}/${progress.totalCourses}',
          fraction: progress.courseProgress,
        ),
      ],
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final DashboardProgress progress;

  const _ActivitySection({required this.progress});

  @override
  Widget build(BuildContext context) {
    return _CollapsedSection(
      title: 'Activity',
      subtitle: 'Time and sessions',
      children: [
        _MetricRow(label: 'Study time', value: progress.formattedTime),
        _MetricRow(
          label: 'Study set sessions',
          value: '${progress.studySetSessionsCompleted}',
        ),
        _MetricRow(
          label: 'Recent items',
          value: '${progress.recentActivities.length}',
        ),
      ],
    );
  }
}

class _MotivationSection extends StatelessWidget {
  final DashboardProgress progress;
  final MotivationPreferences preferences;

  const _MotivationSection({
    required this.progress,
    required this.preferences,
  });

  @override
  Widget build(BuildContext context) {
    return _CollapsedSection(
      title: 'Motivation',
      subtitle: 'Optional. Turn any of this off in Settings.',
      children: [
        if (preferences.streaks) ...[
          _MetricRow(label: 'Current streak', value: '${progress.currentStreak}'),
          _MetricRow(label: 'Longest streak', value: '${progress.longestStreak}'),
        ],
        if (!preferences.streaks && !preferences.xp && !preferences.levels)
          const Text('Nothing enabled.'),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double? fraction;

  const _MetricRow({
    required this.label,
    required this.value,
    this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: DesignTokens.space1),
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  final VoidCallback onRetry;
  const _SectionError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Row(
          children: [
            const Expanded(child: Text('Could not load progress.')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
