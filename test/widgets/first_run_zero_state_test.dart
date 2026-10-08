import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/next_action_provider.dart';
import 'package:learning_pwa/providers/router_provider.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer container() => ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _StubAuthNotifier(GuestMode())),
          learningBootstrapProvider.overrideWith((ref) async {}),
          learningContextsProvider.overrideWith(
            (ref) => LearningContextsNotifier.stub(
              const LearningContextsState(),
            ),
          ),
          nextActionProvider.overrideWith(
            (ref) async => const ChooseSomething(),
          ),
          activeDueCountProvider.overrideWith((ref) async => 0),
        ],
      );

  testWidgets('fresh first visit renders Learn zero state without setup writes',
      (tester) async {
    final scope = container();
    addTearDown(scope.dispose);
    final router = scope.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What do you want to learn?'), findsOneWidget);
    expect(find.text('Find something to learn'), findsOneWidget);
    expect(find.text('Create your own →'), findsOneWidget);
    expect(find.text('Set Your Daily Goal'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasCompletedOnboarding'), isNull);
    expect(prefs.getInt('dailyGoalMinutes'), isNull);
  });

  testWidgets('legacy onboarding URL redirects to Learn', (tester) async {
    final scope = container();
    addTearDown(scope.dispose);
    final router = scope.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/onboarding');
    await tester.pumpAndSettle();

    expect(find.text('What do you want to learn?'), findsOneWidget);
    expect(find.text('Set Your Daily Goal'), findsNothing);
  });
}

class _StubAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _StubAuthNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
