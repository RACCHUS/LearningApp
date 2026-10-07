import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/taxonomy/taxonomy_explorer_screen.dart';

void main() {
  testWidgets('TaxonomyExplorerScreen renders tabs and switches views cleanly',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TaxonomyExplorerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app bar title and search field
    expect(find.text('Pathways & Taxonomy'), findsOneWidget);
    expect(find.byKey(const Key('taxonomy-search-field')), findsOneWidget);

    // Verify 3 tabs
    expect(find.text('Careers & SOC'), findsOneWidget);
    expect(find.text('CIP Programs'), findsOneWidget);
    expect(find.text('Disciplines'), findsOneWidget);

    // Verify Occupations in tab 1
    expect(find.text('Software Developers'), findsAtLeastNWidgets(1));
    expect(find.text('All Zones'), findsOneWidget);
    expect(find.text('Zone 4 (B.S./B.A.)'), findsOneWidget);

    // Switch to CIP tab
    await tester.tap(find.text('CIP Programs'));
    await tester.pumpAndSettle();

    expect(find.text('Computer Science'), findsAtLeastNWidgets(1));

    // Switch to Disciplines tab
    await tester.tap(find.text('Disciplines'));
    await tester.pumpAndSettle();

    expect(find.text('Computing & Information Technology'), findsOneWidget);

    // Test live search
    await tester.enterText(
      find.byKey(const Key('taxonomy-search-field')),
      'Software',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Search Results for "Software"'), findsOneWidget);
    expect(find.text('Software Developers'), findsAtLeastNWidgets(1));
  });
}
