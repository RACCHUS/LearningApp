import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:learning_pwa/widgets/companion/outside_study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

LearningContext contextFor(ContextRootType type, String rootId) =>
    LearningContext(
      id: 'c1',
      userId: 'local-user',
      label: 'Goal',
      rootType: type,
      rootId: rootId,
      lastActiveAt: DateTime(2026),
    );

const plan = OutsideStudyPlan(
  targetId: 't1',
  resourceId: 'r1',
  resourceTitle: 'My course',
  sectionTitle: 'Unit 2: Roots',
  sectionMinutes: 70,
  remainingMinutes: 95,
  partsWithoutEstimate: 1,
);

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  OutsideStudyPlan? value = plan,
  double width = 900,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeOutsideStudyPlanProvider.overrideWith((ref) async => value),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OutsideStudyPlan', () {
    const done = ResourceSection(title: 'P1', minutes: 10);
    LearnerResource resource(String id, List<ResourceSection> sections) =>
        LearnerResource(
          id: id,
          targetId: 't1',
          title: 'Resource $id',
          kind: LearnerResourceKind.course,
          sections: sections,
        );

    test(
      'is the first unstudied part of the first resource that has one, with totals across all',
      () {
        final studied = done.copyWith(studiedAt: () => DateTime(2026));
        final p = OutsideStudyPlan.from('t1', [
          resource('a', [studied]),
          resource('b', [
            studied,
            const ResourceSection(title: 'B2', minutes: 30),
            const ResourceSection(title: 'B3'),
          ]),
          resource('c', [const ResourceSection(title: 'C1', minutes: 15)]),
        ])!;
        expect(p.resourceId, 'b');
        expect(p.sectionTitle, 'B2');
        expect(p.sectionMinutes, 30);
        expect(p.remainingMinutes, 45);
        expect(p.partsWithoutEstimate, 1);
      },
    );

    test('is null when there is no outline or every part is studied', () {
      expect(OutsideStudyPlan.from('t1', const []), isNull);
      expect(OutsideStudyPlan.from('t1', [resource('a', const [])]), isNull);
      expect(
        OutsideStudyPlan.from('t1', [
          resource('a', [done.copyWith(studiedAt: () => DateTime(2026))]),
        ]),
        isNull,
      );
    });
  });

  group('the active goal', () {
    Future<OutsideStudyPlan?> read(
      LearningContext? context, {
      bool enabled = true,
    }) async {
      final container = ProviderContainer(
        overrides: [
          activeLearningContextProvider.overrideWithValue(context),
          learnerResourcesEnabledProvider.overrideWithValue(enabled),
          learnerResourcesUseAccountProvider.overrideWithValue(false),
          learnerResourceStoreProvider.overrideWithValue(
            LocalLearnerResourceStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(activeOutsideStudyPlanProvider.future);
    }

    setUp(() async {
      final store = LocalLearnerResourceStore();
      final id = await store.save(
        targetId: 't1',
        title: 'My course',
        kind: LearnerResourceKind.course,
      );
      await store.setSections(id, const [
        ResourceSection(title: 'Unit 1', minutes: 20),
      ]);
    });

    test('has an outside step when its goal has an unstudied part', () async {
      expect(
        (await read(contextFor(ContextRootType.target, 't1')))?.sectionTitle,
        'Unit 1',
      );
    });

    test(
      'has none for another goal, a context that is not a goal, no context, or the switch off',
      () async {
        expect(await read(contextFor(ContextRootType.target, 't2')), isNull);
        expect(await read(contextFor(ContextRootType.course, 't1')), isNull);
        expect(await read(null), isNull);
        expect(
          await read(contextFor(ContextRootType.target, 't1'), enabled: false),
          isNull,
        );
      },
    );
  });

  testWidgets(
    'Learn shows the next outside part, with the check that follows it',
    (tester) async {
      await pump(tester, const OutsideStepCard());
      expect(textOf(tester, 'outside_step_title'), 'Next: Unit 2: Roots');
      expect(
        textOf(tester, 'outside_step_detail'),
        'My course · about 1 h 10 min. Then check yourself in LearningApp.',
      );
      expect(find.text('Continue outside study'), findsOneWidget);
    },
  );

  testWidgets(
    'with nothing outside to continue, none of the three takes any space',
    (tester) async {
      await pump(
        tester,
        const Column(
          children: [
            OutsideStepCard(),
            OutsideStudyPlanLine(dailyMinutes: 30),
            OutsideStudyFinishLine(dailyGoalMinutes: 30),
          ],
        ),
        value: null,
      );
      expect(find.byKey(const Key('outside_step_card')), findsNothing);
      expect(find.byKey(const Key('daily_plan_outside_study')), findsNothing);
      expect(find.byKey(const Key('projection_outside_study')), findsNothing);
      expect(tester.getSize(find.byType(Column)).height, 0);
    },
  );

  testWidgets(
    'the daily plan says whether the next part fits in today\'s goal',
    (tester) async {
      await pump(tester, const OutsideStudyPlanLine(dailyMinutes: 30));
      expect(
        textOf(tester, 'daily_plan_outside_study'),
        'Outside study next: Unit 2: Roots, about 1 h 10 min. '
        'That is longer than your 30-minute goal, so allow about 3 days for it. '
        'At least 1 h 35 min of outside study left, by your own estimates.',
      );
      await pump(tester, const OutsideStudyPlanLine(dailyMinutes: 90));
      expect(
        textOf(tester, 'daily_plan_outside_study'),
        contains('It fits in your 90-minute goal today.'),
      );
    },
  );

  testWidgets(
    'the projected finish states outside time on its own line, outside the dates',
    (tester) async {
      await pump(tester, const OutsideStudyFinishLine(dailyGoalMinutes: 30));
      expect(
        textOf(tester, 'projection_outside_study'),
        'At least 1 h 35 min of outside study left, by your own estimates. '
        'At your daily goal that adds about 4 days. It is not included in the dates above.',
      );
    },
  );

  testWidgets(
    'the Learn card meets tap-target, label and contrast guidelines at phone width',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const OutsideStepCard(), width: 360);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );
}
