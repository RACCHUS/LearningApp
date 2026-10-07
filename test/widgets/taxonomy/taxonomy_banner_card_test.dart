import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/taxonomy/taxonomy_banner_card.dart';

void main() {
  testWidgets('TaxonomyBannerCard renders title, provenance, and invokes onTap',
      (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaxonomyBannerCard(
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    // Verify key text elements
    expect(find.text('Career & Taxonomy Explorer'), findsOneWidget);
    expect(find.textContaining('CIP 2020 • SOC 2018'), findsOneWidget);
    expect(find.text('CIP Programs'), findsOneWidget);
    expect(find.text('Labor Crosswalks'), findsOneWidget);
    expect(find.text('Job Zones 1–5'), findsOneWidget);

    // Tap the card
    await tester.tap(find.byType(TaxonomyBannerCard));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
