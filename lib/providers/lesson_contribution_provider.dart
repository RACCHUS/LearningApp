import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/community/lesson_contribution_service.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// `content.public_contribution` (master plan v2.6 §15.0, PR-H). Default
/// OFF and fails closed. A UI hint only: every contribution RPC checks the
/// gate again on the server.
final publicContributionEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.contentPublicContribution,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

final lessonContributionServiceProvider = Provider<LessonContributionService>(
  (ref) => LessonContributionService(),
);
