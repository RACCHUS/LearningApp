import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/daily_plan.dart';
import 'package:learning_pwa/services/daily_plan_service.dart';

void main() {
  const service = DailyPlanService();
  final baseDate = DateTime(2026, 11, 10);

  group('DailyPlanService - Workload and Budgeting', () {
    test('all time allocated to new material when no reviews are due', () {
      final plan = service.computeDailyPlan(
        dueCount: 0,
        totalContextItems: 20,
        completedContextItems: 5,
        emphasis: ReviewEmphasis.balanced,
        targetDailyMinutes: 20,
        now: baseDate,
      );

      expect(plan.reviewMinutesBudget, equals(0));
      expect(plan.newMinutesBudget, equals(20));
      expect(plan.recommendedReviewCount, equals(0));
      expect(plan.recommendedNewCount, greaterThan(0));
      expect(plan.isReviewUrgent, isFalse);
      expect(plan.rationale, contains('All reviews complete'));
    });

    test('all time allocated to review when course material is complete', () {
      final plan = service.computeDailyPlan(
        dueCount: 8,
        totalContextItems: 20,
        completedContextItems: 20, // All 20 complete
        emphasis: ReviewEmphasis.balanced,
        targetDailyMinutes: 20,
        now: baseDate,
      );

      expect(plan.reviewMinutesBudget, equals(20));
      expect(plan.newMinutesBudget, equals(0));
      expect(plan.recommendedReviewCount, equals(8));
      expect(plan.recommendedNewCount, equals(0));
      expect(plan.rationale, contains('Course material complete'));
    });

    test('prioritiseReviews allocates time to reviews first and sets urgency', () {
      final plan = service.computeDailyPlan(
        dueCount: 10,
        totalContextItems: 20,
        completedContextItems: 2,
        emphasis: ReviewEmphasis.prioritiseReviews,
        targetDailyMinutes: 20,
        now: baseDate,
      );

      expect(plan.reviewMinutesBudget, equals(10)); // 10 items * 1 min
      expect(plan.newMinutesBudget, equals(10));
      expect(plan.isReviewUrgent, isTrue);
      expect(plan.rationale, contains('Learner policy: clearing due reviews'));
    });

    test('prioritiseNew protects new material allocation', () {
      final plan = service.computeDailyPlan(
        dueCount: 15,
        totalContextItems: 30,
        completedContextItems: 5,
        emphasis: ReviewEmphasis.prioritiseNew,
        targetDailyMinutes: 20,
        now: baseDate,
      );

      expect(plan.newMinutesBudget, equals(15)); // 75% of 20 min
      expect(plan.reviewMinutesBudget, equals(5));
      expect(plan.isReviewUrgent, isFalse);
      expect(plan.rationale, contains('focusing on new material'));
    });
  });

  group('DailyPlanService - Load-Aware Caps (Backlog Protection)', () {
    test('heavy backlog (>= 20) freezes new items to prevent debt compounding', () {
      final cap = service.computeLoadAwareNewCap(
        dueCount: 25,
        emphasis: ReviewEmphasis.balanced,
        baseDailyMinutes: 30,
      );
      expect(cap, equals(0));

      final plan = service.computeDailyPlan(
        dueCount: 22,
        totalContextItems: 50,
        completedContextItems: 10,
        emphasis: ReviewEmphasis.balanced,
        targetDailyMinutes: 30,
        now: baseDate,
      );
      expect(plan.newItemsCap, equals(0));
      expect(plan.recommendedNewCount, equals(0));
      expect(plan.rationale, contains('new lessons paused'));
    });

    test('moderate backlog (10-19) caps new items at 1', () {
      final cap = service.computeLoadAwareNewCap(
        dueCount: 14,
        emphasis: ReviewEmphasis.balanced,
        baseDailyMinutes: 30,
      );
      expect(cap, equals(1));
    });

    test('mild backlog (5-9) caps new items at 2', () {
      final cap = service.computeLoadAwareNewCap(
        dueCount: 7,
        emphasis: ReviewEmphasis.balanced,
        baseDailyMinutes: 30,
      );
      expect(cap, equals(2));
    });

    test('clean backlog (< 5) allows normal new items pacing', () {
      final cap = service.computeLoadAwareNewCap(
        dueCount: 2,
        emphasis: ReviewEmphasis.balanced,
        baseDailyMinutes: 30,
      );
      expect(cap, greaterThanOrEqualTo(3));
    });
  });

  group('DailyPlanService - Exam-Date Workload Planning', () {
    test('approaching exam within 7 days activates consolidation window', () {
      final examDate = baseDate.add(const Duration(days: 4)); // 4 days away
      final plan = service.computeDailyPlan(
        dueCount: 6,
        totalContextItems: 30,
        completedContextItems: 20,
        emphasis: ReviewEmphasis.balanced,
        targetDailyMinutes: 20,
        examDate: examDate,
        now: baseDate,
      );

      expect(plan.daysUntilExam, equals(4));
      expect(plan.isExamApproaching, isTrue);
      expect(plan.isReviewUrgent, isTrue);
      expect(plan.reviewTimeRatio, closeTo(0.70, 0.05)); // ~70% review
      expect(plan.newItemsCap, equals(0)); // Pauses new material in final week when reviews are due
      expect(plan.rationale, contains('Exam in 4 days: consolidation prioritized'));
    });

    test('exam day (0 days) triggers immediate review consolidation', () {
      final plan = service.computeDailyPlan(
        dueCount: 5,
        totalContextItems: 30,
        completedContextItems: 25,
        emphasis: ReviewEmphasis.balanced,
        targetDailyMinutes: 20,
        examDate: baseDate, // Exam is today
        now: baseDate,
      );

      expect(plan.daysUntilExam, equals(0));
      expect(plan.isExamApproaching, isTrue);
      expect(plan.isReviewUrgent, isTrue);
      expect(plan.rationale, contains('Exam is today'));
    });

    test('distant exam (> 14 days) maintains steady state pacing', () {
      final examDate = baseDate.add(const Duration(days: 45)); // 45 days away
      final plan = service.computeDailyPlan(
        dueCount: 3,
        totalContextItems: 50,
        completedContextItems: 10,
        emphasis: ReviewEmphasis.balanced,
        targetDailyMinutes: 20,
        examDate: examDate,
        now: baseDate,
      );

      expect(plan.daysUntilExam, equals(45));
      expect(plan.isExamApproaching, isFalse);
      expect(plan.isReviewUrgent, isFalse);
      expect(plan.recommendedNewCount, greaterThan(0));
    });
  });
}

