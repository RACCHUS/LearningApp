import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/exam_reference_manifest.dart';
import 'package:learning_pwa/models/assessment/diagnostic_assessment.dart';
import 'package:learning_pwa/services/assessment/diagnostic_assessment_service.dart';
import 'package:learning_pwa/services/assessment/exam_evaluation_service.dart';
import 'package:learning_pwa/services/assessment/exam_part_curriculum_scope.dart';
import 'package:learning_pwa/services/assessment/mock_exam_generator_service.dart';
import 'package:learning_pwa/services/target_readiness_service.dart';

import '../../test_helpers/fake_supabase_client.dart';

const _version = 'version-scoped';
const _metadata = <String, dynamic>{
  'exam_preparation': {
    'schema_version': 1,
    'exam_parts': [
      {
        'key': 'part_a',
        'display_name': 'Synthetic Part A',
        'curriculum_root_node_id': 'root-a',
      },
      {
        'key': 'part_b',
        'display_name': 'Synthetic Part B',
        'curriculum_root_node_id': 'root-b',
      },
    ],
  },
};

List<Map<String, dynamic>> _nodes() {
  final rows = <Map<String, dynamic>>[];
  for (final part in ['a', 'b']) {
    rows.add({
      'id': 'root-$part', 'target_version_id': _version,
      'parent_id': null, 'node_type': 'exam_part',
    });
    rows.add({
      'id': 'domain-$part', 'target_version_id': _version,
      'parent_id': 'root-$part', 'node_type': 'domain',
      'code': part.toUpperCase(), 'title': 'Part $part',
      'weight': 1.0, 'sort_order': 1,
    });
    for (var i = 1; i <= 3; i++) {
      rows.add({
        'id': 'obj-$part-$i', 'target_version_id': _version,
        'parent_id': 'domain-$part', 'node_type': 'objective',
      });
    }
  }
  return rows;
}

FakeSupabaseClient _client({bool withMixedItem = false}) {
  final fake = FakeSupabaseClient();
  fake.setTableData('target_versions', [
    {
      'id': _version, 'target_id': 'target-a',
      'status': 'published', 'version_code': 'SYNTH',
      'title': 'Synthetic Practice', 'metadata': _metadata,
    }
  ]);
  fake.setTableData('curriculum_nodes', _nodes());
  final nodeConcepts = <Map<String, dynamic>>[];
  for (final part in ['a', 'b']) {
    for (var i = 1; i <= 3; i++) {
      nodeConcepts.add({
        'curriculum_node_id': 'obj-$part-$i',
        'concept_id': 'concept-$part-$i',
        'relevance': 'core', 'weight': 1.0,
      });
    }
    // One globally transferable concept belongs to both parts; it is NOT
    // enough, alone, to prove a question belongs to either part.
    nodeConcepts.add({
      'curriculum_node_id': 'obj-$part-1',
      'concept_id': 'shared', 'relevance': 'core', 'weight': 1.0,
    });
  }
  fake.setTableData('curriculum_node_concepts', nodeConcepts);
  final items = <Map<String, dynamic>>[];
  final mappings = <Map<String, dynamic>>[];
  for (final part in ['a', 'b']) {
    for (var i = 0; i < 6; i++) {
      final id = 'item-$part-$i';
      items.add({
        'id': id, 'origin_target_version_id': _version,
        'interaction_type': 'single_choice',
        'prompt': 'Question $id',
        'response_spec': {'options': ['A', 'B']},
        'scoring_spec': {'correct_index': 0},
        'difficulty': 'intermediate',
      });
      mappings.add({
        'assessment_item_id': id,
        'concept_id': 'concept-$part-${(i % 3) + 1}',
        'role': 'primary', 'weight': 1.0,
      });
    }
  }
  items.add({
    'id': 'ambiguous-item', 'origin_target_version_id': _version,
    'interaction_type': 'single_choice', 'prompt': 'Shared concept',
    'response_spec': {'options': ['A', 'B']},
    'scoring_spec': {'correct_index': 0},
    'difficulty': 'intermediate',
  });
  mappings.add({
    'assessment_item_id': 'ambiguous-item', 'concept_id': 'shared',
    'role': 'primary', 'weight': 1.0,
  });
  if (withMixedItem) {
    mappings.add({
      'assessment_item_id': 'item-a-0',
      'concept_id': 'concept-b-1',
      'role': 'supporting',
      'weight': 0.5,
    });
  }
  fake.setTableData('assessment_items', items);
  fake.setTableData('assessment_item_concepts', mappings);
  fake.setTableData('knowledge_concepts', [
    for (final part in ['a', 'b'])
      for (var i = 1; i <= 3; i++)
        {'id': 'concept-$part-$i', 'name': 'Concept $part $i'},
    {'id': 'shared', 'name': 'Shared concept'},
  ]);
  return fake;
}

