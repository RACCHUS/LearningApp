import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/governance/curriculum_freshness_screen.dart';

void main() {
  Map<String, dynamic> data({bool withItem = true}) => {
    'versions': [
      {'target_slug': 'open-openstax-prealgebra-1e', 'target_title': 'Prealgebra (open textbook)',
       'version_code': 'OPENSTAX-EB2E29D-R3', 'volatility_class': 'V0', 'review_by': '2029-11-21', 'source_pin': 'eb2e29d'},
      {'target_slug': 'clep-algebra', 'target_title': 'CLEP Algebra', 'version_code': 'v1',
       'volatility_class': null, 'review_by': null, 'source_pin': null},
    ],
    'open_items': [
      if (withItem)
        {'id': 'i1', 'target_slug': 'open-openstax-prealgebra-1e', 'version_code': 'OPENSTAX-EB2E29D-R3',
         'reason': 'source_changed', 'detail': 'Pinned eb2e29d, publisher now f00d123'},
    ],
  };

  testWidgets('shows the queue and the versions, and resolves an item', (tester) async {
    var withItem = true;
    final resolved = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: CurriculumFreshnessScreen(
        load: () async => data(withItem: withItem),
        resolve: (id, status) async {
          resolved.add('$id:$status');
          withItem = false;
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Needs attention (1)'), findsOneWidget);
    expect(find.textContaining('Source changed: open-openstax-prealgebra-1e'), findsOneWidget);
    expect(find.textContaining('V0 · review by 2029-11-21 · source eb2e29d'), findsOneWidget);
    expect(find.textContaining('No freshness set'), findsOneWidget);

    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();
    expect(resolved, ['i1:resolved']);
    expect(find.text('Needs attention (0)'), findsOneWidget);
    expect(find.text('Nothing due.'), findsOneWidget);
  });

  testWidgets('non-admins see a plain message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CurriculumFreshnessScreen(load: () async => throw StateError('42501')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Admins only'), findsOneWidget);
  });
}
