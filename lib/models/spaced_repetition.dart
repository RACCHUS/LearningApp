import 'package:fsrs/fsrs.dart' as fsrs;

/// Spaced repetition intervals in days (simplified SM-2 algorithm)
/// Intervals: 1, 3, 7, 14, 30, 60, 120 days
class SpacedRepetitionIntervals {
  static const List<int> intervals = [1, 3, 7, 14, 30, 60, 120];
  
  /// Get the next interval based on current level (0-indexed)
  static int getInterval(int level) {
    if (level < 0) return intervals[0];
    if (level >= intervals.length) return intervals.last;
    return intervals[level];
  }
  
  /// Get the next review date based on current level
  static DateTime getNextReviewDate(int level) {
    final interval = getInterval(level);
    return DateTime.now().add(Duration(days: interval));
  }
}

/// Quality of recall rating (used in SM-2 algorithm)
enum RecallQuality {
  /// Complete blackout - couldn't recall at all
  blackout(0),
  /// Incorrect - remembered incorrectly
  incorrect(1),
  /// Difficult - correct with serious difficulty
  difficult(2),
  /// Hesitant - correct after hesitation
  hesitant(3),
  /// Good - correct with some effort
  good(4),
  /// Perfect - instant recall
  perfect(5);

  final int value;
  const RecallQuality(this.value);
}

/// Extension mapping RecallQuality to FSRS Rating
extension RecallQualityFsrs on RecallQuality {
  fsrs.Rating toFsrsRating() {
    switch (this) {
      case RecallQuality.blackout:
      case RecallQuality.incorrect:
        return fsrs.Rating.again;
      case RecallQuality.difficult:
        return fsrs.Rating.hard;
      case RecallQuality.hesitant:
      case RecallQuality.good:
        return fsrs.Rating.good;
      case RecallQuality.perfect:
        return fsrs.Rating.easy;
    }
  }
}

/// Content types that can be reviewed
/// This enum is designed to be extensible for future question types
enum ReviewableContentType {
  /// Flashcard-style term with definition
  term,
  /// Multiple choice question
  multipleChoice,
  /// True or false question
  trueFalse,
  /// Fill in the blank
  fillInBlank,
  /// Concept explanation
  concept,
  /// Matching pairs
  matching,
  /// Free-form question (legacy)
  question,
  /// Standalone or lesson-bound flashcard (v2)
  flashcard,
  /// A word-form skill, independent of any particular word list.
  wordSkill;

  String get dbValue => this == wordSkill ? 'word_skill' : name;

  static ReviewableContentType fromDbValue(String? value) =>
      ReviewableContentType.values.firstWhere(
        (v) => v.dbValue == value,
        orElse: () => ReviewableContentType.term,
      );

  String get displayName {
    switch (this) {
      case ReviewableContentType.term:
        return 'Flashcard';
      case ReviewableContentType.multipleChoice:
        return 'Multiple Choice';
      case ReviewableContentType.trueFalse:
        return 'True/False';
      case ReviewableContentType.fillInBlank:
        return 'Fill in Blank';
      case ReviewableContentType.concept:
        return 'Concept';
      case ReviewableContentType.matching:
        return 'Matching';
      case ReviewableContentType.question:
        return 'Question';
      case ReviewableContentType.flashcard:
        return 'Flashcard';
      case ReviewableContentType.wordSkill:
        return 'Word spelling';
    }
  }

  /// Icon for this content type
  String get icon {
    switch (this) {
      case ReviewableContentType.term:
        return '🗂️';
      case ReviewableContentType.multipleChoice:
        return '📝';
      case ReviewableContentType.trueFalse:
        return '✅';
      case ReviewableContentType.fillInBlank:
        return '✏️';
      case ReviewableContentType.concept:
        return '💡';
      case ReviewableContentType.matching:
        return '🔗';
      case ReviewableContentType.question:
        return '❓';
      case ReviewableContentType.flashcard:
        return '🗂️';
      case ReviewableContentType.wordSkill:
        return '✏️';
    }
  }

  /// Whether this type requires answer options
  bool get hasOptions {
    return this == multipleChoice || this == trueFalse || this == matching;
  }

  /// Whether this type requires text input
  bool get requiresTextInput {
    return this == fillInBlank || this == wordSkill;
  }
}

