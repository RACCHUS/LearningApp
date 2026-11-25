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
];

const readiness = TargetObjectiveReadiness(
  signedIn: true,
  weightsEditorial: false,
  minHeldOutItems: 6,
  domains: [
    DomainReadiness(
      code: '1',
      title: 'Algebra',
      weightShare: 0.5,
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

Future<void> pump(WidgetTester tester, {bool enabled = true, bool account = false}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        learnerResourcesEnabledProvider.overrideWithValue(enabled),
        learnerResourcesUseAccountProvider.overrideWithValue(account),
        learnerResourceStoreProvider.overrideWithValue(LocalLearnerResourceStore()),
        targetCurriculumNodesProvider.overrideWith((ref, id) async => nodes),
        objectiveReadinessProvider.overrideWith((ref, id) async => readiness),
        // No published Coverage Matrix here; goal_coverage_flow_test covers it.
        targetCoverageProvider.overrideWith((ref, slug) async => CoverageSummary([])),
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

Future<void> addResource(WidgetTester tester, {String title = 'My video course', String link = ''}) async {
  await tester.tap(find.byKey(const Key('learner_resources_add')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('learner_resource_title')), title);
  await tester.enterText(find.byKey(const Key('learner_resource_link')), link);
  await tester.tap(find.byKey(const Key('learner_resource_save')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with the switch off the card takes no space and reads nothing', (tester) async {
    await pump(tester, enabled: false);
    expect(find.byKey(const Key('learner_resources_card')), findsNothing);
    expect(find.byKey(const Key('learner_resources_add')), findsNothing);
  });

  testWidgets('a name is required and a bad link is explained', (tester) async {
    await pump(tester);
    await addResource(tester, title: '', link: 'http://example.org');
    expect(find.text('Give it a name.'), findsOneWidget);
    expect(find.textContaining('https://'), findsWidgets);
    expect(await LocalLearnerResourceStore().list('t1'), isEmpty);
  });

  testWidgets('adding a resource opens it with nothing covered and the self-report note', (tester) async {
    await pump(tester);
    await addResource(tester, link: 'example.org/course?utm_source=x');
    expect(find.text('My video course'), findsOneWidget);
    expect(find.text('https://example.org/course'), findsOneWidget);
    expect(find.text('Open (leaves LearningApp)'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('learner_resource_summary'))).data,
      startsWith('Covers 0 of 3 objectives, about 0% of this goal by weight.'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('learner_resource_self_report_note'))).data,
      contains("Only LearningApp's checks count toward readiness."),
    );
    expect(find.byKey(const Key('studied_1.1')), findsNothing);
  });

  testWidgets('ticking covers an objective; studied is a separate self-report', (tester) async {
    await pump(tester);
    await addResource(tester);
    await tester.tap(find.byKey(const Key('covers_1.1')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('learner_resource_summary'))).data,
      startsWith('Covers 1 of 3 objectives, about 25% of this goal by weight. 0 marked studied.'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('learner_resource_uncovered_note'))).data,
      startsWith('2 objectives are not covered by this.'),
    );

    await tester.tap(find.byKey(const Key('studied_1.1')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('learner_resource_summary'))).data,
      endsWith('1 marked studied.'),
    );
    // Marking studied does not change what LearningApp's own checks say.
    expect(tester.widget<Text>(find.byKey(const Key('readiness_1.1'))).data, 'LearningApp checks: Not started');

    final saved = (await LocalLearnerResourceStore().list('t1')).single;
    expect(saved.objectives.keys, ['1.1']);
    expect(saved.objectives['1.1'], isNotNull);
  });

  testWidgets('the resource screen meets tap-target, label and contrast guidelines at phone width', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    tester.view.physicalSize = const Size(360, 2400);
    await addResource(tester, link: 'example.org');
    await tester.tap(find.byKey(const Key('covers_1.1')));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('unticking removes the objective and its studied chip', (tester) async {
    await pump(tester);
    await addResource(tester);
    await tester.tap(find.byKey(const Key('covers_2.1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('covers_2.1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('studied_2.1')), findsNothing);
    expect((await LocalLearnerResourceStore().list('t1')).single.objectives, isEmpty);
  });

  testWidgets('the card lists the resource and removing it asks first', (tester) async {
    await pump(tester);
    await addResource(tester);
    await tester.tap(find.byKey(const Key('learner_resource_remove')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your LearningApp progress is not affected.'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('Course · covers 0 · 0 marked studied'), findsOneWidget);

    await tester.tap(find.text('My video course'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('learner_resource_remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('learner_resource_confirm_remove')));
    await tester.pumpAndSettle();
    expect(find.text('My video course'), findsNothing);
    expect(await LocalLearnerResourceStore().list('t1'), isEmpty);
  });

  testWidgets('resources left on the device are offered to the account, never moved silently', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalLearnerResourceStore().save(
      targetId: 't1',
      title: 'Guest book',
      kind: LearnerResourceKind.book,
    );
    await pump(tester, account: true);
    expect(
      tester.widget<Text>(find.byKey(const Key('learner_resources_stranded'))).data,
      '1 saved on this device is not in your account yet.',
    );
    expect(find.byKey(const Key('learner_resources_move')), findsOneWidget);
    expect((await LocalLearnerResourceStore().listAll()).length, 1);
  });
}
