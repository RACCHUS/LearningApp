import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStudyNotifier extends StateNotifier<StudyState> implements StudyNotifier {
  FakeStudyNotifier() : super(StudyState.initial());

  @override
  void markTermAsKnown(String termId) {
    state = state.copyWith(
      cardsStudied: state.cardsStudied + 1,
      termStatus: {...state.termStatus, termId: true},
    );
  }

  @override
  void markTermAsDifficult(String termId) {
    state = state.copyWith(
      cardsStudied: state.cardsStudied + 1,
      termStatus: {...state.termStatus, termId: false},
    );
  }

  @override
  void markAnswerCorrect() {}

  @override
  void markAnswerIncorrect() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<Term> testTerms = [
    Term(
      id: 'term-1',
      term: 'Photosynthesis',
      definition: 'Process by which plants convert light energy into chemical energy.',
      example: 'Plants use chlorophyll in leaves.',
      createdBy: 'test-user',
    ),
    Term(
      id: 'term-2',
      term: 'Cellular Respiration',
      definition: 'Metabolic pathway breaking down glucose to produce ATP.',
      example: 'Occurs primarily in mitochondria.',
      createdBy: 'test-user',
    ),
    Term(
      id: 'term-3',
      term: 'Osmosis',
      definition: 'Net movement of solvent molecules across a semipermeable membrane.',
      example: 'Water absorption in root hair cells.',
      createdBy: 'test-user',
    ),
  ];

  Widget buildTestWidget({required List<Term> terms}) {
    return ProviderScope(
      overrides: [
        canSpeakProvider.overrideWithValue(false),
        studyProvider.overrideWith((ref) => FakeStudyNotifier()),
      ],
      child: MaterialApp(
        home: FlashcardScreen(terms: terms),
      ),
    );
  }

  group('FlashcardScreen Recall-Before-Reveal & Focus Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'settings': '{"studyBatchSize":0,"recallBeforeReveal":true,"notificationsEnabled":true,"darkMode":true}',
      });
    });

    testWidgets('enforces active recall prompt before revealing definition and rating buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget(terms: testTerms));
      await tester.pumpAndSettle();

      // Front term is shown
      expect(find.text('Photosynthesis'), findsOneWidget);

      // Active Recall prompt is displayed
      expect(find.text('Active Recall: Try to retrieve the answer first'), findsOneWidget);

      // Reveal button is prominently displayed
      expect(find.text('Reveal Definition'), findsOneWidget);

      // Rating buttons are hidden during recall phase
      expect(find.text('Need Practice'), findsNothing);
      expect(find.text('I Know This'), findsNothing);

      // Reveal the card
      await tester.tap(find.text('Reveal Definition'));
      await tester.pumpAndSettle();

      // Definition is now visible
      expect(find.text('Process by which plants convert light energy into chemical energy.'), findsOneWidget);

      // Self-Assessment prompt is now displayed
      expect(find.text('Self-Assessment: Did you recall it accurately?'), findsOneWidget);

      // Evaluation buttons are now available
      expect(find.text('Need Practice'), findsOneWidget);
      expect(find.text('I Know This'), findsOneWidget);
      expect(find.text('Hide definition'), findsOneWidget);

      // Rate as known and advance to next card
      await tester.tap(find.text('I Know This'));
      await tester.pumpAndSettle();

      // Card 2 is now shown and starts in unrevealed recall stage
      expect(find.text('Cellular Respiration'), findsOneWidget);
      expect(find.text('Active Recall: Try to retrieve the answer first'), findsOneWidget);
      expect(find.text('Reveal Definition'), findsOneWidget);
      expect(find.text('Need Practice'), findsNothing);
      expect(find.text('I Know This'), findsNothing);
    });

    testWidgets('toggles focus mode smoothly', (tester) async {
      await tester.pumpWidget(buildTestWidget(terms: testTerms));
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

    testWidgets('supports cognitive-load batching with batch checkpoints', (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings': '{"studyBatchSize":2,"recallBeforeReveal":false,"notificationsEnabled":true,"darkMode":true}',
      });

      await tester.pumpWidget(buildTestWidget(terms: testTerms));
      await tester.pumpAndSettle();

      // Title indicates Batch 1 of 2
      expect(find.textContaining('Batch 1/2'), findsOneWidget);

      // Card 1: Rate Known
      await tester.tap(find.text('I Know This'));
      await tester.pumpAndSettle();

      // Card 2: Rate Difficult
      await tester.tap(find.text('Need Practice'));
      await tester.pumpAndSettle();

      // Batch 1 checkpoint appears
      expect(find.text('Batch 1 of 2 Complete!'), findsOneWidget);
      expect(find.text('2 of 3 cards studied.'), findsOneWidget);
      expect(find.text('Continue to Batch 2'), findsOneWidget);
      expect(find.text('Review 1 Difficult Cards in Batch'), findsOneWidget);

      // Continue to Batch 2
      await tester.tap(find.text('Continue to Batch 2'));
      await tester.pumpAndSettle();

      // Now studying Card 3 (Batch 2)
      expect(find.text('Osmosis'), findsOneWidget);

      // Rate Card 3
      await tester.tap(find.text('I Know This'));
      await tester.pumpAndSettle();

      // Final complete overlay appears
      expect(find.text('Flashcards Complete!'), findsOneWidget);
      expect(find.text('2/3 known'), findsOneWidget);
    });
  });
}