/// How well-learned an item is, derived from its SM-2 repetition level.
/// Used purely for UI cues (e.g. a colored difficulty dot); carries no color
/// itself so the model stays presentation-agnostic.
enum DifficultyCategory {
  /// Not yet learned or reset after a lapse (level 0).
  learning('Learning'),
  /// Recalled a few times but not yet solid (levels 1–2).
  familiar('Familiar'),
  /// Reliably recalled over longer intervals (level 3+).
  mastered('Mastered');

  final String displayName;
  const DifficultyCategory(this.displayName);
}

/// A single reviewable item with spaced repetition metadata
/// 
/// This model is designed to support any content type through:
/// - [contentType]: Determines how the item is rendered
/// - [metadata]: Stores type-specific data (options, correct answer, etc.)
/// 
/// Example metadata structures:
/// - Multiple Choice: {"options": ["A", "B", "C", "D"], "correctIndex": 2}
/// - True/False: {"correctAnswer": true}
/// - Fill in Blank: {"correctAnswer": "Paris", "acceptableAnswers": ["paris", "PARIS"]}
/// - Matching: {"pairs": [{"left": "A", "right": "1"}, ...]}
class ReviewableItem {
  final String id;
  final String contentId;
  final ReviewableContentType contentType;
  final String? lessonId;
  final String title;
  final String? subtitle;
  final int repetitionLevel;
  final double easeFactor;
  final DateTime nextReviewDate;
  final DateTime? lastReviewedAt;
  final int totalReviews;
  final int correctReviews;
  
  /// Type-specific metadata for rendering and validation
  /// This allows any content type to store its unique data
  final Map<String, dynamic>? metadata;

  /// FSRS algorithm properties
  final double? stability;
  final double? difficulty;
  final int fsrsState;
  final double? retrievability;
  final int step;

  ReviewableItem({
    required this.id,
    required this.contentId,
    required this.contentType,
    this.lessonId,
    required this.title,
    this.subtitle,
    this.repetitionLevel = 0,
    this.easeFactor = 2.5,
    required this.nextReviewDate,
    this.lastReviewedAt,
    this.totalReviews = 0,
    this.correctReviews = 0,
    this.metadata,
    this.stability,
    this.difficulty,
    this.fsrsState = 1,
    this.retrievability,
    this.step = 0,
  });

  /// FSRS State conversion helper
  fsrs.State get _cardState {
    switch (fsrsState) {
      case 2:
        return fsrs.State.review;
      case 3:
        return fsrs.State.relearning;
      case 1:
      default:
        return fsrs.State.learning;
    }
  }

  /// Current retrievability estimate
  double currentRetrievability({DateTime? asOf}) {
    if (stability == null || lastReviewedAt == null) return retrievability ?? 0.0;
    try {
      final scheduler = fsrs.Scheduler(desiredRetention: 0.9);
      final card = fsrs.Card(
        cardId: id.hashCode,
        state: _cardState,
        step: _cardState == fsrs.State.review ? null : step,
        stability: stability,
        difficulty: difficulty,
        due: nextReviewDate.toUtc(),
        lastReview: lastReviewedAt?.toUtc(),
      );
      return scheduler.getCardRetrievability(card, currentDateTime: (asOf ?? DateTime.now()).toUtc());
    } catch (_) {
      return retrievability ?? 0.0;
    }
  }

  /// Check if this item is due for review
  bool get isDue => DateTime.now().isAfter(nextReviewDate);

