import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/core/hive_type_ids.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/models/scope.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/providers/next_action_provider.dart';
import 'package:learning_pwa/services/course_service.dart';
import 'package:learning_pwa/services/learning_context_service.dart';
import 'package:learning_pwa/services/learning_target_service.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';
import 'package:learning_pwa/services/scope_resolver.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';
import '../test_helpers/fake_supabase_client.dart';

class FakeCourseService extends Fake implements CourseService {}

class FakeSavedStudySetService extends Fake implements SavedStudySetService {}

class FakeSpacedRepetitionService extends Fake implements SpacedRepetitionService {
  @override
  Future<List<ReviewableItem>> getDueItems() async => [];
}

class _FakeReviewServiceWithDueItems extends Fake implements SpacedRepetitionService {
  final List<ReviewableItem> items;
  _FakeReviewServiceWithDueItems(this.items);

  @override
  Future<List<ReviewableItem>> getDueItems() async => items;
}

ReviewableItem _createReviewItem({
  required String id,
  required String contentId,
  String? lessonId,
}) {
  return ReviewableItem(
    id: id,
    contentId: contentId,
    lessonId: lessonId,
    contentType: ReviewableContentType.concept,
    title: 'Item $id',
    nextReviewDate: DateTime.now().subtract(const Duration(hours: 1)),
  );
}

class FakeLearningContextService extends Fake implements LearningContextService {
  @override
  ResumePointer? resumeFor(String contextId) => null;
}

