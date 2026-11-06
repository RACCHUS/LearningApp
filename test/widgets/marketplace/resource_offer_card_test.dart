import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/marketplace/resource_offer_card.dart';

void main() {
  group('ResourceOfferCard Widget Tests (ECO-12)', () {
    testWidgets('renders offer details and transparent revenue share breakdown',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResourceOfferCard(
              resourceId: 'res-nclex-review',
              title: 'NCLEX-RN Next Generation Case Studies',
              targetDomain: 'Nursing Licensure',
              creatorName: 'Prof. Miller, MSN',
              priceCents: 2000, // $20.00
              hasAccess: false,
            ),
          ),
        ),
      );

      // Verify basic metadata
      expect(find.text('NCLEX-RN Next Generation Case Studies'), findsOneWidget);
      expect(find.text('NURSING LICENSURE'), findsOneWidget);
      expect(find.text('by Prof. Miller, MSN'), findsOneWidget);

      // Verify revenue share transparency
      expect(find.text('\$20.00'), findsOneWidget);
      expect(find.text('Creator Net (85%):'), findsOneWidget);
      expect(find.text('\$17.00'), findsOneWidget);
      expect(find.text('Platform Fee (15%):'), findsOneWidget);
      expect(find.text('\$3.00'), findsOneWidget);

      // Button says Unlock
      expect(find.text('Unlock Full Access (\$20.00)'), findsOneWidget);
    });

    testWidgets('triggers onUnlock callback when unlock button is tapped', (tester) async {
      String? unlockedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceOfferCard(
              resourceId: 'res-cdl-guide',
              title: 'CDL Pre-Trip Inspection Guide',
              targetDomain: 'Commercial Driving',
              creatorName: 'Captain Bob',
              priceCents: 1500,
              onUnlock: (id) {
                unlockedId = id;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('unlock_button_res-cdl-guide')));
      await tester.pump();

      expect(unlockedId, equals('res-cdl-guide'));
    });

    testWidgets('displays unlocked badge when learner has active entitlement', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResourceOfferCard(
              resourceId: 'res-cna-skills',
              title: 'CNA Clinical Skills Video Bank',
              targetDomain: 'Nurse Aide',
              creatorName: 'Sarah Jenkins, RN',
              priceCents: 2500,
              hasAccess: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('unlocked_badge_res-cna-skills')), findsOneWidget);
      expect(find.text('UNLOCKED / ACTIVE'), findsOneWidget);
      expect(find.text('Open Enrolled Resource'), findsOneWidget);
    });
  });
}
