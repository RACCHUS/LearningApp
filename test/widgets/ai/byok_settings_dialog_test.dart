import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/ai/byok_provider.dart';
import 'package:learning_pwa/services/ai/llm_client.dart';
import 'package:learning_pwa/widgets/ai/byok_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Disabled BYOK shows no credential editor and permits local erase',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'learningapp_byok_config':
            '{"provider":"openai","apiKey":"previous-test-key","model":"gpt-4o-mini"}',
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ByokSettingsDialog.show(context),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('byok-unavailable-dialog')), findsOneWidget);
      expect(find.text('Save & Apply'), findsNothing);
      expect(find.text('Test Connection'), findsNothing);
      expect(find.text('previous-test-key'), findsNothing);
      expect(prefs.getString('learningapp_byok_config'), isNotNull);

      await tester.tap(find.text('Clear saved local key'));
      await tester.pumpAndSettle();
      expect(prefs.getString('learningapp_byok_config'), isNull);
    },
  );

  releasedDialogTests();
}

class _MemoryStorage extends ByokStorageService {
  ByokConfig? saved;

  @override
  Future<ByokConfig> loadConfig() async => const ByokConfig(
    provider: AiProvider.gemini,
    apiKey: '',
    model: 'gemini-1.5-flash',
  );

  @override
  Future<void> saveConfig(ByokConfig config) async => saved = config;

  @override
  Future<void> clearConfig() async => saved = null;
}

class _ModelsClient implements LlmClient {
  @override
  Future<List<String>> listModels() async => const [
    'text-embedding-004',
    'gemini-flash-latest',
    'gemini-pro-latest',
  ];

  @override
  Future<String> generateText({
    required String prompt,
    int maxOutputTokens = 8192,
  }) async => '';

  @override
  Future<String> generateStructuredJson({
    required String prompt,
    required Map<String, dynamic> jsonSchema,
    String? systemPrompt,
  }) async => '';
}

void releasedDialogTests() {
  testWidgets(
    'released: needs the 18+ confirmation and fixes a retired model',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final storage = _MemoryStorage();
      ByokConfig? applied;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ByokSettingsDialog.show(
                  context,
                  storageService: storage,
                  onSaved: (c) => applied = c,
                  clientFactory: (_) => _ModelsClient(),
                  releaseApproved: true,
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('byok-settings-dialog')), findsOneWidget);
      expect(
        find.textContaining('never saved or sent to LearningApp'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('byok-key-field')), 'k-123');
      await tester.pump();
      FilledButton save() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Use this key'),
      );
      expect(save().onPressed, isNull, reason: 'needs the 18+ confirmation');

      await tester.tap(find.text('Check key'));
      await tester.pumpAndSettle();
      expect(find.text('Your key works.'), findsOneWidget);
      expect(find.text('gemini-flash-latest'), findsOneWidget);

      await tester.tap(find.byKey(const Key('byok-adult-confirm')));
      await tester.pump();
      await tester.tap(find.text('Use this key'));
      await tester.pumpAndSettle();
      expect(storage.saved?.model, 'gemini-flash-latest');
      expect(applied?.apiKey, 'k-123');
    },
  );
}
