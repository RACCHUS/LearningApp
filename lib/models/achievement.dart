import 'package:flutter/material.dart';

/// Activities the server will award XP for (`claim_activity_xp`). The server
/// fixes the amount; the browser only names the activity.
enum ActivityXpKind {
  lessonComplete('lesson_complete'),
  reviewSession('review_session');

  const ActivityXpKind(this.wireName);
  final String wireName;
}

/// Server answer to an activity XP claim.
class ActivityXpResult {
  const ActivityXpResult({
    required this.status,
    required this.awardedXp,
    required this.totalXp,
    required this.newAchievements,
  });

  /// `awarded`, `already_processed` or `limit_reached`.
  final String status;
  final int awardedXp;
  final int totalXp;

  /// Keys earned by this claim only, in catalog order.
  final List<String> newAchievements;

  bool get awarded => status == 'awarded' && awardedXp > 0;

  factory ActivityXpResult.fromJson(Map<String, dynamic> json) {
    final keys = json['new_achievements'];
    return ActivityXpResult(
      status: json['status'] as String? ?? 'unknown',
      awardedXp: (json['awarded_xp'] as num?)?.toInt() ?? 0,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      newAchievements: keys is List
          ? AchievementCatalog.known(keys.whereType<String>())
          : const [],
    );
  }
}

/// One achievement the learner has earned (`user_achievements` row).
class EarnedAchievementRecord {
  const EarnedAchievementRecord({required this.key, required this.earnedAt});

  final String key;
  final DateTime earnedAt;

  factory EarnedAchievementRecord.fromJson(Map<String, dynamic> json) =>
      EarnedAchievementRecord(
        key: json['achievement_key'] as String,
        earnedAt: DateTime.parse(json['earned_at'] as String),
      );
}

/// Display text for a server achievement key.
class AchievementDefinition {
  const AchievementDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String key;
  final String title;
  final String description;
  final IconData icon;
}

/// Mirrors the CHECK list in
/// `supabase/migrations/20261115000000_learning_xp_achievements.sql`.
/// Copy follows UI_ARCHITECTURE_LOCKED.md §9: activity milestones, never a
/// claim about knowledge, and no streak or loss framing ("active days" need
/// not be consecutive).
abstract final class AchievementCatalog {
  static const List<AchievementDefinition> all = [
    AchievementDefinition(
      key: 'first_lesson',
      title: 'First lesson',
      description: 'Finished your first lesson.',
      icon: Icons.flag_outlined,
    ),
    AchievementDefinition(
      key: 'lessons_10',
      title: 'Ten lessons',
      description: 'Finished 10 different lessons.',
      icon: Icons.menu_book_outlined,
    ),
    AchievementDefinition(
      key: 'lessons_50',
      title: 'Fifty lessons',
      description: 'Finished 50 different lessons.',
      icon: Icons.local_library_outlined,
    ),
    AchievementDefinition(
      key: 'first_review',
      title: 'First review',
      description: 'Finished your first review session.',
      icon: Icons.replay_outlined,
    ),
    AchievementDefinition(
      key: 'reviews_25',
      title: '25 reviews',
      description: 'Finished 25 review sessions.',
      icon: Icons.autorenew,
    ),
    AchievementDefinition(
      key: 'active_days_7',
      title: '7 active days',
      description: 'Studied on 7 different days.',
      icon: Icons.calendar_today_outlined,
    ),
    AchievementDefinition(
      key: 'active_days_30',
      title: '30 active days',
      description: 'Studied on 30 different days.',
      icon: Icons.calendar_month_outlined,
    ),
  ];

  static AchievementDefinition? byKey(String key) {
    for (final a in all) {
      if (a.key == key) return a;
    }
    return null;
  }

  /// Keeps only keys this build can describe, in catalog order.
  static List<String> known(Iterable<String> keys) {
    final wanted = keys.toSet();
    return [
      for (final a in all)
        if (wanted.contains(a.key)) a.key,
    ];
  }
}
