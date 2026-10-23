import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_pwa/models/assessment/diagnostic_assessment.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/providers/diagnostic_assessment_provider.dart';
import 'package:learning_pwa/providers/exam_part_progress_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/services/assessment/exam_part_curriculum_scope.dart';

import '../test_helpers/fake_supabase_client.dart';

const _targetId = 'target-a';
const _versionId = 'version-a';
const _partKey = 'part_a';
const _rawProfile = {
  'exam_preparation': {
    'schema_version': 1,
    'exam_parts': [
      {
        'key': _partKey,
        'display_name': 'Part A',
        'curriculum_root_node_id': 'root-a',
      },
    ],
  },
};

FakeSupabaseClient _client({
  String targetId = _targetId,
  String status = 'published',
}) {
  final fake = FakeSupabaseClient();
  fake.setTableData('target_versions', [
    {
      'id': _versionId,
      'target_id': targetId,
      'status': status,
      'metadata': _rawProfile,
    },
  ]);
  fake.setTableData('curriculum_nodes', [
    {'id': 'root-a', 'target_version_id': _versionId, 'parent_id': null},
    {'id': 'objective-a', 'target_version_id': _versionId,
     'parent_id': 'root-a'},
    {'id': 'root-b', 'target_version_id': _versionId, 'parent_id': null},
    {'id': 'objective-b', 'target_version_id': _versionId,
     'parent_id': 'root-b'},
  ]);
  return fake;
}

void main() {
  group('EXM-03 part Progress projection authorization', () {
    test('profile resolves only matching published target and version',
        () async {
      final service = ExamPartProfileService(supabase: _client());
      final profile = await service.load((
        targetId: _targetId,
        targetVersionId: _versionId,
      ));
      expect(profile!.findPart(_partKey)!.curriculumRootNodeId, 'root-a');
      await expectLater(
        service.load((
          targetId: 'unrelated-target',
          targetVersionId: _versionId,
        )),
        throwsStateError,
      );
      await expectLater(
        ExamPartProfileService(supabase: _client(status: 'draft'))
            .load((targetId: _targetId, targetVersionId: _versionId)),
        throwsStateError,
      );
      await expectLater(
        service.load((targetId: _targetId, targetVersionId: 'version-b')),
        throwsStateError,
      );
    });

    test('scope, part, owner and version are all checked before projection',
        () async {
      final fake = _client();
      final learner = StateProvider<String>((ref) => 'learner-a');
      const readiness = TargetReadiness(
        targetVersionId: _versionId,
        band: TargetReadinessBand.notYetAssessed,
        score: 0,
        totalCoreConcepts: 2,
        assessedConceptsCount: 0,
        bandDistribution: {},
      );
      const diagnostic = DiagnosticAvailability(
        targetVersionId: _versionId,
        isPublishedVersion: true,
        availableItemCount: 6,
        representedConceptCount: 3,
        minimumItemCount: 6,
        minimumConceptCount: 3,
      );
      final container = ProviderContainer(overrides: [
        learnerIdProvider.overrideWith((ref) => ref.watch(learner)),
        examPartProfileServiceProvider.overrideWithValue(
            ExamPartProfileService(supabase: fake)),
        examPartScopeResolverProvider.overrideWithValue(
            ExamPartCurriculumScopeResolver(client: fake)),
        examPartReadinessProvider((
          targetVersionId: _versionId,
          examPartKey: _partKey,
        )).overrideWith((ref) async => readiness),
        examPartDiagnosticAvailabilityProvider((
          targetId: _targetId,
          targetVersionId: _versionId,
          examPartKey: _partKey,
        )).overrideWith((ref) async => diagnostic),
      ]);
      addTearDown(container.dispose);
      final key = (
        targetId: _targetId,
        targetVersionId: _versionId,
        examPartKey: _partKey,
        learnerId: 'learner-a',
      );
      final snapshot = await container.read(examPartProgressProvider(key).future);
      expect(snapshot.rootNodeId, 'root-a');
      expect(snapshot.knowledge.totalCoreConcepts, 2);
      expect(snapshot.hasVerifiedPartAttemptHistory, isFalse);
      expect(snapshot.nextStep.canLaunchDiagnostic, isTrue);

      final badKey = (
        targetId: _targetId,
        targetVersionId: _versionId,
        examPartKey: 'part_b',
        learnerId: 'learner-a',
      );
      await expectLater(
        container.read(examPartProgressProvider(badKey).future),
        throwsStateError,
      );
      final wrongTarget = (
        targetId: 'target-b',
        targetVersionId: _versionId,
        examPartKey: _partKey,
        learnerId: 'learner-a',
      );
      await expectLater(
        container.read(examPartProgressProvider(wrongTarget).future),
        throwsStateError,
      );
      final wrongOwner = (
        targetId: _targetId,
        targetVersionId: _versionId,
        examPartKey: _partKey,
        learnerId: 'learner-b',
      );
      await expectLater(
        container.read(examPartProgressProvider(wrongOwner).future),
        throwsStateError,
      );
      container.read(learner.notifier).state = 'learner-b';
      await expectLater(
        container.read(examPartProgressProvider(key).future),
        throwsStateError,
      );
    });
  });
}
