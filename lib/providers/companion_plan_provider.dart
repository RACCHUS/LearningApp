import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/services/learning_support/companion_plan_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

final companionPlanLibraryProvider = FutureProvider<CompanionPlanLibrary>((ref) async {
  final bridges = await ref.watch(bridgeLibraryProvider.future);
  final companions = await ref.watch(externalCompanionLibraryProvider.future);
  return CompanionPlanLibrary.load(rootBundle, bridges, companions);
});

/// The learner's own "done" ticks for one plan's steps. Device-local, never
/// sent anywhere and never counted as evidence (§9.3: progress outside
/// LearningApp is self-report).
class CompanionPlanProgress extends StateNotifier<Set<String>> {
  CompanionPlanProgress(this.planId) : super(const {}) {
    _load();
  }

  final String planId;
  String get _key => 'companion_plan_done_v1_$planId';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key);
      if (saved != null && mounted) state = saved.toSet();
    } catch (_) {}
  }

  Future<void> toggle(String partId) async {
    state = state.contains(partId)
        ? ({...state}..remove(partId))
        : {...state, partId};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, state.toList()..sort());
    } catch (_) {}
  }
}

final companionPlanProgressProvider =
    StateNotifierProvider.family<CompanionPlanProgress, Set<String>, String>(
  (ref, planId) => CompanionPlanProgress(planId),
);
