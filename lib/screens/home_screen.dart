import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/lesson_list_provider.dart';
import 'package:learning_pwa/widgets/tag_filter_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? selectedTag;

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: lessonAsync.when(
        data: (lessons) {
          final allTags = {
            for (final lesson in lessons) ...lesson.tags
          }.toList();
          final filteredLessons = selectedTag == null
              ? lessons
              : lessons.where((l) => l.tags.contains(selectedTag)).toList();
          return Column(
            children: [
              TagFilterBar(
                tags: allTags,
                selectedTag: selectedTag,
                onTagSelected: (tag) => setState(() => selectedTag = tag),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredLessons.length,
                  itemBuilder: (context, idx) {
                    final lesson = filteredLessons[idx];
                    return ListTile(
                      title: Text(lesson.title),
                      subtitle: Text(lesson.tags.join(', ')),
                      onTap: () {
                        // TODO: Navigate to lesson detail
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
