import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/next_action_provider.dart';
import 'package:learning_pwa/models/retrieval_state.dart';
import 'package:learning_pwa/screens/learn/learn_screen.dart';
import 'package:learning_pwa/screens/library/library_screen.dart';
import 'package:learning_pwa/screens/progress/progress_dashboard_screen.dart';
import 'package:learning_pwa/screens/progress/progress_screen.dart';
import 'package:learning_pwa/screens/settings_screen.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/widgets/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestHelper.initializeSupabase();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app({AuthState? authState, String location = '/learn'}) {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/learn',
              builder: (context, state) => const LearnScreen(),
            ),
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
            ),
            GoRoute(
              path: '/progress',
              builder: (context, state) => const ProgressScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('LOGIN PAGE')),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Text('PROFILE PAGE'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => _StubAuthNotifier(authState ?? GuestMode()),
        ),
        learningBootstrapProvider.overrideWith((ref) async {}),
        learningContextsProvider.overrideWith(
          (ref) => LearningContextsNotifier.stub(const LearningContextsState()),
        ),
        nextActionProvider.overrideWith(
          (ref) async => const ChooseSomething(),
        ),
        activeDueCountProvider.overrideWith((ref) async => 0),
        availableLessonsCatalogProvider.overrideWith(
          (ref) async => const AvailableLessonsCatalog(lessons: []),
        ),
        dashboardProgressProvider.overrideWith(
          (ref) async => const DashboardProgress(),
        ),
        retentionSummaryProvider.overrideWith(
          (ref) async => RetrievalSummary.from(const []),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  User accountUser({bool anonymous = false}) => User(
        id: 'test-user',
        email: anonymous ? null : 'richardgurudeo@gmail.com',
        isAnonymous: anonymous,
        appMetadata: {'provider': anonymous ? 'anonymous' : 'google'},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
      );

  testWidgets('signed-out Learn header makes Log in visible', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('signed-out Settings choice survives leaving and returning',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final notifications =
        find.widgetWithText(SwitchListTile, 'Enable Notifications');
    expect(tester.widget<SwitchListTile>(notifications).value, isTrue);

    await tester.tap(notifications);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(notifications).value, isFalse);
  });

  testWidgets('signed-in avatar opens Profile and Settings', (tester) async {
    await tester.pumpWidget(app(authState: AuthSuccess(accountUser())));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LearnScreen)),
    );
    expect(container.read(authProvider), isA<AuthSuccess>());
    expect(find.text('Log in'), findsNothing);
    await tester.tap(find.byTooltip('Account: richardgurudeo@gmail.com'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE PAGE'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account: richardgurudeo@gmail.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('anonymous guest sees Log in and Settings', (tester) async {
    await tester.pumpWidget(
      app(authState: AuthSuccess(accountUser(anonymous: true))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('signed-out Library header exposes Log in and Settings',
      (tester) async {
    await tester.pumpWidget(app(location: '/library'));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('signed-in Progress header exposes the account menu',
      (tester) async {
    await tester.pumpWidget(
      app(location: '/progress', authState: AuthSuccess(accountUser())),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Account: richardgurudeo@gmail.com'),
        findsOneWidget);
  });
}

class _StubAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _StubAuthNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
