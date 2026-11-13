import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/content_generation/manual_job_store.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// `ai.manual_generation_v2` (master plan v2.6 §15.0). Default OFF and
/// fails closed. It only hides the new slot-based generator; the V1
/// Quick Generate / AI-Guided / JSON Import / Manual Builder routes never
/// read it.
final manualGenerationV2EnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.aiManualGenerationV2,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// Imports personal-lesson JSON as the signed-in learner's private lesson
/// through the existing validated importer, returning the new lesson ID.
typedef ManualDraftImporter = Future<String> Function(String lessonJson);

final manualDraftImporterProvider = Provider<ManualDraftImporter>((ref) {
  return (lessonJson) async {
    final auth = ref.read(authProvider);
    final userId = auth is AuthSuccess ? auth.user.id : '';
    final lesson = await ref
        .read(lessonServiceProvider)
        .importLessonFromJson(lessonJson, userId);
    ref.invalidate(availableLessonsCatalogProvider);
    ref.invalidate(remoteCatalogLessonsProvider);
    return lesson.id;
  };
});

/// One store per app instance, so each tab has its own editor ID.
final manualJobStoreProvider = Provider<ManualJobStore>(
  (ref) => ManualJobStore(),
);

/// Owner scope for saved generator progress: the learner ID, or `guest`.
final manualJobOwnerProvider = Provider<String>((ref) {
  try {
    return supportOwnerScope(ref.watch(learnerIdProvider));
  } catch (_) {
    return 'guest';
  }
});