  /// Check if this item is due today
  bool get isDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localReview = nextReviewDate.toLocal();
    final reviewDay = DateTime(
      localReview.year,
      localReview.month,
      localReview.day,
    );
    return reviewDay.isAtSameMomentAs(today) || reviewDay.isBefore(today);
  }

  /// Days until next review (negative if overdue)
  int get daysUntilReview {
    final now = DateTime.now();
    return nextReviewDate.difference(now).inDays;
  }

  /// Accuracy percentage
  double get accuracy {
    if (totalReviews == 0) return 0.0;
    return correctReviews / totalReviews;
  }

  /// Coarse difficulty bucket derived from the SM-2 repetition level.
  DifficultyCategory get difficultyCategory {
    if (repetitionLevel <= 0) return DifficultyCategory.learning;
    if (repetitionLevel <= 2) return DifficultyCategory.familiar;
    return DifficultyCategory.mastered;
  }

  /// Calculate next review state using FSRS algorithm with SM-2 synchronization
  ReviewableItem processReview(RecallQuality quality, {DateTime? reviewDateTime}) {
    final now = (reviewDateTime ?? DateTime.now()).toUtc();
    final isCorrect = quality.value >= 3;
    
    // 1. SM-2 calculation (kept in sync for backward compatibility)
    int newLevel;
    if (isCorrect) {
      newLevel = repetitionLevel + 1;
    } else {
      // Reset to beginning on failure
      newLevel = 0;
    }

    // Update ease factor (EF) using SM-2 formula
    // EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
    double newEaseFactor = easeFactor +
        (0.1 - (5 - quality.value) * (0.08 + (5 - quality.value) * 0.02));
    newEaseFactor = newEaseFactor.clamp(1.3, 2.5);

    // 2. FSRS calculation
    final scheduler = fsrs.Scheduler(desiredRetention: 0.9);
    final isBrandNew = stability == null && lastReviewedAt == null && repetitionLevel == 0;

    final double? seedStability;
    final double? seedDifficulty;
    final DateTime? cardLastReview;
    final fsrs.State currentCardState;
    final int? cardStep;

    if (isBrandNew) {
      seedStability = null;
      seedDifficulty = null;
      cardLastReview = null;
      currentCardState = fsrs.State.learning;
      cardStep = 0;
    } else {
      seedStability = stability ??
          (repetitionLevel > 0
              ? (SpacedRepetitionIntervals.getInterval(repetitionLevel) * easeFactor).clamp(1.0, 365.0)
              : null);
      seedDifficulty = difficulty ??
          ((2.5 - easeFactor) * 5.0 + 4.0).clamp(1.0, 10.0);
      cardLastReview = (lastReviewedAt ??
          now.subtract(Duration(days: SpacedRepetitionIntervals.getInterval(repetitionLevel)))).toUtc();
      currentCardState = repetitionLevel > 0 ? fsrs.State.review : _cardState;
      cardStep = currentCardState == fsrs.State.review ? null : step;
    }

    final card = fsrs.Card(
      cardId: id.hashCode,
      state: currentCardState,
      step: cardStep,
      stability: seedStability,
      difficulty: seedDifficulty,
      due: nextReviewDate.toUtc(),
      lastReview: cardLastReview,
    );

    final fsrsRating = quality.toFsrsRating();
    final reviewResult = scheduler.reviewCard(card, fsrsRating, reviewDateTime: now);
    final updatedCard = reviewResult.card;
    final newRetrievability = scheduler.getCardRetrievability(updatedCard, currentDateTime: now);

    return ReviewableItem(
      id: id,
      contentId: contentId,
      contentType: contentType,
      lessonId: lessonId,
      title: title,
      subtitle: subtitle,
      repetitionLevel: newLevel,
      easeFactor: newEaseFactor,
      nextReviewDate: updatedCard.due.toLocal(),
      lastReviewedAt: now.toLocal(),
      totalReviews: totalReviews + 1,
      correctReviews: isCorrect ? correctReviews + 1 : correctReviews,
      metadata: metadata,
      stability: updatedCard.stability,
      difficulty: updatedCard.difficulty,
      fsrsState: updatedCard.state.value,
      retrievability: newRetrievability,
      step: updatedCard.step ?? 0,
    );
  }

  /// Create from Supabase row
  factory ReviewableItem.fromJson(Map<String, dynamic> json) {
    return ReviewableItem(
      id: json['id'] as String,
      contentId: json['content_id'] as String,
      contentType: ReviewableContentType.fromDbValue(
        json['content_type'] as String?,
      ),
      lessonId: json['lesson_id'] as String?,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      repetitionLevel: json['repetition_level'] as int? ?? 0,
      easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      nextReviewDate: DateTime.parse(json['next_review_date'] as String),
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.parse(json['last_reviewed_at'] as String)
          : null,
      totalReviews: json['total_reviews'] as int? ?? 0,
      correctReviews: json['correct_reviews'] as int? ?? 0,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      stability: (json['stability'] as num?)?.toDouble(),
      difficulty: (json['difficulty'] as num?)?.toDouble(),
      fsrsState: json['fsrs_state'] as int? ?? 1,
      retrievability: (json['retrievability'] as num?)?.toDouble(),
      step: json['step'] as int? ?? 0,
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_id': contentId,
      'content_type': contentType.dbValue,
      'lesson_id': lessonId,
      'title': title,
      'subtitle': subtitle,
      'repetition_level': repetitionLevel,
      'ease_factor': easeFactor,
      'next_review_date': nextReviewDate.toUtc().toIso8601String(),
      'last_reviewed_at': lastReviewedAt?.toUtc().toIso8601String(),
      'total_reviews': totalReviews,
      'correct_reviews': correctReviews,
      'metadata': metadata,
      'stability': stability,
      'difficulty': difficulty,
      'fsrs_state': fsrsState,
      'retrievability': retrievability,
      'step': step,
    };
  }

  ReviewableItem copyWith({
    String? id,
    String? contentId,
    ReviewableContentType? contentType,
    String? lessonId,
    bool clearLessonId = false,
    String? title,
    String? subtitle,
    int? repetitionLevel,
    double? easeFactor,
    DateTime? nextReviewDate,
    DateTime? lastReviewedAt,
    int? totalReviews,
    int? correctReviews,
    Map<String, dynamic>? metadata,
    double? stability,
    double? difficulty,
    int? fsrsState,
    double? retrievability,
    int? step,
  }) {
    return ReviewableItem(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      lessonId: clearLessonId ? null : (lessonId ?? this.lessonId),
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      repetitionLevel: repetitionLevel ?? this.repetitionLevel,
      easeFactor: easeFactor ?? this.easeFactor,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      totalReviews: totalReviews ?? this.totalReviews,
      correctReviews: correctReviews ?? this.correctReviews,
      metadata: metadata ?? this.metadata,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      fsrsState: fsrsState ?? this.fsrsState,
      retrievability: retrievability ?? this.retrievability,
      step: step ?? this.step,
    );
  }
}

