import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      body: Column(
        children: [
          // Development section (only show in debug mode)
          if (const bool.fromEnvironment('dart.vm.product') == false)
            Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Development Tools', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children: [
                        ActionChip(
                          label: const Text('Test Notifications'),
                          onPressed: () => context.go('/test/notifications'),
                          avatar: const Icon(Icons.notifications, size: 18),
                          backgroundColor: Colors.blue[50],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Main content
          Expanded(
            child: lessonAsync.when(
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
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
