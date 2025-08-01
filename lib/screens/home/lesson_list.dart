import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/base_lesson.dart';
import 'package:learning_pwa/models/local_lesson.dart';

class LessonList extends StatelessWidget {
  final AsyncValue<List<BaseLesson>> lessonsStream;
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

  Widget _buildLessonCard(BuildContext context, BaseLesson lesson) {
    final isLocalLesson = lesson is LocalLesson;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(lesson.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lesson.description != null) ...[
              const SizedBox(height: 4),
              Text(
                lesson.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDate(lesson.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (lesson.tags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      lesson.tags.first,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                      ),
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
            if (isLocalLesson)
              const Icon(Icons.offline_pin, color: Colors.orange),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push('/lesson/${lesson.id}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return lessonsStream.when(
      data: (lessons) {
        if (lessons.isEmpty) {
          return const Center(
            child: Text('No lessons available'),
          );
        }

        final filteredLessons = lessons.where((lesson) {
          final matchesSearch = searchQuery.isEmpty ||
              lesson.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (lesson.description?.toLowerCase() ?? '')
                  .contains(searchQuery.toLowerCase());
          final matchesTag =
              selectedTag == null || lesson.tags.contains(selectedTag);
          return matchesSearch && matchesTag;
        }).toList();

        if (filteredLessons.isEmpty) {
          return const Center(
            child: Text('No lessons match your filters'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredLessons.length,
          itemBuilder: (context, index) {
            final lesson = filteredLessons[index];
            return _buildLessonCard(context, lesson);
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
