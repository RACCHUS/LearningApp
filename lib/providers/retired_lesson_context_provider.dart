import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/services/hive_service.dart';
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

/// Device-local progress for a lesson: its lesson ids, and moving them.
/// Server progress is carried by the database when a version is retired
/// (migration 20261121000000); this covers guests and the offline queue.
abstract class LocalLessonProgress {
  Future<Set<String>> lessonIds();
  Future<int> moveLesson(String fromLessonId, String toLessonId);
}

class HiveLocalLessonProgress implements LocalLessonProgress {
  HiveLocalLessonProgress(this._hive);
  final HiveService _hive;

  @override
  Future<Set<String>> lessonIds() async =>
      {for (final p in await _hive.getProgress()) p.lessonId};

  @override
  Future<int> moveLesson(String fromLessonId, String toLessonId) async {
    var moved = 0;
    for (final p in await _hive.getProgress()) {
      if (p.lessonId != fromLessonId) continue;
      await _hive.saveProgress(p.copyWith(lessonId: toLessonId));
      moved++;
    }
    return moved;
  }
}

final localLessonProgressProvider = Provider<LocalLessonProgress>((ref) {
  return HiveLocalLessonProgress(ref.watch(hiveServiceProvider));
});

/// Server lesson ids (UUIDs) missing from a successfully loaded catalog.
@visibleForTesting
Set<String> lessonIdsMissingFromCatalog(
  Iterable<String> lessonIds,
  AvailableLessonsCatalog catalog,
) {
  if (catalog.hasRemoteError) return const {};
  final ids = {for (final l in catalog.lessons) l.id};
  return lessonIds.where((id) => _uuid.hasMatch(id) && !ids.contains(id)).toSet();
}

/// Server answers per lesson for this app session (null: the lookup
/// failed, so leave that lesson alone until the next session). Answers are
/// reused, not skipped: contexts and progress can load at different times,
/// and whatever turns up later must still be moved.
final _answers = <String, LessonReplacement?>{};

@visibleForTesting
void resetRetiredLessonChecks() => _answers.clear();

/// Keeps learning contexts and device-local progress on live lessons after
/// a corrected curriculum version replaces a retired one: moves each stale
/// context (with its resume pointer) and local progress record to the
/// replacement, or archives the context when the section was dropped. Acts
/// only when the server confirms the lesson's version is retired.
final retiredLessonContextRepairProvider = FutureProvider<void>((ref) async {
  final contexts = ref.watch(learningContextsProvider.select((s) => s.contexts));
  final catalog = await ref.watch(availableLessonsCatalogProvider.future);
  final lookup = ref.watch(lessonReplacementLookupProvider);
  final notifier = ref.read(learningContextsProvider.notifier);
  final local = ref.watch(localLessonProgressProvider);

  final staleContexts = lessonContextsMissingFromCatalog(contexts, catalog);
  Set<String> progressIds = const {};
  try {
    progressIds = lessonIdsMissingFromCatalog(await local.lessonIds(), catalog);
  } catch (e) {
    debugPrint('⚠️ Could not read local progress: $e');
  }
  final candidates = {...staleContexts.map((c) => c.rootId), ...progressIds};

  for (final lessonId in candidates) {
    try {
      final LessonReplacement? answer;
      if (_answers.containsKey(lessonId)) {
        answer = _answers[lessonId];
      } else {
        try {
          answer = _answers[lessonId] = await lookup(lessonId);
        } catch (e) {
          _answers[lessonId] = null;
          rethrow;
        }
      }
      if (answer == null || !answer.retired) continue;
      final replacement = answer.replacementId;
      if (replacement != null && progressIds.contains(lessonId)) {
        await local.moveLesson(lessonId, replacement);
      }
      for (final stale in staleContexts.where((c) => c.rootId == lessonId)) {
        await notifier.replaceRetiredLesson(stale, replacement);
      }
    } catch (e) {
      debugPrint('⚠️ Could not check lesson $lessonId: $e');
    }
  }
});
