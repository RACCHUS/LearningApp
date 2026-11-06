import 'package:fsrs/fsrs.dart' as fsrs;

/// Scheduling rating corresponding to FSRS rating scale.
enum MemoryRatingCore {
  again(1),
  hard(2),
  good(3),
  easy(4);

  final int value;
  const MemoryRatingCore(this.value);

  fsrs.Rating toFsrsRating() {
    switch (this) {
      case MemoryRatingCore.again:
        return fsrs.Rating.again;
      case MemoryRatingCore.hard:
        return fsrs.Rating.hard;
      case MemoryRatingCore.good:
        return fsrs.Rating.good;
      case MemoryRatingCore.easy:
        return fsrs.Rating.easy;
    }
  }
}

/// The result of an FSRS-6 review calculation.
class FsrsReviewResultCore {
  final double stability;
  final double difficulty;
  final double retrievability;
  final DateTime nextReviewDate;
  final int intervalDays;
  final int state;

  const FsrsReviewResultCore({
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.nextReviewDate,
    required this.intervalDays,
    required this.state,
  });

  Map<String, dynamic> toJson() {
    return {
      'stability': stability,
      'difficulty': difficulty,
      'retrievability': retrievability,
      'next_review_date': nextReviewDate.toUtc().toIso8601String(),
      'interval_days': intervalDays,
      'state': state,
    };
  }
}

/// Standalone FSRS-6 scheduler wrapper (zero Flutter dependencies).
class FsrsSchedulerCore {
  final fsrs.Scheduler _scheduler;

  FsrsSchedulerCore({double desiredRetention = 0.9})
      : _scheduler = fsrs.Scheduler(desiredRetention: desiredRetention);

  /// Calculates memory state forward given card's current state and learner rating.
  FsrsReviewResultCore scheduleReview({
    int cardId = 1,
    double? currentStability,
    double? currentDifficulty,
    DateTime? lastReviewDate,
    DateTime? dueDate,
    required MemoryRatingCore rating,
    DateTime? reviewTimestamp,
  }) {
    final now = (reviewTimestamp ?? DateTime.now()).toUtc();
    final fsrs.State cardState;
    final int? cardStep;

    if (currentStability != null && currentDifficulty != null && lastReviewDate != null) {
      cardState = fsrs.State.review;
      cardStep = null;
    } else {
      cardState = fsrs.State.learning;
      cardStep = 0;
    }

    final card = fsrs.Card(
      cardId: cardId,
      state: cardState,
      step: cardStep,
      stability: currentStability,
      difficulty: currentDifficulty,
      due: (dueDate ?? now).toUtc(),
      lastReview: lastReviewDate?.toUtc(),
    );

    final fsrsRating = rating.toFsrsRating();
    final reviewResult = _scheduler.reviewCard(card, fsrsRating, reviewDateTime: now);
    final updatedCard = reviewResult.card;
    final retrievability = _scheduler.getCardRetrievability(updatedCard, currentDateTime: now);

    final intervalDays = updatedCard.due.difference(now).inDays;

    return FsrsReviewResultCore(
      stability: updatedCard.stability ?? 0.0,
      difficulty: updatedCard.difficulty ?? 0.0,
      retrievability: retrievability,
      nextReviewDate: updatedCard.due,
      intervalDays: intervalDays < 0 ? 0 : intervalDays,
      state: updatedCard.state.value,
    );
  }
}
