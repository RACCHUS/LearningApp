import 'dart:math';
import 'package:learning_pwa/models/daily_plan.dart';

/// Pure, testable service that computes daily study workload, load-aware caps,
/// and time budget allocations between due reviews and new material.
///
/// Grounded in cognitive and spaced repetition science:
/// - Cepeda et al. (2006): Retention depends on completing reviews near their due window.
/// - Dunlosky et al. (2013): High utility of distributed practice and retrieval practice.
/// - Invariant: FSRS-6 memory parameters (S, D) are NEVER mutated for exam planning.
class DailyPlanService {
  const DailyPlanService();

  /// Default threshold of due review concepts before balanced mode prioritizes reviews.
  static const int defaultBalancedBacklogThreshold = 5;

  /// Days before target exam when review consolidation begins taking priority.
  static const int examConsolidationWindowDays = 7;

  /// Days before target exam when late preparation pacing begins.
  static const int examLatePrepWindowDays = 14;

  /// Computes a [DailyPlan] for the active context.
  DailyPlan computeDailyPlan({
    required int dueCount,
    required int totalContextItems,
    required int completedContextItems,
    required ReviewEmphasis emphasis,
    int targetDailyMinutes = 15,
    DateTime? examDate,
    DateTime? now,
    int estimatedMinutesPerReview = 1,
    int estimatedMinutesPerNew = 10,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final remainingNewItems = max(0, totalContextItems - completedContextItems);

    // 1. Calculate days until target exam (if configured).
    int? daysUntilExam;
    if (examDate != null) {
      final todayDate = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
      final examDay = DateTime(examDate.year, examDate.month, examDate.day);
      daysUntilExam = max(0, examDay.difference(todayDate).inDays);
    }

    final isExamApproaching = daysUntilExam != null &&
        daysUntilExam <= examConsolidationWindowDays;

    // 2. Compute load-aware cap on new items.
    final newItemsCap = computeLoadAwareNewCap(
      dueCount: dueCount,
      emphasis: emphasis,
      daysUntilExam: daysUntilExam,
      baseDailyMinutes: targetDailyMinutes,
      estimatedMinutesPerNew: estimatedMinutesPerNew,
    );

    // 3. Determine whether reviews are urgent.
    final isReviewUrgent = _determineReviewUrgency(
      dueCount: dueCount,
      emphasis: emphasis,
      isExamApproaching: isExamApproaching,
    );

    // 4. Allocate time budgets.
    final (reviewBudget, newBudget) = _allocateTimeBudget(
      targetDailyMinutes: targetDailyMinutes,
      dueCount: dueCount,
      remainingNewItems: remainingNewItems,
      emphasis: emphasis,
      isExamApproaching: isExamApproaching,
      estimatedMinutesPerReview: estimatedMinutesPerReview,
      estimatedMinutesPerNew: estimatedMinutesPerNew,
    );

    // 5. Compute recommended item quantities.
    final recommendedReviewCount = dueCount > 0 && reviewBudget > 0
        ? min(dueCount, max(1, (reviewBudget / estimatedMinutesPerReview).round()))
        : 0;

    final maxPossibleNewFromTime = (newBudget / estimatedMinutesPerNew).floor();
    final recommendedNewCount = remainingNewItems > 0 && newBudget > 0
        ? min(newItemsCap, min(remainingNewItems, max(1, maxPossibleNewFromTime)))
        : 0;

    // 6. Build educational rationale.
    final rationale = _buildRationale(
      emphasis: emphasis,
      dueCount: dueCount,
      remainingNewItems: remainingNewItems,
      reviewBudget: reviewBudget,
      newBudget: newBudget,
      daysUntilExam: daysUntilExam,
      isReviewUrgent: isReviewUrgent,
      newItemsCap: newItemsCap,
    );

    return DailyPlan(
      targetDailyMinutes: targetDailyMinutes,
      reviewMinutesBudget: reviewBudget,
      newMinutesBudget: newBudget,
      dueItemsCount: dueCount,
      recommendedReviewCount: recommendedReviewCount,
      recommendedNewCount: recommendedNewCount,
      newItemsCap: newItemsCap,
      reviewEmphasis: emphasis,
      examDate: examDate,
      daysUntilExam: daysUntilExam,
      isReviewUrgent: isReviewUrgent,
      rationale: rationale,
    );
  }

  /// Calculates a load-aware cap on new items to prevent compounding review debt.
  int computeLoadAwareNewCap({
    required int dueCount,
    required ReviewEmphasis emphasis,
    int? daysUntilExam,
    int baseDailyMinutes = 15,
    int estimatedMinutesPerNew = 10,
  }) {
    // If exam is within 7 days and reviews are due, halt or restrict new items for consolidation.
    if (daysUntilExam != null && daysUntilExam <= examConsolidationWindowDays) {
      if (dueCount > 0) return 0;
      return 1;
    }

    final maxByTime = max(1, (baseDailyMinutes / estimatedMinutesPerNew).ceil());

    if (emphasis == ReviewEmphasis.prioritiseReviews && dueCount > 0) {
      // Learner explicitly asked to clear reviews first.
      return dueCount >= 10 ? 0 : 1;
    }

    if (emphasis == ReviewEmphasis.prioritiseNew) {
      // Learner prioritized forward progress; cap generously based on time.
      return max(1, maxByTime + 1);
    }

    // Balanced policy: scale cap with backlog severity.
    if (dueCount >= 20) {
      return 0; // Heavy backlog: freeze new lessons to clear debt.
    } else if (dueCount >= 10) {
      return 1; // Moderate backlog: at most 1 new lesson.
    } else if (dueCount >= defaultBalancedBacklogThreshold) {
      return min(2, maxByTime); // Mild backlog: up to 2.
    }

    return maxByTime;
  }

  bool _determineReviewUrgency({
    required int dueCount,
    required ReviewEmphasis emphasis,
    required bool isExamApproaching,
  }) {
    if (dueCount <= 0) return false;
    if (emphasis == ReviewEmphasis.prioritiseReviews) return true;
    if (isExamApproaching) return true;
    if (emphasis == ReviewEmphasis.balanced &&
        dueCount >= defaultBalancedBacklogThreshold) {
      return true;
    }
    return false;
  }

  (int reviewBudget, int newBudget) _allocateTimeBudget({
    required int targetDailyMinutes,
    required int dueCount,
    required int remainingNewItems,
    required ReviewEmphasis emphasis,
    required bool isExamApproaching,
    required int estimatedMinutesPerReview,
    required int estimatedMinutesPerNew,
  }) {
    if (targetDailyMinutes <= 0) return (0, 0);

    // If no due items exist, all time goes to new material.
    if (dueCount <= 0) {
      return (0, targetDailyMinutes);
    }

    // If no new material remains, all time goes to reviews.
    if (remainingNewItems <= 0) {
      return (targetDailyMinutes, 0);
    }

    final estimatedDueMinutes = dueCount * estimatedMinutesPerReview;

    switch (emphasis) {
      case ReviewEmphasis.prioritiseReviews:
        final reviewMin = min(targetDailyMinutes, max(5, estimatedDueMinutes));
        final newMin = max(0, targetDailyMinutes - reviewMin);
        return (reviewMin, newMin);

      case ReviewEmphasis.prioritiseNew:
        final newMin = min(targetDailyMinutes, max(estimatedMinutesPerNew, (targetDailyMinutes * 0.75).round()));
        final reviewMin = max(0, targetDailyMinutes - newMin);
        return (reviewMin, newMin);

      case ReviewEmphasis.balanced:
        if (isExamApproaching) {
          // Exam consolidation: 70% review, 30% new
          final reviewMin = min(targetDailyMinutes, max(5, (targetDailyMinutes * 0.7).round()));
          final newMin = max(0, targetDailyMinutes - reviewMin);
          return (reviewMin, newMin);
        }

        if (dueCount >= defaultBalancedBacklogThreshold) {
          // Backlog protection: 60% review, 40% new
          final reviewMin = min(targetDailyMinutes, max(5, (targetDailyMinutes * 0.6).round()));
          final newMin = max(0, targetDailyMinutes - reviewMin);
          return (reviewMin, newMin);
        }

        // Light backlog: allocate exact needed review time up to 40% of daily budget
        final maxReviewFraction = (targetDailyMinutes * 0.4).round();
        final reviewMin = min(maxReviewFraction, estimatedDueMinutes);
        final newMin = max(0, targetDailyMinutes - reviewMin);
        return (reviewMin, newMin);
    }
  }

  String _buildRationale({
    required ReviewEmphasis emphasis,
    required int dueCount,
    required int remainingNewItems,
    required int reviewBudget,
    required int newBudget,
    required int? daysUntilExam,
    required bool isReviewUrgent,
    required int newItemsCap,
  }) {
    if (daysUntilExam != null && daysUntilExam <= examConsolidationWindowDays) {
      if (daysUntilExam == 0) {
        return 'Exam is today: review key concepts to maximize retrievability.';
      }
      return 'Exam in $daysUntilExam day${daysUntilExam == 1 ? '' : 's'}: consolidation prioritized to ensure recall at exam time.';
    }

    if (dueCount <= 0) {
      return 'All reviews complete. Focus on forward progress with new material.';
    }

    if (remainingNewItems <= 0) {
      return 'Course material complete. Dedicate study time to spaced reviews.';
    }

    if (emphasis == ReviewEmphasis.prioritiseReviews) {
      return 'Learner policy: clearing due reviews ($dueCount due) before new material.';
    }

    if (emphasis == ReviewEmphasis.prioritiseNew) {
      return 'Learner policy: focusing on new material ($newBudget min), reviews second ($reviewBudget min).';
    }

    // Balanced
    if (dueCount >= 20) {
      return 'Review backlog ($dueCount items): new lessons paused to protect retention and clear backlog.';
    }

    if (dueCount >= defaultBalancedBacklogThreshold) {
      return 'Review backlog ($dueCount items): reviews prioritized today ($reviewBudget min review, $newBudget min new).';
    }

    return 'Balanced pacing: $newBudget min new material, $reviewBudget min review ($dueCount due).';
  }
}

