import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/services/planning/readiness_projection.dart';
import 'package:learning_pwa/widgets/progress/readiness_projection_card.dart';

// Projected finish card (ingestion plan v1.2 §8.7).
void main() {
  Future<void> pump(WidgetTester tester, ReadinessProjection? p) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [readinessProjectionProvider('v1').overrideWith((ref) async => p)],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ReadinessProjectionCard(targetVersionId: 'v1'))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  ReadinessProjection projection({
    int low = 300,
    int high = 600,
    DateTime? exam,
    int? perDay,
    double unavailable = 0,
    bool dates = true,
  }) =>
      ReadinessProjection(
        remainingLow: low,
        remainingHigh: high,
        finishEarliest: dates && high > 0 ? DateTime(2026, 12, 9) : null,
        finishLatest: dates && high > 0 ? DateTime(2026, 12, 24) : null,
        dailyGoalMinutes: 20,
        minutesPerDayForExam: perDay,
        examDate: exam,
        unavailableShare: unavailable,
      );

  testWidgets('nothing is shown while off or unreadable', (tester) async {
    await pump(tester, null);
    expect(find.byKey(const Key('readiness_projection_card')), findsNothing);
  });

  testWidgets('shows time left, a date range and the estimate note', (tester) async {
    await pump(tester, projection());
    expect(find.text('Projected finish'), findsOneWidget);
    expect(find.text('Study time left: about 5 hours to about 10 hours.'), findsOneWidget);
    expect(find.textContaining('At your daily goal of 20 minutes'), findsOneWidget);
    expect(find.textContaining('between'), findsOneWidget);
    expect(find.byKey(const Key('projection_note')), findsOneWidget);
    expect(find.textContaining("isn't a promise of exam readiness"), findsOneWidget);
    expect(find.byKey(const Key('projection_exam')), findsNothing);
    expect(find.byKey(const Key('projection_unavailable')), findsNothing);
  });

  testWidgets('a tight exam date asks for more minutes a day; missing content is named', (tester) async {
    await pump(tester, projection(exam: DateTime(2026, 12, 1), perDay: 85, unavailable: 0.4));
    expect(find.textContaining('plan on about 85 minutes a day'), findsOneWidget);
    expect(find.textContaining("40% of this target isn't in LearningApp yet"), findsOneWidget);
  });

  testWidgets('an exam after the slower estimate says it is on track', (tester) async {
    await pump(tester, projection(exam: DateTime(2027, 2, 1), perDay: 10));
    expect(find.textContaining("That's before your exam"), findsOneWidget);
  });

  testWidgets('nothing left says so, with no dates', (tester) async {
    await pump(tester, projection(low: 0, high: 0));
    expect(find.byKey(const Key('projection_done')), findsOneWidget);
    expect(find.byKey(const Key('projection_dates')), findsNothing);
  });
}
