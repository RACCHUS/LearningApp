import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/widgets/community/educator_credential_badge.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('EducatorCredentialBadge', () {
    testWidgets('renders licensed credential badge and opens dialog on tap', (tester) async {
      final verification = EducatorVerification(
        id: 'ver_licensed_1',
        educatorId: 'edu_1',
        verificationType: 'licensed_credential',
        jurisdiction: 'FL',
        issuer: 'FL DBPR',
        status: 'verified',
        verifiedAt: DateTime(2026, 5, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildApp(EducatorCredentialBadge(verification: verification)));

      expect(find.text('State Licensed • FL'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user), findsOneWidget);

      // Tap to open modal info
      await tester.tap(find.text('State Licensed • FL'));
      await tester.pumpAndSettle();

      expect(find.text('Verified Regulatory Licensure'), findsOneWidget);
      expect(find.textContaining('FL DBPR'), findsOneWidget);
      expect(find.textContaining('official regulatory registries'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Verified Regulatory Licensure'), findsNothing);
    });

    testWidgets('renders platform-vetted credential badge and dialog', (tester) async {
      final verification = EducatorVerification(
        id: 'ver_vetted_1',
        educatorId: 'edu_2',
        verificationType: 'platform_vetted',
        subjectId: 'workplace_safety',
        status: 'verified',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildApp(EducatorCredentialBadge(verification: verification)));

      expect(find.text('Platform Vetted'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);

      await tester.tap(find.text('Platform Vetted'));
      await tester.pumpAndSettle();

      expect(find.text('Platform-Vetted Expertise'), findsOneWidget);
      expect(find.textContaining('workplace_safety'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders self-declared badge with explicit unverified disclosure', (tester) async {
      final verification = EducatorVerification(
        id: 'ver_self_1',
        educatorId: 'edu_3',
        verificationType: 'self_declared',
        issuer: '10 years workplace trainer',
        status: 'unverified',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildApp(EducatorCredentialBadge(verification: verification)));

      expect(find.text('Self-Declared Experience'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await tester.tap(find.text('Self-Declared Experience'));
      await tester.pumpAndSettle();

      expect(find.text('Self-Declared Contributor Experience'), findsOneWidget);
      expect(find.textContaining('not independently verified'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders compact version cleanly', (tester) async {
      final verification = EducatorVerification(
        id: 'ver_licensed_compact',
        educatorId: 'edu_1',
        verificationType: 'licensed_credential',
        issuer: 'FL DBPR',
        status: 'verified',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildApp(EducatorCredentialBadge(
        verification: verification,
        isCompact: true,
      )));

      expect(find.text('Licensed (FL DBPR)'), findsOneWidget);
    });
  });

  group('EducatorReputationBadge', () {
    testWidgets('renders different reputation tiers with icons and scores', (tester) async {
      await tester.pumpWidget(buildApp(const Column(
        children: [
          EducatorReputationBadge(tier: EducatorReputationTier.masterContributor, score: 92.5),
          EducatorReputationBadge(tier: EducatorReputationTier.verifiedSpecialist, score: 34.0),
          EducatorReputationBadge(tier: EducatorReputationTier.activeContributor, score: 18.2),
          EducatorReputationBadge(tier: EducatorReputationTier.newContributor, score: 4.5),
        ],
      )));

      expect(find.text('Master Contributor (92.5)'), findsOneWidget);
      expect(find.byIcon(Icons.military_tech), findsOneWidget);

      expect(find.text('Verified Specialist (34.0)'), findsOneWidget);
      expect(find.byIcon(Icons.stars), findsOneWidget);

      expect(find.text('Active Contributor (18.2)'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium), findsOneWidget);

      expect(find.text('New Contributor (4.5)'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });
  });
}