/// Summary of review items for display
class ReviewSummary {
  final int dueToday;
  final int dueThisWeek;
  final int totalItems;
  final int masteredItems;
  final double averageAccuracy;
  final int overdueCount;

  ReviewSummary({
    required this.dueToday,
    required this.dueThisWeek,
    required this.totalItems,
    required this.masteredItems,
    required this.averageAccuracy,
    this.overdueCount = 0,
  });

  factory ReviewSummary.empty() => ReviewSummary(
        dueToday: 0,
        dueThisWeek: 0,
        totalItems: 0,
        masteredItems: 0,
        averageAccuracy: 0.0,
        overdueCount: 0,
      );

  factory ReviewSummary.fromItems(List<ReviewableItem> items) {
    if (items.isEmpty) return ReviewSummary.empty();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekFromNow = today.add(const Duration(days: 7));

    int dueToday = 0;
    int dueThisWeek = 0;
    int mastered = 0;
    int overdue = 0;
    double totalAccuracy = 0;
    int itemsWithReviews = 0;

    for (final item in items) {
      final localReviewDate = item.nextReviewDate.toLocal();
      final reviewDay = DateTime(
        localReviewDate.year,
        localReviewDate.month,
        localReviewDate.day,
      );

      if (reviewDay.isBefore(today)) {
        overdue++;
        dueToday++;
      } else if (reviewDay.isAtSameMomentAs(today)) {
        dueToday++;
      }
      if (reviewDay.isBefore(weekFromNow)) {
        dueThisWeek++;
      }
      if (item.repetitionLevel >= SpacedRepetitionIntervals.intervals.length - 1) {
        mastered++;
      }
      if (item.totalReviews > 0) {
        totalAccuracy += item.accuracy;
        itemsWithReviews++;
      }
    }

    return ReviewSummary(
      dueToday: dueToday,
      dueThisWeek: dueThisWeek,
      totalItems: items.length,
      masteredItems: mastered,
      averageAccuracy: itemsWithReviews > 0 ? totalAccuracy / itemsWithReviews : 0.0,
      overdueCount: overdue,
    );
  }
}