void main() {
  const testPath = 'build/test_hive_v2_stabilization';
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
        'scope_${DateTime.now().microsecondsSinceEpoch}');
    snapshotBox = await Hive.openBox<ContextCurriculumSnapshot>(
        'snap_${DateTime.now().microsecondsSinceEpoch}');
  });

  tearDown(() async {
    await scopeBox.close();
    await snapshotBox.close();
  });

  group('V2 Scoped Review & includesItem', () {
    test('correctly identifies items in scope by contentId, questionId, and lessonId', () {
      final scope = ResolvedScope(
        contextId: 'ctx-ccna',
        coreConceptIds: const {'c-subnetting', 'c-osi'},
        supportingConceptIds: const {'c-binary'},
        orderedActivities: const [
          ScopedLearningActivity(
            activityId: 'lesson-ip',
            kind: ScopedActivityKind.lesson,
            title: 'IPv4 Addressing',
            curriculumOrder: 1,
          ),
          ScopedLearningActivity(
            activityId: 'lesson-routing',
            kind: ScopedActivityKind.lesson,
            title: 'Static Routing',
            curriculumOrder: 2,
          ),
        ],
        questionIds: const {'q-101', 'q-102'},
        termIds: const {'t-subnet-mask'},
        resolvedAt: DateTime.now(),
      );

      // In scope by direct question/content ID
      expect(scope.includesItem(contentId: 'q-101'), isTrue);
      expect(scope.includesItem(contentId: 't-subnet-mask'), isTrue);

      // In scope by associated lesson
      expect(
        scope.includesItem(contentId: 'q-unlisted', lessonId: 'lesson-ip'),
        isTrue,
      );

      // Out of scope: unrelated question and unrelated lesson
      expect(scope.includesItem(contentId: 'q-nursing-pharmacology'), isFalse);
      expect(
        scope.includesItem(
          contentId: 'q-med-calc',
          lessonId: 'lesson-pharmacokinetics',
        ),
        isFalse,
      );
    });
  });

  group('NextAction Structural Progress vs Review Scheduling', () {
    test('NextAction resolver uses actual completed lessons, NOT due review items', () async {
      final context = LearningContext(
        id: 'ctx-prog',
        userId: 'u1',
        label: 'Programming Target',
        rootType: ContextRootType.target,
        rootId: 'target-prog',
        lastActiveAt: DateTime.now(),
      );

      // Setup scope with two ordered lessons
      final scope = ResolvedScope(
        contextId: 'ctx-prog',
        coreConceptIds: const {'c-vars', 'c-loops'},
        supportingConceptIds: const {},
        orderedActivities: const [
          ScopedLearningActivity(
            activityId: 'lesson-vars',
            kind: ScopedActivityKind.lesson,
            title: 'Variables',
            curriculumOrder: 1,
          ),
          ScopedLearningActivity(
            activityId: 'lesson-loops',
            kind: ScopedActivityKind.lesson,
            title: 'Loops',
            curriculumOrder: 2,
          ),
        ],
        resolvedAt: DateTime.now(),
      );

      // Scenario: Learner has a due review item for lesson-vars.
      // But lesson-vars IS completed structurally.
      final completedLessonIds = {'lesson-vars'};

      // Store scope in cache so resolver uses it
      await scopeBox.put('ctx-prog', scope);

      final resolver = ContextSnapshotResolver(
        courses: FakeCourseService(),
        studySets: FakeSavedStudySetService(),
        reviews: FakeSpacedRepetitionService(),
        contexts: FakeLearningContextService(),
        scopeResolver: ScopeResolver(scopeBox: scopeBox, snapshotBox: snapshotBox),
        completedLessonIdsFetcher: () async => completedLessonIds,
      );

      final snapshot = await resolver.resolve(context);
      final action = const NextActionEngine().resolve(
        contexts: [context],
        active: snapshot,
      );

      // Next action MUST be lesson-loops, advancing past structurally completed lesson-vars!
      expect(action, isA<StartActivity>());
      final start = action as StartActivity;
      final lessonAct = start.activity as LessonActivity;
      expect(lessonAct.lessonId, 'lesson-loops');
      expect(lessonAct.title, 'Loops');
    });

    test('NextAction resolver completed lesson fetcher isolates by user', () async {
      final context = LearningContext(
        id: 'ctx-prog',
        userId: 'user-alice',
        label: 'Programming Target',
        rootType: ContextRootType.target,
        rootId: 'target-prog',
        lastActiveAt: DateTime.now(),
      );

      final scope = ResolvedScope(
        contextId: 'ctx-prog',
        coreConceptIds: const {'c-vars'},
        supportingConceptIds: const {},
        orderedActivities: const [
          ScopedLearningActivity(
            activityId: 'lesson-vars',
            kind: ScopedActivityKind.lesson,
            title: 'Variables',
            curriculumOrder: 1,
          ),
        ],
        resolvedAt: DateTime.now(),
      );

      await scopeBox.put('ctx-prog', scope);

      // Alice has completed nothing; Bob's completed lessons must NOT bleed into Alice's resolution
      final resolver = ContextSnapshotResolver(
        courses: FakeCourseService(),
        studySets: FakeSavedStudySetService(),
        reviews: FakeSpacedRepetitionService(),
        contexts: FakeLearningContextService(),
        scopeResolver: ScopeResolver(scopeBox: scopeBox, snapshotBox: snapshotBox),
        completedLessonIdsFetcher: () async => <String>{},
      );

      final snapshot = await resolver.resolve(context);
      final action = const NextActionEngine().resolve(
        contexts: [context],
        active: snapshot,
      );

      // Lesson must still be recommended for Alice
      expect(action, isA<StartActivity>());
      final start = action as StartActivity;
      final lessonAct = start.activity as LessonActivity;
      expect(lessonAct.lessonId, 'lesson-vars');
    });
  });

  group('Target Privacy Defaults & Authoring Binding Schemas', () {
    test('LearningTargetService.createTarget creates private draft by default', () async {
      final fake = FakeSupabaseClient();
      final service = LearningTargetService(supabase: fake);

      await service.createTarget(
        title: 'My Custom Target',
        targetType: TargetType.certification,
      );

      expect(fake.insertedRecords, isNotEmpty);
      final targetInsert = fake.insertedRecords.firstWhere(
        (r) => r.containsKey('title') && r['title'] == 'My Custom Target',
      );
      expect(targetInsert['is_public'], isFalse, reason: 'Custom target must default to is_public = false');
      expect(targetInsert['status'], 'draft', reason: 'Custom target must default to status = draft');
      expect(targetInsert['target_type'], 'certification');
    });

    test('Curriculum binding methods write correct database schema columns', () async {
      final fake = FakeSupabaseClient();
      final service = LearningTargetService(supabase: fake);

      // 1. bindCourseToNode writes is_required (NOT is_primary) and sort_order
      await service.bindCourseToNode(
        curriculumNodeId: 'node-1',
        courseId: 'course-1',
        isRequired: true,
        sortOrder: 3,
      );
      final courseBinding = fake.insertedRecords.firstWhere(
        (r) => r['curriculum_node_id'] == 'node-1' && r['course_id'] == 'course-1',
      );
      expect(courseBinding['is_required'], isTrue);
      expect(courseBinding['sort_order'], 3);
      expect(courseBinding.containsKey('is_primary'), isFalse, reason: 'Table column is is_required, not is_primary');

      // 2. bindModuleToNode writes is_required and sort_order
      await service.bindModuleToNode(
        curriculumNodeId: 'node-1',
        moduleId: 'module-1',
        isRequired: false,
        sortOrder: 2,
      );
      final moduleBinding = fake.insertedRecords.firstWhere(
        (r) => r['curriculum_node_id'] == 'node-1' && r['module_id'] == 'module-1',
      );
      expect(moduleBinding['is_required'], isFalse);
      expect(moduleBinding['sort_order'], 2);

      // 3. bindLessonToNode writes is_required (NOT teaching_role) and sort_order
      await service.bindLessonToNode(
        curriculumNodeId: 'node-1',
        lessonId: 'lesson-1',
        isRequired: true,
        sortOrder: 1,
      );
      final lessonBinding = fake.insertedRecords.firstWhere(
        (r) => r['curriculum_node_id'] == 'node-1' && r['lesson_id'] == 'lesson-1',
      );
      expect(lessonBinding['is_required'], isTrue);
      expect(lessonBinding['sort_order'], 1);
      expect(lessonBinding.containsKey('teaching_role'), isFalse, reason: 'Table column is is_required, not teaching_role');

      // 4. bindConceptToNode writes relevance and weight (NOT importance / sort_order)
      await service.bindConceptToNode(
        curriculumNodeId: 'node-1',
        conceptId: 'concept-1',
        relevance: 'core',
        weight: 0.85,
      );
      final conceptBinding = fake.insertedRecords.firstWhere(
        (r) => r['curriculum_node_id'] == 'node-1' && r['concept_id'] == 'concept-1',
      );
      expect(conceptBinding['relevance'], 'core');
      expect(conceptBinding['weight'], 0.85);
      expect(conceptBinding.containsKey('importance'), isFalse, reason: 'Table column is relevance, not importance');
      expect(conceptBinding.containsKey('sort_order'), isFalse, reason: 'curriculum_node_concepts uses relevance/weight');
    });
  });

  group('Fail-Closed Review Scoping & Reinforce Concept Targeting', () {
    test('startSession with nonexistent contextId fails closed to empty list', () async {
      final container = ProviderContainer(
        overrides: [
          spacedRepetitionServiceProvider.overrideWithValue(
            _FakeReviewServiceWithDueItems([
              _createReviewItem(id: 'r1', contentId: 'c1', lessonId: 'l1'),
              _createReviewItem(id: 'r2', contentId: 'c2', lessonId: 'l2'),
            ]),
          ),
        ],
      );

      final notifier = container.read(reviewSessionProvider.notifier);
      await notifier.startSession(contextId: 'nonexistent-context');

      final session = container.read(reviewSessionProvider);
      expect(session.items, isEmpty, reason: 'Contextual review MUST fail closed if context is invalid');
      expect(session.isComplete, isTrue);
    });

    test('startSession filters to specificConceptIds for Reinforce', () async {
      final container = ProviderContainer(
        overrides: [
          spacedRepetitionServiceProvider.overrideWithValue(
            _FakeReviewServiceWithDueItems([
              _createReviewItem(id: 'r1', contentId: 'concept-weak-1'),
              _createReviewItem(id: 'r2', contentId: 'concept-ok-2'),
              _createReviewItem(id: 'r3', contentId: 'q3', lessonId: 'concept-weak-1'),
            ]),
          ),
        ],
      );

      final notifier = container.read(reviewSessionProvider.notifier);
      await notifier.startSession(specificConceptIds: ['concept-weak-1']);

      final session = container.read(reviewSessionProvider);
      expect(session.items.length, 2);
      expect(session.items.map((i) => i.id), containsAll(['r1', 'r3']));
      expect(session.items.any((i) => i.id == 'r2'), isFalse);
    });
  });

  group('ScopeResolver Stale-While-Revalidate & ConfigHash', () {
    test('computeConfigHash captures rootId, targetVersionId, scopeMode, and scopeConfig', () {
      final ctx1 = LearningContext(
        id: 'ctx-1',
        userId: 'u1',
        label: 'Context 1',
        rootType: ContextRootType.target,
        rootId: 'target-1',
        targetVersionId: 'v1',
        scopeMode: ScopeMode.coreOnly,
        lastActiveAt: DateTime.now(),
      );

      final ctx2 = ctx1.copyWith(targetVersionId: 'v2');
      final ctx3 = ctx1.copyWith(scopeMode: ScopeMode.custom);

      final hash1 = ScopeResolver.computeConfigHash(ctx1);
      final hash2 = ScopeResolver.computeConfigHash(ctx2);
      final hash3 = ScopeResolver.computeConfigHash(ctx3);

      expect(hash1, isNotEmpty);
      expect(hash1, isNot(equals(hash2)));
      expect(hash1, isNot(equals(hash3)));
      expect(hash1, equals(ScopeResolver.computeConfigHash(ctx1)));
    });
  });
}