void main() {
  group('EXM-03 part curriculum contract', () {
    final profile = ExamPreparationProfile.fromTargetVersionMetadata(
      targetVersionId: _version, metadata: _metadata,
    )!;

    test('resolves only the selected subtree and preserves part identity', () {
      final scope = ExamPartCurriculumScope.fromRows(
        targetVersionId: _version, examPartKey: 'part_a',
        profile: profile, nodes: _nodes(),
      );
      expect(scope.examPartKey, 'part_a');
      expect(scope.rootNodeId, 'root-a');
      expect(scope.nodeIds,
          containsAll(['root-a', 'domain-a', 'obj-a-1']));
      expect(scope.nodeIds, isNot(contains('obj-b-1')));
      expect(scope.outsideNodeIds, contains('domain-b'));
    });

    test('unknown part, missing root and cross-version profile fail closed', () {
      expect(
        () => ExamPartCurriculumScope.fromRows(
          targetVersionId: _version, examPartKey: 'unknown',
          profile: profile, nodes: _nodes(),
        ),
        throwsStateError,
      );
      expect(
        () => ExamPartCurriculumScope.fromRows(
          targetVersionId: _version, examPartKey: 'part_a',
          profile: profile,
          nodes: _nodes().where((row) => row['id'] != 'root-a').toList(),
        ),
        throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
      );
      expect(
        () => ExamPartCurriculumScope.fromRows(
          targetVersionId: 'different-version', examPartKey: 'part_a',
          profile: profile, nodes: _nodes(),
        ),
        throwsStateError,
      );
    });

    test('cyclic and duplicated curriculum identities are rejected', () {
      final cycle = _nodes();
      cycle.first['parent_id'] = 'obj-a-1';
      expect(
        () => ExamPartCurriculumScope.fromRows(
          targetVersionId: _version, examPartKey: 'part_a',
          profile: profile, nodes: cycle,
        ),
        throwsFormatException,
      );
      expect(
        () => ExamPartCurriculumScope.fromRows(
          targetVersionId: _version, examPartKey: 'part_a',
          profile: profile, nodes: [..._nodes(), _nodes().first],
        ),
        throwsFormatException,
      );
    });

    test('resolver refuses absent, invalid, or mismatched metadata', () async {
      final fake = _client();
      final resolver = ExamPartCurriculumScopeResolver(client: fake);
      final scope = await resolver.resolve(
        targetVersionId: _version, examPartKey: 'part_b',
      );
      expect(scope.nodeIds, contains('domain-b'));
      expect(scope.nodeIds, isNot(contains('domain-a')));
      expect(
        () => resolver.resolve(
          targetVersionId: _version, examPartKey: 'does_not_exist',
        ),
        throwsStateError,
      );
      expect(
        () => resolver.resolve(
          targetVersionId: 'unrelated', examPartKey: 'part_a',
        ),
        throwsStateError,
      );
    });
  });

  group('EXM-03 scoped mock, diagnostic and readiness', () {
    test('mock exam never borrows other-part or ambiguous questions', () async {
      final service = MockExamGeneratorService(
        supabase: _client(), random: Random(11),
      );
      final session = await service.generateExamSession(
        targetVersionId: _version, examPartKey: 'part_a',
        questionCount: 5,
      );
      expect(session.items, hasLength(5));
      expect(session.items.map((i) => i.id),
          everyElement(startsWith('item-a-')));
      expect(session.blueprint.examPartKey, 'part_a');
      expect(session.blueprint.curriculumRootNodeId, 'root-a');
      expect(session.blueprint.domainWeights.map((d) => d.domainId),
          ['domain-a']);
      expect(session.blueprint.toJson()['exam_part_key'], 'part_a');
      final report = ExamEvaluationService().evaluateExam(session);
      expect(report.examPartKey, 'part_a');

      expect(
        () => service.generateExamSession(
          targetVersionId: _version, examPartKey: 'part_a',
          questionCount: 7,
        ),
        throwsStateError,
      );
    });

    test('preloaded whole-target or wrong-part mock blueprint is rejected',
        () async {
      final service = MockExamGeneratorService(
        supabase: _client(), random: Random(7),
      );
      final other = await service.loadBlueprint(
        _version, examPartKey: 'part_b',
      );
      expect(
        () => service.generateExamSession(
          targetVersionId: _version, examPartKey: 'part_a',
          preloadedBlueprint: other, questionCount: 1,
        ),
        throwsStateError,
      );
    });

    test('diagnostic coverage never counts shared or other-part items',
        () async {
      final service = DiagnosticAssessmentService(supabase: _client());
      final availability = await service.getAvailability(
        targetId: 'target-a', targetVersionId: _version,
        examPartKey: 'part_a',
      );
      expect(availability.availableItemCount, 6);
      expect(availability.representedConceptCount, 3);
      expect(availability.isAvailable, isTrue);
      final a = await service.generatePreAssessment(
        targetId: 'target-a', targetVersionId: _version,
        examPartKey: 'part_a',
      );
      final b = await service.generatePreAssessment(
        targetId: 'target-a', targetVersionId: _version,
        examPartKey: 'part_b',
      );
      expect(a, hasLength(6));
      expect(b, hasLength(6));
      expect(a.map((i) => i.item.id), everyElement(startsWith('item-a-')));
      expect(b.map((i) => i.item.id), everyElement(startsWith('item-b-')));
    });

    test('diagnostic rejects a mixed-part item rather than masking its B link',
        () async {
      final service = DiagnosticAssessmentService(
        supabase: _client(withMixedItem: true),
      );
      final a = await service.getAvailability(
        targetId: 'target-a', targetVersionId: _version,
        examPartKey: 'part_a',
      );
      expect(a.availableItemCount, 5);
      expect(a.isAvailable, isFalse);
      expect(
        () => service.generatePreAssessment(
          targetId: 'target-a', targetVersionId: _version,
          examPartKey: 'part_a',
        ),
        throwsA(isA<DiagnosticUnavailableException>()),
      );
    });

    test('shared global concept can count toward part readiness, not other-part',
        () async {
      final service = TargetReadinessService(supabase: _client());
      final a = await service.evaluateTargetReadiness(
        userId: '', targetVersionId: _version, examPartKey: 'part_a',
      );
      final b = await service.evaluateTargetReadiness(
        userId: '', targetVersionId: _version, examPartKey: 'part_b',
      );
      final whole = await service.evaluateTargetReadiness(
        userId: '', targetVersionId: _version,
      );
      expect(a.totalCoreConcepts, 4); // Part A + transferable shared
      expect(b.totalCoreConcepts, 4);
      expect(whole.totalCoreConcepts, 7);
      expect(a.assessedConceptsCount, 0);
      expect(
        () => service.evaluateTargetReadiness(
          userId: '', targetVersionId: _version,
          examPartKey: 'unknown',
        ),
        throwsStateError,
      );
    });

    test('scoped evaluation pins part identity and canonical questions', () async {
      final fake = _client();
      final service = DiagnosticAssessmentService(supabase: fake);
      final original = await service.generatePreAssessment(
        targetId: 'target-a', targetVersionId: _version,
        examPartKey: 'part_a',
      );
      final report = await service.evaluatePartDiagnosticSession(
        userId: '',
        targetId: 'target-a',
        targetTitle: 'Synthetic Target',
        targetVersionId: _version,
        examPartKey: 'part_a',
        items: original,
        submissions: [
          for (final entry in original)
            DiagnosticAnswerSubmission(
              itemId: entry.item.id,
              response: 0,
            ),
        ],
      );
      expect(report.examPartKey, 'part_a');
      expect(report.curriculumRootNodeId, 'root-a');
      expect(report.learnerId, '');
      expect(report.correctQuestions, 6);
      expect(report.totalQuestions, 6);
      expect(report.evidencePersisted, isFalse); // guest, no owner writes
      final copy = report.copyWith(
        remedialSetCreated: true,
        remedialSetId: 'remedial-1',
      );
      expect(copy.examPartKey, 'part_a');
      expect(copy.curriculumRootNodeId, 'root-a');
      expect(copy.remedialSetId, 'remedial-1');
    });

    test('stale, duplicated or foreign part items fail before evidence writes',
        () async {
      final fake = _client();
      final service = DiagnosticAssessmentService(supabase: fake);
      final a = await service.generatePreAssessment(
        targetId: 'target-a', targetVersionId: _version,
        examPartKey: 'part_a',
      );
      final b = await service.generatePreAssessment(
        targetId: 'target-a', targetVersionId: _version,
        examPartKey: 'part_b',
      );
      Future<void> expectRejected(
        List<DiagnosticAssessmentItem> selection,
      ) async {
        final before = fake.insertedRecords.length;
        await expectLater(
          service.evaluatePartDiagnosticSession(
            userId: 'user-1',
            targetId: 'target-a', targetTitle: 'Synthetic Target',
            targetVersionId: _version, examPartKey: 'part_a',
            items: selection,
            submissions: [
              for (final entry in selection)
                DiagnosticAnswerSubmission(
                    itemId: entry.item.id, response: 0),
            ],
          ),
          throwsA(isA<StateError>()),
        );
        expect(fake.insertedRecords.length, before);
      }

      await expectRejected([...a.take(5), b.first]);
      await expectRejected([...a.take(5), a.first]); // duplicate ID
      final changed = DiagnosticAssessmentItem(
        item: a.first.item.copyWith(
          scoringSpec: const {'correct_index': 1},
        ),
        concepts: a.first.concepts,
      );
      await expectRejected([changed, ...a.skip(1)]);
      final modifiedConcept = DiagnosticAssessmentItem(
        item: a.first.item,
        concepts: [
          const DiagnosticConceptRef(
              conceptId: 'concept-b-1', conceptName: 'Foreign'),
        ],
      );
      await expectRejected([modifiedConcept, ...a.skip(1)]);
    });

    test('part evaluation refuses insufficient currently published coverage',
        () async {
      final fake = _client(withMixedItem: true);
      final service = DiagnosticAssessmentService(supabase: fake);
      final wholeService = DiagnosticAssessmentService(supabase: _client());
      final selected = await wholeService.generatePreAssessment(
        targetId: 'target-a', targetVersionId: _version,
        examPartKey: 'part_a',
      );
      await expectLater(
        service.evaluatePartDiagnosticSession(
          userId: 'user-1', targetId: 'target-a',
          targetTitle: 'Synthetic Target', targetVersionId: _version,
          examPartKey: 'part_a', items: selected,
          submissions: [
            for (final entry in selected)
              DiagnosticAnswerSubmission(
                itemId: entry.item.id, response: 0),
          ],
        ),
        throwsA(isA<DiagnosticUnavailableException>()),
      );
      expect(fake.insertedRecords, isEmpty);
    });
  });
}
