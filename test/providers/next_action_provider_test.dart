import 'package:flutter_test/flutter_test.dart';
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

class FakeScopeResolver extends Fake implements ScopeResolver {
  final ResolvedScope scope;
  FakeScopeResolver(this.scope);

  @override
  Future<ResolvedScope> resolveScope(
    LearningContext context, {
    bool forceRefresh = false,
    Duration? cacheTtl,
  }) async =>
      scope;
}

void main() {
  final now = DateTime(2026, 10, 1);

  LearningContext targetContext({String id = 'ctx-target-1'}) {
    return LearningContext(
      id: id,
      userId: 'user-1',
      label: 'Official Target',
      rootType: ContextRootType.target,
      rootId: 'target-1',
      lastActiveAt: now,
    );
  }

  group('ContextSnapshotResolver personal overlay separation', () {
    test('incomplete required official lesson outranks earlier-sorting unfinished personal lesson', () async {
      // Personal lesson appears first in orderedActivities (e.g. node 1 personal overlay)
      // Official lesson appears second (node 2 required official lesson)
      final scope = ResolvedScope(
        contextId: 'ctx-target-1',
        coreConceptIds: const {'concept-1'},
        supportingConceptIds: const {},
        orderedActivities: const [
          ScopedLearningActivity(
            activityId: 'personal-lesson-1',
            kind: ScopedActivityKind.lesson,
            title: 'Personal Supplementary Lesson',
            curriculumOrder: 1,
            source: ScopedActivitySource.personal,
            isRequired: false,
          ),
          ScopedLearningActivity(
            activityId: 'official-lesson-1',
            kind: ScopedActivityKind.lesson,
            title: 'Official Core Lesson',
            curriculumOrder: 2,
            source: ScopedActivitySource.official,
            isRequired: true,
          ),
        ],
        resolvedAt: now,
      );

      final resolver = ContextSnapshotResolver(
        courses: FakeCourseService(),
        studySets: FakeSavedStudySetService(),
        reviews: FakeSpacedRepetitionService(),
        contexts: FakeLearningContextService(),
        scopeResolver: FakeScopeResolver(scope),
        completedLessonIdsFetcher: () async => <String>{},
      );

      final snapshot = await resolver.resolve(targetContext());

      // Next candidate must be official-lesson-1, NOT personal-lesson-1
      expect(snapshot.nextActivity, isNotNull);
      expect(snapshot.nextActivity, isA<LessonActivity>());
      final next = snapshot.nextActivity as LessonActivity;
      expect(next.lessonId, 'official-lesson-1');
      expect(next.title, 'Official Core Lesson');

      // officialRequiredCount is 1, completedOfficialRequiredCount is 0, totalActivityCount is 2
      expect(snapshot.officialRequiredCount, 1);
      expect(snapshot.completedOfficialRequiredCount, 0);
      expect(snapshot.totalActivityCount, 2);
      expect(snapshot.officialRequirementsComplete, isFalse);
    });

    test('when official requirements are complete, unfinished personal lessons are recommended next', () async {
      final scope = ResolvedScope(
        contextId: 'ctx-target-1',
        coreConceptIds: const {'concept-1'},
        supportingConceptIds: const {},
        orderedActivities: const [
          ScopedLearningActivity(
            activityId: 'official-lesson-1',
            kind: ScopedActivityKind.lesson,
            title: 'Official Core Lesson 1',
            curriculumOrder: 1,
            source: ScopedActivitySource.official,
            isRequired: true,
          ),
          ScopedLearningActivity(
            activityId: 'official-lesson-2',
            kind: ScopedActivityKind.lesson,
            title: 'Official Core Lesson 2',
            curriculumOrder: 2,
            source: ScopedActivitySource.official,
            isRequired: true,
          ),
          ScopedLearningActivity(
            activityId: 'personal-lesson-1',
            kind: ScopedActivityKind.lesson,
            title: 'Personal Study Material',
            curriculumOrder: 3,
            source: ScopedActivitySource.personal,
            isRequired: false,
          ),
        ],
        resolvedAt: now,
      );

      final resolver = ContextSnapshotResolver(
        courses: FakeCourseService(),
        studySets: FakeSavedStudySetService(),
        reviews: FakeSpacedRepetitionService(),
        contexts: FakeLearningContextService(),
        scopeResolver: FakeScopeResolver(scope),
        completedLessonIdsFetcher: () async => {'official-lesson-1', 'official-lesson-2'},
      );

      final snapshot = await resolver.resolve(targetContext());

      // All official requirements complete!
      expect(snapshot.officialRequiredCount, 2);
      expect(snapshot.completedOfficialRequiredCount, 2);
      expect(snapshot.officialRequirementsComplete, isTrue);

      // Next activity falls through to incomplete personal lesson
      expect(snapshot.nextActivity, isNotNull);
      expect(snapshot.nextActivity, isA<LessonActivity>());
      final next = snapshot.nextActivity as LessonActivity;
      expect(next.lessonId, 'personal-lesson-1');
      expect(next.title, 'Personal Study Material');
    });

    test('10 completed official lessons + 3 unfinished personal lessons means official requirements complete', () async {
      final officialActivities = List.generate(
        10,
        (i) => ScopedLearningActivity(
          activityId: 'official-$i',
          kind: ScopedActivityKind.lesson,
          title: 'Official $i',
          curriculumOrder: i + 1,
          source: ScopedActivitySource.official,
          isRequired: true,
        ),
      );

      final personalActivities = List.generate(
        3,
        (i) => ScopedLearningActivity(
          activityId: 'personal-$i',
          kind: ScopedActivityKind.lesson,
          title: 'Personal $i',
          curriculumOrder: 11 + i,
          source: ScopedActivitySource.personal,
          isRequired: false,
        ),
      );

      final scope = ResolvedScope(
        contextId: 'ctx-target-1',
        coreConceptIds: const {'concept-1'},
        supportingConceptIds: const {},
        orderedActivities: [...officialActivities, ...personalActivities],
        resolvedAt: now,
      );

      final completed = officialActivities.map((a) => a.activityId).toSet();

      final resolver = ContextSnapshotResolver(
        courses: FakeCourseService(),
        studySets: FakeSavedStudySetService(),
        reviews: FakeSpacedRepetitionService(),
        contexts: FakeLearningContextService(),
        scopeResolver: FakeScopeResolver(scope),
        completedLessonIdsFetcher: () async => completed,
      );

      final snapshot = await resolver.resolve(targetContext());

      expect(snapshot.totalActivityCount, 13);
      expect(snapshot.officialRequiredCount, 10);
      expect(snapshot.completedOfficialRequiredCount, 10);
      expect(snapshot.officialRequirementsComplete, isTrue);
      // Next candidate will be the first unfinished personal lesson
      expect((snapshot.nextActivity as LessonActivity).lessonId, 'personal-0');
    });

    test('empty official curriculum with personal lessons does not count as official completion', () async {
      final personalActivities = List.generate(
        2,
        (i) => ScopedLearningActivity(
          activityId: 'personal-$i',
          kind: ScopedActivityKind.lesson,
          title: 'Personal $i',
          curriculumOrder: i + 1,
          source: ScopedActivitySource.personal,
          isRequired: false,
        ),
      );

      final scope = ResolvedScope(
        contextId: 'ctx-target-1',
        coreConceptIds: const {'concept-1'},
        supportingConceptIds: const {},
        orderedActivities: personalActivities,
        resolvedAt: now,
      );

      final resolver = ContextSnapshotResolver(
        courses: FakeCourseService(),
        studySets: FakeSavedStudySetService(),
        reviews: FakeSpacedRepetitionService(),
        contexts: FakeLearningContextService(),
        scopeResolver: FakeScopeResolver(scope),
        completedLessonIdsFetcher: () async => {'personal-0', 'personal-1'},
      );

      final snapshot = await resolver.resolve(targetContext());

      expect(snapshot.totalActivityCount, 2);
      expect(snapshot.officialRequiredCount, 0);
      expect(snapshot.completedOfficialRequiredCount, 0);
      expect(snapshot.officialRequirementsComplete, isFalse);
    });
  });
}
