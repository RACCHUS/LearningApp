import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_pwa/models/lesson.dart';


class LessonList extends StatelessWidget {
  final AsyncValue<List<Lesson>> lessonsStream;
  final String searchQuery;
  final String? selectedTag;

  const LessonList({
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


  @override
  Widget build(BuildContext context) {
    return lessonsStream.when(
      data: (lessons) {
        if (lessons.isEmpty) {
          return const Center(
            child: Text('No lessons available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          );
        }

        final filteredLessons = lessons.where((lesson) {
          final query = searchQuery.toLowerCase();
          final matchesSearch = query.isEmpty ||
              lesson.title.toLowerCase().contains(query) ||
              (lesson.description?.toLowerCase() ?? '').contains(query) ||
              lesson.tags.any((tag) => tag.toLowerCase().contains(query));
          final matchesTag =
              selectedTag == null || lesson.tags.contains(selectedTag);
          return matchesSearch && matchesTag;
        }).toList();

        if (filteredLessons.isEmpty) {
          return const Center(
            child: Text('No lessons match your filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
          itemCount: filteredLessons.length,
          itemBuilder: (context, index) {
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
                    hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
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
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (lesson.tags.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Wrap(
                                  spacing: 6,
                                  children: lesson.tags.map((tag) => Chip(
                                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                    labelStyle: const TextStyle(color: Colors.blue),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 28),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => Center(
        child: Text('Error: $error'),
      ),
    );
  }
}
