import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/achievement.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:learning_pwa/services/xp_service.dart';

/// `learning.xp_achievements`. Default OFF and fails closed. A UI hint only:
/// `claim_activity_xp` re-checks the gate on the server for every claim.
final xpAchievementsEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningXpAchievements,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// Records finished activities for XP. Recording does not depend on the
/// learner's motivation display switches: those decide what Progress and the
/// session summary show, not whether activity is counted.
class ActivityXpRecorder {
  ActivityXpRecorder(this._ref);

  final Ref _ref;

  /// Returns null when the gate is OFF, signed out, offline or refused.
  Future<ActivityXpResult?> record(
    ActivityXpKind kind,
    String sourceId, {
    String? eventId,
  }) async {
    if (!_ref.read(xpAchievementsEnabledProvider)) return null;
    final result = await _ref.read(xpServiceProvider).claimActivityXp(
          kind: kind,
          sourceId: sourceId,
          eventId: eventId,
        );
    if (result != null &&
        (result.awarded || result.newAchievements.isNotEmpty)) {
      _ref.invalidate(userXpSummaryProvider);
      _ref.invalidate(totalXpProvider);
      _ref.invalidate(recentXpEventsProvider);
      _ref.invalidate(userAchievementsProvider);
    }
    return result;
  }
}

final activityXpRecorderProvider = Provider<ActivityXpRecorder>(
  (ref) => ActivityXpRecorder(ref),
);
