import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/core/hive_type_ids.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/scope.dart';
import 'package:learning_pwa/services/scope_resolver.dart';
import '../test_helpers/fake_supabase_client.dart';

void main() {
  const testPath = 'build/test_hive_scope_resolver';
  late Box<ResolvedScope> scopeBox;
  late Box<ContextCurriculumSnapshot> snapshotBox;

  setUpAll(() {
    final dir = Directory(testPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    Hive.init(testPath);
    if (!Hive.isAdapterRegistered(HiveTypeIds.resolvedScopeCache)) {
      Hive.registerAdapter(ResolvedScopeAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.contextCurriculumSnapshot)) {
      Hive.registerAdapter(ContextCurriculumSnapshotAdapter());
    }
  });

  tearDownAll(() {
    final dir = Directory(testPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    scopeBox = await Hive.openBox<ResolvedScope>(
      'scope_${DateTime.now().microsecondsSinceEpoch}',
    );
    snapshotBox = await Hive.openBox<ContextCurriculumSnapshot>(
      'snap_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await scopeBox.close();
    await snapshotBox.close();
  });

  group('ScopeResolver Offline & Cache Strategy (§7.4)', () {
    test('returns cached scope immediately when available', () async {
      final cachedScope = ResolvedScope(
        contextId: 'ctx-hvac',
        coreConceptIds: const {'c-refrigeration', 'c-superheat'},
        supportingConceptIds: const {'c-latent-heat'},
        orderedActivities: const [
          ScopedLearningActivity(
            activityId: 'lesson-101',
            kind: ScopedActivityKind.lesson,
            title: 'Basic Refrigeration',
            curriculumOrder: 1,
          ),
        ],
        resolvedAt: DateTime(2026, 9, 25),
      );

      await scopeBox.put('ctx-hvac', cachedScope);

      final resolver = ScopeResolver(
        scopeBox: scopeBox,
        snapshotBox: snapshotBox,
      );

      final context = LearningContext(
        id: 'ctx-hvac',
        userId: 'u1',
        label: 'Florida AC Class A',
        rootType: ContextRootType.target,
        rootId: 'target-hvac',
        lastActiveAt: DateTime.now(),
      );

      final resolved = await resolver.resolveScope(context);
      expect(resolved.contextId, 'ctx-hvac');
      expect(resolved.coreConceptIds, contains('c-refrigeration'));
      expect(resolved.supportingConceptIds, contains('c-latent-heat'));
      expect(resolved.orderedActivities.first.activityId, 'lesson-101');
      expect(resolved.containsConcept('c-superheat'), isTrue);
      expect(resolved.containsConcept('c-latent-heat'), isTrue);
    });

    test(
      'stores and reads snapshot in snapshotBox for instant outline',
      () async {
        final snapshot = ContextCurriculumSnapshot(
          contextId: 'ctx-hvac',
          targetVersionId: 'ver-2026',
          nodes: const [
            SnapshotNode(
              id: 'node-domain-1',
              title: 'Refrigeration Systems',
              code: 'DOM-01',
              nodeType: 'domain',
              sortOrder: 1,
            ),
            SnapshotNode(
              id: 'node-domain-2',
              parentId: 'node-domain-1',
              title: 'Piping & Line Sizing',
              code: 'DOM-01.1',
              nodeType: 'subdomain',
              sortOrder: 2,
            ),
          ],
          activeFocusId: 'node-domain-1',
          snapshotAt: DateTime(2026, 9, 25),
        );

        await snapshotBox.put('ctx-hvac', snapshot);

        final readSnapshot = snapshotBox.get('ctx-hvac');
        expect(readSnapshot, isNotNull);
        expect(readSnapshot!.targetVersionId, 'ver-2026');
        expect(readSnapshot.nodes.length, 2);
        expect(readSnapshot.nodes.first.code, 'DOM-01');
        expect(readSnapshot.nodes.last.parentId, 'node-domain-1');
        expect(readSnapshot.activeFocusId, 'node-domain-1');
      },
    );

    test(
      'returns safe empty fallback if offline and no cache exists',
      () async {
        final resolver = ScopeResolver(
          scopeBox: scopeBox,
          snapshotBox: snapshotBox,
        );

        final context = LearningContext(
          id: 'ctx-uncached',
          userId: 'u1',
          label: 'Uncached Target',
          rootType: ContextRootType.target,
          rootId: 'target-uncached',
          lastActiveAt: DateTime.now(),
        );

        final resolved = await resolver.resolveScope(context);
        expect(resolved.contextId, 'ctx-uncached');
        expect(resolved.coreConceptIds, isEmpty);
        expect(resolved.orderedActivities, isEmpty);
      },
    );
  });

  group('Scope Filtering and Concept Membership', () {
    test(
      'ScopeMode.coreOnly ignores supporting concepts in active concept scope',
      () {
        final scope = ResolvedScope(
          contextId: 'ctx-1',
          coreConceptIds: const {'c-core-1', 'c-core-2'},
          supportingConceptIds: const {'c-supp-1'},
          relatedConceptIds: const {'c-related-1'},
          resolvedAt: DateTime.now(),
        );

        expect(scope.activeConceptIds, contains('c-core-1'));
        expect(scope.activeConceptIds, contains('c-supp-1'));
        expect(
          scope.activeConceptIds.contains('c-related-1'),
          isFalse,
          reason:
              'Related concepts are excluded from active Learn sequence per §7.1',
        );
      },
    );
  });

  test(
    'study set scope maps legacy concepts without inferring extra items',
    () async {
      final fake = FakeSupabaseClient();
      fake.setTableData('study_sets', [
        {
          'id': 'set-1',
          'title': 'My set',
          'question_ids': ['question-in-set'],
          'term_ids': <String>[],
          'lesson_ids': <String>[],
          'concept_ids': ['legacy-concept'],
        },
      ]);
      fake.setTableData('study_set_flashcards', [
        {'study_set_id': 'set-1', 'flashcard_id': 'flashcard-in-set'},
      ]);
      fake.setTableData('v2_migration_map', [
        {
          'legacy_type': 'legacy_concept',
          'legacy_id': 'legacy-concept',
          'v2_type': 'knowledge_concept',
          'v2_id': 'canonical-concept',
        },
      ]);
      fake.setTableData('question_concepts', [
        {'concept_id': 'canonical-concept', 'question_id': 'outside-question'},
      ]);
      fake.setTableData('flashcard_concepts', [
        {
          'concept_id': 'canonical-concept',
          'flashcard_id': 'outside-flashcard',
        },
      ]);

      final context = LearningContext(
        id: 'ctx-set-1',
        userId: 'user-1',
        label: 'My set',
        rootType: ContextRootType.studySet,
        rootId: 'set-1',
        lastActiveAt: DateTime.now(),
      );
      final scope = await ScopeResolver(supabase: fake).resolveScope(context);

      expect(scope.coreConceptIds, {'canonical-concept'});
      expect(scope.questionIds, {'question-in-set'});
      expect(scope.flashcardIds, {'flashcard-in-set'});
    },
  );
}
