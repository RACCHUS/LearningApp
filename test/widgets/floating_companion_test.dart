import 'dart:io';

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
import 'package:learning_pwa/screens/companion/companion_screen.dart';
import 'package:learning_pwa/services/companion/floating_companion.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the browser window: records what it was asked to show.
class FakeFloatingWindow implements FloatingWindow {
  FakeFloatingWindow({this.supported = true, this.refuses = false});

  @override
  final bool supported;
  final bool refuses;
  final shown = <FloatingContent>[];
  void Function()? onDone;
  bool _open = false;

  @override
  bool get isOpen => _open;

  @override
  Future<bool> open(
    FloatingContent content, {
    required void Function() onDone,
    required void Function() onClosed,
  }) async {
    if (refuses) return false;
    _open = true;
    this.onDone = onDone;
    shown.add(content);
    return true;
  }

  @override
  void update(FloatingContent content) {
    if (_open) shown.add(content);
  }

  @override
  void close() => _open = false;
}

const goal = (targetId: 't1', targetVersionId: 'v1', targetSlug: 's1');

final nodes = [
  CurriculumNode(
    id: 'd1',
    targetVersionId: 'v1',
    nodeType: 'domain',
    title: 'Algebra',
    sortOrder: 1,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  CurriculumNode(
    id: 'o1',
    targetVersionId: 'v1',
    parentId: 'd1',
    nodeType: 'objective',
    title: 'Exponents',
    code: '1.1',
    sortOrder: 1,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

Future<String> seed({bool outline = true}) async {
  final store = LocalLearnerResourceStore();
  final id = await store.save(
    targetId: 't1',
    title: 'My course',
    kind: LearnerResourceKind.course,
  );
  if (outline) {
    await store.setSections(id, const [
      ResourceSection(
        title: 'Unit 1: Powers',
        objectiveKeys: {'1.1'},
        minutes: 25,
      ),
      ResourceSection(title: 'Unit 2: Wrap-up'),
    ]);
  }
  return id;
}

Future<void> pump(WidgetTester tester, String id, FloatingWindow window) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        learnerResourcesEnabledProvider.overrideWithValue(true),
        companionEmbedsEnabledProvider.overrideWithValue(false),
        floatingWindowProvider.overrideWithValue(window),
        learnerResourcesUseAccountProvider.overrideWithValue(false),
        learnerResourceStoreProvider.overrideWithValue(
          LocalLearnerResourceStore(),
        ),
        targetCurriculumNodesProvider.overrideWith((ref, id) async => nodes),
        objectiveReadinessProvider.overrideWith((ref, id) async => null),
        targetCoverageProvider.overrideWith(
          (ref, slug) async => CoverageSummary([]),
        ),
      ],
      child: MaterialApp(
        home: CompanionScreen(goal: goal, resourceId: id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'the window shows the first unstudied part and what to look for, or that all is done',
    () {
      const labels = {'1.1': '1.1 Exponents', '1.2': '1.2 Radicals'};
      LearnerResource resource(List<ResourceSection> sections) =>
          LearnerResource(
            id: 'r',
            targetId: 't1',
            title: 'My course',
            kind: LearnerResourceKind.course,
            sections: sections,
          );
      final studied = const ResourceSection(
        title: 'A',
      ).copyWith(studiedAt: () => DateTime(2026));
      final c = FloatingContent.of(
        resource([
          studied,
          const ResourceSection(
            title: 'B',
            objectiveKeys: {'1.2', '1.1', 'gone'},
            minutes: 40,
          ),
          const ResourceSection(title: 'C'),
        ]),
        labels,
      );
      expect(c.partTitle, 'B');
      expect(c.minutes, 40);
      expect(c.lookFor, [
        '1.1 Exponents',
        '1.2 Radicals',
      ], reason: 'in the goal order; unknown keys are left out');
      expect(c.partsLeft, 2);
      expect(c.allDone, isFalse);

      final done = FloatingContent.of(resource([studied]), labels);
      expect(done.allDone, isTrue);
      expect(done.resourceTitle, 'My course');
    },
  );

  testWidgets(
    'where the browser has no floating window the button is not shown at all',
    (tester) async {
      await pump(tester, await seed(), FakeFloatingWindow(supported: false));
      expect(find.byKey(const Key('companion_float')), findsNothing);
    },
  );

  testWidgets('without an outline there is nothing to float', (tester) async {
    await pump(tester, await seed(outline: false), FakeFloatingWindow());
    expect(find.byKey(const Key('companion_float')), findsNothing);
  });

  testWidgets(
    'the button opens the window on the current part; Done there moves both on',
    (tester) async {
      final window = FakeFloatingWindow();
      await pump(tester, await seed(), window);
      await tester.tap(find.byKey(const Key('companion_float')));
      await tester.pumpAndSettle();
      expect(window.isOpen, isTrue);
      expect(window.shown.last.partTitle, 'Unit 1: Powers');
      expect(window.shown.last.minutes, 25);
      expect(window.shown.last.lookFor, ['1.1 Exponents']);

      // "Done studying this part" pressed in the floating window.
      await tester.runAsync(() async => window.onDone!());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(window.shown.last.partTitle, 'Unit 2: Wrap-up');
      final saved = (await LocalLearnerResourceStore().list('t1')).single;
      expect(saved.sections.first.studied, isTrue);
      expect(saved.nextSectionIndex, 1);
      expect(
        find.byKey(const Key('companion_done_1')),
        findsOneWidget,
        reason: 'the main screen moved on too',
      );
    },
  );

  testWidgets('marking a part on the main screen updates an open window', (
    tester,
  ) async {
    final window = FakeFloatingWindow();
    await pump(tester, await seed(), window);
    await tester.tap(find.byKey(const Key('companion_float')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('companion_done_0')));
    await tester.pumpAndSettle();
    expect(window.shown.last.partTitle, 'Unit 2: Wrap-up');
    await tester.tap(find.byKey(const Key('companion_done_1')));
    await tester.pumpAndSettle();
    expect(window.shown.last.allDone, isTrue);
  });

  testWidgets(
    'if the browser refuses, the learner is told and nothing else changes',
    (tester) async {
      final window = FakeFloatingWindow(refuses: true);
      await pump(tester, await seed(), window);
      await tester.tap(find.byKey(const Key('companion_float')));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't open the floating window in this browser."),
        findsOneWidget,
      );
      expect(window.isOpen, isFalse);
      expect(
        (await LocalLearnerResourceStore().list(
          't1',
        )).single.studiedSectionCount,
        0,
      );
    },
  );

  testWidgets('the button has a label and a full-size tap target', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, await seed(), FakeFloatingWindow());
    expect(
      find.byTooltip('Float a small window beside what you are studying'),
      findsOneWidget,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  test(
    'the clock says when the planned time for a part is up, and only then',
    () {
      expect(
        floatingClockText(const Duration(minutes: 9, seconds: 5), 10),
        'Time on this part: 9:05',
      );
      expect(
        plannedTimeUp(const Duration(minutes: 9, seconds: 59), 10),
        isFalse,
      );
      expect(plannedTimeUp(const Duration(minutes: 10), 10), isTrue);
      expect(
        floatingClockText(const Duration(minutes: 10, seconds: 1), 10),
        'Time on this part: 10:01 (planned 10 min)',
      );
      expect(
        floatingClockText(const Duration(minutes: 95), null),
        'Time on this part: 95:00',
        reason: 'no estimate, no reminder',
      );
      expect(plannedTimeUp(const Duration(hours: 3), 0), isFalse);
      expect(
        plannedTimeUpMessage('2.1 Linear equations', 80),
        'Your planned 1 h 20 min for "2.1 Linear equations" is up. Mark it done when you finish, then check yourself.',
      );
    },
  );

  test('the reminder needs no permission prompt and stores nothing', () {
    final web = File(
      'lib/services/companion/floating_companion_web.dart',
    ).readAsStringSync();
    expect(
      web.contains('requestPermission'),
      isFalse,
      reason: 'it must never ask for notification permission',
    );
    for (final banned in [
      'localStorage',
      'SharedPreferences',
      'rpc(',
      'fetch(',
    ]) {
      expect(
        web.contains(banned),
        isFalse,
        reason: 'the floating window must not use $banned',
      );
    }
  });
}
