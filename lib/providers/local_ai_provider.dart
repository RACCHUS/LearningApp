import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/ai/local_ai/local_summarizer.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// `ai.local_experimental`: the switch for on-device AI (plan v2.6 P4.1).
final localAiEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.aiLocalExperimental,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

final localSummarizerProvider = Provider<LocalSummarizer>(
  (ref) => createLocalSummarizer(),
);

/// What this browser and device can do. Unsupported when the switch is off,
/// so nothing is asked of the browser at all.
final localAiAvailabilityProvider = FutureProvider<LocalAiAvailability>((
  ref,
) async {
  if (!ref.watch(localAiEnabledProvider)) return LocalAiAvailability.unsupported;
  try {
    return await ref.watch(localSummarizerProvider).availability();
  } catch (_) {
    return LocalAiAvailability.unsupported;
  }
});
