import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/base_lesson.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/providers/combined_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';

/// Lessons the learner can browse right now.
///
/// Database/offline lessons are merged with bundled asset lessons so Library is
/// never empty just because the user is signed out, offline, or has no Supabase
/// rows yet. Asset lessons are real selectable lessons, not marketing cards.
final availableLessonsProvider = FutureProvider<List<BaseLesson>>((ref) async {
  final userId = ref.watch(learnerIdProvider);
  final combined = await ref.watch(combinedLessonsProvider(userId).future);
  final assets = await ref.watch(assetLessonsProvider.future);

  final byId = <String, BaseLesson>{};
  for (final lesson in [...assets, ...combined]) {
    byId[lesson.id] = lesson;
  }
  final lessons = byId.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return lessons;
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
