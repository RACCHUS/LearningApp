import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/widgets/answer_feedback.dart';
import 'package:learning_pwa/widgets/audio/audio_mcq_widget.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';
import 'package:learning_pwa/widgets/true_false_selector.dart';

// Correct/incorrect must be visible without color: success and danger are
// nearly indistinguishable in grayscale and for red-green CVD
// (docs/design/CONTRAST_AUDIT.md).
void main() {
  late Directory hiveDir;
  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('answer_feedback');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(AudioSettingsAdapter().typeId)) {
      Hive.registerAdapter(AudioSettingsAdapter());
    }
  });
  tearDownAll(() async {
    await Hive.close();
    hiveDir.deleteSync(recursive: true);
  });

  Widget host(Widget child) => ProviderScope(
        overrides: [
          canSpeakProvider.overrideWithValue(false),
          canListenProvider.overrideWithValue(false),
          readAloudOffProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  final correct = find.byKey(const Key('answer-mark-correct'));
  final incorrect = find.byKey(const Key('answer-mark-incorrect'));

  testWidgets('AudioMCQWidget marks correct and wrong options with icons',
      (tester) async {
    await tester.pumpWidget(host(const AudioMCQWidget(
      questionText: 'Capital of France?',
      options: ['Paris', 'Rome', 'Madrid'],
      correctAnswer: 0,
      selectedAnswer: 1,
      showResults: true,
    )));
    await tester.pump();
    expect(correct, findsOneWidget);
    expect(incorrect, findsOneWidget);
    expect(tester.widget<Icon>(correct).semanticLabel, 'Correct answer');
    expect(tester.widget<Icon>(incorrect).semanticLabel, 'Incorrect answer');
  });

  testWidgets('AudioMCQWidget shows no marks before results', (tester) async {
    await tester.pumpWidget(host(const AudioMCQWidget(
      questionText: 'Capital of France?',
      options: ['Paris', 'Rome'],
      correctAnswer: 0,
      selectedAnswer: 1,
    )));
    await tester.pump();
    expect(correct, findsNothing);
    expect(incorrect, findsNothing);
  });

  testWidgets('McqOptions marks the right answer when the learner was right',
      (tester) async {
    await tester.pumpWidget(host(McqOptions(
      options: const ['Paris', 'Rome'],
      selectedIndex: 0,
      correctIndex: 0,
      showCorrect: true,
      onChanged: (_) {},
    )));
    expect(correct, findsOneWidget);
    expect(incorrect, findsNothing);
  });

  testWidgets('McqOptions marks both answers when the learner was wrong',
      (tester) async {
    await tester.pumpWidget(host(McqOptions(
      options: const ['Paris', 'Rome'],
      selectedIndex: 1,
      correctIndex: 0,
      showCorrect: true,
      onChanged: (_) {},
    )));
    expect(correct, findsOneWidget);
    expect(incorrect, findsOneWidget);
  });

  testWidgets('TrueFalseSelector marks chips with icons', (tester) async {
    await tester.pumpWidget(host(TrueFalseSelector(
      value: true,
      correctValue: false,
      showCorrect: true,
      onChanged: (_) {},
    )));
    expect(correct, findsOneWidget);
    expect(incorrect, findsOneWidget);
  });

  testWidgets('AnswerFeedbackText pairs an icon with the result text',
      (tester) async {
    await tester.pumpWidget(host(const AnswerFeedbackText(correct: false)));
    expect(find.text('Incorrect'), findsOneWidget);
    expect(incorrect, findsOneWidget);
  });
}
