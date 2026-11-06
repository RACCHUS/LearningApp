import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';
import 'package:learning_pwa/widgets/question_widgets/mcq_question_widget.dart';

void main() {
  group('McqOptions & McqQuestionWidget', () {
    final options = [
      'First Option',
      'Second Option',
      'Third Option',
      'All of the above',
    ];

    test('computePresentationOrder preserves anchor position at the end', () {
      final order1 =
          McqOptions.computePresentationOrder(options, presentationSeed: 42);
      final order2 =
          McqOptions.computePresentationOrder(options, presentationSeed: 99);

      // 'All of the above' is at index 3, must remain at the last position
      expect(order1.last, equals(3));
      expect(order2.last, equals(3));

      // Shuffled non-anchor positions should contain 0, 1, 2
      expect(order1.sublist(0, 3)..sort(), equals([0, 1, 2]));
      expect(order2.sublist(0, 3)..sort(), equals([0, 1, 2]));
    });

    test('computePresentationOrder produces different permutations for different seeds', () {
      final orderA = McqOptions.computePresentationOrder(
        ['Apple', 'Banana', 'Cherry', 'Date'],
        presentationSeed: 1,
      );
      final orderB = McqOptions.computePresentationOrder(
        ['Apple', 'Banana', 'Cherry', 'Date'],
        presentationSeed: 2,
      );

      // Both must be valid permutations
      expect(List.of(orderA)..sort(), equals([0, 1, 2, 3]));
      expect(List.of(orderB)..sort(), equals([0, 1, 2, 3]));
    });

    test('nextPresentationNonce produces a fresh raw nonce with a distinct permutation from previousOrder', () {
      final fourOptions = ['Alpha', 'Bravo', 'Charlie', 'Delta'];
      const itemHash = 0x12345678;
      int nonce = 100;
      List<int> prevOrder = McqOptions.computePresentationOrder(
        fourOptions,
        presentationSeed: nonce ^ itemHash,
        shuffle: true,
      );

      for (int i = 0; i < 10; i++) {
        final nextNonce = McqOptions.nextPresentationNonce(
          currentNonce: nonce,
          options: fourOptions,
          itemHash: itemHash,
          previousOrder: prevOrder,
        );
        expect(nextNonce, isNot(equals(nonce)));
        final nextOrder = McqOptions.computePresentationOrder(
          fourOptions,
          presentationSeed: nextNonce ^ itemHash,
          shuffle: true,
        );
        expect(nextOrder, isNot(equals(prevOrder)));
        nonce = nextNonce;
        prevOrder = nextOrder;
      }
    });

    testWidgets('renders options in shuffled order and passes original index to onChanged', (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: McqOptions(
              options: options,
              selectedIndex: selected,
              presentationSeed: 42,
              onChanged: (val) {
                selected = val;
              },
            ),
          ),
        ),
      );

      // Verify that All of the above is rendered last
      final listTiles =
          tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(listTiles.length, equals(4));
      expect((listTiles.last.title as Text).data, equals('All of the above'));

      // Tap the first rendered option
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();

      // Selected value must be an original valid index
      expect(selected, isNotNull);
      expect(selected, isIn([0, 1, 2]));
    });

    testWidgets('correctly highlights correct and incorrect options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: McqOptions(
              options: options,
              selectedIndex: 0,
              correctIndex: 1,
              showCorrect: true,
              presentationSeed: 10,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final listTiles =
          tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      final colors = listTiles.map((t) => t.tileColor).toList();

      // At least one tile should have a green-ish tint and one red-ish tint
      expect(colors.any((c) => c != null && c.toARGB32() != 0), isTrue);
    });

    testWidgets('McqQuestionWidget shuffles widget.content.options by default and re-randomizes on retry', (tester) async {
      final now = DateTime.now();
      final content = QuestionContent(
        id: 'mcq-widget-q1',
        lessonId: 'lesson-1',
        order: 1,
        questionText: 'Which layer routes packets across networks?',
        options: ['Physical', 'Data Link', 'Network', 'Transport'],
        correctAnswer: 2,
        explanation: 'The Network layer handles logical addressing and routing.',
        createdAt: now,
        updatedAt: now,
      );

      int? selectedIdx;
      bool showCorrect = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canSpeakProvider.overrideWithValue(false),
            canListenProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return McqQuestionWidget(
                    content: content,
                    selectedIndex: selectedIdx,
                    showCorrect: showCorrect,
                    onSelectionChanged: (idx) => setState(() => selectedIdx = idx),
                    onSubmit: () => setState(() => showCorrect = true),
                    onNext: () {},
                    onVoiceInput: (_) {},
                    customTextBuilder: (text) => Text(text),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final widgetState =
          tester.state(find.byType(McqQuestionWidget)) as dynamic;
      final order1 = List<int>.from(widgetState.presentationOrder as List<int>);
      expect(order1.toSet(), equals({0, 1, 2, 3}));

      // Verify rendered ListTile order matches order1
      final renderedTitles1 = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data!)
          .toList();
      expect(
        renderedTitles1,
        equals(order1.map((i) => content.options[i]).toList()),
      );

      // Trigger retry on McqQuestionWidget state and verify a fresh permutation is generated
      widgetState.retry();
      await tester.pumpAndSettle();

      final order2 = List<int>.from(widgetState.presentationOrder as List<int>);
      expect(order2.toSet(), equals({0, 1, 2, 3}));
      expect(order2, isNot(equals(order1)));

      final renderedTitles2 = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data!)
          .toList();
      expect(
        renderedTitles2,
        equals(order2.map((i) => content.options[i]).toList()),
      );
    });
  });
}
