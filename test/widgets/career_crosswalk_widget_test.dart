import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/taxonomy/taxonomy.dart';
import 'package:learning_pwa/providers/taxonomy_provider.dart';
import 'package:learning_pwa/widgets/taxonomy/career_crosswalk_sheet.dart';

void main() {
  group('Phase F: CareerCrosswalkSheet Widget Tests', () {
    testWidgets('renders header, provenance banner, occupation cards, and safeguards',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockCrosswalks = [
        const TargetCrosswalkOccupation(
          occupationId: 'occ-1',
          occupationCode: '15-1252',
          occupationTitle: 'Software Developers',
          occupationLevel: 'detailed_occupation',
          jobZone: 4,
          fieldId: 'f-cs',
          fieldName: 'Computer Science',
          fieldRole: 'primary',
          classificationCode: '11.0701',
          classificationTitle: 'Computer Science',
        ),
        const TargetCrosswalkOccupation(
          occupationId: 'occ-2',
          occupationCode: '15-1211.00',
          occupationTitle: 'Information Security Analysts',
          occupationLevel: 'onet_extension',
          jobZone: 4,
          fieldId: 'f-cs',
          fieldName: 'Computer Science',
          fieldRole: 'supporting',
          classificationCode: '11.1003',
          classificationTitle: 'Information Assurance',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            targetCrosswalkOccupationsProvider('target-test-id')
                .overrideWith((ref) async => mockCrosswalks),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CareerCrosswalkSheet(
                targetId: 'target-test-id',
                targetTitle: 'B.S. in Computer Science',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header & Title
      expect(find.text('Career & Labor Pathways'), findsOneWidget);
      expect(find.text('B.S. in Computer Science'), findsOneWidget);

      // Provenance banner
      expect(
        find.text('NCES CIP 2020 ↔ BLS SOC 2018 / O*NET 31.0 Official Crosswalk'),
        findsOneWidget,
      );

      // Occupation cards
      expect(find.text('15-1252'), findsOneWidget);
      expect(find.text('Software Developers'), findsOneWidget);
      expect(find.text('Primary Alignment'), findsOneWidget);

      expect(find.text('15-1211.00'), findsOneWidget);
      expect(find.text('Information Security Analysts'), findsOneWidget);
      expect(find.text('O*NET'), findsOneWidget);
      expect(find.text('Supporting Field'), findsOneWidget);

      // Job Zone pill
      expect(find.textContaining('Job Zone 4: Considerable Preparation'), findsNWidgets(2));

      // Pedagogical safeguards notice
      expect(
        find.textContaining('Crosswalk alignments derive from published federal qualitative matrices'),
        findsOneWidget,
      );
    });

    testWidgets('renders empty state when no occupations are mapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            targetCrosswalkOccupationsProvider('target-empty')
                .overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CareerCrosswalkSheet(
                targetId: 'target-empty',
                targetTitle: 'General Exploratory Studies',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Career & Labor Pathways'), findsOneWidget);
      expect(
        find.text('No direct federal occupational crosswalk recorded for this target yet.'),
        findsOneWidget,
      );
    });
  });
}
