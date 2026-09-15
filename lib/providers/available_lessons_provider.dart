import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/base_lesson.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/lesson/lesson_catalog_service.dart';

/// Catalog data shown in Library.
///
/// [remoteError] is intentionally retained even when local/assets let the
/// Library keep working. A broken Supabase catalog must not be silently masked
/// by bundled fallback content.
class AvailableLessonsCatalog {
  final List<BaseLesson> lessons;
  final String? remoteError;

  const AvailableLessonsCatalog({
    required this.lessons,
    this.remoteError,
  });

  bool get hasRemoteError => remoteError != null;
}

final lessonCatalogServiceProvider = Provider<LessonCatalogService>((ref) {
  return LessonCatalogService();
});

/// All lessons the current Supabase session is allowed to read.
///
/// There is deliberately no user-id filter here. Supabase RLS decides catalog
/// visibility; ownership only controls mutation permissions.
final remoteCatalogLessonsProvider = FutureProvider<List<Lesson>>((ref) async {
  return ref.watch(lessonCatalogServiceProvider).getReadableLessons();
});

/// Device-local lessons are a separate source from the remote catalog.
final offlineCatalogLessonsProvider = FutureProvider<List<BaseLesson>>((ref) async {
  final userId = ref.watch(learnerIdProvider);
  return hiveService.getOfflineLessons(userId);
});

/// Complete Library catalog with graceful fallback.
///
/// Precedence for duplicate IDs is assets < remote < offline. That preserves
/// the user's local working copy when the same lesson exists in multiple
/// sources while still making every RLS-readable Supabase lesson discoverable.
final availableLessonsCatalogProvider =
    FutureProvider<AvailableLessonsCatalog>((ref) async {
  final assets = await ref.watch(assetLessonsProvider.future);

  List<Lesson> remote = const [];
  String? remoteError;
  try {
    remote = await ref.watch(remoteCatalogLessonsProvider.future);
  } catch (e) {
    remoteError = e.toString();
    debugPrint('⚠️ Remote lesson catalog unavailable: $e');
  }

  List<BaseLesson> offline = const [];
  try {
    offline = await ref.watch(offlineCatalogLessonsProvider.future);
  } catch (e) {
    debugPrint('⚠️ Offline lesson catalog unavailable: $e');
  }

  final byId = <String, BaseLesson>{};
  for (final lesson in <BaseLesson>[...assets, ...remote, ...offline]) {
    byId[lesson.id] = lesson;
  }

  final lessons = byId.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return AvailableLessonsCatalog(
    lessons: lessons,
    remoteError: remoteError,
  );
});

/// Backward-compatible list-only view for call sites that do not need source
/// health. Library uses [availableLessonsCatalogProvider] so it can surface a
/// remote-source warning without hiding fallback lessons.
final availableLessonsProvider = FutureProvider<List<BaseLesson>>((ref) async {
  final catalog = await ref.watch(availableLessonsCatalogProvider.future);
  return catalog.lessons;
});

final assetLessonsProvider = FutureProvider<List<Lesson>>((ref) async {
  try {
    final manifestRaw = await rootBundle.loadString('AssetManifest.json');
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final paths = manifest.keys
        .where((key) => key.startsWith('assets/lessons/') && key.endsWith('.json'))
        .toList()
      ..sort();

    final lessons = <Lesson>[];
    for (final path in paths) {
      try {
        final raw = await rootBundle.loadString(path);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        lessons.add(_parseAssetLesson(path, json));
      } catch (e) {
        debugPrint('⚠️ Skipping malformed asset lesson $path: $e');
      }
    }
    return lessons;
  } catch (e, stack) {
    debugPrint('⚠️ Could not load bundled lesson manifest: $e\n$stack');
    return const [];
  }
});

Lesson _parseAssetLesson(String path, Map<String, dynamic> json) {
  final id = path
      .split('/')
      .last
      .replaceAll(RegExp(r'\.json$'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final now = DateTime.utc(2026, 1, 1);
  final userId = 'asset-lessons';

  final concepts = (json['concepts'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(
        (c) => Concept(
          id: c['id']?.toString() ?? '${id}_concept',
          lessonId: id,
          conceptText: c['concept_text']?.toString() ?? '',
          exampleText: c['example_text']?.toString(),
          emoji: c['emoji']?.toString(),
          createdBy: userId,
          createdAt: now,
        ),
      )
      .where((c) => c.conceptText.isNotEmpty)
      .toList();

  final terms = (json['terms'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(
        (t) => Term(
          id: t['id']?.toString() ?? '${id}_term',
          term: t['term']?.toString() ?? '',
          definition: t['definition']?.toString() ?? '',
          example: t['example']?.toString(),
          emoji: t['emoji']?.toString(),
          createdBy: userId,
        ),
      )
      .where((t) => t.term.isNotEmpty && t.definition.isNotEmpty)
      .toList();

  final questions = (json['questions'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(
        (q) => Question(
          id: q['id']?.toString() ?? '${id}_question',
          questionText:
              q['question_text']?.toString() ?? q['question']?.toString() ?? '',
          options: q['options'] is List
              ? List<String>.from(q['options'] as List)
              : const <String>[],
          correctAnswer: q['correct_answer'] is int
              ? q['correct_answer'] as int
              : int.tryParse(q['correct_answer']?.toString() ?? '') ?? 0,
          type: q['type']?.toString() ?? 'mcq',
          explanation: q['explanation']?.toString(),
          createdBy: userId,
          createdAt: now,
        ),
      )
      .where((q) => q.questionText.isNotEmpty && q.options.isNotEmpty)
      .toList();

  final tags = json['tags'] is List
      ? List<String>.from(json['tags'] as List)
      : const <String>[];

  return Lesson(
    id: id,
    title: json['title']?.toString() ?? 'Untitled lesson',
    description: json['description']?.toString(),
    emoji: json['emoji']?.toString(),
    tags: tags,
    createdAt: now,
    updatedAt: now,
    userId: userId,
    terms: terms,
    questions: questions,
    concepts: concepts,
  );
}
