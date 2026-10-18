import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/verified_destinations_provider.dart';
import 'package:learning_pwa/widgets/targets/pathway_preparation_goal_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final sampleDestination = VerifiedDestination(
    sourceNamespace: 'fl_dfs',
    sourceKey: 'general-lines-2-20',
    destinationType: 'professional_license',
    title: 'Florida General Lines (2-20) Agent',
    issuerName: 'Florida Department of Financial Services',
    jurisdiction: 'US-FL',
    officialUrl: Uri.parse(
        'https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications'),
    requirementsStatus: 'not_verified',
    popularityStatus: 'not_verified',
    verifiedAt: DateTime.utc(2026, 10, 13),
  );

  final mockReviewedPathway = ReviewedLicensePathway(
    title: 'Florida General Lines (2-20) Agent: selected examination-route steps',
    overview: 'Selected qualification and licensing steps for 2-20 agents.',
    coverage: 'selected_steps_only',
    revision: 1,
    sourceCheckedAt: DateTime.utc(2026, 10, 13, 12, 0, 0),
    sourceUrl: Uri.parse(
        'https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications'),
    pathwayTree: {
      'op': 'all',
      'children': [
        {
          'op': 'any',
          'children': [
            {
              'op': 'step',
              'label': '200-hour state-approved property and casualty pre-licensing course',
              'stage': 'education',
              'source_url':
                  'https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications',
            },
            {
              'op': 'step',
              'label': '1 year experience under licensed agent plus 40-hour approved course',
              'stage': 'experience',
              'source_url':
                  'https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications',
            },
          ],
        },
        {
          'op': 'step',
          'label': 'Submit resident agent application through MyFloridaCFO portal',
          'stage': 'application',
          'source_url':
              'https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications',
        },
        {
          'op': 'step',
          'label': 'Pass state insurance examination',
          'stage': 'examination',
          'source_url':
              'https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications',
        },
      ],
    },
  );

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        reviewedLicensePathwayProvider((
          namespace: 'fl_dfs',
          key: 'general-lines-2-20',
        )).overrideWith((ref) async => mockReviewedPathway),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PathwayPreparationGoalCard(
              targetId: 'goal-dfs-123',
              destination: sampleDestination,
            ),
          ),
        ),
      ),
    );
  }

  group('PathwayPreparationGoalCard Widget Tests', () {
    testWidgets('renders preparation card, progress, and milestones',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('goal-pathway-preparation-card')), findsOneWidget);
      expect(find.text('License Preparation Checklist'), findsOneWidget);
      expect(find.text('Self-Reported'), findsOneWidget);
      expect(find.textContaining('Florida General Lines (2-20) Agent (US-FL)'), findsOneWidget);
      expect(find.text('Milestones Completed'), findsOneWidget);

      // Verify action buttons
      expect(find.byKey(const Key('goal-pathway-change-route-button')), findsOneWidget);
      expect(find.byKey(const Key('goal-pathway-full-details-button')), findsOneWidget);
    });

    testWidgets('toggling a checklist step updates progress count',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Initially 0 of 4 (2 alternatives + 2 common steps when no route selected)
      expect(find.text('0 of 4'), findsOneWidget);

      // Tap first checkbox
      await tester.tap(find.byKey(const Key('goal-pathway-step-checkbox-0')));
      await tester.pumpAndSettle();

      expect(find.text('1 of 4'), findsOneWidget);

      // Tap second checkbox
      await tester.tap(find.byKey(const Key('goal-pathway-step-checkbox-1')));
      await tester.pumpAndSettle();

      expect(find.text('2 of 4'), findsOneWidget);
    });
  });
}
