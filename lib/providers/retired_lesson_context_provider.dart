import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server answer for a lesson that is missing from the catalog.
class LessonReplacement {
  final bool retired;
  final String? replacementId;

  const LessonReplacement({required this.retired, this.replacementId});

  factory LessonReplacement.fromJson(Map<String, dynamic> json) =>
      LessonReplacement(
        retired: json['retired'] == true,
        replacementId: json['replacement_id'] as String?,
      );
}

typedef LessonReplacementLookup = Future<LessonReplacement> Function(
  String lessonId,
);

/// Calls `public.lesson_replacement` (migration 20261120030000).
final lessonReplacementLookupProvider = Provider<LessonReplacementLookup>((ref) {
  return (lessonId) async {
    final res = await Supabase.instance.client
        .rpc('lesson_replacement', params: {'p_lesson_id': lessonId});
    return LessonReplacement.fromJson(Map<String, dynamic>.from(res as Map));
  };
});

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Lesson contexts whose lesson is not in the loaded catalog. Only server
/// lesson ids (UUIDs) qualify, and nothing qualifies while the remote
/// catalog failed to load, so an outage never looks like a retirement.
@visibleForTesting
List<LearningContext> lessonContextsMissingFromCatalog(
  List<LearningContext> contexts,
  AvailableLessonsCatalog catalog,
) {
  if (catalog.hasRemoteError) return const [];
  final ids = {for (final l in catalog.lessons) l.id};
  return contexts
      .where((c) =>
          !c.isArchived &&
          c.rootType == ContextRootType.lesson &&
          _uuid.hasMatch(c.rootId) &&
          !ids.contains(c.rootId))
      .toList();
}

/// Lesson ids already asked about in this app session.
final _askedLessonIds = <String>{};

@visibleForTesting
void resetRetiredLessonChecks() => _askedLessonIds.clear();

/// Keeps learning contexts pointing at live lessons after a corrected
/// curriculum version replaces a retired one: moves each stale context to
/// its replacement, or archives it when the section was dropped. Acts only
/// when the server confirms the lesson's version is retired.
final retiredLessonContextRepairProvider = FutureProvider<void>((ref) async {
  final contexts = ref.watch(learningContextsProvider.select((s) => s.contexts));
  final catalog = await ref.watch(availableLessonsCatalogProvider.future);
  final lookup = ref.watch(lessonReplacementLookupProvider);
  final notifier = ref.read(learningContextsProvider.notifier);

  for (final stale in lessonContextsMissingFromCatalog(contexts, catalog)) {
    if (!_askedLessonIds.add(stale.rootId)) continue;
    try {
      final answer = await lookup(stale.rootId);
      if (!answer.retired) continue;
      await notifier.replaceRetiredLesson(stale, answer.replacementId);
    } catch (e) {
      debugPrint('⚠️ Could not check lesson ${stale.rootId}: $e');
    }
  }
});
