import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learning_pwa/services/ai/byok_provider.dart';
import 'package:learning_pwa/services/ai/byok_release_gate.dart';
import 'package:learning_pwa/services/ai/llm_client.dart';

/// Release-candidate checks for the own-key clients. They need the latch,
/// so they run only in CI's dedicated step built with
/// `--dart-define=BYOK_RELEASE_APPROVED=true` (registered conditional skip
/// in tool/ci/check_test_skips.py). No real provider is contacted.
void main() => group(
  'BYOK release candidate',
  _tests,
  skip: ByokReleaseGate.enabled ? false : 'BYOK release latch is off',
);

void _tests() {
  const gemini = ByokConfig(
    provider: AiProvider.gemini,
    apiKey: 'synthetic-key',
    model: 'gemini-flash-latest',
  );
  const openai = ByokConfig(
    provider: AiProvider.openai,
    apiKey: 'synthetic-key',
    model: 'gpt-test',
  );

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  Matcher failsWith(LlmFailureKind kind) =>
      throwsA(isA<LlmException>().having((e) => e.kind, 'kind', kind));

  group('Gemini own key', () {
    test('sends the key in a header and joins the reply parts', () async {
      late http.Request seen;
      final client = GeminiLlmClient(
        gemini,
        httpClient: MockClient((r) async {
          seen = r;
          return json({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'thinking', 'thought': true},
                    {'text': 'Hello '},
                    {'text': 'world'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          });
        }),
      );
      expect(await client.generateText(prompt: 'p'), 'Hello world');
      expect(
        seen.url.path,
        endsWith('/models/gemini-flash-latest:generateContent'),
      );
      expect(seen.url.query, isEmpty, reason: 'never put the key in the URL');
      expect(seen.headers['x-goog-api-key'], 'synthetic-key');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['generationConfig']['responseSchema'], isNull);
    });

    test('a reply cut off at the token limit is still returned', () async {
      final client = GeminiLlmClient(
        gemini,
        httpClient: MockClient(
          (_) async => json({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"items": ['},
                  ],
                },
                'finishReason': 'MAX_TOKENS',
              },
            ],
          }),
        ),
      );
      expect(await client.generateText(prompt: 'p'), '{"items": [');
    });

    test('a safety stop is reported as blocked', () async {
      final client = GeminiLlmClient(
        gemini,
        httpClient: MockClient(
          (_) async => json({
            'candidates': [
              {'finishReason': 'SAFETY'},
            ],
          }),
        ),
      );
      expect(
        client.generateText(prompt: 'p'),
        failsWith(LlmFailureKind.blocked),
      );
    });

    test('a daily quota error is a quota stop', () async {
      final client = GeminiLlmClient(
        gemini,
        httpClient: MockClient(
          (_) async => json({
            'error': {
              'code': 429,
              'status': 'RESOURCE_EXHAUSTED',
              'details': [
                {
                  '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
                  'violations': [
                    {
                      'quotaId':
                          'GenerateRequestsPerDayPerProjectPerModel-FreeTier',
                    },
                  ],
                },
              ],
            },
          }, 429),
        ),
      );
      expect(
        client.generateText(prompt: 'p'),
        failsWith(LlmFailureKind.quotaExhausted),
      );
    });

    test('no connection is a network failure', () async {
      final client = GeminiLlmClient(
        gemini,
        httpClient: MockClient((_) async => throw http.ClientException('x')),
      );
      expect(
        client.generateText(prompt: 'p'),
        failsWith(LlmFailureKind.network),
      );
    });

    test('lists only models that can write text', () async {
      final client = GeminiLlmClient(
        gemini,
        httpClient: MockClient(
          (_) async => json({
            'models': [
              {
                'name': 'models/gemini-flash-latest',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/text-embedding',
                'supportedGenerationMethods': ['embedContent'],
              },
            ],
          }),
        ),
      );
      expect(await client.listModels(), ['gemini-flash-latest']);
    });
  });

  group('OpenAI-compatible own key', () {
    test('sends a plain chat request and returns the message', () async {
      late http.Request seen;
      final client = OpenAiCompatibleLlmClient(
        openai,
        httpClient: MockClient((r) async {
          seen = r;
          return json({
            'choices': [
              {
                'message': {'content': 'reply text'},
              },
            ],
          });
        }),
      );
      expect(await client.generateText(prompt: 'p'), 'reply text');
      expect(seen.headers['authorization'], 'Bearer synthetic-key');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body.containsKey('response_format'), isFalse);
    });

    test('insufficient_quota is a quota stop', () async {
      final client = OpenAiCompatibleLlmClient(
        openai,
        httpClient: MockClient(
          (_) async => json({
            'error': {'code': 'insufficient_quota'},
          }, 429),
        ),
      );
      expect(
        client.generateText(prompt: 'p'),
        failsWith(LlmFailureKind.quotaExhausted),
      );
    });

    test('a refusal is reported as blocked', () async {
      final client = OpenAiCompatibleLlmClient(
        openai,
        httpClient: MockClient(
          (_) async => json({
            'choices': [
              {
                'message': {'content': null, 'refusal': 'no'},
              },
            ],
          }),
        ),
      );
      expect(
        client.generateText(prompt: 'p'),
        failsWith(LlmFailureKind.blocked),
      );
    });
  });

  test('custom endpoints still never receive a key', () {
    const custom = ByokConfig(
      provider: AiProvider.openai,
      apiKey: 'synthetic-key',
      model: 'm',
      customEndpoint: 'https://example.com/v1',
    );
    expect(() => LlmClient.create(custom), throwsA(isA<LlmException>()));
  });
}
