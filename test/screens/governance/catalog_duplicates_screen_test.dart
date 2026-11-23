import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/governance/catalog_duplicates_screen.dart';

void main() {
  testWidgets('lists pairs with reason and dismisses one', (tester) async {
    var pairs = <dynamic>[
      {'a_id': 'a', 'a_title': 'Percent change', 'a_target': 'open-openstax-prealgebra-1e',
       'b_id': 'b', 'b_title': 'Percent Change!', 'b_target': null,
       'same_book': false, 'reason': 'similar_title', 'confidence': 0.82},
    ];
    final dismissed = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: CatalogDuplicatesScreen(
        load: () async => pairs,
        dismiss: (a, b) async {
          dismissed.add('$a|$b');
          pairs = [];
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Percent change  ↔  Percent Change!'), findsOneWidget);
    expect(find.textContaining('similar title, 82% · open-openstax-prealgebra-1e / standalone'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('dup_dismiss_a_b')));
    await tester.pumpAndSettle();
    expect(dismissed, ['a|b']);
    expect(find.text('No likely duplicates.'), findsOneWidget);
  });

  testWidgets('a failed load says moderators only', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CatalogDuplicatesScreen(load: () async => throw Exception('42501')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Moderators only'), findsOneWidget);
  });
}
