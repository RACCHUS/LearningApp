import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/models/objective_readiness.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/screens/companion/companion_screen.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:learning_pwa/widgets/companion/learner_resources_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

CurriculumNode node(
  String id,
  String title, {
  String? parent,
  String? code,
  int order = 0,
}) => CurriculumNode(
  id: id,
  targetVersionId: 'v1',
  parentId: parent,
  nodeType: parent == null ? 'domain' : 'objective',
  title: title,
  code: code,
  sortOrder: order,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final nodes = [
  node('d1', 'Algebra', order: 1),
  node('o1', 'Exponents', parent: 'd1', code: '1.1', order: 1),
  node('o2', 'Radicals', parent: 'd1', code: '1.2', order: 2),
];

const readiness = TargetObjectiveReadiness(
  signedIn: false,
  weightsEditorial: false,
  minHeldOutItems: 6,
  domains: [
    DomainReadiness(
      code: '1',
      title: 'Algebra',
      weightShare: 1,
      status: ObjectiveReadinessStatus.notStarted,
      objectives: [
        ObjectiveReadiness(
          code: '1.1',
          title: 'Exponents',
          status: ObjectiveReadinessStatus.notStarted,
          checked: true,
        ),
      ],
    ),
  ],
);

const goal = (targetId: 't1', targetVersionId: 'v1', targetSlug: 's1');

const threeParts = [
  ResourceSection(title: 'Unit 1: Powers', objectiveKeys: {'1.1'}, minutes: 25),
  ResourceSection(
    title: 'Unit 2: Roots',
    objectiveKeys: {'1.1', '1.2'},
    minutes: 70,
  ),
  ResourceSection(title: 'Unit 3: Wrap-up'),
];

Future<String> seed({
  List<ResourceSection> sections = threeParts,
  String? url,
}) async {
  final store = LocalLearnerResourceStore();
  final id = await store.save(
    targetId: 't1',
    title: 'My course',
    kind: LearnerResourceKind.course,
    url: url,
  );
  if (sections.isNotEmpty) await store.setSections(id, sections);
  return id;
}

Future<void> pump(
  WidgetTester tester,
  Widget home, {
  double width = 900,
}) async {
  tester.view.physicalSize = Size(width, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        learnerResourcesEnabledProvider.overrideWithValue(true),
        learnerResourcesUseAccountProvider.overrideWithValue(false),
        learnerResourceStoreProvider.overrideWithValue(
          LocalLearnerResourceStore(),
        ),
        targetCurriculumNodesProvider.overrideWith((ref, id) async => nodes),
        objectiveReadinessProvider.overrideWith((ref, id) async => readiness),
        targetCoverageProvider.overrideWith(
          (ref, slug) async => CoverageSummary([]),
        ),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'it opens at the first part not yet studied and adds up the time left',
    (tester) async {
      final id = await seed();
      await pump(tester, CompanionScreen(goal: goal, resourceId: id));
      expect(
        textOf(tester, 'companion_summary'),
        '0 of 3 parts studied. At least 1 h 35 min of outside study left (1 part has no time estimate).',
      );
      expect(textOf(tester, 'companion_state_0'), 'Next · about 25 min');
      expect(textOf(tester, 'companion_state_1'), 'about 1 h 10 min');
      expect(find.byKey(const Key('companion_done_0')), findsOneWidget);
      expect(
        find.byKey(const Key('companion_done_1')),
        findsNothing,
        reason: 'later parts start closed',
      );
      expect(find.text('In this part, look for:'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('In this part, look for:')).dx,
        lessThan(60),
        reason: 'the opened part reads from the left edge, not the middle',
      );
      expect(find.text('1.1 Exponents'), findsOneWidget);
      expect(find.byKey(const Key('help-action')), findsOneWidget);
      expect(
        textOf(tester, 'companion_self_report_note'),
        contains("only LearningApp's checks count toward readiness"),
      );
    },
  );

  testWidgets(
    'marking a part done moves the resume point and never changes what the checks say',
    (tester) async {
      final id = await seed();
      await pump(tester, CompanionScreen(goal: goal, resourceId: id));
      await tester.tap(find.byKey(const Key('companion_done_0')));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'companion_state_0'), 'Studied · about 25 min');
      expect(textOf(tester, 'companion_state_1'), 'Next · about 1 h 10 min');
      expect(
        find.byKey(const Key('companion_done_1')),
        findsOneWidget,
        reason: 'the next part opens',
      );
      expect(find.text('LearningApp checks: Not started'), findsOneWidget);

      var saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect(saved.nextSectionIndex, 1);
      expect(
        saved.studiedCount,
        0,
        reason: '1.1 is also in unit 2, which is not studied yet',
      );

      await tester.tap(find.byKey(const Key('companion_done_1')));
      await tester.pumpAndSettle();
      saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect(
        saved.studiedCount,
        2,
        reason: 'every part covering 1.1 and 1.2 is now studied',
      );
      expect(textOf(tester, 'companion_summary'), '2 of 3 parts studied.');
    },
  );

  testWidgets(
    'a part can be unmarked, and finishing every part points at the checks',
    (tester) async {
      final id = await seed(
        sections: const [
          ResourceSection(
            title: 'Only part',
            objectiveKeys: {'1.1'},
            minutes: 10,
          ),
        ],
      );
      await pump(tester, CompanionScreen(goal: goal, resourceId: id));
      await tester.tap(find.byKey(const Key('companion_done_0')));
      await tester.pumpAndSettle();
      expect(
        textOf(tester, 'companion_summary'),
        'You have marked every part studied. Check yourself in LearningApp to see where you stand.',
      );
      await tester.tap(find.byKey(const Key('companion_tile_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('companion_undo_0')));
      await tester.pumpAndSettle();
      expect(
        textOf(tester, 'companion_summary'),
        '0 of 1 part studied. About 10 min of outside study left.',
      );
      final saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect(saved.sections.single.studied, isFalse);
      expect(
        saved.studiedCount,
        1,
        reason: 'unmarking a part does not unmark the objective',
      );
    },
  );

  testWidgets('without an outline it asks for one and still opens the link', (
    tester,
  ) async {
    final id = await seed(
      sections: const [],
      url: 'https://example.org/course',
    );
    await pump(tester, CompanionScreen(goal: goal, resourceId: id));
    expect(
      textOf(tester, 'companion_summary'),
      startsWith('Add the list of chapters'),
    );
    expect(find.byKey(const Key('companion_add_outline')), findsOneWidget);
    expect(find.text('Open (leaves LearningApp)'), findsOneWidget);
  });

  testWidgets('the goal card offers to continue at the resume point', (
    tester,
  ) async {
    final id = await seed();
    await LocalLearnerResourceStore().setSectionStudied(id, 0, true);
    await pump(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: LearnerResourcesCard(
            targetId: 't1',
            targetVersionId: 'v1',
            targetSlug: 's1',
          ),
        ),
      ),
    );
    expect(
      find.text('Continue: Unit 2: Roots (about 1 h 10 min)'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(Key('learner_resource_continue_$id')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'companion_state_1'), 'Next · about 1 h 10 min');
  });

  testWidgets(
    'the companion fits a 320-wide split-view pane and meets the access guidelines',
    (tester) async {
      final handle = tester.ensureSemantics();
      final id = await seed(url: 'https://example.org/course');
      await pump(
        tester,
        CompanionScreen(goal: goal, resourceId: id),
        width: 320,
      );
      expect(tester.takeException(), isNull, reason: 'no overflow at 320 wide');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );
}
