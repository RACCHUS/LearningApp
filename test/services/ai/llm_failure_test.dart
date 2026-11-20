import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/ai/byok_provider.dart';
import 'package:learning_pwa/services/ai/llm_failure.dart';

String geminiError(
  int code,
  String status,
  List<Map<String, dynamic>> details,
) => jsonEncode({
  'error': {
    'code': code,
    'message': 'synthetic',
    'status': status,
    'details': details,
  },
});

void main() {
  group('Gemini errors', () {
    test('a per-day 429 is a quota stop', () {
      final c = classifyProviderError(
        AiProvider.gemini,
        429,
        geminiError(429, 'RESOURCE_EXHAUSTED', [
          {
            '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
            'violations': [
              {'quotaId': 'GenerateRequestsPerDayPerProjectPerModel-FreeTier'},
            ],
          },
        ]),
      );
      expect(c.kind, LlmFailureKind.quotaExhausted);
    });

    test('a per-minute 429 is a short wait with the given delay', () {
      final c = classifyProviderError(
        AiProvider.gemini,
        429,
        geminiError(429, 'RESOURCE_EXHAUSTED', [
          {
            '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
            'violations': [
              {
                'quotaId':
                    'GenerateRequestsPerMinutePerProjectPerModel-FreeTier',
              },
            ],
          },
          {
            '@type': 'type.googleapis.com/google.rpc.RetryInfo',
            'retryDelay': '12s',
          },
        ]),
      );
      expect(c.kind, LlmFailureKind.rateLimited);
      expect(c.retryAfter, const Duration(seconds: 12));
    });

    test('an invalid key', () {
      final c = classifyProviderError(
        AiProvider.gemini,
        400,
        geminiError(400, 'INVALID_ARGUMENT', [
          {
            '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
            'reason': 'API_KEY_INVALID',
          },
        ]),
      );
      expect(c.kind, LlmFailureKind.badCredential);
    });

    test('free tier not available here', () {
      final c = classifyProviderError(
        AiProvider.gemini,
        400,
        geminiError(400, 'FAILED_PRECONDITION', const []),
      );
      expect(c.kind, LlmFailureKind.badCredential);
    });

    test('a retired model', () {
      expect(
        classifyProviderError(
          AiProvider.gemini,
          404,
          geminiError(404, 'NOT_FOUND', const []),
        ).kind,
        LlmFailureKind.modelUnavailable,
      );
    });

    test('overloaded', () {
      expect(
        classifyProviderError(
          AiProvider.gemini,
          503,
          geminiError(503, 'UNAVAILABLE', const []),
        ).kind,
        LlmFailureKind.providerBusy,
      );
    });
  });

  group('OpenAI-compatible errors', () {
    test('insufficient_quota is a quota stop', () {
      final c = classifyProviderError(
        AiProvider.openai,
        429,
        jsonEncode({
          'error': {'type': 'insufficient_quota', 'code': 'insufficient_quota'},
        }),
      );
      expect(c.kind, LlmFailureKind.quotaExhausted);
    });

    test('a rate limit uses Retry-After', () {
      final c = classifyProviderError(
        AiProvider.openai,
        429,
        jsonEncode({
          'error': {'code': 'rate_limit_exceeded'},
        }),
        headers: {'retry-after': '3'},
      );
      expect(c.kind, LlmFailureKind.rateLimited);
      expect(c.retryAfter, const Duration(seconds: 3));
    });

    test('OpenRouter out of credits', () {
      expect(
        classifyProviderError(AiProvider.openrouter, 402, '{}').kind,
        LlmFailureKind.quotaExhausted,
      );
    });

    test('401 is a bad key', () {
      expect(
        classifyProviderError(AiProvider.openai, 401, 'not json').kind,
        LlmFailureKind.badCredential,
      );
    });
  });

  test('only short waits and hiccups are retried', () {
    expect(LlmFailureKind.rateLimited.isRetryable, isTrue);
    expect(LlmFailureKind.providerBusy.isRetryable, isTrue);
    expect(LlmFailureKind.network.isRetryable, isTrue);
    expect(LlmFailureKind.quotaExhausted.isRetryable, isFalse);
    expect(LlmFailureKind.badCredential.isRetryable, isFalse);
  });

  test('messages name the provider and never state numbers or times', () {
    for (final k in LlmFailureKind.values) {
      final m = k.message('Gemini');
      expect(m, contains('Gemini'), reason: k.name);
      expect(RegExp(r'\d').hasMatch(m), isFalse, reason: k.name);
    }
  });
}
