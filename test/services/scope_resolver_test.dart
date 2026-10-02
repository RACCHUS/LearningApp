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

    test('invalidateScope evicts cached scope for context or all contexts', () async {
      final cachedScope1 = ResolvedScope(
        contextId: 'ctx-1',
        resolvedAt: DateTime.now(),
      );
      final cachedScope2 = ResolvedScope(
        contextId: 'ctx-2',
        resolvedAt: DateTime.now(),
      );

      await scopeBox.put('ctx-1', cachedScope1);
      await scopeBox.put('ctx-2', cachedScope2);

      final resolver = ScopeResolver(
        scopeBox: scopeBox,
        snapshotBox: snapshotBox,
      );

      expect(scopeBox.containsKey('ctx-1'), isTrue);
      expect(scopeBox.containsKey('ctx-2'), isTrue);

      await resolver.invalidateScope('ctx-1');
      expect(scopeBox.containsKey('ctx-1'), isFalse);
      expect(scopeBox.containsKey('ctx-2'), isTrue);

      await resolver.invalidateScope();
      expect(scopeBox.containsKey('ctx-2'), isFalse);
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

  group('Personal Curriculum Overlays in Scope (§7.3.1)', () {
    test('old Hive scope JSON reads as official activity and required', () {
      final legacyJson = {
        'activity_id': 'legacy-lesson-1',
        'kind': 'lesson',
        'title': 'Legacy Lesson',
      };
      final activity = ScopedLearningActivity.fromJson(legacyJson);
      expect(activity.source, ScopedActivitySource.official);
      expect(activity.isRequired, isTrue);
    });

    test(
      'focused node plus descendants includes personal lessons but excludes siblings',
      () async {
        final fake = FakeSupabaseClient();
        fake.setTableData('curriculum_nodes', [
          {
            'id': 'node-parent',
            'target_version_id': 'ver-1',
            'parent_id': null,
            'title': 'Parent Topic',
            'node_type': 'domain',
            'sort_order': 0,
          },
          {
            'id': 'node-child',
            'target_version_id': 'ver-1',
            'parent_id': 'node-parent',
            'title': 'Child Topic',
            'node_type': 'topic',
            'sort_order': 1,
          },
          {
            'id': 'node-sibling',
            'target_version_id': 'ver-1',
            'parent_id': null,
            'title': 'Sibling Topic',
            'node_type': 'domain',
            'sort_order': 2,
          },
        ]);
        fake.setTableData('curriculum_node_concepts', []);
        fake.setTableData('curriculum_node_lessons', []);
        fake.setTableData('curriculum_node_modules', []);
        fake.setTableData('curriculum_node_courses', []);
        fake.setTableData('user_curriculum_resources', [
          {
            'curriculum_node_id': 'node-parent',
            'lesson_id': 'lesson-parent',
            'sort_order': 0,
            'lessons': {'id': 'lesson-parent', 'title': 'Parent Lesson'},
          },
          {
            'curriculum_node_id': 'node-child',
            'lesson_id': 'lesson-child',
            'sort_order': 0,
            'lessons': {'id': 'lesson-child', 'title': 'Child Lesson'},
          },
          {
            'curriculum_node_id': 'node-sibling',
            'lesson_id': 'lesson-sibling',
            'sort_order': 0,
            'lessons': {'id': 'lesson-sibling', 'title': 'Sibling Lesson'},
          },
        ]);

        final context = LearningContext(
          id: 'ctx-focus-test',
          userId: 'user-1',
          label: 'Focus Test',
          rootType: ContextRootType.target,
          rootId: 'target-1',
          targetVersionId: 'ver-1',
          activeFocusId: 'node-parent',
          activeFocusType: 'domain',
          lastActiveAt: DateTime.now(),
        );

        final scope = await ScopeResolver(supabase: fake).resolveScope(context);
        final activityIds = scope.orderedActivities.map((a) => a.activityId).toList();
        expect(activityIds, contains('lesson-parent'));
        expect(activityIds, contains('lesson-child'));
        expect(activityIds, isNot(contains('lesson-sibling')));
      },
    );

    test(
      'official activity precedes personal activity deterministically and deduplicates',
      () async {
        final fake = FakeSupabaseClient();
        fake.setTableData('curriculum_nodes', [
          {
            'id': 'node-1',
            'target_version_id': 'ver-1',
            'parent_id': null,
            'title': 'Topic 1',
            'node_type': 'topic',
            'sort_order': 0,
          },
        ]);
        fake.setTableData('curriculum_node_concepts', []);
        fake.setTableData('curriculum_node_lessons', [
          {
            'curriculum_node_id': 'node-1',
            'lesson_id': 'lesson-official',
            'sort_order': 10,
            'lessons': {'id': 'lesson-official', 'title': 'Official Lesson'},
          },
        ]);
        fake.setTableData('curriculum_node_modules', []);
        fake.setTableData('curriculum_node_courses', []);
        fake.setTableData('user_curriculum_resources', [
          {
            'curriculum_node_id': 'node-1',
            'lesson_id': 'lesson-personal',
            'sort_order': 0,
            'lessons': {'id': 'lesson-personal', 'title': 'Personal Lesson'},
          },
          {
            'curriculum_node_id': 'node-1',
            'lesson_id': 'lesson-official',
            'sort_order': 0,
            'lessons': {'id': 'lesson-official', 'title': 'Official Lesson'},
          },
        ]);

        final context = LearningContext(
          id: 'ctx-order-test',
          userId: 'user-1',
          label: 'Order Test',
          rootType: ContextRootType.target,
          rootId: 'target-1',
          targetVersionId: 'ver-1',
          lastActiveAt: DateTime.now(),
        );

        final scope = await ScopeResolver(supabase: fake).resolveScope(context);
        expect(scope.orderedActivities.length, 2);
        expect(scope.orderedActivities[0].activityId, 'lesson-official');
        expect(scope.orderedActivities[0].source, ScopedActivitySource.official);
        expect(scope.orderedActivities[0].isRequired, isTrue);

        expect(scope.orderedActivities[1].activityId, 'lesson-personal');
        expect(scope.orderedActivities[1].source, ScopedActivitySource.personal);
        expect(scope.orderedActivities[1].isRequired, isFalse);
      },
    );

    test(
      'personal lesson term and question IDs enter scoped practice without concept mappings',
      () async {
        final fake = FakeSupabaseClient();
        fake.setTableData('curriculum_nodes', [
          {
            'id': 'node-1',
            'target_version_id': 'ver-1',
            'parent_id': null,
            'title': 'Topic 1',
            'node_type': 'topic',
            'sort_order': 0,
          },
        ]);
        fake.setTableData('curriculum_node_concepts', []);
        fake.setTableData('curriculum_node_lessons', []);
        fake.setTableData('curriculum_node_modules', []);
        fake.setTableData('curriculum_node_courses', []);
        fake.setTableData('user_curriculum_resources', [
          {
            'curriculum_node_id': 'node-1',
            'lesson_id': 'lesson-personal',
            'sort_order': 0,
            'lessons': {'id': 'lesson-personal', 'title': 'Personal Lesson'},
          },
        ]);
        fake.setTableData('questions', [
          {'id': 'q-personal-1', 'lesson_id': 'lesson-personal'},
        ]);
        fake.setTableData('terms', [
          {'id': 't-personal-1', 'lesson_id': 'lesson-personal'},
        ]);

        final context = LearningContext(
          id: 'ctx-practice-test',
          userId: 'user-1',
          label: 'Practice Test',
          rootType: ContextRootType.target,
          rootId: 'target-1',
          targetVersionId: 'ver-1',
          lastActiveAt: DateTime.now(),
        );

        final scope = await ScopeResolver(supabase: fake).resolveScope(context);
        expect(scope.coreConceptIds, isEmpty);
        expect(scope.questionIds, contains('q-personal-1'));
        expect(scope.termIds, contains('t-personal-1'));
        expect(scope.includesItem(contentId: 'q-personal-1'), isTrue);
        expect(scope.includesItem(contentId: 't-personal-1'), isTrue);
        expect(scope.includesItem(contentId: 'lesson-personal'), isTrue);
      },
    );

    test('computeConfigHash differentiates by userId and versions the hash', () {
      final ctxUserA = LearningContext(
        id: 'ctx-1',
        userId: 'user-A',
        label: 'Test',
        rootType: ContextRootType.target,
        rootId: 'target-1',
        lastActiveAt: DateTime.now(),
      );
      final ctxUserB = LearningContext(
        id: 'ctx-1',
        userId: 'user-B',
        label: 'Test',
        rootType: ContextRootType.target,
        rootId: 'target-1',
        lastActiveAt: DateTime.now(),
      );

      final hashA = ScopeResolver.computeConfigHash(ctxUserA);
      final hashB = ScopeResolver.computeConfigHash(ctxUserB);

      expect(hashA, startsWith('v2:user-A:'));
      expect(hashB, startsWith('v2:user-B:'));
      expect(hashA, isNot(equals(hashB)));
    });
  });
}
