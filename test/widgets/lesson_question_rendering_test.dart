import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/widgets/lesson_content_renderer.dart';

QuestionContent q(List<String> options, {String? type}) => QuestionContent(
  id: 'q',
  lessonId: 'l',
  order: 0,
  questionText: 'Capital of France?',
  options: options,
  correctAnswer: 0,
  questionType: type,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Widget host(QuestionContent content) => ProviderScope(
  overrides: [
    canSpeakProvider.overrideWithValue(false),
    canListenProvider.overrideWithValue(false),
    readAloudOffProvider.overrideWithValue(false),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LessonContentRenderer(content: content, onNext: () {}),
      ),
    ),
  ),
);

void main() {
  testWidgets('lesson questions no longer render as unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(host(q(['Paris', 'Rome', 'Berlin'])));
    await tester.pump();
    expect(find.text('Unsupported question type'), findsNothing);
    expect(find.textContaining('Rome'), findsOneWidget);
  });

  testWidgets('short answer grades with the declared rule and explains it', (
    tester,
  ) async {
    await tester.pumpWidget(host(q(['Paris'], type: 'short_answer')));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'paris.');
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.textContaining('Correct! Accepted as "Paris"'), findsOneWidget);
  });
}
