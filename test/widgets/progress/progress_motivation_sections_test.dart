import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/retrieval_state.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/daily_goal_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/screens/progress/progress_dashboard_screen.dart';
import 'package:learning_pwa/screens/progress/progress_screen.dart';
import 'package:learning_pwa/widgets/daily_goal_ring.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helper.dart';

/// Progress Activity/Motivation honour the Settings motivation switches
/// (UI_ARCHITECTURE_LOCKED section 5.5 and the section 10 migration map):
/// the daily goal ring lives in Activity and is hidden when the goal is off;
/// XP and levels are not awarded anywhere yet, so Progress says so instead
/// of showing a permanent zero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestHelper.initializeSupabase();
  });

  Future<void> pumpProgress(
    WidgetTester tester, {
    required Map<String, Object> motivation,
  }) async {
    SharedPreferences.setMockInitialValues(motivation);
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _StubAuthNotifier(GuestMode())),
        learningContextsProvider.overrideWith(
          (ref) => LearningContextsNotifier.stub(const LearningContextsState()),
        ),
        dashboardProgressProvider.overrideWith(
          (ref) async => const DashboardProgress(currentStreak: 3, longestStreak: 7),
        ),
        retentionSummaryProvider.overrideWith(
          (ref) async => RetrievalSummary.from(const []),
        ),
        dailyGoalProgressProvider.overrideWith(
          (ref) async => DailyGoalProgress(
            studyMinutesToday: 12,
            studySecondsToday: 720,
            goalMinutes: 20,
          ),
        ),
      ],
      child: const MaterialApp(home: ProgressScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Knowledge'));
    await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester, String section) async {
    await tester.ensureVisible(find.text(section));
    await tester.tap(find.text(section));
    await tester.pumpAndSettle();
  }

  testWidgets('daily goal ring shows in Activity when the goal is on',
      (tester) async {
    await pumpProgress(tester, motivation: {'motivation.dailyGoal': true});
    await expand(tester, 'Activity');

    expect(find.byType(DailyGoalRingLarge), findsOneWidget);
    expect(find.text('Daily Goal (this device)'), findsOneWidget);
    expect(find.text('8m remaining'), findsOneWidget);
  });

  testWidgets('daily goal ring is hidden when the goal is off',
      (tester) async {
    await pumpProgress(tester, motivation: {'motivation.dailyGoal': false});
    await expand(tester, 'Activity');

    expect(find.byType(DailyGoalRingLarge), findsNothing);
    expect(find.text('Study time'), findsOneWidget);
  });

  testWidgets('daily goal alone does not show an empty Motivation section',
      (tester) async {
    await pumpProgress(tester, motivation: {
      'motivation.dailyGoal': true,
      'motivation.xp': false,
      'motivation.levels': false,
      'motivation.streaks': false,
    });
    expect(find.text('Motivation'), findsNothing);
  });

  testWidgets('XP or levels on says they are not tracked, never a zero',
      (tester) async {
    await pumpProgress(tester, motivation: {
      'motivation.xp': true,
      'motivation.levels': true,
      'motivation.streaks': false,
    });
    await expand(tester, 'Motivation');

    expect(find.text('XP and levels are not tracked yet.'), findsOneWidget);
    expect(find.text('Current streak'), findsNothing);
  });

  testWidgets('streaks keep their rows; no XP note when XP and levels are off',
      (tester) async {
    await pumpProgress(tester, motivation: {
      'motivation.xp': false,
      'motivation.levels': false,
      'motivation.streaks': true,
    });
    await expand(tester, 'Motivation');

    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('XP and levels are not tracked yet.'), findsNothing);
  });
}

class _StubAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _StubAuthNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
