import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStudyNotifier extends StateNotifier<StudyState> implements StudyNotifier {
  FakeStudyNotifier() : super(StudyState.initial());

  @override
  void markAnswerCorrect() {
    state = state.copyWith(correctAnswers: state.correctAnswers + 1);
  }

  @override
  void markAnswerIncorrect() {
    state = state.copyWith(incorrectAnswers: state.incorrectAnswers + 1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testQuestions = [
    Question(
      id: 'q-1',
      questionText: 'What organelle produces ATP in eukaryotic cells?',
      options: ['Ribosome', 'Mitochondria', 'Nucleus', 'Endoplasmic reticulum'],
      correctAnswer: 1,
      type: 'multiple_choice',
      explanation: 'Mitochondria generate most cellular ATP via oxidative phosphorylation.',
      createdBy: 'test-user',
    ),
    Question(
      id: 'q-2',
      questionText: 'Which base pairs with Adenine in DNA?',
      options: ['Cytosine', 'Guanine', 'Thymine', 'Uracil'],
      correctAnswer: 2,
      type: 'multiple_choice',
      explanation: 'Adenine pairs with Thymine in DNA via two hydrogen bonds.',
      createdBy: 'test-user',
    ),
    Question(
      id: 'q-3',
      questionText: 'What is the primary function of hemoglobin?',
      options: ['Oxygen transport', 'Blood clotting', 'Immune defense', 'Hormone regulation'],
      correctAnswer: 0,
      type: 'multiple_choice',
      explanation: 'Hemoglobin transports oxygen from the lungs to peripheral tissues.',
      createdBy: 'test-user',
    ),
  ];

  Widget buildTestWidget({required List<Question> questions}) {
    return ProviderScope(
      overrides: [
        canSpeakProvider.overrideWithValue(false),
        canListenProvider.overrideWithValue(false),
        studyProvider.overrideWith((ref) => FakeStudyNotifier()),
      ],
      child: MaterialApp(
        home: McqScreen(questions: questions),
      ),
    );
  }

  group('McqScreen Cognitive Batching & Focus Tests', () {
    testWidgets('toggles focus mode cleanly', (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings': '{"studyBatchSize":0,"recallBeforeReveal":true,"notificationsEnabled":true,"darkMode":true}',
      });

      await tester.pumpWidget(buildTestWidget(questions: testQuestions));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Focus mode'), findsOneWidget);

      // Enter focus mode
      await tester.tap(find.byTooltip('Focus mode'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Exit focus mode'), findsOneWidget);

      // Exit focus mode
      await tester.tap(find.byTooltip('Exit focus mode'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Focus mode'), findsOneWidget);
    });

    testWidgets('supports cognitive-load batching with checkpoints in MCQ mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'settings': '{"studyBatchSize":2,"recallBeforeReveal":true,"notificationsEnabled":true,"darkMode":true}',
      });

      await tester.pumpWidget(buildTestWidget(questions: testQuestions));
      await tester.pumpAndSettle();

      // Title indicates Batch 1 of 2
      expect(find.textContaining('Batch 1/2'), findsOneWidget);
      expect(find.text('What organelle produces ATP in eukaryotic cells?'), findsOneWidget);

      // Answer question 1 correctly (Mitochondria)
      await tester.tap(find.textContaining('Mitochondria'));
      await tester.pumpAndSettle();

      // Advance to question 2
      expect(find.text('Next Question'), findsOneWidget);
      await tester.ensureVisible(find.text('Next Question'));
      await tester.tap(find.text('Next Question'));
      await tester.pumpAndSettle();

      // Answer question 2 (Thymine)
      expect(find.text('Which base pairs with Adenine in DNA?'), findsOneWidget);
      await tester.tap(find.textContaining('Thymine'));
      await tester.pumpAndSettle();

      // Because this is the end of batch 1, button is "Finish Batch"
      expect(find.text('Finish Batch'), findsOneWidget);
      await tester.ensureVisible(find.text('Finish Batch'));
      await tester.tap(find.text('Finish Batch'));
      await tester.pumpAndSettle();

      // Batch 1 checkpoint appears
      expect(find.text('Batch 1 of 2 Complete!'), findsOneWidget);
      expect(find.text('2 of 3 questions answered.'), findsOneWidget);
      expect(find.text('Continue to Batch 2'), findsOneWidget);

      // Continue to Batch 2
      await tester.tap(find.text('Continue to Batch 2'));
      await tester.pumpAndSettle();

      // Question 3 is shown
      expect(find.text('What is the primary function of hemoglobin?'), findsOneWidget);
      await tester.tap(find.textContaining('Oxygen transport'));
      await tester.pumpAndSettle();

      // Finish Quiz button appears
      expect(find.text('Finish Quiz'), findsOneWidget);
      await tester.ensureVisible(find.text('Finish Quiz'));
      await tester.tap(find.text('Finish Quiz'));
      await tester.pumpAndSettle();

      // Final completion overlay
      expect(find.text('Quiz Complete!'), findsOneWidget);
      expect(find.text('Score: 3/3'), findsOneWidget);
    });
  });
}
