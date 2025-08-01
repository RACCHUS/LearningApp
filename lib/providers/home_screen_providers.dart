import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/base_lesson.dart';
import 'package:learning_pwa/providers/combined_lessons_provider.dart';
import 'package:flutter/material.dart';

// StateProvider for the search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// StateProvider for the selected tag
final selectedTagProvider = StateProvider<String?>((ref) => null);

// Provider for the search TextEditingController
final searchControllerProvider = Provider.autoDispose<TextEditingController>((ref) {
  final controller = TextEditingController(text: ref.read(searchQueryProvider));
  controller.addListener(() {
    ref.read(searchQueryProvider.notifier).state = controller.text;
  });
  ref.onDispose(() => controller.dispose());
  return controller;
});

// Provider for filtered lessons based on search query and selected tag
final filteredLessonsProvider = Provider.family<List<BaseLesson>, String>((ref, userId) {
  final lessonsAsync = ref.watch(combinedLessonsProvider(userId));
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
  final selectedTag = ref.watch(selectedTagProvider);

  return lessonsAsync.when(
    data: (lessons) {
      return lessons.where((lesson) {
        final title = lesson.title.toLowerCase();
        final description = lesson.description?.toLowerCase() ?? '';

        final matchesSearch = searchQuery.isEmpty ||
            title.contains(searchQuery) ||
            description.contains(searchQuery);

        final matchesTag = selectedTag == null || lesson.tags.contains(selectedTag);

        return matchesSearch && matchesTag;
      }).toList();
    },
    loading: () => [], // Return empty list while loading
    error: (error, stackTrace) {
      print('Error filtering lessons: $error');
      return []; // Return empty list on error
    },
  );
});