import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment/diagnostic_assessment.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/providers/diagnostic_assessment_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/screens/assessment/diagnostic_assessment_screen.dart';
import 'package:learning_pwa/services/assessment/diagnostic_assessment_service.dart';
import '../../test_helpers/fake_supabase_client.dart';

void main() {
  testWidgets(
    'uses exact target version, canonical renderer, and reaches report',
    (tester) async {
      final target = LearningTarget(
        id: 'target-1',
        targetType: TargetType.certification,
        title: 'Security Fundamentals',
        slug: 'security-fundamentals',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final items = [
        _item('item-1', 'Concept One'),
        _item('item-2', 'Concept Two'),
      ];
      final service = _FakeDiagnosticService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            targetDetailProvider('target-1')
                .overrideWith((ref) => Future.value(target)),
            diagnosticItemsProvider('version-1')
                .overrideWith((ref) => Future.value(items)),
            diagnosticAssessmentServiceProvider.overrideWithValue(service),
            learnerIdProvider.overrideWith((ref) => 'user-1'),
          ],
          child: const MaterialApp(
            home: DiagnosticAssessmentScreen(
              targetId: 'target-1',
              targetVersionId: 'version-1',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 2'), findsOneWidget);
      expect(find.text('Canonical prompt item-1'), findsOneWidget);
      expect(find.text('Concept One'), findsOneWidget);

      await tester.tap(find.text('Answer A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Question 2 of 2'), findsOneWidget);
      expect(find.text('Canonical prompt item-2'), findsOneWidget);

      await tester.tap(find.text('Answer A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete Diagnostic'));
      await tester.pumpAndSettle();

      expect(find.text('Diagnostic Results'), findsOneWidget);
      expect(service.lastTargetVersionId, 'version-1');
      expect(service.lastItemIds, ['item-1', 'item-2']);
    },
  );
}

DiagnosticAssessmentItem _item(String id, String conceptName) {
  return DiagnosticAssessmentItem(
    item: AssessmentItem(
      id: id,
      interactionType: AssessmentInteractionType.singleChoice,
      prompt: 'Canonical prompt $id',
      responseSpec: const {
        'options': ['Answer A', 'Answer B'],
      },
      scoringSpec: const {'correct_index': 0},
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    concepts: [
      DiagnosticConceptRef(
        conceptId: 'concept-$id',
        conceptName: conceptName,
      ),
    ],
  );
}

class _FakeDiagnosticService extends DiagnosticAssessmentService {
  _FakeDiagnosticService() : super(supabase: FakeSupabaseClient());

  String? lastTargetVersionId;
  List<String> lastItemIds = const [];

  @override
  Future<DiagnosticAssessmentReport> evaluateDiagnosticSession({
    required String userId,
    required String targetId,
    required String targetTitle,
    required String targetVersionId,
    required List<DiagnosticAssessmentItem> items,
    required List<DiagnosticAnswerSubmission> submissions,
  }) async {
    lastTargetVersionId = targetVersionId;
    lastItemIds = items.map((entry) => entry.item.id).toList();
    return DiagnosticAssessmentReport(
      id: 'report-1',
      targetId: targetId,
      targetTitle: targetTitle,
      targetVersionId: targetVersionId,
      completedAt: DateTime(2026),
      totalQuestions: items.length,
      correctQuestions: items.length,
      partialQuestions: 0,
      overallEvidenceScore: 1.0,
      evidenceBand: DiagnosticEvidenceBand.strongEvidence,
      conceptEvaluations: const [],
      reinforcementPriorities: const [],
      strongEvidenceConcepts: const [],
      evidencePersisted: true,
    );
  }
}
