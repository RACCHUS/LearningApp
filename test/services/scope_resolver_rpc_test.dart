import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/services/scope_resolver.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../mocks/supabase_mocks.mocks.dart';
import '../test_helpers/fake_supabase_client.dart';

class FakeRpcFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _value;
  FakeRpcFilterBuilder(this._value);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return Future.value(_value).then(onValue, onError: onError);
  }
}

void main() {
  group('ScopeResolver RPC Resolution (ARCH-2, PERF-8)', () {
    final testContext = LearningContext(
      id: 'ctx-fast-01',
      userId: 'user-fast-01',
      label: 'Security+ Scope',
      rootType: ContextRootType.target,
      rootId: '77777777-7777-4000-8000-777777777777',
      targetVersionId: '88888888-8888-4000-8000-888888888888',
      scopeMode: ScopeMode.coreOnly,
      lastActiveAt: DateTime.now(),
    );

    test('parses fast server-side resolve_scope RPC result correctly', () async {
      final mockResult = {
        'context_id': 'ctx-fast-01',
        'core_concept_ids': ['concept-crypto-aes', 'concept-crypto-rsa'],
        'supporting_concept_ids': ['concept-hash-sha256'],
        'related_concept_ids': <String>[],
        'curriculum_node_ids': ['node-sec-01', 'node-sec-02'],
        'ordered_activities': [
          {
            'activity_id': 'node-sec-01',
            'kind': 'lesson',
            'source': 'official',
            'is_required': true,
            'curriculum_node_id': 'node-sec-01',
            'curriculum_order': 1,
            'activity_order': 1,
            'role': 'core',
            'title': 'Cryptography Foundations',
            'estimated_minutes': 15,
          }
        ],
        'question_ids': ['q-01', 'q-02'],
        'term_ids': <String>[],
        'flashcard_ids': <String>[],
        'resolved_at': DateTime.now().toIso8601String(),
        'config_hash': 'v2:test-hash',
      };

      final client = MockSupabaseClient();
      when(client.rpc('resolve_scope', params: anyNamed('params')))
          .thenAnswer((_) => FakeRpcFilterBuilder(mockResult));

      final resolver = ScopeResolver(supabase: client);
      final scope = await resolver.resolveScope(testContext);

      expect(scope.contextId, 'ctx-fast-01');
      expect(scope.coreConceptIds, containsAll(['concept-crypto-aes', 'concept-crypto-rsa']));
      expect(scope.supportingConceptIds, contains('concept-hash-sha256'));
      expect(scope.curriculumNodeIds, containsAll(['node-sec-01', 'node-sec-02']));
      expect(scope.orderedActivities.length, 1);
      expect(scope.orderedActivities.first.title, 'Cryptography Foundations');
      expect(scope.questionIds, containsAll(['q-01', 'q-02']));
    });

    test('falls back to the client cascade when resolve_scope RPC throws', () async {
      // Previously the cascade hit an unstubbed mock and crashed, and the
      // final safety net returned an empty scope, so this test could not tell
      // a working fallback from a broken one. Now the cascade has data and the
      // test asserts its result.
      final client = FakeSupabaseClient()
        ..rpcHandler = (fn, {params}) {
          throw const PostgrestException(message: 'Simulated RPC failure');
        }
        ..setTableData('curriculum_nodes', [
          {'id': 'node-a', 'target_version_id': testContext.targetVersionId, 'title': 'Domain A', 'sort_order': 1},
          {'id': 'node-other', 'target_version_id': 'another-version', 'title': 'Elsewhere', 'sort_order': 1},
        ])
        ..setTableData('curriculum_node_concepts', [
          {'curriculum_node_id': 'node-a', 'concept_id': 'concept-core', 'relevance': 'core'},
          {'curriculum_node_id': 'node-a', 'concept_id': 'concept-related', 'relevance': 'related'},
          {'curriculum_node_id': 'node-other', 'concept_id': 'concept-elsewhere', 'relevance': 'core'},
        ]);

      final scope = await ScopeResolver(supabase: client).resolveScope(testContext);

      expect(scope.contextId, 'ctx-fast-01');
      expect(scope.curriculumNodeIds, ['node-a']);
      expect(scope.coreConceptIds, ['concept-core']);
      expect(scope.relatedConceptIds, ['concept-related']);
    });
  });
}
