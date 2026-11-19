import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `learning.scratchpad`. Default OFF and fails closed. UI-only: the
/// scratchpad stores and sends nothing.
final scratchpadFeatureEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningScratchpad,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// The learner's own opt-in (Settings), device-local like other study
/// preferences. Off by default: the lesson only gets busier for learners
/// who ask for it (UI_ARCHITECTURE_LOCKED.md §5.6).
class ScratchpadPreferenceNotifier extends StateNotifier<bool> {
  ScratchpadPreferenceNotifier() : super(false) {
    _load();
  }

  static const storageKey = 'study.scratchpad_under_questions';
  bool _changed = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _changed) return;
    state = prefs.getBool(storageKey) ?? false;
  }

  Future<void> set(bool value) async {
    _changed = true;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKey, value);
  }
}

final scratchpadPreferenceProvider =
    StateNotifierProvider<ScratchpadPreferenceNotifier, bool>(
  (ref) => ScratchpadPreferenceNotifier(),
);

/// True only when the gate is ON and the learner opted in.
final showQuestionScratchpadProvider = Provider<bool>((ref) {
  return ref.watch(scratchpadFeatureEnabledProvider) &&
      ref.watch(scratchpadPreferenceProvider);
});
