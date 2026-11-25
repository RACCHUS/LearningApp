import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/companion/goal_coverage.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// Switch `content.learner_resources` (default OFF): the learner's own
/// outside resources on a goal (companion plan v1.0, EX-1). The server
/// checks the same switch on every write.
final learnerResourcesEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.contentLearnerResources,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// Switch `content.companion_capture` (default OFF): the entry points that
/// carry a link from another page into the add-a-resource form (companion
/// plan v1.0, EX-6). It needs the learner-resources switch too, because the
/// save goes through that server gate.
final companionCaptureEnabledProvider = Provider<bool>((ref) {
  return ref.watch(learnerResourcesEnabledProvider) &&
      isSiteFeatureEnabled(
        ref.watch(siteFeatureSnapshotProvider).valueOrNull,
        SiteFeatureKeys.contentCompanionCapture,
        runtimeReady: SiteFeatureRuntime.snapshotEnabled,
      );
});

/// Switch `content.companion_embeds` (default OFF): playing an embeddable
/// video from its provider inside the companion screen (companion plan
/// v1.0, EX-7). A client feature; the player writes nothing to LearningApp.
final companionEmbedsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(learnerResourcesEnabledProvider) &&
      isSiteFeatureEnabled(
        ref.watch(siteFeatureSnapshotProvider).valueOrNull,
        SiteFeatureKeys.contentCompanionEmbeds,
        runtimeReady: SiteFeatureRuntime.snapshotEnabled,
      );
});

/// A goal the learner already has, to attach a captured resource to.
typedef CaptureGoal = ({String targetId, String label});

/// The learner's goals, the active one first. Only goals: a course or a
/// study set is not something an outside resource is mapped to.
final captureGoalsProvider = Provider<List<CaptureGoal>>((ref) {
  final state = ref.watch(learningContextsProvider);
  final seen = <String>{};
  final goals = <CaptureGoal>[];
  for (final c in [
    ...state.contexts.where((c) => c.id == state.activeId),
    ...state.contexts.where((c) => c.id != state.activeId),
  ]) {
    if (c.rootType != ContextRootType.target || c.rootId.isEmpty || !seen.add(c.rootId)) continue;
    goals.add((targetId: c.rootId, label: c.label));
  }
  return goals;
});

/// True when there is an account (or anonymous session) to save to.
final learnerResourcesUseAccountProvider = Provider<bool>(
  (ref) => ref.watch(learnerIdProvider) != 'local-user',
);

final localLearnerResourceStoreProvider = Provider<LocalLearnerResourceStore>(
  (ref) => LocalLearnerResourceStore(),
);

final learnerResourceStoreProvider = Provider<LearnerResourceStore>((ref) {
  return ref.watch(learnerResourcesUseAccountProvider)
      ? SupabaseLearnerResourceStore()
      : ref.watch(localLearnerResourceStoreProvider);
});

/// The learner's outside resources for one goal. Empty while the switch is
/// off: nothing is read and nothing is shown, but saved data is kept.
final learnerResourcesProvider = FutureProvider.family<List<LearnerResource>, String>((ref, targetId) async {
  if (!ref.watch(learnerResourcesEnabledProvider) || targetId.isEmpty) return const [];
  return ref.watch(learnerResourceStoreProvider).list(targetId);
});

/// The next outside step for the active goal. Null when the active context
/// is not a goal, the switch is off, or nothing outside is left to study.
final activeOutsideStudyPlanProvider = FutureProvider<OutsideStudyPlan?>((ref) async {
  final context = ref.watch(activeLearningContextProvider);
  if (context == null || context.rootType != ContextRootType.target || context.rootId.isEmpty) return null;
  return OutsideStudyPlan.from(context.rootId, await ref.watch(learnerResourcesProvider(context.rootId).future));
});

/// How many guest resources are still on this device while an account is in
/// use, so the app can offer to move them. Zero for guests.
final strandedLocalResourcesProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(learnerResourcesEnabledProvider) || !ref.watch(learnerResourcesUseAccountProvider)) {
    return 0;
  }
  return (await ref.watch(localLearnerResourceStoreProvider).listAll()).length;
});

/// The three ways the app names one goal: its id, its current version and
/// its slug (the Coverage Matrix is read by slug).
typedef GoalRef = ({String targetId, String targetVersionId, String targetSlug});

/// A goal's objectives placed against the learner's outside resources and
/// LearningApp's own content (companion plan v1.0 EX-2). LearningApp's side
/// is optional: if its Coverage Matrix can't be read, only the outside half
/// is known and the view says so.
final goalCoverageProvider = FutureProvider.family<GoalCoverage, GoalRef>((ref, goal) async {
  final resourcesFuture = ref.watch(learnerResourcesProvider(goal.targetId).future);
  final nodesFuture = ref.watch(targetCurriculumNodesProvider(goal.targetVersionId).future);
  final matrixFuture = ref.watch(targetCoverageProvider(goal.targetSlug).future);
  final resources = await resourcesFuture;
  final nodes = await nodesFuture;
  List<CoverageRow>? rows;
  try {
    rows = (await matrixFuture).rows;
  } catch (_) {
    rows = null;
  }
  return GoalCoverage.build(
    outline: ResourceOutline.fromNodes(nodes),
    resources: resources,
    coverageRows: rows,
  );
});
