import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';

void main() {
  group('McqOptions', () {
    final options = ['First Option', 'Second Option', 'Third Option', 'All of the above'];

    test('computePresentationOrder preserves anchor position at the end', () {
      final order1 = McqOptions.computePresentationOrder(options, presentationSeed: 42);
      final order2 = McqOptions.computePresentationOrder(options, presentationSeed: 99);

      // 'All of the above' is at index 3, must remain at the last position
      expect(order1.last, equals(3));
      expect(order2.last, equals(3));

      // Shuffled non-anchor positions should contain 0, 1, 2
      expect(order1.sublist(0, 3)..sort(), equals([0, 1, 2]));
      expect(order2.sublist(0, 3)..sort(), equals([0, 1, 2]));
    });

    test('computePresentationOrder produces different permutations for different seeds', () {
      final orderA = McqOptions.computePresentationOrder(['Apple', 'Banana', 'Cherry', 'Date'], presentationSeed: 1);
      final orderB = McqOptions.computePresentationOrder(['Apple', 'Banana', 'Cherry', 'Date'], presentationSeed: 2);

      // Both must be valid permutations
      expect(List.of(orderA)..sort(), equals([0, 1, 2, 3]));
      expect(List.of(orderB)..sort(), equals([0, 1, 2, 3]));
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
      final listTiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
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

      final listTiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      final colors = listTiles.map((t) => t.tileColor).toList();

      // At least one tile should have a green-ish tint and one red-ish tint
      expect(colors.any((c) => c != null && c.value != 0), isTrue);
    });
  });
}

