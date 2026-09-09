import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/services/next_action_engine.dart';

/// The engine is pure, so every precedence case is covered here without Hive,
/// Supabase, or a widget tree. Ship-gate items from §12 are marked SHIP GATE.
void main() {
  const engine = NextActionEngine();
  final now = DateTime(2026, 1, 1);

  LearningContext ctx({
    String id = 'c1',
    ContextRootType rootType = ContextRootType.course,
    String rootId = 'course-1',
    bool archived = false,
    int sortOrder = -1,
    DateTime? lastActive,
  }) {
    return LearningContext(
      id: id,
      userId: 'u1',
      label: 'Test context',
      rootType: rootType,
      rootId: rootId,
      isArchived: archived,
      sortOrder: sortOrder,
      lastActiveAt: lastActive ?? now,
    );
  }

  const lesson = LessonActivity(
    lessonId: 'l1',
    title: 'Provider Basics',
    courseId: 'course-1',
  );

  group('precedence', () {
    test('case 1 — no contexts yields ChooseSomething', () {
      final action = engine.resolve(contexts: const [], active: null);
      expect(action, isA<ChooseSomething>());
    });

    test('case 1 — archived-only contexts still yield ChooseSomething', () {
      final action = engine.resolve(
        contexts: [ctx(archived: true)],
        active: ContextSnapshot(context: ctx(archived: true)),
      );
      expect(action, isA<ChooseSomething>());
    });

    test('case 1 — empty catalog is carried through to the zero state', () {
      final action = engine.resolve(contexts: const [], catalogEmpty: true);
      expect((action as ChooseSomething).catalogEmpty, isTrue);
    });

    test('case 2 — partially completed activity outranks everything', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(
          context: ctx(),
          resume: ResumePointer(
            contextId: 'c1',
            kind: ResumableKind.lesson,
            activityId: 'l1',
            itemIndex: 3,
            updatedAt: now,
          ),
          resumeActivity: lesson,
          resumeItemCount: 10,
          nextActivity: lesson,
          dueConceptIds: const ['a', 'b'],
          strugglingConceptIds: const ['x', 'y', 'z'],
        ),
      );
      expect(action, isA<ResumeActivity>());
      expect((action as ResumeActivity).itemIndex, 3);
    });

    test('case 2 — a finished activity does not count as resumable', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(
          context: ctx(),
          resume: ResumePointer(
            contextId: 'c1',
            kind: ResumableKind.lesson,
            activityId: 'l1',
            itemIndex: 10,
            updatedAt: now,
          ),
          resumeActivity: lesson,
          resumeItemCount: 10,
          nextActivity: lesson,
        ),
      );
      expect(action, isA<StartActivity>());
    });

    test('case 2 — an unresolvable resume target falls through, not breaks', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(
          context: ctx(),
          resume: ResumePointer(
            contextId: 'c1',
            kind: ResumableKind.lesson,
            activityId: 'deleted-lesson',
            itemIndex: 2,
            updatedAt: now,
          ),
          resumeItemCount: 10,
          nextActivity: lesson,
        ),
      );
      expect(action, isA<StartActivity>());
    });

    test('case 3 — remediation fires at the threshold', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(
          context: ctx(),
          nextActivity: lesson,
          strugglingConceptIds: const ['x', 'y', 'z'],
        ),
      );
      expect(action, isA<ReinforceConcepts>());
    });

    test('case 3 — below the threshold new material still wins', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(
          context: ctx(),
          nextActivity: lesson,
          strugglingConceptIds: const ['x', 'y'],
        ),
      );
      expect(action, isA<StartActivity>());
    });

    test('case 4 — next activity becomes the primary action', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(context: ctx(), nextActivity: lesson),
      );
      expect(action, isA<StartActivity>());
      expect((action as StartActivity).activity, lesson);
    });

    test('case 4 — StartActivity stays silent (trivial rationale)', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(context: ctx(), nextActivity: lesson),
      );
      expect(action.rationale, isNull);
    });

    test('case 5 — exhausted context with reviews yields ReviewOnly', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(
          context: ctx(),
          dueConceptIds: const ['a', 'b', 'c'],
        ),
      );
      expect(action, isA<ReviewOnly>());
      expect((action as ReviewOnly).activity.count, 3);
    });

    test('case 6 — exhausted context with nothing due yields ContextComplete', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(context: ctx()),
      );
      expect(action, isA<ContextComplete>());
    });
  });

  group('A1 — reviews never supersede forward progress', () {
    test('SHIP GATE: review is not primary while a lesson remains', () {
      for (final dueCount in [1, 20, 300]) {
        final action = engine.resolve(
          contexts: [ctx()],
          active: ContextSnapshot(
            context: ctx(),
            nextActivity: lesson,
            dueConceptIds: List.generate(dueCount, (i) => 'c$i'),
          ),
        );
        expect(action, isA<StartActivity>(),
            reason: 'dueCount=$dueCount must not promote review');
      }
    });

    test('SHIP GATE: review is not primary while an activity is resumable', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(
          context: ctx(),
          resume: ResumePointer(
            contextId: 'c1',
            kind: ResumableKind.lesson,
            activityId: 'l1',
            itemIndex: 1,
            updatedAt: now,
          ),
          resumeActivity: lesson,
          resumeItemCount: 5,
          dueConceptIds: List.generate(500, (i) => 'c$i'),
        ),
      );
      expect(action, isA<ResumeActivity>());
    });

    test('no backlog size changes the outcome', () {
      NextAction at(int due) => engine.resolve(
            contexts: [ctx()],
            active: ContextSnapshot(
              context: ctx(),
              nextActivity: lesson,
              dueConceptIds: List.generate(due, (i) => 'c$i'),
            ),
          );
      expect(at(0).runtimeType, at(1000).runtimeType);
    });
  });

  group('C1 — no state is reachable-but-terminal', () {
    test('SHIP GATE: ReviewOnly always carries a forward offer', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(
          context: ctx(),
          dueConceptIds: const ['a'],
        ),
      );
      expect((action as ReviewOnly).offer.label, isNotEmpty);
    });

    test('a completed course with perpetual reviews still offers a way on', () {
      // Reviews regenerate forever, so this is the steady state — not an edge.
      for (final due in [1, 50, 5000]) {
        final action = engine.resolve(
          contexts: [ctx()],
          active: ContextSnapshot(
            context: ctx(),
            dueConceptIds: List.generate(due, (i) => 'c$i'),
            forwardOffer: const ForwardOffer(label: 'Next: Advanced Dart'),
          ),
        );
        expect(action, isA<ReviewOnly>());
        expect((action as ReviewOnly).offer.label, 'Next: Advanced Dart');
      }
    });

    test('ContextComplete always carries a forward offer', () {
      final action = engine.resolve(
        contexts: [ctx()],
        active: ContextSnapshot(context: ctx()),
      );
      expect((action as ContextComplete).offer.label, isNotEmpty);
    });
  });

  group('B2 — content neutrality across every rootType', () {
    for (final rootType in ContextRootType.values) {
      test('$rootType resolves a primary action with material available', () {
        final activity = rootType == ContextRootType.studySet
            ? const StudySetActivity(
                studySetId: 's1', title: 'Spanish Verbs', itemCount: 40)
            : lesson;
        final action = engine.resolve(
          contexts: [ctx(rootType: rootType)],
          active: ContextSnapshot(
            context: ctx(rootType: rootType),
            nextActivity: activity,
          ),
        );
        expect(action, isA<StartActivity>());
      });

      test('$rootType never yields a null-ish action when exhausted', () {
        final action = engine.resolve(
          contexts: [ctx(rootType: rootType)],
          active: ContextSnapshot(context: ctx(rootType: rootType)),
        );
        expect(action, isA<ContextComplete>());
      });
    }

    test('SHIP GATE: a bare study set produces a valid primary action', () {
      const activity = StudySetActivity(
        studySetId: 's1',
        title: 'Spanish Verbs',
        itemCount: 40,
      );
      final context = ctx(rootType: ContextRootType.studySet, rootId: 's1');
      final action = engine.resolve(
        contexts: [context],
        active: ContextSnapshot(context: context, nextActivity: activity),
      );
      expect(action, isA<StartActivity>());
      expect((action as StartActivity).activity, isA<StudySetActivity>());
    });

    test('SHIP GATE: a bare lesson context needs no synthetic parent', () {
      const activity = LessonActivity(lessonId: 'l9', title: 'Big-O Notation');
      final context = ctx(rootType: ContextRootType.lesson, rootId: 'l9');
      final action = engine.resolve(
        contexts: [context],
        active: ContextSnapshot(context: context, nextActivity: activity),
      );
      expect(action, isA<StartActivity>());
      expect((activity).courseId, isNull);
    });
  });

  group('B4 — switcher ordering', () {
    test('SHIP GATE: pinned ascending, then lastActiveAt descending', () {
      final contexts = [
        ctx(id: 'recent', lastActive: DateTime(2026, 1, 5)),
        ctx(id: 'pin-b', sortOrder: 1, lastActive: DateTime(2020, 1, 1)),
        ctx(id: 'old', lastActive: DateTime(2025, 1, 1)),
        ctx(id: 'pin-a', sortOrder: 0, lastActive: DateTime(2019, 1, 1)),
      ];
      final ordered = engine.orderForSwitcher(contexts);
      expect(ordered.map((c) => c.id).toList(),
          ['pin-a', 'pin-b', 'recent', 'old']);
    });

    test('archived contexts never appear', () {
      final ordered = engine.orderForSwitcher([
        ctx(id: 'live'),
        ctx(id: 'gone', archived: true),
      ]);
      expect(ordered.map((c) => c.id), ['live']);
    });
  });

  group('secondary review prompt', () {
    test('hidden when nothing is due', () {
      final action = StartActivity(activity: lesson);
      expect(engine.showSecondaryReviewPrompt(action, 0), isFalse);
    });

    test('shown alongside forward progress', () {
      final action = StartActivity(activity: lesson);
      expect(engine.showSecondaryReviewPrompt(action, 6), isTrue);
    });

    test('suppressed when review is already primary', () {
      const action = ReviewOnly(
        activity: ReviewActivity(conceptIds: ['a']),
        offer: ForwardOffer.browse,
      );
      expect(engine.showSecondaryReviewPrompt(action, 1), isFalse);
    });
  });
}
