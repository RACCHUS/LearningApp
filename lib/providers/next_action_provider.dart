import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/services/course_service.dart';
import 'package:learning_pwa/services/learning_context_service.dart';
import 'package:learning_pwa/services/learning_context_migration.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';

final courseServiceProvider = Provider<CourseService>((ref) => CourseService());

final savedStudySetServiceProvider =
    Provider<SavedStudySetService>((ref) => SavedStudySetService());

final learningContextMigrationProvider =
    Provider<LearningContextMigration>((ref) {
  return LearningContextMigration(
    contexts: ref.watch(learningContextServiceProvider),
    courses: ref.watch(courseServiceProvider),
    studySets: ref.watch(savedStudySetServiceProvider),
  );
});

/// Runs the one-time backfill, then reports whether any context exists.
///
/// Idempotent, so a repeated run after a failure is harmless.
final learningBootstrapProvider = FutureProvider<void>((ref) async {
  final userId = ref.watch(learnerIdProvider);
  try {
    final report =
        await ref.watch(learningContextMigrationProvider).runOnce(userId);
    if (report != null && report.created > 0) {
      await ref.read(learningContextsProvider.notifier).load();
    }
  } catch (e) {
    // Startup must never be blocked by migration: the learner can still add
    // a context by hand from Library.
    debugPrint('\u26a0\ufe0f Learning bootstrap skipped: $e');
  }
});

/// Turns a [LearningContext] into the value object the pure engine consumes.
///
/// All I/O lives here so [NextActionEngine] stays testable without a network,
/// a database, or a widget tree.
class ContextSnapshotResolver {
  final CourseService _courses;
  final SavedStudySetService _studySets;
  final SpacedRepetitionService _reviews;
  final LearningContextService _contexts;

  const ContextSnapshotResolver({
    required CourseService courses,
    required SavedStudySetService studySets,
    required SpacedRepetitionService reviews,
    required LearningContextService contexts,
  })  : _courses = courses,
        _studySets = studySets,
        _reviews = reviews,
        _contexts = contexts;

  Future<ContextSnapshot> resolve(LearningContext context) async {
    final due = await _safeDueItems();
    final resume = _contexts.resumeFor(context.id);

    LearningActivity? next;
    LearningActivity? resumeActivity;
    var resumeItemCount = 0;

    switch (context.rootType) {
      case ContextRootType.path:
      case ContextRootType.course:
      case ContextRootType.module:
        final resolved = await _resolveCourseActivity(context, due);
        next = resolved.next;
        resumeActivity = resolved.resume ?? _lessonFromPointer(resume);
        resumeItemCount = resolved.resumeItemCount;
        break;

      case ContextRootType.lesson:
        final started = due.any((i) => i.lessonId == context.rootId);
        next = started
            ? null
            : LessonActivity(lessonId: context.rootId, title: context.label);
        resumeActivity = _lessonFromPointer(resume);
        resumeItemCount = _itemCountForLesson(due, context.rootId);
        break;

      case ContextRootType.studySet:
        // Practice is repeatable, so a study set never runs out of material.
        next = await _resolveStudySetActivity(context, due);
        resumeActivity = resume?.kind == ResumableKind.studySet
            ? next
            : _lessonFromPointer(resume);
        resumeItemCount =
            next is StudySetActivity ? next.itemCount : 0;
        break;
    }

    final dueIds = due
        .where((i) => _belongsToContext(i, context))
        .map((i) => i.contentId)
        .toList();

    return ContextSnapshot(
      context: context,
      resume: resume,
      resumeActivity: resumeActivity,
      resumeItemCount: resumeItemCount,
      nextActivity: next,
      dueConceptIds: dueIds,
      strugglingConceptIds: _struggling(due),
      forwardOffer: next == null ? ForwardOffer.browse : null,
    );
  }

