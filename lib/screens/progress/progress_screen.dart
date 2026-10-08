import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/retrieval_state.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/providers/motivation_preferences_provider.dart';
import 'package:learning_pwa/screens/progress/progress_dashboard_screen.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/account_actions.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';

import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/models/scope.dart';
import 'package:learning_pwa/providers/scope_resolver_provider.dart';
import 'package:learning_pwa/widgets/targets/target_readiness_card.dart';
import 'package:learning_pwa/models/user_concept_state.dart' as ucs;
import 'package:learning_pwa/providers/target_readiness_provider.dart';

final contextScopeProvider = FutureProvider.family<ResolvedScope, LearningContext>((ref, context) async {
  return ref.watch(scopeResolverProvider).resolveScope(context);
});

/// Answers "How am I progressing?".
///
/// Progress V2 implements the dual perspective:
/// 1. Current Context: Scoped readiness and curriculum boundaries for the active target
/// 2. All Knowledge: Global concept retrieval bands and all-time completion
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _selectedTab = 0; // 0: Current Context, 1: All Knowledge

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(dashboardProgressProvider);
    final retention = ref.watch(retentionSummaryProvider);
    final motivation = ref.watch(motivationPreferencesProvider);
    final activeContext = ref.watch(learningContextsProvider).active;

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
          const HelpAction(),
          const AccountActions(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          // Segmented Switch: Current Context vs All Knowledge (§11.3)
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Current Context'),
                icon: Icon(Icons.my_location),
              ),
              ButtonSegment(
                value: 1,
                label: Text('All Knowledge'),
                icon: Icon(Icons.public),
              ),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (set) => setState(() => _selectedTab = set.first),
          ),
          const SizedBox(height: DesignTokens.space4),

          if (_selectedTab == 0) ...[
            // CURRENT CONTEXT VIEW
            if (activeContext != null)
              _CurrentContextSection(activeContext: activeContext)
            else
              const _NoActiveContextCard(),
          ] else ...[
            // ALL KNOWLEDGE VIEW
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
        ],
      ),
    );
  }
}

class _CurrentContextSection extends ConsumerWidget {
  final LearningContext activeContext;

  const _CurrentContextSection({required this.activeContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scopeAsync = ref.watch(contextScopeProvider(activeContext));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Row(
              children: [
                if (activeContext.emoji != null) ...[
                  Text(activeContext.emoji!, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: DesignTokens.space3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeContext.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active Target · ${activeContext.rootType.name.toUpperCase()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.space3),
        if (activeContext.targetVersionId != null &&
            activeContext.targetVersionId!.isNotEmpty) ...[
          TargetReadinessCard(targetVersionId: activeContext.targetVersionId!),
          const SizedBox(height: DesignTokens.space3),
        ],
        scopeAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(DesignTokens.space4),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (scope) => Card(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Curriculum Scope Boundaries',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'Activities',
                        value: '${scope.orderedActivities.length}',
                      ),
                      _StatColumn(
                        label: 'Core Concepts',
                        value: '${scope.coreConceptIds.length}',
                      ),
                      _StatColumn(
                        label: 'Supporting',
                        value: '${scope.supportingConceptIds.length}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NoActiveContextCard extends StatelessWidget {
  const _NoActiveContextCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space5),
        child: Column(
          children: [
            const Icon(Icons.track_changes_outlined, size: 40),
            const SizedBox(height: DesignTokens.space3),
            Text(
              'No Active Learning Context',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            Text(
              'Select an active target, career, or exam from the Learn screen to view scoped knowledge readiness.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Concept-level retrieval bands for the signed-in learner using V2 user_concept_state.
final retentionSummaryProvider =
    FutureProvider<RetrievalSummary>((ref) async {
  try {
    final learnerId = ref.watch(learnerIdProvider);
    if (learnerId.isNotEmpty) {
      final conceptStates = await ref
          .watch(conceptEvidenceServiceProvider)
          .getUserConceptStates(learnerId);

      if (conceptStates.isNotEmpty) {
        final counts = <RetrievalBand, int>{
          for (final band in RetrievalBand.values) band: 0,
        };
        for (final state in conceptStates.values) {
          switch (state.retrievalBand) {
            case ucs.RetrievalBand.needsReinforcement:
              counts[RetrievalBand.needsReinforcement] =
                  (counts[RetrievalBand.needsReinforcement] ?? 0) + 1;
              break;
            case ucs.RetrievalBand.developing:
              counts[RetrievalBand.developing] =
                  (counts[RetrievalBand.developing] ?? 0) + 1;
              break;
            case ucs.RetrievalBand.wellRetained:
              counts[RetrievalBand.wellRetained] =
                  (counts[RetrievalBand.wellRetained] ?? 0) + 1;
              break;
            case ucs.RetrievalBand.wellEstablished:
              counts[RetrievalBand.wellEstablished] =
                  (counts[RetrievalBand.wellEstablished] ?? 0) + 1;
              break;
            case ucs.RetrievalBand.unassessed:
              break;
          }
        }
        return RetrievalSummary(counts);
      }
    }

    // Fallback: If no canonical concept states exist yet, synthesize from review items
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
