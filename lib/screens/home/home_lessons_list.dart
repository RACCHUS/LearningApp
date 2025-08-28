import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/lesson_service.dart';

class HomeLessonsList extends ConsumerWidget {
  final AsyncValue<List<Lesson>> lessonsStream;
  final String searchQuery;
  final String? selectedTag;

  const HomeLessonsList({
    super.key,
    required this.lessonsStream,
    required this.searchQuery,
    this.selectedTag,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'just now';
    }
  }

  List<Lesson> _filterLessons(List<Lesson> lessons) {
    return lessons.where((lesson) {
      final query = searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          lesson.title.toLowerCase().contains(query) ||
          (lesson.description?.toLowerCase() ?? '').contains(query) ||
          lesson.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchesTag =
          selectedTag == null || lesson.tags.contains(selectedTag);
      return matchesSearch && matchesTag;
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return lessonsStream.when(
      data: (lessons) {
        if (lessons.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: Text(
                'No lessons available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
          );
        }

        final filteredLessons = _filterLessons(lessons);

        if (filteredLessons.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: Text(
                'No lessons match your filters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final lesson = filteredLessons[index];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        onTap: () => context.push('/lesson/${lesson.id}'),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          title: Text(
                            lesson.title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (lesson.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  lesson.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    _formatDate(lesson.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  if (lesson.tags.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 6,
                                        children: lesson.tags.map((tag) => Chip(
                                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        )).toList(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                tooltip: 'Delete Lesson',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Lesson'),
                                      content: const Text(
                                        'Are you sure you want to delete this lesson and all its content? This cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    try {
                                      final lessonService = LessonService();
                                      await lessonService.deleteLessonFromSupabase(lesson.id);
                                      
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Lesson deleted successfully.'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error deleting lesson: $e'),
                                            backgroundColor: Theme.of(context).colorScheme.error,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 28,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: filteredLessons.length,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading lessons',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
