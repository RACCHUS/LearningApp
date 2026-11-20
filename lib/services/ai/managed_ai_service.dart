import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a free-AI request did not produce a reply. Codes come from the
/// `managed-ai-generate` Edge Function and `public.ai_managed_admit`.
enum ManagedAiFailure {
  /// The shared free allowance (or Gemini's free daily quota) is used up;
  /// free AI is off for everyone until it resets.
  paused,

  /// This learner used their free requests for today.
  userLimit,

  /// Asked too fast; a short wait fixes it.
  rateLimited,

  /// Switched off, signed out, or not set up by the owner.
  unavailable,

  /// The provider declined to write this.
  blocked,

  /// Provider busy, empty reply or no connection.
  temporary;

  static ManagedAiFailure fromCode(String? code) => switch (code) {
    'paused' => paused,
    'user_limit' => userLimit,
    'rate_limited' => rateLimited,
    'blocked' => blocked,
    'provider_busy' || 'empty_reply' || 'network' => temporary,
    _ => unavailable,
  };

  String get message => switch (this) {
    paused =>
      "Free AI has used up today's shared allowance, so it's turned off "
          'until the allowance resets. You can still copy the prompt into any '
          'AI chat, or use your own API key.',
    userLimit =>
      "You've used your free AI requests for today. Copy and paste still "
          'works with any AI chat.',
    rateLimited => 'Free AI is busy. Wait a minute and try again.',
    unavailable =>
      "Free AI isn't available right now. Copy the prompt into any AI chat "
          'instead.',
    blocked =>
      'The AI declined to write this. Try rewording the topic, or use copy '
          'and paste with another AI chat.',
    temporary =>
      "Free AI couldn't answer just now. Try again, or use copy and paste.",
  };
}

class ManagedAiException implements Exception {
  const ManagedAiException(this.failure, {this.retryAfter});

  final ManagedAiFailure failure;
  final Duration? retryAfter;

  @override
  String toString() => 'ManagedAiException(${failure.name})';
}

class ManagedAiStatus {
  const ManagedAiStatus({
    required this.enabled,
    this.paused = false,
    this.remainingToday = 0,
    this.dailyLimit = 0,
  });

  static const off = ManagedAiStatus(enabled: false);

  factory ManagedAiStatus.fromJson(Object? raw) {
    if (raw is! Map || raw['enabled'] != true) return off;
    int n(Object? v) => v is num ? v.toInt() : 0;
    return ManagedAiStatus(
      enabled: true,
      paused: raw['paused'] == true,
      remainingToday: n(raw['remaining_today']),
      dailyLimit: n(raw['daily_limit']),
    );
  }

  final bool enabled;
  final bool paused;
  final int remainingToday;
  final int dailyLimit;

  ManagedAiStatus copyWith({bool? paused, int? remainingToday}) =>
      ManagedAiStatus(
        enabled: enabled,
        paused: paused ?? this.paused,
        remainingToday: remainingToday ?? this.remainingToday,
        dailyLimit: dailyLimit,
      );
}

/// Talks to the server. The Gemini key never leaves the Edge Function.
abstract class ManagedAiApi {
  Future<ManagedAiStatus> status();

  /// Returns the reply text and how many requests the learner has left.
  Future<({String text, int? remainingToday})> generate(String prompt);
}

class SupabaseManagedAiApi implements ManagedAiApi {
  SupabaseManagedAiApi(this._client);

  final SupabaseClient _client;

  @override
  Future<ManagedAiStatus> status() async {
    if (_client.auth.currentUser == null) return ManagedAiStatus.off;
    try {
      return ManagedAiStatus.fromJson(await _client.rpc('ai_managed_status'));
    } catch (_) {
      return ManagedAiStatus.off;
    }
  }

  @override
  Future<({String text, int? remainingToday})> generate(String prompt) async {
    try {
      final res = await _client.functions.invoke(
        'managed-ai-generate',
        body: {'prompt': prompt},
      );
      final data = res.data;
      final text = data is Map ? data['text'] : null;
      if (text is! String || text.trim().isEmpty) {
        throw const ManagedAiException(ManagedAiFailure.temporary);
      }
      final left = data['remaining_today'];
      return (text: text, remainingToday: left is num ? left.toInt() : null);
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? '${details['code']}' : null;
      final retry = details is Map ? details['retry_after'] : null;
      throw ManagedAiException(
        ManagedAiFailure.fromCode(code),
        retryAfter: retry is num ? Duration(seconds: retry.toInt()) : null,
      );
    } on ManagedAiException {
      rethrow;
    } catch (_) {
      throw const ManagedAiException(ManagedAiFailure.temporary);
    }
  }
}
