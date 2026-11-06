/// Policy for balancing spaced reviews against new forward material.
enum ReviewEmphasis {
  /// Reviews and new material are balanced. If the due review backlog exceeds
  /// the balanced threshold or an exam approaches, reviews take priority
  /// to protect retention and prevent backlog debt.
  balanced,

  /// Reviews always outrank forward progress whenever any items are due.
  prioritiseReviews,

  /// Forward progress on new material always outranks reviews while material remains.
  prioritiseNew,
}

/// A structured daily study plan allocating time between due reviews and new material.
///
/// Grounded in cognitive and spaced repetition science (Cepeda et al., 2006; Dunlosky et al., 2013).
/// Exam-date workload planning adjusts queue allocation and daily targets without
/// ever mutating underlying FSRS-6 memory stability or difficulty parameters (S, D).
class DailyPlan {
  /// The learner's daily study budget in minutes (e.g. 15, 20, 30 min).
  final int targetDailyMinutes;

  /// Allocated minutes for due reviews today.
  final int reviewMinutesBudget;

  /// Allocated minutes for new material (lessons or new cards) today.
  final int newMinutesBudget;

  /// Number of items or concepts currently due for review.
  final int dueItemsCount;

  /// Recommended number of reviews to complete today based on time budget and backlog.
  final int recommendedReviewCount;

  /// Recommended number of new items or lessons to complete today.
  final int recommendedNewCount;

  /// Load-aware cap on new material to prevent exponential future review debt.
  final int newItemsCap;

  /// The active learner review emphasis policy.
  final ReviewEmphasis reviewEmphasis;

  /// Optional target exam date.
  final DateTime? examDate;

  /// Days remaining until the target exam (null if no exam date set).
  final int? daysUntilExam;

  /// Whether reviews are considered urgent today (e.g. high backlog or exam <= 7 days).
  final bool isReviewUrgent;

  /// Human-readable explanation of why this daily plan was composed.
  final String rationale;

  const DailyPlan({
    required this.targetDailyMinutes,
    required this.reviewMinutesBudget,
    required this.newMinutesBudget,
    required this.dueItemsCount,
    required this.recommendedReviewCount,
    required this.recommendedNewCount,
    required this.newItemsCap,
    required this.reviewEmphasis,
    required this.rationale,
    this.examDate,
    this.daysUntilExam,
    this.isReviewUrgent = false,
  });

  bool get hasExamDate => examDate != null;

  /// True when an exam is within 7 days, requiring retrieval consolidation.
  bool get isExamApproaching =>
      daysUntilExam != null && daysUntilExam! <= 7 && daysUntilExam! >= 0;

  /// Ratio of study time allocated to review (0.0 to 1.0).
  double get reviewTimeRatio {
    if (targetDailyMinutes <= 0) return 0.0;
    return (reviewMinutesBudget / targetDailyMinutes).clamp(0.0, 1.0);
  }

  /// Ratio of study time allocated to new material (0.0 to 1.0).
  double get newTimeRatio {
    if (targetDailyMinutes <= 0) return 0.0;
    return (newMinutesBudget / targetDailyMinutes).clamp(0.0, 1.0);
  }
}

