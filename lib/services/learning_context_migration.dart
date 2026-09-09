import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/services/learning_context_service.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';
import 'package:learning_pwa/services/course_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Creates one [LearningContext] per thing the learner already started.
///
/// Runs once per user, but is safe to run any number of times: every write
/// goes through `createOrGet`, which de-duplicates on
/// (userId, rootType, rootId). Nothing here deletes or rewrites content.
class LearningContextMigration {
  final LearningContextService _contexts;
  final CourseService _courses;
  final SavedStudySetService _studySets;

  const LearningContextMigration({
    required LearningContextService contexts,
    required CourseService courses,
    required SavedStudySetService studySets,
  })  : _contexts = contexts,
        _courses = courses,
        _studySets = studySets;

  static const _kMigratedPrefix = 'learning.backfill.v1.';

  Future<BackfillReport?> runOnce(String userId) async {
    if (await _hasRun(userId)) return null;

    final seeds = await _collectSeeds();
    final report = await _contexts.backfill(userId: userId, seeds: seeds);

    // Only mark complete on a clean pass, so a partial failure retries later.
    if (!report.hasFailures) {
      await _markRun(userId);
    }
    debugPrint('ℹ️ Learning context backfill: $report');
    return report;
  }

  Future<List<BackfillSeed>> _collectSeeds() async {
    final seeds = <BackfillSeed>[];

    try {
      for (final course in await _courses.getUserCourses()) {
        seeds.add(BackfillSeed(
          label: course.title,
          rootType: ContextRootType.course,
          rootId: course.id,
          lastActiveAt: course.updatedAt,
        ));
      }
    } catch (e) {
      // A source that cannot be read yields no seeds rather than aborting the
      // whole migration; the next run picks it up.
      debugPrint('⚠️ Backfill could not read courses: $e');
    }

    try {
      for (final set in await _studySets.getUserStudySets()) {
        seeds.add(BackfillSeed(
          label: set.title,
          rootType: ContextRootType.studySet,
          rootId: set.id,
          lastActiveAt: set.updatedAt,
        ));
      }
    } catch (e) {
      debugPrint('⚠️ Backfill could not read study sets: $e');
    }

    return seeds;
  }

  Future<bool> _hasRun(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_kMigratedPrefix$userId') ?? false;
    } catch (_) {
      // If we cannot tell, running again is harmless — it is idempotent.
      return false;
    }
  }

  Future<void> _markRun(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_kMigratedPrefix$userId', true);
    } catch (e) {
      debugPrint('⚠️ Could not record backfill completion: $e');
    }
  }
}
