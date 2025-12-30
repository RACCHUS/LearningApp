import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/services/recommendation_service.dart';

/// Horizontal scrolling recommendation section
class RecommendationSection extends ConsumerWidget {
  const RecommendationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(recommendationsProvider);

    return recommendationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: groups.map((group) {
            return _RecommendationRow(group: group);
          }).toList(),
        );
      },
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  final RecommendationGroup group;

  const _RecommendationRow({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                _getIcon(group.type),
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: group.items.length,
            itemBuilder: (context, index) {
              return _RecommendationCard(
                recommendation: group.items[index],
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.popularInTag:
        return Icons.trending_up;
      case RecommendationType.becauseYouStudied:
        return Icons.lightbulb_outline;
      case RecommendationType.continueProgress:
        return Icons.play_circle_outline;
      case RecommendationType.newContent:
        return Icons.new_releases_outlined;
      case RecommendationType.trending:
        return Icons.whatshot;
    }
  }
}

class _RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;

  const _RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            if (recommendation.targetType == 'lesson') {
              context.push('/lesson/${recommendation.targetId}');
            } else if (recommendation.targetType == 'course') {
              context.push('/course/${recommendation.targetId}');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getTypeColor(recommendation.type)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    recommendation.targetType.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _getTypeColor(recommendation.type),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Title
                Text(
                  recommendation.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Description or context
                if (recommendation.description != null)
                  Text(
                    recommendation.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.popularInTag:
        return Colors.blue;
      case RecommendationType.becauseYouStudied:
        return Colors.purple;
      case RecommendationType.continueProgress:
        return Colors.orange;
      case RecommendationType.newContent:
        return Colors.green;
      case RecommendationType.trending:
        return Colors.red;
    }
  }
}

/// Compact recommendation chip for inline display
class RecommendationChip extends StatelessWidget {
  final Recommendation recommendation;
  final VoidCallback? onTap;

  const RecommendationChip({
    super.key,
    required this.recommendation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ActionChip(
      avatar: Icon(
        _getTypeIcon(recommendation.type),
        size: 16,
        color: theme.colorScheme.primary,
      ),
      label: Text(
        recommendation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: onTap ??
          () {
            if (recommendation.targetType == 'lesson') {
              context.push('/lesson/${recommendation.targetId}');
            }
          },
    );
  }

  IconData _getTypeIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.popularInTag:
        return Icons.trending_up;
      case RecommendationType.becauseYouStudied:
        return Icons.lightbulb_outline;
      case RecommendationType.continueProgress:
        return Icons.play_circle_outline;
      case RecommendationType.newContent:
        return Icons.new_releases_outlined;
      case RecommendationType.trending:
        return Icons.whatshot;
    }
  }
}

/// Full page recommendations list
class RecommendationsPage extends ConsumerWidget {
  const RecommendationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(recommendationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended for You'),
      ),
      body: recommendationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading recommendations: $e'),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recommendations yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start studying to get personalized suggestions!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recommendationsProvider);
            },
            child: ListView(
              children: groups.map((group) {
                return _RecommendationRow(group: group);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
