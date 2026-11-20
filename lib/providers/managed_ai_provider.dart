import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/byok_session_provider.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/ai/managed_ai_service.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `ai.managed`: free AI on LearningApp's own free-tier Gemini key. The
/// client only decides whether to show the button; the server admits each
/// request (switch, pause, caps) before anything reaches Gemini.
final managedAiEnabledProvider = Provider<bool>((ref) {
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.aiManaged,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

final managedAiApiProvider = Provider<ManagedAiApi>(
  (_) => SupabaseManagedAiApi(Supabase.instance.client),
);

class ManagedAiState {
  const ManagedAiState({
    this.status = ManagedAiStatus.off,
    this.loaded = false,
    this.busy = false,
    this.adultConfirmed = false,
  });

  final ManagedAiStatus status;
  final bool loaded;
  final bool busy;

  /// The learner confirmed they are 18 or older (Gemini API terms).
  final bool adultConfirmed;

  bool get outOfRequests => status.enabled && status.remainingToday <= 0;
  bool get ready =>
      status.enabled && !status.paused && !outOfRequests && !busy;

  ManagedAiState copyWith({
    ManagedAiStatus? status,
    bool? loaded,
    bool? busy,
    bool? adultConfirmed,
  }) => ManagedAiState(
    status: status ?? this.status,
    loaded: loaded ?? this.loaded,
    busy: busy ?? this.busy,
    adultConfirmed: adultConfirmed ?? this.adultConfirmed,
  );
}

class ManagedAiController extends StateNotifier<ManagedAiState> {
  ManagedAiController(this._ref) : super(const ManagedAiState()) {
    refresh();
  }

  final Ref _ref;
  static const _adultKey = 'managed_ai_adult_confirmed_v1';

  Future<void> refresh() async {
    var adult = state.adultConfirmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      adult = prefs.getBool(_adultKey) ?? adult;
    } catch (_) {}
    final status = _ref.read(managedAiEnabledProvider)
        ? await _ref.read(managedAiApiProvider).status()
        : ManagedAiStatus.off;
    if (!mounted) return;
    state = state.copyWith(status: status, loaded: true, adultConfirmed: adult);
  }

  Future<void> confirmAdult() async {
    state = state.copyWith(adultConfirmed: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adultKey, true);
    } catch (_) {}
  }

  /// Sends [prompt] through the server. Throws [ManagedAiException]; when
  /// the free allowance runs out the state turns off and says why.
  Future<String> ask(String prompt) async {
    if (!state.ready || !state.adultConfirmed) {
      throw ManagedAiException(
        state.status.paused
            ? ManagedAiFailure.paused
            : state.outOfRequests
            ? ManagedAiFailure.userLimit
            : ManagedAiFailure.unavailable,
      );
    }
    state = state.copyWith(busy: true);
    final api = _ref.read(managedAiApiProvider);
    try {
      for (var attempt = 1; ; attempt++) {
        try {
          final result = await api.generate(prompt);
          if (mounted && result.remainingToday != null) {
            state = state.copyWith(
              status: state.status.copyWith(
                remainingToday: result.remainingToday,
              ),
            );
          }
          return result.text;
        } on ManagedAiException catch (e) {
          if (!mounted) rethrow;
          switch (e.failure) {
            case ManagedAiFailure.paused:
              state = state.copyWith(
                status: state.status.copyWith(paused: true),
              );
              rethrow;
            case ManagedAiFailure.userLimit:
              state = state.copyWith(
                status: state.status.copyWith(remainingToday: 0),
              );
              rethrow;
            case ManagedAiFailure.rateLimited:
              final wait = e.retryAfter ?? const Duration(seconds: 5);
              if (attempt >= 2 || wait > const Duration(seconds: 30)) rethrow;
              await _ref.read(byokRetryDelayProvider)(wait);
            default:
              rethrow;
          }
        }
      }
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }
}

final managedAiProvider =
    StateNotifierProvider.autoDispose<ManagedAiController, ManagedAiState>(
      ManagedAiController.new,
    );
