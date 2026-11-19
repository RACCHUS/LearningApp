import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:learning_pwa/services/progress/reinforcement_suggestion_service.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `learning.reinforcement_suggestions`: the Progress "needs reinforcement"
/// list (UI spec §5.5). Default OFF and fails closed. Read-only: it stores
/// nothing on the server, so there is no server write to gate.
final reinforcementSuggestionsFeatureEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.learningReinforcementSuggestions,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

final reinforcementSuggestionServiceProvider =
    Provider<ReinforcementSuggestionService>((ref) {
  return ReinforcementSuggestionService(
    client: Supabase.instance.client,
    conceptStates: (userId) =>
        ref.read(conceptEvidenceServiceProvider).getUserConceptStates(userId),
    dueItems: () => ref.read(spacedRepetitionServiceProvider).getDueItems(),
  );
});

/// Empty while the gate is OFF, without touching the network.
final reinforcementSuggestionsProvider =
    FutureProvider<List<ReinforcementSuggestion>>((ref) async {
  if (!ref.watch(reinforcementSuggestionsFeatureEnabledProvider)) {
    return const [];
  }
  final learnerId = ref.watch(learnerIdProvider);
  return ref.read(reinforcementSuggestionServiceProvider).load(learnerId);
});

/// Suggestions the learner hid, on this device, per account. Hiding is
/// silent (UI spec §8.5). The key includes the concept's latest evidence
/// time, so a concept comes back only after new evidence still finds it weak.
class ReinforcementDismissals extends StateNotifier<Set<String>> {
  ReinforcementDismissals(this._userId) : super(const {}) {
    _load();
  }

  final String _userId;
  bool _changed = false;

  String get _storageKey => 'progress.reinforcement_hidden.$_userId';

  static String keyFor(ReinforcementSuggestion s) =>
      '${s.conceptId}|${s.lastEvidenceAt?.toUtc().toIso8601String() ?? ''}';

  bool isHidden(ReinforcementSuggestion s) => state.contains(keyFor(s));

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _changed) return;
    state = (prefs.getStringList(_storageKey) ?? const []).toSet();
  }

  Future<void> hide(ReinforcementSuggestion s) async {
    _changed = true;
    state = {...state, keyFor(s)};
    final prefs = await SharedPreferences.getInstance();
    // Keep the stored list bounded.
    final list = state.toList();
    await prefs.setStringList(
        _storageKey, list.length > 200 ? list.sublist(list.length - 200) : list);
  }
}

final reinforcementDismissalsProvider =
    StateNotifierProvider<ReinforcementDismissals, Set<String>>((ref) {
  return ReinforcementDismissals(ref.watch(learnerIdProvider));
});
