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
  question;

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
    }
  }

  /// Whether this type requires answer options
  bool get hasOptions {
    return this == multipleChoice || this == trueFalse || this == matching;
  }

  /// Whether this type requires text input
  bool get requiresTextInput {
    return this == fillInBlank;
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
  final String lessonId;
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

  ReviewableItem({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.lessonId,
    required this.title,
    this.subtitle,
    this.repetitionLevel = 0,
    this.easeFactor = 2.5,
    required this.nextReviewDate,
    this.lastReviewedAt,
    this.totalReviews = 0,
    this.correctReviews = 0,
    this.metadata,
  });

  /// Check if this item is due for review
  bool get isDue => DateTime.now().isAfter(nextReviewDate);

  /// Check if this item is due today
  bool get isDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reviewDay = DateTime(
      nextReviewDate.year,
      nextReviewDate.month,
      nextReviewDate.day,
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

  /// Calculate next review state using simplified SM-2 algorithm
  ReviewableItem processReview(RecallQuality quality) {
    final isCorrect = quality.value >= 3;
    
    // Update repetition level
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
    
    // EF should not go below 1.3
    newEaseFactor = newEaseFactor.clamp(1.3, 2.5);

    // Calculate next review date
    final interval = SpacedRepetitionIntervals.getInterval(newLevel);
    final adjustedInterval = (interval * newEaseFactor).round();
    final nextDate = DateTime.now().add(Duration(days: adjustedInterval));

    return ReviewableItem(
      id: id,
      contentId: contentId,
      contentType: contentType,
      lessonId: lessonId,
      title: title,
      subtitle: subtitle,
      repetitionLevel: newLevel,
      easeFactor: newEaseFactor,
      nextReviewDate: nextDate,
      lastReviewedAt: DateTime.now(),
      totalReviews: totalReviews + 1,
      correctReviews: isCorrect ? correctReviews + 1 : correctReviews,
      metadata: metadata,
    );
  }

  /// Create from Supabase row
  factory ReviewableItem.fromJson(Map<String, dynamic> json) {
    return ReviewableItem(
      id: json['id'] as String,
      contentId: json['content_id'] as String,
      contentType: ReviewableContentType.values.firstWhere(
        (e) => e.name == json['content_type'],
        orElse: () => ReviewableContentType.term,
      ),
      lessonId: json['lesson_id'] as String,
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
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_id': contentId,
      'content_type': contentType.name,
      'lesson_id': lessonId,
      'title': title,
      'subtitle': subtitle,
      'repetition_level': repetitionLevel,
      'ease_factor': easeFactor,
      'next_review_date': nextReviewDate.toIso8601String(),
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
      'total_reviews': totalReviews,
      'correct_reviews': correctReviews,
      'metadata': metadata,
    };
  }

  ReviewableItem copyWith({
    String? id,
    String? contentId,
    ReviewableContentType? contentType,
    String? lessonId,
    String? title,
    String? subtitle,
    int? repetitionLevel,
    double? easeFactor,
    DateTime? nextReviewDate,
    DateTime? lastReviewedAt,
    int? totalReviews,
    int? correctReviews,
    Map<String, dynamic>? metadata,
  }) {
    return ReviewableItem(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      repetitionLevel: repetitionLevel ?? this.repetitionLevel,
      easeFactor: easeFactor ?? this.easeFactor,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      totalReviews: totalReviews ?? this.totalReviews,
      correctReviews: correctReviews ?? this.correctReviews,
      metadata: metadata ?? this.metadata,
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
      final reviewDay = DateTime(
        item.nextReviewDate.year,
        item.nextReviewDate.month,
        item.nextReviewDate.day,
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
