import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/user_xp.dart';

void main() {
  group('XpEventType Deserialization', () {
    test('parses both legacy camelCase and canonical snake_case strings', () {
      final expectations = <String, XpEventType>{
        'questionCorrect': XpEventType.questionCorrect,
        'question_correct': XpEventType.questionCorrect,
        'lessonComplete': XpEventType.lessonComplete,
        'lesson_complete': XpEventType.lessonComplete,
        'courseComplete': XpEventType.courseComplete,
        'course_complete': XpEventType.courseComplete,
        'reviewSession': XpEventType.reviewSession,
        'review_session': XpEventType.reviewSession,
        'streakBonus': XpEventType.streakBonus,
        'streak_bonus': XpEventType.streakBonus,
        'achievement': XpEventType.achievement,
        'dailyGoal': XpEventType.dailyGoal,
        'daily_goal': XpEventType.dailyGoal,
      };

      for (final entry in expectations.entries) {
        expect(
          XpEventType.fromString(entry.key),
          equals(entry.value),
          reason: 'Failed parsing "${entry.key}"',
        );
      }
    });

    test('XpEvent.fromJson deserializes canonical snake_case events without falling back', () {
      final event = XpEvent.fromJson({
        'id': 'event-1',
        'event_type': 'lesson_complete',
        'xp_amount': 100,
        'source_id': 'lesson-1',
        'description': 'Completed Lesson 1',
        'earned_at': '2026-11-01T12:00:00Z',
      });

      expect(event.type, equals(XpEventType.lessonComplete));
      expect(event.xpAmount, equals(100));
      expect(event.sourceId, equals('lesson-1'));
    });

    test('XpEvent.fromJson deserializes legacy camelCase events', () {
      final event = XpEvent.fromJson({
        'id': 'event-2',
        'event_type': 'courseComplete',
        'xp_amount': 500,
        'source_id': 'course-1',
        'description': 'Completed Course 1',
        'earned_at': '2026-11-01T12:00:00Z',
      });

      expect(event.type, equals(XpEventType.courseComplete));
      expect(event.xpAmount, equals(500));
      expect(event.sourceId, equals('course-1'));
    });
  });

  group('Level and Tier Computation', () {
    test('calculates levels accurately across tiers', () {
      expect(XpConstants.levelFromXp(0), equals(1));
      expect(LevelTier.fromLevel(1), equals(LevelTier.bronze));

      final lvl5Xp = XpConstants.xpForLevel(5);
      expect(XpConstants.levelFromXp(lvl5Xp), equals(5));
      expect(LevelTier.fromLevel(5), equals(LevelTier.silver));

      final lvl10Xp = XpConstants.xpForLevel(10);
      expect(XpConstants.levelFromXp(lvl10Xp), equals(10));
      expect(LevelTier.fromLevel(10), equals(LevelTier.gold));
    });
  });
}

