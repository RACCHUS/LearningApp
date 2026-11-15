import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/achievement.dart';
import 'package:learning_pwa/widgets/progress/motivation_xp_rows.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-of-session XP line (UI_ARCHITECTURE_LOCKED.md §9: XP appears only in
/// Progress and the session summary, and follows the motivation switches).
void main() {
  Future<void> pump(
    WidgetTester tester,
    ActivityXpResult? result, {
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: SessionXpSummary(result: result)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  const awarded = ActivityXpResult(
    status: 'awarded',
    awardedXp: 50,
    totalXp: 150,
    newAchievements: ['first_lesson'],
  );

  testWidgets('shows XP, a level reached and the new achievement',
      (tester) async {
    await pump(tester, awarded);
    expect(find.text('+50 XP'), findsOneWidget);
    expect(find.text('Level 2 reached'), findsOneWidget);
    expect(find.text('Achievement: First lesson'), findsOneWidget);
  });

  testWidgets('nothing when the learner has XP switched off', (tester) async {
    await pump(tester, awarded, prefs: {'motivation.xp': false});
    expect(find.byKey(const ValueKey('session-xp-summary')), findsNothing);
  });

  testWidgets('never shows +0 XP for a cooldown or limit', (tester) async {
    await pump(
      tester,
      const ActivityXpResult(
        status: 'already_processed',
        awardedXp: 0,
        totalXp: 300,
        newAchievements: [],
      ),
    );
    expect(find.textContaining('XP'), findsNothing);
  });

  testWidgets('nothing when the claim was refused or offline', (tester) async {
    await pump(tester, null);
    expect(find.byKey(const ValueKey('session-xp-summary')), findsNothing);
  });

  testWidgets('celebrations off keeps XP but drops the achievement line',
      (tester) async {
    await pump(tester, awarded, prefs: {'motivation.celebrations': false});
    expect(find.text('+50 XP'), findsOneWidget);
    expect(find.textContaining('Achievement:'), findsNothing);
  });

  testWidgets('levels off hides the level line', (tester) async {
    await pump(tester, awarded, prefs: {'motivation.levels': false});
    expect(find.text('+50 XP'), findsOneWidget);
    expect(find.textContaining('Level'), findsNothing);
  });
}
