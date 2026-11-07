import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/words/word_sense_service.dart';
import 'package:learning_pwa/widgets/words/combined_word_practice_widget.dart';

void main() {
  group('CombinedWordPracticeWidget Tests', () {
    testWidgets('renders W1 spelling step and UI elements', (tester) async {
      final service = WordSenseService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CombinedWordPracticeWidget(
              senseService: service,
              category: 'Workplace Safety',
            ),
          ),
        ),
      );

      expect(find.textContaining('Word 1 of'), findsOneWidget);
      expect(find.textContaining('Phase 1: Spelling Recall (W1)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Check Answer'), findsOneWidget);
    });

    testWidgets('submits correct spelling and displays success feedback', (tester) async {
      final service = WordSenseService();
      final items = service.getSensesByCategory('Workplace Safety');
      final targetWord = items.first.word;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CombinedWordPracticeWidget(
              senseService: service,
              category: 'Workplace Safety',
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), targetWord);
      await tester.tap(find.byKey(const Key('practice_action_button')));
      await tester.pump();

      expect(find.textContaining('Excellent! Correct spelling.'), findsOneWidget);
      expect(find.text('Practice Definition'), findsOneWidget);
    });
  });
}
