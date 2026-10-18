import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/verified_destinations_provider.dart';
import 'package:learning_pwa/widgets/taxonomy/pathway_preparation_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final sampleDestination = VerifiedDestination(
    sourceNamespace: 'fl_bon',
    sourceKey: 'registered-nurse',
    destinationType: 'professional_license',
    title: 'Florida Registered Nurse (RN)',
    issuerName: 'Florida Board of Nursing',
    jurisdiction: 'US-FL',
    officialUrl: Uri.parse('https://floridasnursing.gov/nurse-rn-lpn/'),
    requirementsStatus: 'not_verified',
    popularityStatus: 'not_verified',
    verifiedAt: DateTime.utc(2026, 10, 12),
  );

  final mockReviewedPathway = ReviewedLicensePathway(
    title: 'Florida RN initial licensure: selected examination-path steps',
    overview: 'Selected regulator-sourced steps for Florida nursing licensure.',
    coverage: 'selected_steps_only',
    revision: 1,
    sourceCheckedAt: DateTime.utc(2026, 10, 12, 12, 0, 0),
    sourceUrl: Uri.parse('https://floridasnursing.gov/nurse-rn-lpn/'),
    pathwayTree: {
      'op': 'all',
      'children': [
        {
          'op': 'any',
          'children': [
            {
              'op': 'step',
              'label': 'Florida-approved nursing education program',
              'stage': 'education',
              'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
            },
            {
              'op': 'step',
              'label': 'ACEN- or CCNE-accredited nursing program',
              'stage': 'education',
              'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
            },
          ],
        },
        {
          'op': 'step',
          'label': 'Complete electronic fingerprinting and Level 2 background screening',
          'stage': 'background_screening',
          'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
        },
        {
          'op': 'step',
          'label': 'Pass NCLEX examination',
          'stage': 'examination',
          'source_url': 'https://floridasnursing.gov/nurse-rn-lpn/',
        },
      ],
    },
  );

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        reviewedLicensePathwayProvider((
          namespace: 'fl_bon',
          key: 'registered-nurse',
        )).overrideWith((ref) async => mockReviewedPathway),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PathwayPreparationSheet(
            destination: sampleDestination,
          ),
        ),
      ),
    );
  }

  group('PathwayPreparationSheet Widget Tests', () {
    testWidgets('renders title, disclaimers, and alternative routes',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Check title and disclaimers
      expect(find.text(mockReviewedPathway.title), findsOneWidget);
      expect(find.text('Informational Preparation Only'), findsOneWidget);
      expect(
        find.textContaining('Selected regulator-sourced steps only'),
        findsOneWidget,
      );

      // Check route options
      expect(find.text('1. Choose Qualification Route'), findsOneWidget);
      expect(find.byKey(const Key('pathway-route-option-0')), findsOneWidget);
      expect(find.byKey(const Key('pathway-route-option-1')), findsOneWidget);

      // Check steps list
      expect(find.text('2. Track Required Steps'), findsOneWidget);
      expect(
        find.text('Complete electronic fingerprinting and Level 2 background screening'),
        findsOneWidget,
      );
      expect(find.text('Pass NCLEX examination'), findsOneWidget);

      // Check actions
      expect(find.byKey(const Key('pathway-connect-goal-button')), findsOneWidget);
      expect(
        find.byKey(const Key('pathway-open-regulator-source-button')),
        findsOneWidget,
      );
    });

    testWidgets('selecting a route updates selected state and checklist',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Tap the first route option
      await tester.tap(find.byKey(const Key('pathway-route-option-0')));
      await tester.pumpAndSettle();

      // Progress should now be 0 of 3 (1 selected route + 2 common steps)
      expect(find.text('0 of 3 steps'), findsOneWidget);

      // Clear button is visible
      expect(find.byKey(const Key('pathway-clear-route-button')), findsOneWidget);
    });

    testWidgets('toggling a step checkbox updates progress meter',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Select route 0 (total 3 steps)
      await tester.tap(find.byKey(const Key('pathway-route-option-0')));
      await tester.pumpAndSettle();

      expect(find.text('0 of 3 steps'), findsOneWidget);

      // Tap first step checkbox
      await tester.tap(find.byKey(const Key('pathway-step-checkbox-0')));
      await tester.pumpAndSettle();

      expect(find.text('1 of 3 steps'), findsOneWidget);

      // Tap second step checkbox
      await tester.tap(find.byKey(const Key('pathway-step-checkbox-1')));
      await tester.pumpAndSettle();

      expect(find.text('2 of 3 steps'), findsOneWidget);
    });
  });
}
