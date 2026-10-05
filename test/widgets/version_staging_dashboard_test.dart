import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/governance/governance.dart';
import 'package:learning_pwa/providers/version_governance_provider.dart';
import 'package:learning_pwa/screens/governance/version_staging_dashboard_screen.dart';

void main() {
  group('Phase G: VersionStagingDashboardScreen Widget Tests', () {
    const mockReportBalanced = TargetVersionAuditReport(
      targetVersionId: 'v-staging-1',
      versionCode: 'SY0-701',
      status: 'review_ready',
      targetTitle: 'CompTIA Security+ Certification',
      domainCount: 5,
      objectiveCount: 28,
      leafObjectiveCount: 23,
      domainWeightSum: 100.0,
      isDomainWeightBalanced: true,
      lessonCount: 42,
      lessonBlockCount: 210,
      stimulusCount: 8,
      assessmentItemCount: 96,
      emptyObjectivesCount: 0,
      conceptCoverageCount: 54,
      unassessedConceptsCount: 0,
      provenanceCitationsCount: 28,
      missingProvenanceCount: 0,
      crossVersionMappingsCount: 48,
      canStageReview: true,
      canPublish: true,
      blockingIssues: [],
      warnings: [],
    );

    const mockReportDraft = TargetVersionAuditReport(
      targetVersionId: 'v-staging-2',
      versionCode: 'SY0-801-DRAFT',
      status: 'draft',
      targetTitle: 'CompTIA Security+ Next Gen',
      domainCount: 4,
      objectiveCount: 16,
      leafObjectiveCount: 12,
      domainWeightSum: 85.0,
      isDomainWeightBalanced: false,
      lessonCount: 10,
      lessonBlockCount: 30,
      stimulusCount: 2,
      assessmentItemCount: 20,
      emptyObjectivesCount: 2,
      conceptCoverageCount: 25,
      unassessedConceptsCount: 4,
      provenanceCitationsCount: 12,
      missingProvenanceCount: 2,
      crossVersionMappingsCount: 10,
      canStageReview: false,
      canPublish: false,
      blockingIssues: [
        'Domain weights sum to 85.0%, but must equal 100.0%',
        '2 objectives have no lessons or items',
      ],
      warnings: [
        '2 items are missing formal provenance citations',
      ],
    );

    testWidgets('renders empty state when no staged versions exist and no initial ID',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stagedTargetVersionsProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(
            home: VersionStagingDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Version Governance & QA'), findsOneWidget);
      expect(
        find.text('No versions currently in draft or review staging.'),
        findsOneWidget,
      );
      expect(
        find.text('All official target blueprints are actively published.'),
        findsOneWidget,
      );
    });

    testWidgets('renders balanced audit report and Promote button for review_ready edition',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final stagedList = [
        {
          'id': 'v-staging-1',
          'version_code': 'SY0-701',
          'title': 'Edition 2026',
          'status': 'review_ready',
          'created_at': '2026-10-01T00:00:00Z',
          'target_id': 't-secplus',
          'learning_targets': {'title': 'CompTIA Security+ Certification', 'target_type': 'certification'},
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stagedTargetVersionsProvider.overrideWith((ref) async => stagedList),
            targetVersionAuditProvider('v-staging-1')
                .overrideWith((ref) async => mockReportBalanced),
          ],
          child: const MaterialApp(
            home: VersionStagingDashboardScreen(initialVersionId: 'v-staging-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title & Edition Info
      expect(find.text('CompTIA Security+ Certification'), findsOneWidget);
      expect(find.text('Edition: SY0-701'), findsOneWidget);

      // Domain Weights Balanced
      expect(find.text('Domain Weights Balanced (100.0%)'), findsOneWidget);
      expect(
        find.text('5 root domain(s) comprising 23 leaf objective(s).'),
        findsOneWidget,
      );

      // Metrics Grid Check
      expect(find.text('Lessons & Blocks'), findsOneWidget);
      expect(find.text('42 / 210'), findsOneWidget);
      expect(find.text('Assessments'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      expect(find.text('8 shared stimuli'), findsOneWidget);
      expect(find.text('Concept Coverage'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('54 concepts'), findsOneWidget);

      // Lifecycle Action: For review_ready, should offer "Promote to Published"
      expect(find.text('Promote to Published'), findsOneWidget);
    });

    testWidgets('renders unbalanced domain weights and blocking issues for draft edition',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final stagedList = [
        {
          'id': 'v-staging-2',
          'version_code': 'SY0-801-DRAFT',
          'title': 'Next Gen Draft',
          'status': 'draft',
          'created_at': '2026-10-02T00:00:00Z',
          'target_id': 't-secplus',
          'learning_targets': {'title': 'CompTIA Security+ Next Gen', 'target_type': 'certification'},
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stagedTargetVersionsProvider.overrideWith((ref) async => stagedList),
            targetVersionAuditProvider('v-staging-2')
                .overrideWith((ref) async => mockReportDraft),
          ],
          child: const MaterialApp(
            home: VersionStagingDashboardScreen(initialVersionId: 'v-staging-2'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title & Edition Info
      expect(find.text('CompTIA Security+ Next Gen'), findsOneWidget);
      expect(find.text('Edition: SY0-801-DRAFT'), findsOneWidget);

      // Unbalanced Domain Weight Banner
      expect(find.text('Domain Weights Unbalanced (85.0%)'), findsOneWidget);

      // Blocking Issues List
      expect(
        find.text('Domain weights sum to 85.0%, but must equal 100.0%'),
        findsOneWidget,
      );
      expect(
        find.text('2 objectives have no lessons or items'),
        findsOneWidget,
      );

      // Warnings List
      expect(
        find.text('2 items are missing formal provenance citations'),
        findsOneWidget,
      );

      // Lifecycle Action: For draft, should offer "Advance to Review Ready"
      expect(find.text('Advance to Review Ready'), findsOneWidget);
    });
  });
}
