import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/avatar/avatar_persistence_service.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// This is a device-local preference only. There is no server mutation.
/// A missing/unavailable operator flag leaves the customizer hidden.
final avatarCustomizerEnabledProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  if (auth is! AuthSuccess || auth.user.isAnonymous) return false;
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningAvatarCustomizer,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// Rebuilt on account changes: no local avatar is shared between learners
/// who use the same browser.
final avatarPersistenceProvider =
    ChangeNotifierProvider.autoDispose<AvatarPersistenceService>((ref) {
  final auth = ref.watch(authProvider);
  if (auth is! AuthSuccess || auth.user.isAnonymous) {
    throw StateError('Avatar preferences require a signed-in account.');
  }
  final service = AvatarPersistenceService(userId: auth.user.id);
  unawaited(service.load());
  return service;
});
