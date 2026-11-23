import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/rescue_candidates_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

const lessonId = '11111111-2222-4333-8444-555555555555';
const otherId = '99999999-2222-4333-8444-555555555555';

const candidate = RescueCandidate(
  lessonId: otherId,
  title: 'Percent, another way',
  targetTitle: 'Prealgebra (open textbook)',
  sharedTags: ['percent'],
  reviewed: false,
  hasExample: true,
  hasPractice: true,
  hasCheck: false,
);

void main() {
  late BridgeLibrary library;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await BridgeLibrary.load(rootBundle);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester, {
    required List<String> tags,
    required Future<List<RescueCandidate>> Function(String) loader,
    String id = lessonId,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          appBar: AppBar(
            title: const Text('Lesson'),
            actions: [LearningHelpAction(lessonId: id, lessonTitle: 'Lesson', tags: tags)],
          ),
          body: const Text('Lesson body'),
        ),
      ),
      GoRoute(path: '/lesson/:id', builder: (_, s) => Text('opened ${s.pathParameters['id']}')),
      GoRoute(path: '/community/wanted', builder: (_, __) => const Text('wanted board')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        quickRescueEnabledProvider.overrideWith((ref) => true),
        bridgeLibraryProvider.overrideWith((ref) async => library),
        supportSessionStoreProvider.overrideWithValue(SupportSessionStore()),
        supportOwnerScopeProvider.overrideWithValue('user-a'),
        supportContextIdProvider.overrideWith((ref, id) => 'ctx-1'),
        supportStrategyProvider.overrideWithValue(PersistedLearningStrategy.fast),
        rescueCandidatesLoaderProvider.overrideWithValue(loader),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('no Bridge but another lesson on the topic: help offers it honestly', (tester) async {
    await pump(tester, tags: const ['history'], loader: (_) async => [candidate]);
    await tester.tap(find.byKey(const Key('learning_help_action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support_choice_no_bridge')), findsOneWidget);
    expect(find.text('Percent, another way'), findsOneWidget);
    expect(find.text('Prealgebra (open textbook) · Imported, not yet reviewed · has examples, practice'),
        findsOneWidget);
    expect(find.byKey(const Key('support_choice_ask_for_it')), findsOneWidget);

    await tester.tap(find.byKey(const Key('support_candidate_$otherId')));
    await tester.pumpAndSettle();
    expect(find.text('opened $otherId'), findsOneWidget);
  });

  testWidgets('"Ask for a short lesson" opens the Wanted Board', (tester) async {
    await pump(tester, tags: const ['history'], loader: (_) async => [candidate]);
    await tester.tap(find.byKey(const Key('learning_help_action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('support_choice_ask_for_it')));
    await tester.pumpAndSettle();
    expect(find.text('wanted board'), findsOneWidget);
  });

  testWidgets('with a Bridge, other lessons are listed after it and no "nothing yet"', (tester) async {
    await pump(tester, tags: const ['percent'], loader: (_) async => [candidate]);
    await tester.tap(find.byKey(const Key('learning_help_action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support_choice_bridge-percent-of-number')), findsOneWidget);
    expect(find.byKey(const Key('support_candidate_$otherId')), findsOneWidget);
    expect(find.byKey(const Key('support_choice_no_bridge')), findsNothing);
    expect(find.byKey(const Key('support_choice_ask_for_it')), findsNothing);
  });

  testWidgets('no Bridge and the lookup fails: no help button', (tester) async {
    await pump(tester, tags: const ['history'], loader: (_) async => throw Exception('offline'));
    expect(find.byKey(const Key('learning_help_action')), findsNothing);
  });

  testWidgets('bundled lessons are never looked up', (tester) async {
    var calls = 0;
    await pump(tester, tags: const ['history'], id: 'bundled-lesson', loader: (_) async {
      calls++;
      return [candidate];
    });
    expect(calls, 0);
    expect(find.byKey(const Key('learning_help_action')), findsNothing);
  });
}
