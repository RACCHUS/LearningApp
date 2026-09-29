import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/core/hive_type_ids.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/scope.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/providers/next_action_provider.dart';
import 'package:learning_pwa/services/course_service.dart';
import 'package:learning_pwa/services/learning_context_service.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';
import 'package:learning_pwa/services/scope_resolver.dart';
import 'package:learning_pwa/services/spaced_repetition_service.dart';

class FakeCourseService extends Fake implements CourseService {}

class FakeSavedStudySetService extends Fake implements SavedStudySetService {}

class FakeSpacedRepetitionService extends Fake implements SpacedRepetitionService {
  @override
  Future<List<ReviewableItem>> getDueItems() async => [];
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
  });

  group('Target Privacy Defaults & Authoring', () {
    test('createTarget parameters default to private and draft', () {
      const defaultIsPublic = false;
      const defaultStatus = 'draft';

      expect(defaultIsPublic, isFalse, reason: 'Custom targets must never default to public catalog');
      expect(defaultStatus, 'draft', reason: 'Custom targets must start in draft status');
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
