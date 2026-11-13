import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/community/lesson_contribution_service.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';
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

/// `content.refresh_proposals` (PR-H slice 4). Default OFF; the server
/// re-checks it on every proposal and decision.
final refreshProposalsEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.contentRefreshProposals,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

final lessonContributionServiceProvider = Provider<LessonContributionService>(
  (ref) => LessonContributionService(),
);

/// The caller's review roles, from the server (`is_moderator` / `is_admin`).
/// A display hint only: every review RPC re-checks the role server-side.
class ContributionRoles {
  const ContributionRoles({required this.moderator, required this.admin});

  final bool moderator;
  final bool admin;
}

final contributionRolesProvider = FutureProvider.autoDispose<ContributionRoles>(
  (ref) async {
    final service = ModerationService();
    final moderator = await service.isModerator();
    final admin = moderator && await service.isAdmin();
    return ContributionRoles(moderator: moderator, admin: admin);
  },
);
