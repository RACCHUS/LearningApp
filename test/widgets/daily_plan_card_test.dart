import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/daily_plan.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/daily_plan_provider.dart';
import 'package:learning_pwa/widgets/progress/daily_plan_card.dart';

void main() {
  final testContext = LearningContext(
    id: 'ctx-1',
    userId: 'u1',
    label: 'Florida Contractor Prep',
    rootType: ContextRootType.target,
    rootId: 'contractor-fl',
    lastActiveAt: DateTime(2026, 11, 1),
    scopeConfig: const {
      'examDate': '2026-11-20T00:00:00.000',
    },
  );

  testWidgets('DailyPlanCard renders plan details, workload metrics, and exam countdown', (tester) async {
    const testPlan = DailyPlan(
      targetDailyMinutes: 25,
      reviewMinutesBudget: 10,
      newMinutesBudget: 15,
      dueItemsCount: 6,
      recommendedReviewCount: 6,
      recommendedNewCount: 2,
      newItemsCap: 2,
      reviewEmphasis: ReviewEmphasis.balanced,
      rationale: 'Review backlog (6 items): reviews prioritized today.',
      examDate: null,
      daysUntilExam: 10,
      isReviewUrgent: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyPlanProvider.overrideWith((ref) async => testPlan),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DailyPlanCard(context: testContext),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily Study Plan'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Review backlog (6 items): reviews prioritized today.'), findsOneWidget);
    expect(find.text('New Material'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
  });
}

