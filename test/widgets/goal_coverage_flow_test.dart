import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:learning_pwa/widgets/companion/learner_resources_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

CurriculumNode node(String id, String title, {String? parent, String? code, double? weight, int order = 0}) =>
    CurriculumNode(
      id: id,
      targetVersionId: 'v1',
      parentId: parent,
      nodeType: parent == null ? 'domain' : 'objective',
      title: title,
      code: code,
      weight: weight,
      sortOrder: order,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

final nodes = [
  node('d1', 'Algebra', weight: 50, order: 1),
  node('d2', 'Functions', weight: 50, order: 2),
  node('o1', 'Exponents', parent: 'd1', code: '1.1', order: 1),
  node('o2', 'Radicals', parent: 'd1', code: '1.2', order: 2),
  node('o3', 'Graphs', parent: 'd2', code: '2.1', order: 1),
  node('o4', 'Inverses', parent: 'd2', code: '2.2', order: 2),
];

CoverageRow row(String id, String code, {required CoverageState teach, CoverageState check = CoverageState.gap}) =>
    CoverageRow(
      objectiveId: id,
      code: code,
      title: code,
      cells: {
        CoverageRole.teach: teach,
        CoverageRole.example: CoverageState.gap,
        CoverageRole.check: check,
      },
    );

/// 1.1 taught and checked; 1.2 taught, no checks; 2.1 taught; 2.2 nothing.
final rows = [
  row('o1', '1.1', teach: CoverageState.reviewed, check: CoverageState.verified),
  row('o2', '1.2', teach: CoverageState.imported),
  row('o3', '2.1', teach: CoverageState.reviewed, check: CoverageState.partial),
  row('o4', '2.2', teach: CoverageState.gap),
];

Future<void> pump(WidgetTester tester, {bool matrixFails = false}) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        learnerResourcesEnabledProvider.overrideWithValue(true),
        learnerResourcesUseAccountProvider.overrideWithValue(false),
        learnerResourceStoreProvider.overrideWithValue(LocalLearnerResourceStore()),
        targetCurriculumNodesProvider.overrideWith((ref, id) async => nodes),
        objectiveReadinessProvider.overrideWith((ref, id) async => null),
        targetCoverageProvider.overrideWith(
          (ref, slug) async => matrixFails ? throw StateError('offline') : CoverageSummary(rows),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LearnerResourcesCard(targetId: 't1', targetVersionId: 'v1', targetSlug: 's1'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A saved resource covering 1.1 and 1.2 (all of Algebra, half the goal).
Future<void> seed() async {
  final store = LocalLearnerResourceStore();
  final id = await store.save(targetId: 't1', title: 'My course', kind: LearnerResourceKind.course);
  await store.setObjectives(id, {'1.1', '1.2'});
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('no coverage summary until the learner has added something', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('goal_coverage_outside')), findsNothing);
  });

  testWidgets('the goal is split three ways by weight', (tester) async {
    await seed();
    await pump(tester);
    expect(find.text('How this goal is covered (by weight)'), findsOneWidget);
    expect(textOf(tester, 'goal_coverage_outside'), 'In what you use: 50%');
    expect(textOf(tester, 'goal_coverage_app_only'), 'Not in what you use, but LearningApp has lessons: 25%');
    expect(textOf(tester, 'goal_coverage_nothing'), 'Not covered by anything yet: 25%');
  });

  testWidgets('without LearningApp content data only the outside split is shown', (tester) async {
    await seed();
    await pump(tester, matrixFails: true);
    expect(textOf(tester, 'goal_coverage_outside'), 'In what you use: 50%');
    expect(textOf(tester, 'goal_coverage_rest'), 'Not in what you use: 50%');
    expect(find.byKey(const Key('goal_coverage_app_only')), findsNothing);
    await tester.tap(find.byKey(const Key('goal_coverage_gaps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal_gaps_app_unknown')), findsOneWidget);
    expect(find.byKey(const Key('gap_open_2.1')), findsNothing);
  });

  testWidgets('the gaps screen offers a lesson, or a request where nothing exists', (tester) async {
    await seed();
    await pump(tester);
    await tester.tap(find.byKey(const Key('goal_coverage_gaps')));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'goal_gaps_intro'), 'These objectives are not in anything you added for this goal.');
    // 2.1: LearningApp has a lesson.
    expect(find.text('LearningApp can fill these (1)'), findsOneWidget);
    expect(find.byKey(const Key('gap_open_2.1')), findsOneWidget);
    // 2.2: nothing anywhere, so make your own or ask.
    expect(find.text('Not covered by anything yet (1)'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('goal_gaps_nothing')), matching: find.byKey(const Key('gap_ask_2.2'))),
      findsOneWidget,
    );
    expect(find.byKey(const Key('gap_make_own_2.2')), findsOneWidget);
    expect(find.byKey(const Key('gap_open_2.2')), findsNothing);
    // 1.2 is studied outside but has no independent check; 1.1 has them.
    expect(find.text("LearningApp can't check these yet (1)"), findsOneWidget);
    final uncheckable = find.byKey(const Key('goal_gaps_uncheckable'));
    expect(find.descendant(of: uncheckable, matching: find.text('1.2 Radicals')), findsOneWidget);
    expect(find.descendant(of: uncheckable, matching: find.text('In: My course')), findsOneWidget);
    expect(find.descendant(of: uncheckable, matching: find.text('1.1 Exponents')), findsNothing);
    expect(find.textContaining("can't count toward readiness yet"), findsOneWidget);
  });

  testWidgets('full coverage says so and lists no gaps', (tester) async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: 'Everything', kind: LearnerResourceKind.book);
    await store.setObjectives(id, {'1.1', '1.2', '2.1', '2.2'});
    await pump(tester);
    expect(textOf(tester, 'goal_coverage_outside'), 'In what you use: 100%');
    await tester.tap(find.byKey(const Key('goal_coverage_gaps')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'goal_gaps_intro'), 'What you use covers every objective of this goal.');
    expect(find.byKey(const Key('goal_gaps_app_only')), findsNothing);
    expect(find.byKey(const Key('goal_gaps_nothing')), findsNothing);
  });

  testWidgets('a covered objective offers a check only when LearningApp has a lesson for it', (tester) async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: 'My course', kind: LearnerResourceKind.course);
    await store.setObjectives(id, {'1.1', '1.2', '2.2'});
    await pump(tester);
    await tester.tap(find.text('My course'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('check_1.1')), matching: find.text('Check this in LearningApp')),
        findsOneWidget);
    // 1.2 has a lesson but no independent checks: that is practice, not a check.
    expect(find.descendant(of: find.byKey(const Key('check_1.2')), matching: find.text('Practise this in LearningApp')),
        findsOneWidget);
    // 2.2 is covered by the resource, but LearningApp has nothing to check it with.
    expect(find.byKey(const Key('check_2.2')), findsNothing);
    // 2.1 has a lesson but is not covered by this resource.
    expect(find.byKey(const Key('check_2.1')), findsNothing);
    expect(find.byKey(const Key('learner_resource_gaps')), findsOneWidget);
  });

  testWidgets('the summary and gaps screen meet tap-target, label and contrast guidelines at phone width', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await seed();
    await pump(tester);
    tester.view.physicalSize = const Size(360, 2600);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byKey(const Key('goal_coverage_gaps')));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
