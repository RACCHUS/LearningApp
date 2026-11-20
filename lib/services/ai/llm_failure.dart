import 'dart:convert';

import 'byok_provider.dart';

/// What went wrong with a provider call, in terms the app can act on.
/// Messages never echo provider bodies (they can contain the request or
/// account details) and never state quota sizes or reset times, which
/// providers change without notice (master plan v2.6 §5.3).
enum LlmFailureKind {
  /// A daily or billing quota is used up. Retrying soon will not help, so
  /// the app turns "Ask my AI" off and points to copy and paste.
  quotaExhausted,

  /// A short per-minute limit. Safe to retry after a short wait.
  rateLimited,

  /// The key is missing, wrong, revoked or not allowed for this API.
  badCredential,

  /// The chosen model does not exist or is not available to this key.
  modelUnavailable,

  /// The provider refused to answer this prompt (safety or policy).
  blocked,

  /// The provider is overloaded or failing. Safe to retry.
  providerBusy,

  /// No connection, or the browser blocked the request.
  network,

  /// The provider answered with nothing usable.
  emptyReply,

  /// Anything else.
  unknown;

  bool get isRetryable =>
      this == rateLimited || this == providerBusy || this == network;

  /// Plain-language message for the learner. [provider] is a short name
  /// such as "Gemini".
  String message(String provider) => switch (this) {
    quotaExhausted =>
      "Your $provider quota is used up for now, so asking it is turned "
          'off. Copy the prompt into an AI chat instead, or try your key '
          'again later.',
    rateLimited =>
      '$provider is limiting how fast you can ask. Wait a minute and '
          'try again.',
    badCredential =>
      "$provider didn't accept your key. Check it in \"Use your own API "
          'key".',
    modelUnavailable =>
      "That $provider model isn't available to your key. Pick another "
          'model in "Use your own API key".',
    blocked =>
      '$provider declined to write this. Try rewording the topic, or use '
          'copy and paste with another AI chat.',
    providerBusy =>
      '$provider is busy right now. Try again in a moment, or use copy '
          'and paste.',
    network =>
      "Couldn't reach $provider. Check your connection, or use copy and "
          'paste.',
    emptyReply =>
      '$provider sent back an empty answer. Try again, or use copy and '
          'paste.',
    unknown =>
      'Something went wrong asking $provider. Try again, or use copy and '
          'paste.',
  };
}

/// Classifies an HTTP error from [provider]. Reads only the structured
/// error fields; the body is never stored or shown.
({LlmFailureKind kind, Duration? retryAfter}) classifyProviderError(
  AiProvider provider,
  int status,
  String body, {
  Map<String, String> headers = const {},
}) {
  Map<String, dynamic>? error;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is Map) {
      error = Map<String, dynamic>.from(decoded['error'] as Map);
    }
  } catch (_) {}
  final statusText = '${error?['status'] ?? ''}';
  final code = '${error?['code'] ?? ''}';
  final type = '${error?['type'] ?? ''}';
  final text = jsonEncode(error ?? const {});

  Duration? retryAfter = _parseRetryAfter(headers['retry-after']);

  if (provider == AiProvider.gemini && status == 429) {
    // Gemini says which quota ran out. Only a per-day (or spend) quota
    // means "stop for today"; per-minute limits clear quickly.
    final details = error?['details'];
    var daily = false;
    if (details is List) {
      for (final d in details) {
        if (d is! Map) continue;
        final violations = d['violations'];
        if (violations is List) {
          for (final v in violations) {
            final id = v is Map ? '${v['quotaId'] ?? ''}' : '';
            if (id.contains('PerDay') || id.contains('Spend')) daily = true;
          }
        }
        final delay = d['retryDelay'];
        if (delay is String) {
          retryAfter ??= _parseRetryAfter(delay.replaceAll('s', ''));
        }
      }
    }
    return (
      kind: daily ? LlmFailureKind.quotaExhausted : LlmFailureKind.rateLimited,
      retryAfter: retryAfter,
    );
  }

  if (status == 429) {
    final quota =
        code == 'insufficient_quota' ||
        type == 'insufficient_quota' ||
        text.contains('insufficient_quota');
    return (
      kind: quota ? LlmFailureKind.quotaExhausted : LlmFailureKind.rateLimited,
      retryAfter: retryAfter,
    );
  }
  if (status == 402) {
    // OpenRouter: out of credits.
    return (kind: LlmFailureKind.quotaExhausted, retryAfter: null);
  }
  if (status == 401 ||
      (status == 403 && !text.contains('moderation')) ||
      text.contains('API_KEY_INVALID') ||
      code == 'invalid_api_key') {
    return (kind: LlmFailureKind.badCredential, retryAfter: null);
  }
  if (status == 404 || code == 'model_not_found') {
    return (kind: LlmFailureKind.modelUnavailable, retryAfter: null);
  }
  if (status == 403) {
    return (kind: LlmFailureKind.blocked, retryAfter: null);
  }
  if (status == 408 || status >= 500) {
    return (kind: LlmFailureKind.providerBusy, retryAfter: retryAfter);
  }
  if (status == 400 && statusText == 'FAILED_PRECONDITION') {
    // Gemini: free tier not available for this project or region.
    return (kind: LlmFailureKind.badCredential, retryAfter: null);
  }
  return (kind: LlmFailureKind.unknown, retryAfter: null);
}

Duration? _parseRetryAfter(String? raw) {
  if (raw == null) return null;
  final seconds = double.tryParse(raw.trim());
  if (seconds == null || seconds < 0) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}
