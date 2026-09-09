import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/study_set_provider.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Shows saved study sets on the home screen
class HomeStudySetsSection extends ConsumerStatefulWidget {
  const HomeStudySetsSection({super.key});

  @override
  ConsumerState<HomeStudySetsSection> createState() =>
      _HomeStudySetsSectionState();
}

class _HomeStudySetsSectionState extends ConsumerState<HomeStudySetsSection> {
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    // Load study sets when the widget is first built
    Future.microtask(() {
      ref.read(studySetProvider.notifier).loadStudySets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final studySets = ref.watch(studySetsListProvider);
    final isLoading = ref.watch(studySetLoadingProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Don't show section if no saved study sets
    if (studySets.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand/collapse
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space4,
              vertical: DesignTokens.space2,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.collections_bookmark,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: DesignTokens.space2),
                Text(
                  'My Study Sets',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: DesignTokens.space2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${studySets.length}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        // Content
        if (_isExpanded) ...[
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(DesignTokens.space4),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space4,
                ),
                itemCount: studySets.length,
                itemBuilder: (context, index) {
                  final studySet = studySets[index];
                  return _StudySetCard(
                    studySet: studySet,
                    onTap: () => _openStudySet(context, studySet),
                    onDelete: () => _deleteStudySet(studySet),
                  );
                },
              ),
            ),
        ],

        const SizedBox(height: DesignTokens.space2),
        const Divider(indent: 16, endIndent: 16),
      ],
    );
  }

  void _openStudySet(BuildContext context, SavedStudySet studySet) {
    // Get the lesson IDs from the study set
    final lessonIds = studySet.lessonIds;

    if (lessonIds.isNotEmpty) {
      // Navigate to the study set screen with the lesson IDs
      context.push('/study-set?ids=${lessonIds.join(',')}');
    } else {
      // If no lessons, show message
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

class _StudySetCard extends StatelessWidget {
  final SavedStudySet studySet;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _StudySetCard({
    required this.studySet,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(right: DesignTokens.space3),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(DesignTokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and menu
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.library_books,
                      size: 20,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                  ),
                ],
              ),

              const SizedBox(height: DesignTokens.space2),

              // Title
              Text(
                studySet.title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              // Item count
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
