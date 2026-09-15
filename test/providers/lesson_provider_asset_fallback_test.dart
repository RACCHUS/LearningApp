import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lessonProvider opens bundled asset lessons without a database row',
      () async {
    final binding = TestDefaultBinaryMessengerBinding.instance;
    rootBundle.evict('AssetManifest.json');
    rootBundle.evict('assets/lessons/prog_01_variables.json');

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
    addTearDown(() => binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final lesson = await container.read(
      lessonProvider('prog_01_variables').future,
    );

    expect(lesson.lesson.title, 'Variables & Data Types');
    expect(lesson.lessonContent, hasLength(3));
    expect(lesson.lessonContent.map((c) => c.type),
        containsAll(['term', 'concept', 'question']));
  });
}
