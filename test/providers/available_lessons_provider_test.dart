import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('assetLessonsProvider', () {
    test('loads bundled lessons from assets/lessons', () async {
      await _evictMockedAssets([
        'AssetManifest.json',
        'assets/lessons/prog_01_variables.json',
      ]);
      final binding = TestDefaultBinaryMessengerBinding.instance;
      binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final key = const StringCodec().decodeMessage(message);
          final value = switch (key) {
            'AssetManifest.json' => '''{
              "assets/lessons/prog_01_variables.json": ["assets/lessons/prog_01_variables.json"]
            }''',
            'assets/lessons/prog_01_variables.json' => '''{
              "title": "Variables & Data Types",
              "description": "The basics of storing data.",
              "tags": ["programming"],
              "terms": [
                {"id": "t1", "term": "String", "definition": "Text"}
              ],
              "questions": [
                {"id": "q1", "question": "Text type?", "options": ["int", "String"], "correct_answer": 1}
              ],
              "concepts": [
                {"id": "c1", "concept_text": "Variables store values."}
              ]
            }''',
            _ => null,
          };
          return const StringCodec().encodeMessage(value);
        },
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(() => binding.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null));

      final lessons = await container.read(assetLessonsProvider.future);

      expect(lessons, hasLength(1));
      expect(lessons.single.id, 'prog_01_variables');
      expect(lessons.single.title, 'Variables & Data Types');
      expect(lessons.single.terms, hasLength(1));
      expect(lessons.single.questions, hasLength(1));
      expect(lessons.single.concepts, hasLength(1));
    });

    test('skips malformed asset lessons without failing the catalog', () async {
      await _evictMockedAssets([
        'AssetManifest.json',
        'assets/lessons/bad.json',
        'assets/lessons/good.json',
      ]);
      final binding = TestDefaultBinaryMessengerBinding.instance;
      binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final key = const StringCodec().decodeMessage(message);
          final value = switch (key) {
            'AssetManifest.json' => '''{
              "assets/lessons/bad.json": ["assets/lessons/bad.json"],
              "assets/lessons/good.json": ["assets/lessons/good.json"]
            }''',
            'assets/lessons/bad.json' => '{',
            'assets/lessons/good.json' => '''{
              "title": "Good Lesson",
              "tags": [],
              "terms": [],
              "questions": [],
              "concepts": []
            }''',
            _ => null,
          };
          return const StringCodec().encodeMessage(value);
        },
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(() => binding.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null));

      final lessons = await container.read(assetLessonsProvider.future);

      expect(lessons.map((l) => l.title), ['Good Lesson']);
    });
  });
}

Future<void> _evictMockedAssets(List<String> keys) async {
  for (final key in keys) {
    rootBundle.evict(key);
  }
}