  Future<({LearningActivity? next, LearningActivity? resume, int resumeItemCount})>
      _resolveCourseActivity(
    LearningContext context,
    List<ReviewableItem> due,
  ) async {
    try {
      final content = await _courses.getCourseWithContent(context.rootId);
      final lessons = content.orderedLessons;
      if (lessons.isEmpty) {
        return (next: null, resume: null, resumeItemCount: 0);
      }

      final studied = due.map((i) => i.lessonId).toSet();
      final nextLesson = lessons.where((l) => !studied.contains(l.id));
      final index = lessons.indexWhere((l) => !studied.contains(l.id));

      final next = nextLesson.isEmpty
          ? null
          : LessonActivity(
              lessonId: nextLesson.first.id,
              title: nextLesson.first.title,
              courseId: content.course.id,
              courseTitle: content.course.title,
              position: index + 1,
              total: lessons.length,
            );

      return (next: next, resume: null, resumeItemCount: 0);
    } catch (e) {
      // A course that will not load must not strand the learner on a blank
      // screen — fall through to the exhausted branch, which always offers
      // a way onward.
      debugPrint('⚠️ Could not resolve course ${context.rootId}: $e');
      return (next: null, resume: null, resumeItemCount: 0);
    }
  }

  Future<LearningActivity?> _resolveStudySetActivity(
    LearningContext context,
    List<ReviewableItem> due,
  ) async {
    try {
      final set = await _studySets.getStudySet(context.rootId);
      final dueInSet = due
          .where((i) => set.lessonIds.contains(i.lessonId))
          .length;
      return StudySetActivity(
        studySetId: set.id,
        title: set.title,
        itemCount: dueInSet > 0 ? dueInSet : set.totalItems,
        isDueSubset: dueInSet > 0,
      );
    } catch (e) {
      debugPrint('⚠️ Could not resolve study set ${context.rootId}: $e');
      // Still offer practice: the set exists even if its metadata failed.
      return StudySetActivity(
        studySetId: context.rootId,
        title: context.label,
        itemCount: 0,
      );
    }
  }

  LearningActivity? _lessonFromPointer(ResumePointer? resume) {
    if (resume == null || resume.kind != ResumableKind.lesson) return null;
    return LessonActivity(
      lessonId: resume.activityId,
      title: 'Continue',
    );
  }

  int _itemCountForLesson(List<ReviewableItem> items, String lessonId) {
    return items.where((i) => i.lessonId == lessonId).length;
  }

  bool _belongsToContext(ReviewableItem item, LearningContext context) {
    if (context.rootType == ContextRootType.lesson) {
      return item.lessonId == context.rootId;
    }
    return true;
  }

  List<String> _struggling(List<ReviewableItem> items) {
    return items
        .where((i) => i.totalReviews >= 2 && i.accuracy < 0.6)
        .map((i) => i.contentId)
        .toList();
  }

  Future<List<ReviewableItem>> _safeDueItems() async {
    try {
      return await _reviews.getDueItems();
    } catch (e) {
      // Offline or signed out: an empty due list is correct-enough and lets
      // the engine keep resolving forward progress.
      debugPrint('⚠️ Could not load due items: $e');
      return const [];
    }
  }
}

final contextSnapshotResolverProvider = Provider<ContextSnapshotResolver>((ref) {
  return ContextSnapshotResolver(
    courses: ref.watch(courseServiceProvider),
    studySets: ref.watch(savedStudySetServiceProvider),
    reviews: ref.watch(spacedRepetitionServiceProvider),
    contexts: ref.watch(learningContextServiceProvider),
  );
});

/// The single primary action rendered by the Learn screen.
final nextActionProvider = FutureProvider<NextAction>((ref) async {
  final state = ref.watch(learningContextsProvider);
  final engine = ref.watch(nextActionEngineProvider);
  final active = state.active;

  if (active == null) {
    return const ChooseSomething();
  }

  try {
    final snapshot =
        await ref.watch(contextSnapshotResolverProvider).resolve(active);
    return engine.resolve(contexts: state.contexts, active: snapshot);
  } catch (e, stack) {
    debugPrint('❌ Next action resolution failed: $e\n$stack');
    // Never leave Learn without an action: browsing is always valid.
    return const ContextComplete(offer: ForwardOffer.browse);
  }
});

/// Due count for the active context, used by the secondary review prompt.
final activeDueCountProvider = FutureProvider<int>((ref) async {
  final active = ref.watch(activeLearningContextProvider);
  if (active == null) return 0;
  try {
    final snapshot =
        await ref.watch(contextSnapshotResolverProvider).resolve(active);
    return snapshot.dueCount;
  } catch (_) {
    return 0;
  }
});
