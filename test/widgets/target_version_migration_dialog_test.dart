import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/governance/governance.dart';
import 'package:learning_pwa/providers/version_governance_provider.dart';
import 'package:learning_pwa/widgets/governance/target_version_migration_dialog.dart';

void main() {
  group('Phase G: TargetVersionMigrationDialog Widget Tests', () {
    const mockUpdateInfo = TargetVersionUpdateInfo(
      contextId: 'ctx-security-plus',
      userId: 'usr-learner-1',
      targetId: 't-secplus',
      targetTitle: 'CompTIA Security+ Certification',
      currentVersionId: 'v-sy0-601',
      currentVersionCode: 'SY0-601',
      currentVersionStatus: 'published',
      latestVersionId: 'v-sy0-701',
      latestVersionCode: 'SY0-701',
      latestVersionStatus: 'published',
      isOutdated: true,
      isRetired: false,
    );

    const mockEvaluation = TargetVersionMigrationEvaluation(
      fromTargetVersionId: 'v-sy0-601',
      toTargetVersionId: 'v-sy0-701',
      totalSourceConcepts: 32,
      totalTargetConcepts: 36,
      mappedConceptsCount: 30,
      retainedConceptsCount: 28,
      removedConceptsCount: 2,
      newConceptsCount: 6,
      transferRetentionPct: 87.5,
      userAssessedConceptsCount: 20,
      projectedRetainedAssessedCount: 17.5,
      conceptMappings: [
        ConceptTransferDiff(
          fromConceptId: 'c1',
          toConceptId: 'c2',
          mappingType: 'expanded',
          transferWeight: 0.9,
          fromConceptName: 'Threat Actors',
          toConceptName: 'Modern Threat Vectors',
        ),
      ],
    );

    testWidgets('renders version pills, retention percentage, and Invariant 6 guarantee',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final evalParams = MigrationEvaluationParams(
        userId: mockUpdateInfo.userId,
        fromVersionId: mockUpdateInfo.currentVersionId,
        toVersionId: mockUpdateInfo.latestVersionId!,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            migrationEvaluationProvider(evalParams)
                .overrideWith((ref) async => mockEvaluation),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TargetVersionMigrationDialog(
                updateInfo: mockUpdateInfo,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header & Version Transition
      expect(find.text('Blueprint Version Upgrade'), findsOneWidget);
      expect(find.text('CompTIA Security+ Certification'), findsOneWidget);
      expect(find.text('SY0-601'), findsOneWidget);
      expect(find.text('SY0-701'), findsOneWidget);

      // Upgrade reason
      expect(find.text(mockUpdateInfo.upgradeReason), findsOneWidget);

      // Retention & Metric Chips
      expect(find.text('87.5% Retained'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('Retained Concepts'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('New Topics'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Retired Topics'), findsOneWidget);

      // Invariant 6 Guarantee Banner
      expect(find.textContaining('Invariant 6'), findsOneWidget);
      expect(find.textContaining('Progress Preservation Guarantee'), findsOneWidget);

      // Action Buttons
      expect(find.byKey(const Key('confirm-migration-button')), findsOneWidget);
      expect(find.text('Keep Current Edition for Now'), findsOneWidget);
    });

    testWidgets('triggers upgrade migration when button is clicked',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final evalParams = MigrationEvaluationParams(
        userId: mockUpdateInfo.userId,
        fromVersionId: mockUpdateInfo.currentVersionId,
        toVersionId: mockUpdateInfo.latestVersionId!,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            migrationEvaluationProvider(evalParams)
                .overrideWith((ref) async => mockEvaluation),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TargetVersionMigrationDialog(
                updateInfo: mockUpdateInfo,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(const Key('confirm-migration-button'));
      expect(confirmBtn, findsOneWidget);

      // Tap confirm button
      await tester.tap(confirmBtn);
      await tester.pump();

      // In offline/mock mode, it completes migration successfully and attempts to pop
      await tester.pumpAndSettle();
    });

    testWidgets('Keep Current Edition button is present and clickable',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final evalParams = MigrationEvaluationParams(
        userId: mockUpdateInfo.userId,
        fromVersionId: mockUpdateInfo.currentVersionId,
        toVersionId: mockUpdateInfo.latestVersionId!,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            migrationEvaluationProvider(evalParams)
                .overrideWith((ref) async => mockEvaluation),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TargetVersionMigrationDialog(
                updateInfo: mockUpdateInfo,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final keepBtn = find.text('Keep Current Edition for Now');
      expect(keepBtn, findsOneWidget);
      await tester.tap(keepBtn);
      await tester.pumpAndSettle();
    });
  });
}
