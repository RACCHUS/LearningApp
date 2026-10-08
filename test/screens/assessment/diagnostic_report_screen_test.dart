import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/assessment/diagnostic_assessment.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/providers/diagnostic_assessment_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/screens/assessment/diagnostic_report_screen.dart';
import 'package:learning_pwa/services/assessment/diagnostic_assessment_service.dart';
import '../../test_helpers/fake_supabase_client.dart';

void main() {
  testWidgets('remedial persistence failure is surfaced and never reports success',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosticAssessmentServiceProvider.overrideWithValue(
            _FailingDiagnosticService(),
          ),
        ],
        child: MaterialApp(
          home: DiagnosticReportScreen(report: _report()),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('generate-remedial-set-button')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not create the study set'),
      findsOneWidget,
    );
    expect(find.textContaining('Study set created:'), findsNothing);
  });

  testWidgets('Start Curriculum creates the target context before navigating',
      (tester) async {
    final contexts = _CapturingContextsNotifier();
    final router = GoRouter(
      initialLocation: '/report',
      routes: [
        GoRoute(
          path: '/report',
          builder: (_, __) => DiagnosticReportScreen(report: _report()),
        ),
        GoRoute(
          path: '/learn',
          builder: (_, __) => const Scaffold(body: Text('LEARN DESTINATION')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningContextsProvider.overrideWith((ref) => contexts),
          learnerIdProvider.overrideWith((ref) => 'user-1'),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(
      find.byKey(const Key('diagnostic-start-curriculum-button')),
    );
    await tester.pumpAndSettle();

    expect(contexts.lastRootId, 'target-1');
    expect(contexts.lastTargetVersionId, 'version-1');
    expect(contexts.lastRootType, ContextRootType.target);
    expect(find.text('LEARN DESTINATION'), findsOneWidget);
  });
}

DiagnosticAssessmentReport _report() {
  const gap = DiagnosticConceptEvaluation(
    conceptId: 'concept-gap',
    conceptName: 'Gap Concept',
    testedItemsCount: 2,
    weightedEvidenceEarned: 0.5,
    weightedEvidencePossible: 2.0,
    evidenceRatio: 0.25,
    evidenceBand: DiagnosticEvidenceBand.needsReinforcement,
    confidence: ConceptConfidence.medium,
    isReinforcementPriority: true,
  );
  return DiagnosticAssessmentReport(
    id: 'report-1',
    targetId: 'target-1',
    targetTitle: 'Target One',
    targetVersionId: 'version-1',
    completedAt: DateTime(2026),
    totalQuestions: 6,
    correctQuestions: 2,
    partialQuestions: 1,
    overallEvidenceScore: 0.4,
    evidenceBand: DiagnosticEvidenceBand.needsReinforcement,
    conceptEvaluations: const [gap],
    reinforcementPriorities: const [gap],
    strongEvidenceConcepts: const [],
    evidencePersisted: true,
  );
}

class _FailingDiagnosticService extends DiagnosticAssessmentService {
  _FailingDiagnosticService() : super(supabase: FakeSupabaseClient());

  @override
  Future<DiagnosticAssessmentReport> generateRemedialStudySet({
    required DiagnosticAssessmentReport report,
  }) async {
    throw StateError('database unavailable');
  }
}

class _CapturingContextsNotifier extends LearningContextsNotifier {
  _CapturingContextsNotifier()
      : super.stub(const LearningContextsState());

  String? lastRootId;
  String? lastTargetVersionId;
  ContextRootType? lastRootType;

  @override
  Future<LearningContext?> createOrSwitch({
    required String userId,
    required String label,
    required ContextRootType rootType,
    required String rootId,
    String? emoji,
    String? targetVersionId,
    String? activeFocusType,
    String? activeFocusId,
    ScopeMode scopeMode = ScopeMode.coreAndPrerequisites,
    Map<String, dynamic> scopeConfig = const {},
  }) async {
    lastRootId = rootId;
    lastTargetVersionId = targetVersionId;
    lastRootType = rootType;
    return LearningContext(
      id: 'context-1',
      userId: userId,
      label: label,
      rootType: rootType,
      rootId: rootId,
      targetVersionId: targetVersionId,
      lastActiveAt: DateTime(2026),
    );
  }
}
