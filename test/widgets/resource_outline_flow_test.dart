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
import 'package:learning_pwa/screens/companion/learner_resource_screen.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
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
  node('d2', 'Functions', order: 2),
  node('o1', 'Exponents', parent: 'd1', code: '1.1', order: 1),
  node('o2', 'Radicals', parent: 'd1', code: '1.2', order: 2),
  node('o3', 'Graphs', parent: 'd2', code: '2.1', order: 1),
];

const readiness = TargetObjectiveReadiness(
  signedIn: false,
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

const goal = (targetId: 't1', targetVersionId: 'v1', targetSlug: 's1');

Future<void> pump(
  WidgetTester tester, {
  double width = 900,
  List<ResourceSection> sections = const [],
}) async {
  final store = LocalLearnerResourceStore();
  final id = await store.save(
    targetId: 't1',
    title: 'My course',
    kind: LearnerResourceKind.course,
  );
  if (sections.isNotEmpty) await store.setSections(id, sections);
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
      child: MaterialApp(
        home: LearnerResourceScreen(goal: goal, resourceId: id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pasteAndMatch(WidgetTester tester, String text) async {
  await tester.tap(find.byKey(const Key('learner_resource_outline')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('outline_paste')), text);
  await tester.tap(find.byKey(const Key('outline_match')));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an empty paste is explained and nothing is proposed', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Paste its outline to tick faster'), findsOneWidget);
    await pasteAndMatch(tester, '  \n 12 \n');
    expect(find.textContaining('one per line'), findsWidgets);
    expect(find.byKey(const Key('outline_save')), findsNothing);
  });

  testWidgets(
    'pasting proposes objectives by word match, labelled as unreviewed, and saving ticks them',
    (tester) async {
      await pump(tester);
      await pasteAndMatch(
        tester,
        'Chapter 1: Exponents\nChapter 2: Functions\nChapter 3: Study skills',
      );
      expect(
        textOf(tester, 'outline_summary'),
        '3 parts, 2 matched to objectives',
      );
      expect(
        textOf(tester, 'outline_unreviewed_note'),
        contains('Nobody has reviewed them.'),
      );
      expect(
        textOf(tester, 'outline_unreviewed_note'),
        contains('It does not mark anything studied'),
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('outline_0_1.1')))
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('outline_1_2.1')))
            .value,
        isTrue,
      );
      expect(find.text('Nothing matched by words.'), findsOneWidget);
      expect(find.text('1. Chapter 1: Exponents'), findsOneWidget);

      await tester.tap(find.byKey(const Key('outline_save')));
      await tester.pumpAndSettle();

      final saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect(
        [for (final s in saved.sections) s.title],
        [
          'Chapter 1: Exponents',
          'Chapter 2: Functions',
          'Chapter 3: Study skills',
        ],
      );
      expect(
        [for (final s in saved.sections) s.source.wire],
        ['outline_match', 'outline_match', 'learner'],
      );
      expect(saved.objectives.keys.toSet(), {'1.1', '2.1'});
      expect(saved.studiedCount, 0);

      // Back on the resource: the tick shows where it is, and readiness is untouched.
      expect(textOf(tester, 'sections_1.1'), 'In: Chapter 1: Exponents');
      expect(
        textOf(tester, 'readiness_1.1'),
        'LearningApp checks: Not started',
      );
      expect(find.text('Edit outline (3 parts)'), findsOneWidget);
    },
  );

  testWidgets(
    'a length in the pasted line fills the minutes, and the learner can change it',
    (tester) async {
      await pump(tester);
      await pasteAndMatch(
        tester,
        'Chapter 1: Exponents (12:30)\nChapter 2: Functions',
      );
      expect(find.text('13'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('outline_minutes_1_1')),
        '45',
      );
      await tester.tap(find.byKey(const Key('outline_save')));
      await tester.pumpAndSettle();
      final saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect([for (final s in saved.sections) s.minutes], [13, 45]);
      expect(saved.sections.first.title, 'Chapter 1: Exponents');
      expect(
        find.textContaining('Continue: Chapter 1: Exponents'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the learner can untick a suggestion and choose from all objectives',
    (tester) async {
      await pump(tester);
      await pasteAndMatch(
        tester,
        'Chapter 1: Exponents\nChapter 3: Study skills',
      );
      await tester.tap(find.byKey(const Key('outline_0_1.1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('outline_choose_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('outline_pick_1.2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('outline_pick_done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('outline_save')));
      await tester.pumpAndSettle();

      final saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect(saved.sections[0].objectiveKeys, isEmpty);
      expect(saved.sections[0].source, SectionMapSource.learner);
      expect(saved.sections[1].objectiveKeys, {'1.2'});
      expect(saved.objectives.keys.toSet(), {'1.2'});
    },
  );

  testWidgets(
    'an answer from the learner\'s own AI is checked, applied as a proposal and labelled',
    (tester) async {
      await pump(tester);
      await pasteAndMatch(tester, 'Chapter 1: Powers\nChapter 2: Roots');
      expect(
        textOf(tester, 'outline_summary'),
        '2 parts, 0 matched to objectives',
      );
      await tester.tap(find.text('Get a second opinion from your own AI chat'));
      await tester.pumpAndSettle();
      expect(
        find.text('Optional. LearningApp does not connect to any AI.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SelectableText>(find.byKey(const Key('outline_ai_prompt')))
            .data,
        contains('O1: 1.1 Exponents'),
      );

      await tester.enterText(
        find.byKey(const Key('outline_ai_response')),
        'Sure! Chapter 1 is about exponents.',
      );
      await tester.tap(find.byKey(const Key('outline_ai_check')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("doesn't look like the answer"),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('outline_ai_response')),
        '{"format":"la-resource-map/1","sections":[{"n":1,"objectives":["O1","O42"]},{"n":2,"objectives":["O2"]}]}',
      );
      await tester.tap(find.byKey(const Key('outline_ai_check')));
      await tester.pumpAndSettle();
      expect(
        textOf(tester, 'outline_ai_result'),
        'Used the answer for 2 of 2 parts. 1 entry was left out because it is not in your lists. '
        'An AI can be wrong, so check each part below before you save.',
      );
      expect(
        textOf(tester, 'outline_summary'),
        '2 parts, 2 matched to objectives',
      );

      await tester.tap(find.byKey(const Key('outline_save')));
      await tester.pumpAndSettle();
      final saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect(
        [for (final s in saved.sections) s.source.wire],
        ['own_ai', 'own_ai'],
      );
      expect(saved.objectives.keys.toSet(), {'1.1', '1.2'});
    },
  );

  testWidgets(
    'a saved outline can be edited or removed, and removing keeps the ticks',
    (tester) async {
      await pump(
        tester,
        sections: const [
          ResourceSection(title: 'Unit 1', objectiveKeys: {'1.1', 'gone'}),
        ],
      );
      await tester.tap(find.text('Edit outline (1 part)'));
      await tester.pumpAndSettle();
      expect(
        textOf(tester, 'outline_summary'),
        '1 part, 1 matched to objectives',
      );
      expect(
        find.byKey(const Key('outline_0_gone')),
        findsNothing,
        reason: 'a key the goal no longer has is not shown',
      );

      await tester.tap(find.byKey(const Key('outline_remove')));
      await tester.pumpAndSettle();
      final saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect(saved.sections, isEmpty);
      expect(saved.objectives.containsKey('1.1'), isTrue);
    },
  );

  testWidgets(
    'the outline screen meets tap-target, label and contrast guidelines at phone width',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, width: 360);
      await pasteAndMatch(tester, 'Chapter 1: Exponents\nChapter 2: Functions');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );
}
