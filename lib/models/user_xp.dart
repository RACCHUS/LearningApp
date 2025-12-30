/// XP and Level system for gamification
///
/// XP Awards:
/// - +10 XP per question answered correctly
/// - +50 XP per lesson completed
/// - +100 XP per course completed
/// - +25 XP per review session completed
/// - Streak bonuses: +10 XP per day of streak (e.g., 7-day streak = +70 XP)

class XpConstants {
  /// XP awarded per correct question
  static const int perQuestion = 10;

  /// XP awarded per lesson completion
  static const int perLesson = 50;

  /// XP awarded per course completion
  static const int perCourse = 100;

  /// XP awarded per review session
  static const int perReviewSession = 25;

  /// XP multiplier for streak (XP per day in streak)
  static const int perStreakDay = 10;

  /// Base XP required for level 1
  static const int baseXp = 100;

  /// Exponent for level curve (higher = steeper curve)
  static const double levelExponent = 1.5;

  /// Calculate XP needed to reach a specific level
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return (baseXp * (level - 1) * (1 + (level - 1) * 0.5)).round();
  }

  /// Calculate current level from total XP
  static int levelFromXp(int totalXp) {
    if (totalXp <= 0) return 1;
    
    int level = 1;
    while (xpForLevel(level + 1) <= totalXp) {
      level++;
    }
    return level;
  }

  /// Calculate progress to next level (0.0 to 1.0)
  static double progressToNextLevel(int totalXp) {
    final currentLevel = levelFromXp(totalXp);
    final xpForCurrent = xpForLevel(currentLevel);
    final xpForNext = xpForLevel(currentLevel + 1);
    final xpInLevel = totalXp - xpForCurrent;
    final xpNeeded = xpForNext - xpForCurrent;
    
    if (xpNeeded <= 0) return 1.0;
    return (xpInLevel / xpNeeded).clamp(0.0, 1.0);
  }

  /// XP remaining to reach next level
  static int xpToNextLevel(int totalXp) {
    final currentLevel = levelFromXp(totalXp);
    final xpForNext = xpForLevel(currentLevel + 1);
    return xpForNext - totalXp;
  }
}

/// XP event types
enum XpEventType {
  questionCorrect,
  lessonComplete,
  courseComplete,
  reviewSession,
  streakBonus,
  achievement,
  dailyGoal;

  int get baseXp {
    switch (this) {
      case XpEventType.questionCorrect:
        return XpConstants.perQuestion;
      case XpEventType.lessonComplete:
        return XpConstants.perLesson;
      case XpEventType.courseComplete:
        return XpConstants.perCourse;
      case XpEventType.reviewSession:
        return XpConstants.perReviewSession;
      case XpEventType.streakBonus:
        return XpConstants.perStreakDay;
      case XpEventType.achievement:
        return 50; // Variable, but default 50
      case XpEventType.dailyGoal:
        return 20;
    }
  }

  String get displayName {
    switch (this) {
      case XpEventType.questionCorrect:
        return 'Correct Answer';
      case XpEventType.lessonComplete:
        return 'Lesson Complete';
      case XpEventType.courseComplete:
        return 'Course Complete';
      case XpEventType.reviewSession:
        return 'Review Session';
      case XpEventType.streakBonus:
        return 'Streak Bonus';
      case XpEventType.achievement:
        return 'Achievement';
      case XpEventType.dailyGoal:
        return 'Daily Goal';
    }
  }
}

/// Record of an XP gain event
class XpEvent {
  final String id;
  final XpEventType type;
  final int xpAmount;
  final String? sourceId; // lesson_id, course_id, etc.
  final String? description;
  final DateTime earnedAt;

  XpEvent({
    required this.id,
    required this.type,
    required this.xpAmount,
    this.sourceId,
    this.description,
    required this.earnedAt,
  });

  factory XpEvent.fromJson(Map<String, dynamic> json) {
    return XpEvent(
      id: json['id'] as String,
      type: XpEventType.values.firstWhere(
        (e) => e.name == json['event_type'],
        orElse: () => XpEventType.questionCorrect,
      ),
      xpAmount: json['xp_amount'] as int,
      sourceId: json['source_id'] as String?,
      description: json['description'] as String?,
      earnedAt: DateTime.parse(json['earned_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_type': type.name,
      'xp_amount': xpAmount,
      'source_id': sourceId,
      'description': description,
      'earned_at': earnedAt.toIso8601String(),
    };
  }
}

/// User's XP and level summary
class UserXpSummary {
  final int totalXp;
  final int level;
  final double progressToNextLevel;
  final int xpToNextLevel;
  final int xpEarnedToday;
  final int xpEarnedThisWeek;

  UserXpSummary({
    required this.totalXp,
    required this.level,
    required this.progressToNextLevel,
    required this.xpToNextLevel,
    required this.xpEarnedToday,
    required this.xpEarnedThisWeek,
  });

  factory UserXpSummary.empty() => UserXpSummary(
        totalXp: 0,
        level: 1,
        progressToNextLevel: 0.0,
        xpToNextLevel: XpConstants.xpForLevel(2),
        xpEarnedToday: 0,
        xpEarnedThisWeek: 0,
      );

  factory UserXpSummary.fromTotalXp(int totalXp, {int? todayXp, int? weekXp}) {
    final level = XpConstants.levelFromXp(totalXp);
    return UserXpSummary(
      totalXp: totalXp,
      level: level,
      progressToNextLevel: XpConstants.progressToNextLevel(totalXp),
      xpToNextLevel: XpConstants.xpToNextLevel(totalXp),
      xpEarnedToday: todayXp ?? 0,
      xpEarnedThisWeek: weekXp ?? 0,
    );
  }

  /// Check if user just leveled up
  bool didLevelUp(int previousXp) {
    final previousLevel = XpConstants.levelFromXp(previousXp);
    return level > previousLevel;
  }
}

/// Level tier for visual display
enum LevelTier {
  bronze,    // 1-4
  silver,    // 5-9
  gold,      // 10-19
  platinum,  // 20-34
  diamond,   // 35-49
  master;    // 50+

  static LevelTier fromLevel(int level) {
    if (level < 5) return LevelTier.bronze;
    if (level < 10) return LevelTier.silver;
    if (level < 20) return LevelTier.gold;
    if (level < 35) return LevelTier.platinum;
    if (level < 50) return LevelTier.diamond;
    return LevelTier.master;
  }

  String get displayName {
    switch (this) {
      case LevelTier.bronze:
        return 'Bronze';
      case LevelTier.silver:
        return 'Silver';
      case LevelTier.gold:
        return 'Gold';
      case LevelTier.platinum:
        return 'Platinum';
      case LevelTier.diamond:
        return 'Diamond';
      case LevelTier.master:
        return 'Master';
    }
  }
}
