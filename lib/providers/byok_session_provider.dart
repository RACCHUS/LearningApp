import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/governance/site_feature_keys.dart';
import 'package:learning_pwa/providers/site_feature_provider.dart';
import 'package:learning_pwa/services/ai/byok_provider.dart';
import 'package:learning_pwa/services/ai/byok_release_gate.dart';
import 'package:learning_pwa/services/ai/llm_client.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// The build-time owner latch (FLAG-015). A provider only so widget tests
/// can render the ON state; production reads the compile-time constant.
final byokReleaseApprovedProvider = Provider<bool>(
  (_) => ByokReleaseGate.enabled,
);

/// "Ask my AI" is offered only when the build was released with the latch
/// AND the live `ai.byok` switch is on. Either one alone keeps it hidden,
/// and the copy-and-paste path never depends on it.
final byokAvailableProvider = Provider<bool>((ref) {
  if (!ref.watch(byokReleaseApprovedProvider)) return false;
  return isSiteFeatureEnabled(
    ref.watch(siteFeatureSnapshotProvider).valueOrNull,
    SiteFeatureKeys.aiByok,
    runtimeReady: SiteFeatureRuntime.snapshotEnabled,
  );
});

/// One storage service for the whole app, so a key entered in settings is
/// still in memory when "Ask my AI" runs. Keys are never written to disk.
final byokStorageProvider = Provider<ByokStorageService>(
  (_) => ByokStorageService(),
);

typedef LlmClientFactory = LlmClient Function(ByokConfig config);

/// Production goes through [LlmClient.create], which enforces the latch
/// and the endpoint allowlist on every call.
final llmClientFactoryProvider = Provider<LlmClientFactory>(
  (_) => LlmClient.create,
);

typedef RetryDelay = Future<void> Function(Duration wait);

final byokRetryDelayProvider = Provider<RetryDelay>((_) => Future.delayed);

class ByokSessionState {
  const ByokSessionState({this.config, this.busy = false, this.paused = false});

  /// Settings with the in-memory key, or null when none is set up.
  final ByokConfig? config;
  final bool busy;

  /// True after the provider said the quota is used up. "Ask my AI" stays
  /// off until the learner chooses to try again.
  final bool paused;

  bool get configured => config?.isConfigured ?? false;
  bool get ready => configured && !paused && !busy;
  String get providerName => config?.provider.shortName ?? 'your AI';

  ByokSessionState copyWith({
    ByokConfig? config,
    bool clearConfig = false,
    bool? busy,
    bool? paused,
  }) => ByokSessionState(
    config: clearConfig ? null : (config ?? this.config),
    busy: busy ?? this.busy,
    paused: paused ?? this.paused,
  );
}

/// Owns the learner's own-key session: the in-memory key, retries for
/// short provider hiccups, and switching itself off when the quota runs
/// out (the learner is told and pointed to copy and paste).
class ByokSessionController extends StateNotifier<ByokSessionState> {
  ByokSessionController(this._ref) : super(const ByokSessionState()) {
    _load();
  }

  final Ref _ref;

  /// Longest provider-requested wait we sit through before giving up and
  /// telling the learner; anything longer is treated as a quota stop.
  static const maxWait = Duration(seconds: 30);
  static const maxAttempts = 3;

  Future<void> _load() async {
    final config = await _ref.read(byokStorageProvider).loadConfig();
    if (!mounted) return;
    state = state.copyWith(config: config.isConfigured ? config : null);
  }

  /// Called after settings are saved, so the new key is used at once.
  void useConfig(ByokConfig config) {
    state = state.copyWith(
      config: config.isConfigured ? config : null,
      clearConfig: !config.isConfigured,
      paused: false,
    );
  }

  void clear() {
    state = state.copyWith(clearConfig: true, paused: false);
  }

  /// The learner chose "Try my key again" after a quota stop.
  void resume() => state = state.copyWith(paused: false);

  /// Sends [prompt] and returns the reply text. Throws [LlmException]
  /// with a [LlmFailureKind]; on a quota stop the session also pauses.
  Future<String> ask(String prompt) async {
    final config = state.config;
    if (!_ref.read(byokAvailableProvider) || config == null || state.paused) {
      throw const LlmException(
        'Asking your AI is not available.',
        kind: LlmFailureKind.unknown,
      );
    }
    state = state.copyWith(busy: true);
    final delay = _ref.read(byokRetryDelayProvider);
    final random = Random();
    try {
      final client = _ref.read(llmClientFactoryProvider)(config);
      for (var attempt = 1; ; attempt++) {
        try {
          return await client.generateText(prompt: prompt);
        } on LlmException catch (e) {
          final wait = e.retryAfter;
          final tooLong = wait != null && wait > maxWait;
          if (e.kind == LlmFailureKind.quotaExhausted ||
              (e.kind == LlmFailureKind.rateLimited && tooLong)) {
            if (mounted) state = state.copyWith(paused: true);
            throw LlmException(
              e.message,
              statusCode: e.statusCode,
              kind: LlmFailureKind.quotaExhausted,
            );
          }
          if (!e.kind.isRetryable || attempt >= maxAttempts) rethrow;
          // Exponential backoff with jitter, or the provider's own wait.
          final backoff = Duration(
            milliseconds: 1500 * (1 << (attempt - 1)) + random.nextInt(500),
          );
          await delay(wait ?? backoff);
        }
      }
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }
}

final byokSessionProvider =
    StateNotifierProvider<ByokSessionController, ByokSessionState>(
      ByokSessionController.new,
    );
