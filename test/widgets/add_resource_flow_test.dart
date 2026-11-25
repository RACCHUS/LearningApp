import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/screens/companion/add_resource_screen.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const goals = <CaptureGoal>[
  (targetId: 't1', label: 'CLEP College Algebra'),
  (targetId: 't2', label: 'GRE General Test'),
];

Future<void> pump(
  WidgetTester tester, {
  String? url,
  String? title,
  bool enabled = true,
  List<CaptureGoal> withGoals = goals,
  double width = 900,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        companionCaptureEnabledProvider.overrideWithValue(enabled),
        captureGoalsProvider.overrideWithValue(withGoals),
        learnerResourcesEnabledProvider.overrideWithValue(true),
        learnerResourcesUseAccountProvider.overrideWithValue(false),
        learnerResourceStoreProvider.overrideWithValue(
          LocalLearnerResourceStore(),
        ),
      ],
      child: MaterialApp(
        home: AddResourceScreen(
          initialUrl: url,
          initialTitle: title,
          appOrigin: 'https://app.example',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a captured title is plain text: control characters out, spaces collapsed, capped',
    () {
      expect(
        cleanCapturedTitle('  Algebra\u0000\n\tUnit  1 '),
        'Algebra Unit 1',
      );
      expect(cleanCapturedTitle(null), '');
      expect(cleanCapturedTitle('x' * 500).length, 200);
    },
  );

  test(
    'the bookmarklet keeps the page link in the fragment, so no server sees it',
    () {
      final b = captureBookmarklet('https://app.example');
      expect(b, startsWith('javascript:'));
      final before = b.substring(0, b.indexOf('url='));
      expect(
        before,
        contains('https://app.example/#/add-resource?'),
        reason: 'the query comes after the #',
      );
      expect(b, contains('encodeURIComponent(location.href)'));
      expect(b, contains('encodeURIComponent(document.title)'));
    },
  );

  testWidgets('with the switch off it says so and offers no way to save', (
    tester,
  ) async {
    await pump(
      tester,
      url: 'https://example.org/course',
      title: 'A course',
      enabled: false,
    );
    expect(find.byKey(const Key('capture_unavailable')), findsOneWidget);
    expect(find.byKey(const Key('capture_save')), findsNothing);
    expect(find.byKey(const Key('capture_bookmarklet')), findsNothing);
    expect(find.byKey(const Key('help-action')), findsOneWidget);
    expect(await LocalLearnerResourceStore().listAll(), isEmpty);
  });

  testWidgets(
    'a captured link is cleaned on the device and nothing is saved until Add',
    (tester) async {
      await pump(
        tester,
        url: 'https://Example.org/course?utm_source=x&id=7',
        title: ' My  course\n',
      );
      expect(field(tester, 'capture_title'), 'My course');
      expect(field(tester, 'capture_link'), 'https://example.org/course?id=7');
      expect(
        tester.widget<Text>(find.byKey(const Key('capture_privacy_note'))).data,
        contains('Nothing is saved until you choose Add.'),
      );
      expect(await LocalLearnerResourceStore().listAll(), isEmpty);

      await tester.tap(find.byKey(const Key('capture_save')));
      await tester.pumpAndSettle();
      final saved = (await LocalLearnerResourceStore().listAll()).single;
      expect(
        saved.targetId,
        't1',
        reason: 'the first goal listed is the active one',
      );
      expect(saved.title, 'My course');
      expect(saved.url, 'https://example.org/course?id=7');
      expect(saved.objectives, isEmpty);
    },
  );

  testWidgets('a link that is not a plain https address is shown and refused', (
    tester,
  ) async {
    for (final bad in [
      'javascript:alert(1)',
      'http://example.org/x',
      'https://user:pw@example.org/',
      'data:text/html,x',
    ]) {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, url: bad, title: 'Bad');
      await tester.tap(find.byKey(const Key('capture_save')));
      await tester.pumpAndSettle();
      expect(await LocalLearnerResourceStore().listAll(), isEmpty, reason: bad);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the learner can pick another goal, and a name is required', (
    tester,
  ) async {
    await pump(tester, url: 'https://example.org/a');
    await tester.tap(find.byKey(const Key('capture_save')));
    await tester.pumpAndSettle();
    expect(find.text('Give it a name.'), findsOneWidget);
    expect(await LocalLearnerResourceStore().listAll(), isEmpty);

    await tester.enterText(find.byKey(const Key('capture_title')), 'Prep book');
    await tester.tap(find.text('CLEP College Algebra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GRE General Test').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture_save')));
    await tester.pumpAndSettle();
    expect((await LocalLearnerResourceStore().listAll()).single.targetId, 't2');
  });

  testWidgets('without a goal it asks for one and cannot save', (tester) async {
    await pump(
      tester,
      url: 'https://example.org/a',
      title: 'A',
      withGoals: const [],
    );
    expect(find.byKey(const Key('capture_no_goal')), findsOneWidget);
    expect(find.byKey(const Key('capture_find_goal')), findsOneWidget);
    expect(find.byKey(const Key('capture_save')), findsNothing);
  });

  testWidgets(
    'opened with no link it still works as a form and shows the bookmark to copy',
    (tester) async {
      await pump(tester);
      expect(field(tester, 'capture_link'), '');
      await tester.tap(find.text('Send a page here with one tap'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const Key('capture_bookmarklet')),
            )
            .data,
        captureBookmarklet('https://app.example'),
      );
    },
  );

  test(
    'goals for capture are the learner\'s goals only, the active one first, each once',
    () {
      LearningContext ctx(
        String id,
        ContextRootType type,
        String rootId,
        String label,
      ) => LearningContext(
        id: id,
        userId: 'u',
        label: label,
        rootType: type,
        rootId: rootId,
        lastActiveAt: DateTime(2026),
      );
      final container = ProviderContainer(
        overrides: [
          learningContextsProvider.overrideWith(
            (ref) => LearningContextsNotifier.stub(
              LearningContextsState(
                contexts: [
                  ctx('c1', ContextRootType.course, 'course-1', 'A course'),
                  ctx('c2', ContextRootType.target, 't2', 'GRE'),
                  ctx('c3', ContextRootType.target, 't1', 'CLEP'),
                  ctx('c4', ContextRootType.target, 't1', 'CLEP again'),
                ],
                activeId: 'c3',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(captureGoalsProvider), [
        (targetId: 't1', label: 'CLEP'),
        (targetId: 't2', label: 'GRE'),
      ]);
    },
  );

  testWidgets(
    'the form meets tap-target, label and contrast guidelines at phone width',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, url: 'https://example.org/a', title: 'A', width: 360);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );
}
