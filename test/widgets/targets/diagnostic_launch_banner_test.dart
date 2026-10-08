import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment/diagnostic_assessment.dart';
import 'package:learning_pwa/providers/diagnostic_assessment_provider.dart';
import 'package:learning_pwa/widgets/targets/diagnostic_launch_banner.dart';

void main() {
  testWidgets('hides the diagnostic launch when reviewed coverage is insufficient',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosticAvailabilityProvider((targetId: 'target-1', targetVersionId: 'version-1')).overrideWith(
            (ref) async => const DiagnosticAvailability(
              targetVersionId: 'version-1',
              isPublishedVersion: true,
              availableItemCount: 4,
              representedConceptCount: 2,
              minimumItemCount: 6,
              minimumConceptCount: 3,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DiagnosticLaunchBanner(
              targetId: 'target-1',
              targetVersionId: 'version-1',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostic-launch-banner')), findsNothing);
  });

  testWidgets('shows the diagnostic launch only when canonical coverage is sufficient',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosticAvailabilityProvider((targetId: 'target-1', targetVersionId: 'version-1')).overrideWith(
            (ref) async => const DiagnosticAvailability(
              targetVersionId: 'version-1',
              isPublishedVersion: true,
              availableItemCount: 8,
              representedConceptCount: 4,
              minimumItemCount: 6,
              minimumConceptCount: 3,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DiagnosticLaunchBanner(
              targetId: 'target-1',
              targetVersionId: 'version-1',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostic-launch-banner')), findsOneWidget);
    expect(find.text('Take Diagnostic'), findsOneWidget);
    expect(find.textContaining('8 eligible items'), findsOneWidget);
  });
}
