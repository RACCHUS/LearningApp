import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/byok_session_provider.dart';
import 'package:learning_pwa/services/ai/byok_provider.dart';
import 'package:learning_pwa/services/ai/llm_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = ByokConfig(
  provider: AiProvider.gemini,
  apiKey: 'test-key',
  model: 'gemini-flash-latest',
);

LlmException _fail(LlmFailureKind kind, {Duration? retryAfter}) =>
    LlmException('synthetic', kind: kind, retryAfter: retryAfter);

class _ScriptedClient implements LlmClient {
  _ScriptedClient(this.script);

  /// Each call takes the next step: a String reply or an exception.
  final List<Object> script;
  int calls = 0;

  @override
  Future<String> generateText({
    required String prompt,
    int maxOutputTokens = 8192,
  }) async {
    final step = script[calls++];
    if (step is Exception) throw step;
    return step as String;
  }

  @override
  Future<List<String>> listModels() async => const [];

  @override
  Future<String> generateStructuredJson({
    required String prompt,
    required Map<String, dynamic> jsonSchema,
    String? systemPrompt,
  }) => throw UnimplementedError();
}

void main() {
  late List<Duration> waits;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    waits = [];
  });

  ProviderContainer make(_ScriptedClient client, {bool available = true}) {
    final c = ProviderContainer(
      overrides: [
        byokAvailableProvider.overrideWithValue(available),
        llmClientFactoryProvider.overrideWithValue((_) => client),
        byokRetryDelayProvider.overrideWithValue((d) async => waits.add(d)),
      ],
    );
    addTearDown(c.dispose);
    c.read(byokSessionProvider.notifier).useConfig(_key);
    return c;
  }

  test('nothing is sent when BYOK is not available', () async {
    final client = _ScriptedClient(['reply']);
    final c = make(client, available: false);
    await expectLater(
      c.read(byokSessionProvider.notifier).ask('p'),
      throwsA(isA<LlmException>()),
    );
    expect(client.calls, 0);
  });

  test('returns the reply and clears busy', () async {
    final c = make(_ScriptedClient(['the reply']));
    expect(await c.read(byokSessionProvider.notifier).ask('p'), 'the reply');
    expect(c.read(byokSessionProvider).busy, isFalse);
    expect(c.read(byokSessionProvider).ready, isTrue);
  });

  test('retries a busy provider with backoff, then succeeds', () async {
    final client = _ScriptedClient([
      _fail(LlmFailureKind.providerBusy),
      _fail(LlmFailureKind.network),
      'ok',
    ]);
    final c = make(client);
    expect(await c.read(byokSessionProvider.notifier).ask('p'), 'ok');
    expect(client.calls, 3);
    expect(waits, hasLength(2));
    expect(waits[1], greaterThan(waits[0]));
  });

  test('waits the time the provider asks for on a short rate limit', () async {
    final client = _ScriptedClient([
      _fail(LlmFailureKind.rateLimited, retryAfter: const Duration(seconds: 7)),
      'ok',
    ]);
    final c = make(client);
    expect(await c.read(byokSessionProvider.notifier).ask('p'), 'ok');
    expect(waits, [const Duration(seconds: 7)]);
  });

  test('gives up after three attempts', () async {
    final client = _ScriptedClient(
      List.filled(5, _fail(LlmFailureKind.providerBusy)),
    );
    final c = make(client);
    await expectLater(
      c.read(byokSessionProvider.notifier).ask('p'),
      throwsA(
        isA<LlmException>().having(
          (e) => e.kind,
          'kind',
          LlmFailureKind.providerBusy,
        ),
      ),
    );
    expect(client.calls, 3);
    expect(c.read(byokSessionProvider).paused, isFalse);
  });

  test('a used-up quota pauses Ask until the learner resumes', () async {
    final client = _ScriptedClient([
      _fail(LlmFailureKind.quotaExhausted),
      'after resume',
    ]);
    final c = make(client);
    final session = c.read(byokSessionProvider.notifier);
    await expectLater(
      session.ask('p'),
      throwsA(
        isA<LlmException>().having(
          (e) => e.kind,
          'kind',
          LlmFailureKind.quotaExhausted,
        ),
      ),
    );
    expect(client.calls, 1, reason: 'a quota stop is never retried');
    expect(c.read(byokSessionProvider).paused, isTrue);
    expect(c.read(byokSessionProvider).ready, isFalse);

    await expectLater(session.ask('p'), throwsA(isA<LlmException>()));
    expect(client.calls, 1, reason: 'nothing is sent while paused');

    session.resume();
    expect(await session.ask('p'), 'after resume');
  });

  test('a long rate-limit wait is treated as a quota stop', () async {
    final client = _ScriptedClient([
      _fail(LlmFailureKind.rateLimited, retryAfter: const Duration(hours: 2)),
    ]);
    final c = make(client);
    await expectLater(
      c.read(byokSessionProvider.notifier).ask('p'),
      throwsA(
        isA<LlmException>().having(
          (e) => e.kind,
          'kind',
          LlmFailureKind.quotaExhausted,
        ),
      ),
    );
    expect(waits, isEmpty);
    expect(c.read(byokSessionProvider).paused, isTrue);
  });

  test('a bad key is reported at once, not retried', () async {
    final client = _ScriptedClient([_fail(LlmFailureKind.badCredential)]);
    final c = make(client);
    await expectLater(
      c.read(byokSessionProvider.notifier).ask('p'),
      throwsA(isA<LlmException>()),
    );
    expect(client.calls, 1);
    expect(c.read(byokSessionProvider).paused, isFalse);
  });

  test('forgetting the key leaves nothing to send', () async {
    final c = make(_ScriptedClient(['x']));
    c.read(byokSessionProvider.notifier).clear();
    expect(c.read(byokSessionProvider).configured, isFalse);
  });
}
