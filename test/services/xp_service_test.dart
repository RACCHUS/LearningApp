import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/achievement.dart';
import 'package:learning_pwa/models/user_xp.dart';
import 'package:learning_pwa/providers/xp_achievements_provider.dart';
import 'package:learning_pwa/services/xp_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../test_helpers/fake_supabase_client.dart';

void main() {
  group('XpConstants', () {
    test('should calculate correct XP thresholds for early levels', () {
      // Formula: baseXp * (level - 1) * (1 + (level - 1) * 0.5)
      expect(XpConstants.xpForLevel(1), 0);
      expect(XpConstants.xpForLevel(2), 150); // 100 * 1 * 1.5 = 150
      expect(XpConstants.xpForLevel(3), 400); // 100 * 2 * 2 = 400
    });

    test('should calculate level from XP correctly', () {
      expect(XpConstants.levelFromXp(0), 1);
      expect(XpConstants.levelFromXp(50), 1);
      expect(XpConstants.levelFromXp(100), 1);
      expect(XpConstants.levelFromXp(150), 2);
      expect(XpConstants.levelFromXp(300), 2);
      expect(XpConstants.levelFromXp(400), 3);
    });

    test('should calculate progress to next level', () {
      // At level 1, 75 XP out of 150 needed = 0.5
      final progress = XpConstants.progressToNextLevel(75);
      expect(progress, closeTo(0.5, 0.01));
    });

    test('should return 0 progress at exactly level boundary', () {
      final progress = XpConstants.progressToNextLevel(150);
      expect(progress, closeTo(0.0, 0.01));
    });

    test('should calculate XP needed for next level', () {
      // At 50 XP (level 1), need 100 more to reach level 2 (150)
      final needed = XpConstants.xpToNextLevel(50);
      expect(needed, 100);
    });
  });

  group('LevelTier', () {
    test('should have correct display names', () {
      expect(LevelTier.bronze.displayName, 'Bronze');
      expect(LevelTier.silver.displayName, 'Silver');
      expect(LevelTier.gold.displayName, 'Gold');
      expect(LevelTier.platinum.displayName, 'Platinum');
      expect(LevelTier.diamond.displayName, 'Diamond');
      expect(LevelTier.master.displayName, 'Master');
    });

    test('should return correct tier for each level range', () {
      expect(LevelTier.fromLevel(1), LevelTier.bronze);
      expect(LevelTier.fromLevel(4), LevelTier.bronze);
      expect(LevelTier.fromLevel(5), LevelTier.silver);
      expect(LevelTier.fromLevel(9), LevelTier.silver);
      expect(LevelTier.fromLevel(10), LevelTier.gold);
      expect(LevelTier.fromLevel(19), LevelTier.gold);
      expect(LevelTier.fromLevel(20), LevelTier.platinum);
      expect(LevelTier.fromLevel(34), LevelTier.platinum);
      expect(LevelTier.fromLevel(35), LevelTier.diamond);
      expect(LevelTier.fromLevel(49), LevelTier.diamond);
      expect(LevelTier.fromLevel(50), LevelTier.master);
      expect(LevelTier.fromLevel(100), LevelTier.master);
    });
  });

  group('XpEventType', () {
    test('should have correct base XP amounts', () {
      expect(XpEventType.questionCorrect.baseXp, XpConstants.perQuestion);
      expect(XpEventType.lessonComplete.baseXp, XpConstants.perLesson);
      expect(XpEventType.courseComplete.baseXp, XpConstants.perCourse);
      expect(XpEventType.reviewSession.baseXp, XpConstants.perReviewSession);
      expect(XpEventType.streakBonus.baseXp, XpConstants.perStreakDay);
      expect(XpEventType.dailyGoal.baseXp, 20);
    });

    test('should have correct display names', () {
      expect(XpEventType.questionCorrect.displayName, 'Correct Answer');
      expect(XpEventType.lessonComplete.displayName, 'Lesson Complete');
      expect(XpEventType.dailyGoal.displayName, 'Daily Goal');
      expect(XpEventType.streakBonus.displayName, 'Streak Bonus');
    });
  });

  group('XpEvent', () {
    test('should create event with correct fields', () {
      final now = DateTime.now();
      final event = XpEvent(
        id: 'test-id',
        type: XpEventType.questionCorrect,
        xpAmount: 10,
        earnedAt: now,
      );

      expect(event.id, 'test-id');
      expect(event.type, XpEventType.questionCorrect);
      expect(event.xpAmount, 10);
      expect(event.earnedAt, now);
    });

    test('should serialize to JSON correctly', () {
      final event = XpEvent(
        id: 'test-id',
        type: XpEventType.lessonComplete,
        xpAmount: 50,
        earnedAt: DateTime(2024, 1, 15, 10, 30),
        sourceId: 'lesson-123',
        description: 'Completed French Basics',
      );

      final json = event.toJson();

      expect(json['id'], 'test-id');
      expect(json['event_type'], 'lessonComplete');
      expect(json['xp_amount'], 50);
      expect(json['source_id'], 'lesson-123');
      expect(json['description'], 'Completed French Basics');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'json-id',
        'event_type': 'dailyGoal',
        'xp_amount': 25,
        'earned_at': '2024-01-15T10:30:00.000',
        'source_id': null,
        'description': null,
      };

      final event = XpEvent.fromJson(json);

      expect(event.id, 'json-id');
      expect(event.type, XpEventType.dailyGoal);
      expect(event.xpAmount, 25);
    });
  });

  group('UserXpSummary', () {
    test('should create empty summary with level 1', () {
      final summary = UserXpSummary.empty();

      expect(summary.totalXp, 0);
      expect(summary.level, 1);
      expect(summary.progressToNextLevel, 0.0);
    });

    test('should calculate level from total XP using factory', () {
      final summary = UserXpSummary.fromTotalXp(400, todayXp: 50, weekXp: 100);

      expect(summary.level, 3); // 400 XP is level 3
      expect(summary.xpEarnedToday, 50);
      expect(summary.xpEarnedThisWeek, 100);
    });

    test('should calculate progress to next level', () {
      // At level 1, 75 XP progress towards 150 = 0.5
      final summary = UserXpSummary.fromTotalXp(75);

      expect(summary.level, 1);
      expect(summary.progressToNextLevel, closeTo(0.5, 0.05));
    });

    test('should detect level up correctly', () {
      final summary = UserXpSummary.fromTotalXp(200);
      expect(summary.didLevelUp(50), isTrue); // Level 1 (50) → Level 2 (200)
      expect(summary.didLevelUp(160), isFalse); // Both at Level 2
    });
  });

  group('LevelTier from level', () {
    test('should correctly identify tier from level', () {
      // Level 5 should be Silver
      expect(LevelTier.fromLevel(5), LevelTier.silver);

      // Level 10 should be Gold
      expect(LevelTier.fromLevel(10), LevelTier.gold);

      // Level 20 should be Platinum
      expect(LevelTier.fromLevel(20), LevelTier.platinum);
    });
  });

  group('XP Progression Tests', () {
    test('should require exponentially more XP for higher levels', () {
      final xpFor5 = XpConstants.xpForLevel(5);
      final xpFor10 = XpConstants.xpForLevel(10);
      final xpFor15 = XpConstants.xpForLevel(15);
      
      final gap5to10 = xpFor10 - xpFor5;
      final gap10to15 = xpFor15 - xpFor10;
      
      // Gap should increase as levels go up
      expect(gap10to15, greaterThan(gap5to10));
    });

    test('should handle edge cases in level calculation', () {
      expect(XpConstants.levelFromXp(-1), 1); // Negative XP
      expect(XpConstants.levelFromXp(0), 1); // Zero XP
      expect(XpConstants.levelFromXp(1), 1); // Small XP
      expect(XpConstants.levelFromXp(999999), greaterThan(50)); // Very high XP
    });
  });

  group('XpService.claimActivityXp', () {
    User user() => User(
          id: 'test-user-id',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );

    test('sends only kind, source and event id; never an XP amount', () async {
      final calls = <(String, Map<String, dynamic>?)>[];
      final client = FakeSupabaseClient(currentUser: user())
        ..rpcHandler = (fn, {params}) {
          calls.add((fn, params));
          return {
            'status': 'awarded',
            'awarded_xp': 50,
            'total_xp': 50,
            'new_achievements': ['first_lesson', 'not_in_this_build'],
          };
        };

      final result = await XpService(supabase: client).claimActivityXp(
        kind: ActivityXpKind.lessonComplete,
        sourceId: 'lesson-1',
        eventId: 'e-1',
      );

      expect(calls.single.$1, 'claim_activity_xp');
      expect(calls.single.$2, {
        'p_event_id': 'e-1',
        'p_kind': 'lesson_complete',
        'p_source_id': 'lesson-1',
      });
      expect(result!.awarded, isTrue);
      expect(result.awardedXp, 50);
      expect(result.newAchievements, ['first_lesson'],
          reason: 'unknown server keys are dropped, not shown raw');
    });

    test('a cooldown or limit answer is not reported as awarded', () async {
      final client = FakeSupabaseClient(currentUser: user())
        ..rpcHandler = (fn, {params}) => {
              'status': 'limit_reached',
              'awarded_xp': 0,
              'total_xp': 900,
              'new_achievements': <String>[],
            };
      final result = await XpService(supabase: client).claimActivityXp(
          kind: ActivityXpKind.reviewSession, sourceId: 's-1');
      expect(result!.awarded, isFalse);
      expect(result.totalXp, 900);
    });

    test('signed out or blank source sends nothing', () async {
      var calls = 0;
      final signedOut = FakeSupabaseClient()
        ..rpcHandler = (fn, {params}) => calls++;
      expect(
          await XpService(supabase: signedOut).claimActivityXp(
              kind: ActivityXpKind.lessonComplete, sourceId: 'lesson-1'),
          isNull);
      final signedIn = FakeSupabaseClient(currentUser: user())
        ..rpcHandler = (fn, {params}) => calls++;
      expect(
          await XpService(supabase: signedIn).claimActivityXp(
              kind: ActivityXpKind.lessonComplete, sourceId: '  '),
          isNull);
      expect(calls, 0);
    });

    test('a server refusal returns null instead of throwing', () async {
      final client = FakeSupabaseClient(currentUser: user())
        ..rpcHandler = (fn, {params}) => throw Exception('feature_disabled');
      expect(
          await XpService(supabase: client).claimActivityXp(
              kind: ActivityXpKind.lessonComplete, sourceId: 'lesson-1'),
          isNull);
    });

    test('getAchievements reads only the learner own rows', () async {
      final client = FakeSupabaseClient(currentUser: user())
        ..setTableData('user_achievements', [
          {
            'user_id': 'test-user-id',
            'achievement_key': 'first_lesson',
            'earned_at': '2026-11-15T10:00:00Z',
          },
          {
            'user_id': 'someone-else',
            'achievement_key': 'lessons_10',
            'earned_at': '2026-11-15T10:00:00Z',
          },
        ]);
      final earned = await XpService(supabase: client).getAchievements();
      expect(earned.map((e) => e.key), ['first_lesson']);
    });
  });

  group('ActivityXpRecorder', () {
    test('gate OFF claims nothing and sends no request', () async {
      var calls = 0;
      final client = FakeSupabaseClient(
        currentUser: User(
          id: 'u',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-11-15T00:00:00Z',
        ),
      )..rpcHandler = (fn, {params}) => calls++;
      final container = ProviderContainer(overrides: [
        xpAchievementsEnabledProvider.overrideWithValue(false),
        xpServiceProvider.overrideWithValue(XpService(supabase: client)),
      ]);
      addTearDown(container.dispose);

      final result = await container
          .read(activityXpRecorderProvider)
          .record(ActivityXpKind.lessonComplete, 'lesson-1');
      expect(result, isNull);
      expect(calls, 0);
    });

    test('gate ON forwards the claim', () async {
      final client = FakeSupabaseClient(
        currentUser: User(
          id: 'u',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-11-15T00:00:00Z',
        ),
      )..rpcHandler = (fn, {params}) => {
            'status': 'awarded',
            'awarded_xp': 25,
            'total_xp': 25,
            'new_achievements': ['first_review'],
          };
      final container = ProviderContainer(overrides: [
        xpAchievementsEnabledProvider.overrideWithValue(true),
        xpServiceProvider.overrideWithValue(XpService(supabase: client)),
      ]);
      addTearDown(container.dispose);

      final result = await container
          .read(activityXpRecorderProvider)
          .record(ActivityXpKind.reviewSession, 'session-1');
      expect(result?.awardedXp, 25);
    });
  });
}
