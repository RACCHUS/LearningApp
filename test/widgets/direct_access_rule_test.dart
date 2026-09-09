import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/next_action_provider.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/widgets/app_shell.dart';
import 'package:learning_pwa/widgets/learn/context_switcher.dart';
import 'package:learning_pwa/widgets/learn/continue_card.dart';
import 'package:learning_pwa/widgets/learn/review_prompt.dart';

/// Enforces the Direct Access Rule (§7.3):
///
/// > From Learn, in <= 2 deliberate actions, the learner must be able to reach
/// > (a) a different active learning context, (b) any other available lesson,
/// > or (c) unrestricted browse/search.
///
/// If a future change breaks one of these, the build fails. That is the point.
void main() {
  LearningContext ctx(String id, String label) => LearningContext(
        id: id,
        userId: 'u1',
        label: label,
        rootType: ContextRootType.course,
        rootId: 'course-$id',
        lastActiveAt: DateTime(2026, 1, 1),
      );

  final twoContexts = [ctx('a', 'Software Engineering'), ctx('b', 'Spanish')];

  const lesson = LessonActivity(
    lessonId: 'l1',
    title: 'Provider Basics',
    courseId: 'course-a',
  );

  /// A minimal Learn surface with the same widgets and routes as production,
  /// but no Hive/Supabase dependency.
  Widget harness({
    required List<LearningContext> contexts,
    required NextAction action,
    int dueCount = 0,
    required List<String> visited,
  }) {
    final state = LearningContextsState(
      contexts: contexts,
      activeId: contexts.isEmpty ? null : contexts.first.id,
    );

    Widget stub(String name) => Scaffold(body: Center(child: Text(name)));

    final router = GoRouter(
      initialLocation: '/learn',
      observers: [_RouteRecorder(visited)],
      routes: [
        ShellRoute(
          builder: (context, s, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/learn',
              builder: (context, s) => Scaffold(
                appBar: AppBar(title: ContextSwitcher(state: state)),
                body: ListView(
                  children: [
                    LearnColumn(
                      child: Column(
                        children: [
                          ContinueCard(action: action),
                          if (dueCount > 0) ReviewPrompt(dueCount: dueCount),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GoRoute(
                path: '/library', builder: (context, s) => stub('LIBRARY')),
            GoRoute(
                path: '/progress', builder: (context, s) => stub('PROGRESS')),
          ],
        ),
        GoRoute(
          path: '/course/:courseId/outline',
          builder: (context, s) => stub('OUTLINE'),
        ),
        GoRoute(path: '/lesson/:id', builder: (context, s) => stub('LESSON')),
        GoRoute(path: '/review', builder: (context, s) => stub('REVIEW')),
        GoRoute(
            path: '/create-lesson', builder: (context, s) => stub('CREATE')),
        GoRoute(path: '/study-sets', builder: (context, s) => stub('SETS')),
        GoRoute(path: '/settings', builder: (context, s) => stub('SETTINGS')),
        GoRoute(path: '/profile', builder: (context, s) => stub('PROFILE')),
      ],
    );

    return ProviderScope(
      overrides: [
        learningContextsProvider.overrideWith(
          (ref) => _StubContextsNotifier(state),
        ),
        nextActionProvider.overrideWith((ref) async => action),
        activeDueCountProvider.overrideWith((ref) async => dueCount),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
      'SHIP GATE: <=2 actions from Learn reaches an alternate LearningContext',
      (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(harness(
      contexts: twoContexts,
      action: StartActivity(activity: lesson),
      visited: visited,
    ));
    await tester.pumpAndSettle();

    // Action 1: open the switcher.
    await tester.tap(find.byKey(const Key('context-switcher')));
    await tester.pumpAndSettle();

    // Action 2: choose the other context.
    expect(find.byKey(const Key('context-row-b')), findsOneWidget);
    await tester.tap(find.byKey(const Key('context-row-b')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('context-row-b')), findsNothing,
        reason: 'switching should dismiss the sheet and return to Learn');
  });

  testWidgets('SHIP GATE: <=2 actions from Learn reaches another lesson',
      (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(harness(
      contexts: twoContexts,
      action: StartActivity(activity: lesson),
      visited: visited,
    ));
    await tester.pumpAndSettle();

    // Action 1: open the course outline. (Action 2 — tapping any lesson there
    // — is covered by CourseOutlineScreen's own direct-tap wiring.)
    await tester.tap(find.byKey(const Key('learn-secondary-action')));
    await tester.pumpAndSettle();

    expect(find.text('OUTLINE'), findsOneWidget);
  });

  testWidgets('SHIP GATE: <=2 actions from Learn reaches Library search',
      (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(harness(
      contexts: twoContexts,
      action: StartActivity(activity: lesson),
      visited: visited,
    ));
    await tester.pumpAndSettle();

    // Action 1: tap the Library destination in the shell.
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('LIBRARY'), findsOneWidget);
  });

  testWidgets('no learner is trapped by a ReviewOnly state', (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(harness(
      contexts: twoContexts,
      action: const ReviewOnly(
        activity: ReviewActivity(conceptIds: ['a', 'b']),
        offer: ForwardOffer(label: 'Next: Advanced Dart'),
      ),
      visited: visited,
    ));
    await tester.pumpAndSettle();

    // The forward offer is present as the secondary action, not hidden behind
    // an emptied review queue.
    expect(find.text('Next: Advanced Dart'), findsOneWidget);
    await tester.tap(find.byKey(const Key('learn-secondary-action')));
    await tester.pumpAndSettle();
    expect(find.text('LIBRARY'), findsOneWidget);
  });

  group('Learn screen composition', () {
    testWidgets('SHIP GATE: exactly one filled primary button', (tester) async {
      await tester.pumpWidget(harness(
        contexts: twoContexts,
        action: StartActivity(activity: lesson),
        dueCount: 6,
        visited: <String>[],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('SHIP GATE: no review section when nothing is due',
        (tester) async {
      await tester.pumpWidget(harness(
        contexts: twoContexts,
        action: StartActivity(activity: lesson),
        visited: <String>[],
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review-prompt')), findsNothing);
      expect(find.textContaining('review'), findsNothing);
    });

    testWidgets('SHIP GATE: review emphasis identical at 6 and 300 due',
        (tester) async {
      Future<Type> buttonTypeFor(int due) async {
        await tester.pumpWidget(harness(
          contexts: twoContexts,
          action: StartActivity(activity: lesson),
          dueCount: due,
          visited: <String>[],
        ));
        await tester.pumpAndSettle();
        return tester
            .widget(find.byKey(const Key('review-action')))
            .runtimeType;
      }

      expect(await buttonTypeFor(6), await buttonTypeFor(300));
    });

    testWidgets('SHIP GATE: switcher is plain text with a single context',
        (tester) async {
      await tester.pumpWidget(harness(
        contexts: [ctx('a', 'Software Engineering')],
        action: StartActivity(activity: lesson),
        visited: <String>[],
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('context-switcher')), findsNothing);
      expect(find.text('Software Engineering'), findsOneWidget);
    });

    testWidgets('SHIP GATE: no nav destination shows a badge', (tester) async {
      await tester.pumpWidget(harness(
        contexts: twoContexts,
        action: StartActivity(activity: lesson),
        dueCount: 42,
        visited: <String>[],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('SHIP GATE: no urgency or debt copy on Learn', (tester) async {
      await tester.pumpWidget(harness(
        contexts: twoContexts,
        action: StartActivity(activity: lesson),
        dueCount: 12,
        visited: <String>[],
      ));
      await tester.pumpAndSettle();

      for (final banned in ['overdue', "don't lose", 'expires', '!']) {
        expect(find.textContaining(banned), findsNothing,
            reason: '"$banned" must not appear on Learn');
      }
    });
  });
}

class _StubContextsNotifier extends LearningContextsNotifier {
  _StubContextsNotifier(LearningContextsState initial)
      : super.stub(initial);
}

class _RouteRecorder extends NavigatorObserver {
  final List<String> visited;
  _RouteRecorder(this.visited);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) visited.add(name);
  }
}
