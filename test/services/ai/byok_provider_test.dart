import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learning_pwa/services/ai/byok_provider.dart';
import 'package:learning_pwa/services/ai/llm_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BYOK Configuration & Storage Tests (ARCH-4)', () {
    test('ByokConfig serializes and deserializes correctly', () {
      const config = ByokConfig(
        provider: AiProvider.openrouter,
        apiKey: 'sk-or-v1-testkey123',
        model: 'anthropic/claude-3.5-sonnet',
        customEndpoint: 'https://custom.openrouter.test/v1',
      );

      final json = config.toJson();
      final restored = ByokConfig.fromJson(json);

      expect(restored.provider, equals(AiProvider.openrouter));
      expect(restored.apiKey, equals('sk-or-v1-testkey123'));
      expect(restored.model, equals('anthropic/claude-3.5-sonnet'));
      expect(restored.customEndpoint, equals('https://custom.openrouter.test/v1'));
      expect(restored.isConfigured, isTrue);
    });

    test('ByokStorageService saves and retrieves config cleanly', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ByokStorageService();

      var loaded = await storage.loadConfig();
      expect(loaded.provider, equals(AiProvider.gemini));
      expect(loaded.apiKey, isEmpty);

      const newConfig = ByokConfig(
        provider: AiProvider.openai,
        apiKey: 'sk-test-abc',
        model: 'gpt-4o-mini',
      );
      await storage.saveConfig(newConfig);

      loaded = await storage.loadConfig();
      expect(loaded.provider, equals(AiProvider.openai));
      expect(loaded.apiKey, equals('sk-test-abc'));
      expect(loaded.model, equals('gpt-4o-mini'));

      await storage.clearConfig();
      loaded = await storage.loadConfig();
      expect(loaded.apiKey, isEmpty);
    });
  });

  group('LLM Client Structured JSON Handlers', () {
    test('GeminiLlmClient sends schema and extracts candidate text', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, contains('/models/gemini-1.5-flash:generateContent'));
        expect(request.url.queryParameters['key'], equals('test-gemini-key'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['generationConfig']['responseMimeType'], equals('application/json'));
        expect(body['generationConfig']['responseSchema'], isNotNull);

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"result": "success", "score": 95}'}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      const config = ByokConfig(
        provider: AiProvider.gemini,
        apiKey: 'test-gemini-key',
        model: 'gemini-1.5-flash',
      );

      final client = GeminiLlmClient(config, httpClient: mockHttp);
      final response = await client.generateStructuredJson(
        prompt: 'Generate test JSON',
        jsonSchema: {
          'type': 'object',
          'properties': {
            'result': {'type': 'string'},
            'score': {'type': 'integer'}
          }
        },
      );

      final map = jsonDecode(response) as Map<String, dynamic>;
      expect(map['result'], equals('success'));
      expect(map['score'], equals(95));
    });

    test('OpenAiCompatibleLlmClient sends structured json_schema and extracts content', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, contains('/chat/completions'));
        expect(request.headers['Authorization'], equals('Bearer test-openai-key'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['response_format']['type'], equals('json_schema'));
        expect(body['model'], equals('gpt-4o-mini'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '{"status": "ok", "count": 42}'
                }
              }
            ]
          }),
          200,
        );
      });

      const config = ByokConfig(
        provider: AiProvider.openai,
        apiKey: 'test-openai-key',
        model: 'gpt-4o-mini',
      );

      final client = OpenAiCompatibleLlmClient(config, httpClient: mockHttp);
      final response = await client.generateStructuredJson(
        prompt: 'Generate status object',
        jsonSchema: {
          'type': 'object',
          'properties': {
            'status': {'type': 'string'},
            'count': {'type': 'integer'}
          }
        },
      );

      final map = jsonDecode(response) as Map<String, dynamic>;
      expect(map['status'], equals('ok'));
      expect(map['count'], equals(42));
    });

    test('MockLlmClient returns valid structured default assessment item', () async {
      final mock = MockLlmClient();
      final result = await mock.generateStructuredJson(
        prompt: 'any prompt',
        jsonSchema: {},
      );

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['prompt'], contains('Florida Building Code'));
      expect((parsed['options'] as List).length, equals(4));
      expect(parsed['correct_index'], equals(0));
      expect(parsed['source_citation'], isNotEmpty);
    });
  });
}

