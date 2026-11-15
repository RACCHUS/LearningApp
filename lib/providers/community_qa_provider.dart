import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// The Community Q&A service used by learning screens' in-context Q&A sheet.
///
/// Defaults to the real service (it resolves the Supabase client lazily).
/// Tests override it with a service backed by an explicitly offline client,
/// so "offline" is exercised deliberately instead of through an
/// uninitialized global client.
final communityQaServiceProvider = Provider<CommunityQaService>(
  (ref) => CommunityQaService(),
);

/// `learning.answer_revisions`: earlier versions of resubmitted Q&A answers.
/// Default OFF and fails closed; the server RPCs refuse while it is OFF.
final answerRevisionsFeatureEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningAnswerRevisions,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});
