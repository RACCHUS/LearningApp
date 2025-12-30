import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/study_set_provider.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Full list view of study sets for the Study Sets tab
class HomeStudySetsList extends ConsumerStatefulWidget {
  const HomeStudySetsList({super.key});

  @override
  ConsumerState<HomeStudySetsList> createState() => _HomeStudySetsListState();
}

class _HomeStudySetsListState extends ConsumerState<HomeStudySetsList> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(studySetProvider.notifier).loadStudySets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studySetProvider);

    if (state.isLoading && state.studySets.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.studySets.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(context),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(DesignTokens.space4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final studySet = state.studySets[index];
            final progress = state.progressBySetId[studySet.id];
            return _StudySetListTile(
              studySet: studySet,
              progress: progress,
              onTap: () => _openStudySet(context, studySet),
              onDelete: () => _deleteStudySet(studySet),
            );
          },
          childCount: state.studySets.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No study sets yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a study set to mix lessons together',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              context.push('/lesson-selection');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Study Set'),
          ),
        ],
      ),
    );
  }

  void _openStudySet(BuildContext context, SavedStudySet studySet) {
    final lessonIds = studySet.lessonIds;
    if (lessonIds.isNotEmpty) {
      context.push('/study-set?ids=${lessonIds.join(',')}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This study set has no lessons')),
      );
    }
  }

  Future<void> _deleteStudySet(SavedStudySet studySet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Study Set'),
        content: Text('Are you sure you want to delete "${studySet.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await ref.read(studySetProvider.notifier).deleteStudySet(studySet.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Study set deleted')),
        );
      }
    }
  }
}

class _StudySetListTile extends StatelessWidget {
  final SavedStudySet studySet;
  final StudySetProgress? progress;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _StudySetListTile({
    required this.studySet,
    this.progress,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final progressValue = progress?.completionRate ?? 0.0;
    final lastStudied = progress?.lastStudiedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.library_books,
                  color: colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studySet.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.format_list_bulleted,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${studySet.totalItems} items',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (lastStudied != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatLastStudied(lastStudied),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (progress != null && progress!.totalItems > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressValue,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progressValue * 100).toInt()}%',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  FilledButton(
                    onPressed: onTap,
                    child: const Text('Study'),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastStudied(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
