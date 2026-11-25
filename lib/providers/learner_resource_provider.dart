import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
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

/// How many guest resources are still on this device while an account is in
/// use, so the app can offer to move them. Zero for guests.
final strandedLocalResourcesProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(learnerResourcesEnabledProvider) || !ref.watch(learnerResourcesUseAccountProvider)) {
    return 0;
  }
  return (await ref.watch(localLearnerResourceStoreProvider).listAll()).length;
});
