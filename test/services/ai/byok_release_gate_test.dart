import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learning_pwa/services/ai/byok_provider.dart';
import 'package:learning_pwa/services/ai/byok_release_gate.dart';
import 'package:learning_pwa/services/ai/curriculum_generator.dart';
import 'package:learning_pwa/services/ai/llm_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const gemini = ByokConfig(
    provider: AiProvider.gemini,
    apiKey: 'synthetic-credential',
    model: 'gemini-1.5-flash',
  );
  const openai = ByokConfig(
    provider: AiProvider.openai,
    apiKey: 'synthetic-credential',
    model: 'gpt-4o-mini',
  );

  test('BYOK remains hard-disabled until reviewed release', () {
    expect(ByokReleaseGate.enabled, isFalse);
    expect(() => LlmClient.create(gemini), throwsStateError);
    expect(() => LlmClient.create(ByokConfig.defaultMock), throwsStateError);
  });

  test('direct provider clients issue zero HTTP requests while disabled', () async {
    var requests = 0;
    final network = MockClient((request) async {
      requests++;
      return http.Response('{}', 200);
    });
    await expectLater(
      GeminiLlmClient(gemini, httpClient: network)
          .generateStructuredJson(prompt: 'p', jsonSchema: const {}),
      throwsStateError,
    );
    await expectLater(
      OpenAiCompatibleLlmClient(openai, httpClient: network)
          .generateStructuredJson(prompt: 'p', jsonSchema: const {}),
      throwsStateError,
    );
    expect(requests, 0);
  });

  test('injected mock cannot bypass curriculum generation gate', () async {
    final generator = CurriculumGenerator(
      config: gemini,
      llmClient: MockLlmClient(),
    );
    await expectLater(
      generator.generateAssessmentItem(topic: 't', sourceExcerpt: 'source'),
      throwsStateError,
    );
    await expectLater(
      generator.generateLesson(topic: 't', sourceExcerpt: 'source'),
      throwsStateError,
    );
  });

  test('only exact, HTTPS, first-party provider URLs pass policy', () {
    expect(ByokEndpointPolicy.isApproved(gemini), isTrue);
    expect(ByokEndpointPolicy.isApproved(openai), isTrue);
    expect(
      ByokEndpointPolicy.isApproved(const ByokConfig(
        provider: AiProvider.openai,
        apiKey: 'synthetic',
        model: 'm',
        customEndpoint: 'https://attacker.example/v1',
      )),
      isFalse,
    );
    expect(
      ByokEndpointPolicy.isApproved(const ByokConfig(
        provider: AiProvider.gemini,
        apiKey: 'synthetic',
        model: 'm',
        customEndpoint: 'http://127.0.0.1:8000/v1',
      )),
      isFalse,
    );
  });

  test('cannot save keys; existing local keys are preserved until user clears', () async {
    const stored = '{"provider":"openai","apiKey":"existing-synthetic-key","model":"gpt-4o-mini"}';
    SharedPreferences.setMockInitialValues({
      'learningapp_byok_config': stored,
    });
    final storage = ByokStorageService();
    await expectLater(storage.saveConfig(gemini), throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('learningapp_byok_config'), stored);
    final loaded = await storage.loadConfig();
    expect(loaded.apiKey, isEmpty,
        reason: 'Legacy raw keys must never be rehydrated into app state.');
    await storage.clearConfig();
    expect(prefs.getString('learningapp_byok_config'), isNull);
  });
}
