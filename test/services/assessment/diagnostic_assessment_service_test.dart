import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment/diagnostic_assessment.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/services/assessment/diagnostic_assessment_service.dart';
import 'package:learning_pwa/services/concept_evidence_service.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';
import '../../test_helpers/fake_supabase_client.dart';

void main() {
  group('DiagnosticAssessmentService canonical content', () {
    test('selects only persisted canonical items and never fabricates fallback questions',
        () async {
      final fake = _canonicalDiagnosticClient(itemCount: 6);
      final service = DiagnosticAssessmentService(supabase: fake);

      final items = await service.generatePreAssessment(
        targetId: 'target-1',
        targetVersionId: 'version-1',
      );

      expect(items, hasLength(6));
      expect(
        items.map((entry) => entry.item.id),
        everyElement(startsWith('item-')),
      );
      expect(
        items.map((entry) => entry.item.prompt),
        everyElement(startsWith('Canonical question')),
      );
      expect(
        items.map((entry) => entry.primaryConcept.conceptId).toSet(),
        hasLength(3),
      );
    });

    test('fails closed when canonical assessment coverage is insufficient',
        () async {
      final fake = _canonicalDiagnosticClient(itemCount: 5);
      final service = DiagnosticAssessmentService(supabase: fake);

      expect(
        () => service.generatePreAssessment(targetId: 'target-1', targetVersionId: 'version-1'),
        throwsA(isA<DiagnosticUnavailableException>()),
      );
    });

    test('fails closed when the version belongs to a different target', () async {
      final fake = _canonicalDiagnosticClient(itemCount: 6);
      final service = DiagnosticAssessmentService(supabase: fake);

      final availability = await service.getAvailability(
        targetId: 'target-other',
        targetVersionId: 'version-1',
      );

      expect(availability.isAvailable, isFalse);
      expect(availability.isPublishedVersion, isFalse);
      expect(
        () => service.generatePreAssessment(
          targetId: 'target-other',
          targetVersionId: 'version-1',
        ),
        throwsA(isA<DiagnosticUnavailableException>()),
      );
    });

    test('fails closed for a draft target version', () async {
      final fake = _canonicalDiagnosticClient(
        itemCount: 6,
        versionStatus: 'draft',
      );
      final service = DiagnosticAssessmentService(supabase: fake);

      final availability = await service.getAvailability(targetId: 'target-1', targetVersionId: 'version-1');
      expect(availability.isAvailable, isFalse);
      expect(availability.isPublishedVersion, isFalse);

      expect(
        () => service.generatePreAssessment(targetVersionId: 'version-1'),
        throwsA(isA<DiagnosticUnavailableException>()),
      );
    });

    test('scores with canonical evaluator and records assessment-item evidence',
        () async {
      final evidence = _CapturingEvidenceService();
      final service = DiagnosticAssessmentService(
        supabase: FakeSupabaseClient(),
        evidenceService: evidence,
      );
      final items = [
        _diagnosticItem(
          id: 'item-a',
          conceptId: 'concept-a',
          conceptName: 'Concept A',
          correctIndex: 0,
        ),
        _diagnosticItem(
          id: 'item-b',
          conceptId: 'concept-b',
          conceptName: 'Concept B',
          correctIndex: 1,
        ),
      ];

      final report = await service.evaluateDiagnosticSession(
        userId: 'user-1',
        targetId: 'target-1',
        targetTitle: 'Target',
        targetVersionId: 'version-1',
        items: items,
        submissions: const [
          DiagnosticAnswerSubmission(itemId: 'item-a', response: 0),
          DiagnosticAnswerSubmission(itemId: 'item-b', response: 0),
        ],
      );

      expect(report.correctQuestions, 1);
      expect(report.overallEvidenceScore, 0.5);
      expect(report.evidenceBand, DiagnosticEvidenceBand.needsReinforcement);
      expect(report.evidencePersisted, isTrue);
      expect(evidence.itemIds, ['item-a', 'item-b']);
      expect(evidence.values, [1.0, 0.0]);
    });

    test('remedial creation propagates persistence failure instead of faking success',
        () async {
      final service = DiagnosticAssessmentService(
        supabase: FakeSupabaseClient(),
        studySetService: _FailingStudySetService(),
      );

      expect(
        () => service.generateRemedialStudySet(
          report: _reportWithGap(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('remedial success returns the persisted study set id', () async {
      final service = DiagnosticAssessmentService(
        supabase: FakeSupabaseClient(),
        studySetService: _SuccessfulStudySetService(),
      );

      final report = await service.generateRemedialStudySet(
        report: _reportWithGap(),
      );

      expect(report.remedialSetCreated, isTrue);
      expect(report.remedialSetId, 'saved-set-1');
      expect(report.remedialItemCount, 1);
    });
  });

  test('assessment-item evidence resolves assessment_item_concepts', () async {
    final fake = FakeSupabaseClient();
    fake.setTableData('assessment_item_concepts', [
      {
        'assessment_item_id': 'item-1',
        'concept_id': 'concept-1',
        'weight': 0.75,
      },
    ]);
    fake.setTableData('user_concept_state', []);

    final recorded = await ConceptEvidenceService(supabase: fake)
        .recordAssessmentItemEvidence(
      userId: 'user-1',
      assessmentItemId: 'item-1',
      evidenceValue: 1.0,
    );

    expect(recorded, isTrue);
    expect(
      fake.insertedRecords,
      contains(
        allOf(
          containsPair('user_id', 'user-1'),
          containsPair('concept_id', 'concept-1'),
          containsPair('weighted_total', 0.75),
          containsPair('weighted_correct', 0.75),
        ),
      ),
    );
  });
}

FakeSupabaseClient _canonicalDiagnosticClient({
  required int itemCount,
  String versionStatus = 'published',
}) {
  final fake = FakeSupabaseClient();
  fake.setTableData('target_versions', [
    {'id': 'version-1', 'target_id': 'target-1', 'status': versionStatus},
  ]);
  fake.setTableData('curriculum_nodes', [
    {'id': 'node-1', 'target_version_id': 'version-1'},
    {'id': 'node-2', 'target_version_id': 'version-1'},
    {'id': 'node-3', 'target_version_id': 'version-1'},
  ]);
  fake.setTableData('curriculum_node_concepts', [
    {
      'curriculum_node_id': 'node-1',
      'concept_id': 'concept-1',
      'weight': 1.0,
      'relevance': 'core',
    },
    {
      'curriculum_node_id': 'node-2',
      'concept_id': 'concept-2',
      'weight': 1.0,
      'relevance': 'core',
    },
    {
      'curriculum_node_id': 'node-3',
      'concept_id': 'concept-3',
      'weight': 1.0,
      'relevance': 'core',
    },
  ]);
  fake.setTableData(
    'assessment_items',
    List.generate(itemCount, (index) {
      return {
        'id': 'item-${index + 1}',
        'origin_target_version_id': 'version-1',
        'interaction_type': 'single_choice',
        'prompt': 'Canonical question ${index + 1}',
        'response_spec': {
          'options': ['Correct', 'Distractor'],
        },
        'scoring_spec': {'correct_index': 0},
        'difficulty': index % 2 == 0 ? 'beginner' : 'intermediate',
      };
    }),
  );
  fake.setTableData(
    'assessment_item_concepts',
    List.generate(itemCount, (index) {
      return {
        'assessment_item_id': 'item-${index + 1}',
        'concept_id': 'concept-${(index % 3) + 1}',
        'role': 'primary',
        'weight': 1.0,
      };
    }),
  );
  fake.setTableData('knowledge_concepts', [
    {'id': 'concept-1', 'name': 'Concept One'},
    {'id': 'concept-2', 'name': 'Concept Two'},
    {'id': 'concept-3', 'name': 'Concept Three'},
  ]);
  return fake;
}

DiagnosticAssessmentItem _diagnosticItem({
  required String id,
  required String conceptId,
  required String conceptName,
  required int correctIndex,
}) {
  return DiagnosticAssessmentItem(
    item: AssessmentItem(
      id: id,
      interactionType: AssessmentInteractionType.singleChoice,
      prompt: 'Question $id',
      responseSpec: const {
        'options': ['Option A', 'Option B'],
      },
      scoringSpec: {'correct_index': correctIndex},
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    concepts: [
      DiagnosticConceptRef(
        conceptId: conceptId,
        conceptName: conceptName,
      ),
    ],
  );
}

DiagnosticAssessmentReport _reportWithGap() {
  const gap = DiagnosticConceptEvaluation(
    conceptId: 'concept-gap',
    conceptName: 'Gap Concept',
    testedItemsCount: 2,
    weightedEvidenceEarned: 0.0,
    weightedEvidencePossible: 2.0,
    evidenceRatio: 0.0,
    evidenceBand: DiagnosticEvidenceBand.needsReinforcement,
    confidence: ConceptConfidence.medium,
    isReinforcementPriority: true,
  );

  return DiagnosticAssessmentReport(
    id: 'report-1',
    targetId: 'target-1',
    targetTitle: 'Target',
    targetVersionId: 'version-1',
    completedAt: DateTime(2026),
    totalQuestions: 6,
    correctQuestions: 2,
    partialQuestions: 0,
    overallEvidenceScore: 1 / 3,
    evidenceBand: DiagnosticEvidenceBand.needsReinforcement,
    conceptEvaluations: const [gap],
    reinforcementPriorities: const [gap],
    strongEvidenceConcepts: const [],
    evidencePersisted: true,
  );
}

class _CapturingEvidenceService extends ConceptEvidenceService {
  _CapturingEvidenceService() : super(supabase: FakeSupabaseClient());

  final List<String> itemIds = [];
  final List<double> values = [];

  @override
  Future<bool> recordAssessmentItemEvidence({
    required String userId,
    required String assessmentItemId,
    required double evidenceValue,
  }) async {
    itemIds.add(assessmentItemId);
    values.add(evidenceValue);
    return true;
  }
}

class _FailingStudySetService extends SavedStudySetService {
  _FailingStudySetService() : super(supabase: FakeSupabaseClient());

  @override
  Future<SavedStudySet> createStudySet({
    required String title,
    String? description,
    List<String> lessonIds = const [],
    List<String> questionIds = const [],
    List<String> termIds = const [],
    List<String> conceptIds = const [],
    List<String> tags = const [],
  }) async {
    throw StateError('persistence failed');
  }
}

class _SuccessfulStudySetService extends SavedStudySetService {
  _SuccessfulStudySetService() : super(supabase: FakeSupabaseClient());

  @override
  Future<SavedStudySet> createStudySet({
    required String title,
    String? description,
    List<String> lessonIds = const [],
    List<String> questionIds = const [],
    List<String> termIds = const [],
    List<String> conceptIds = const [],
    List<String> tags = const [],
  }) async {
    return SavedStudySet(
      id: 'saved-set-1',
      userId: 'user-1',
      title: title,
      description: description,
      conceptIds: conceptIds,
      tags: tags,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }
}
