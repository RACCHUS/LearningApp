import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/models/user_xp.dart';
import 'package:uuid/uuid.dart';

/// Service for managing user XP and levels
class XpService {
  final SupabaseClient _supabase;
  static const _uuid = Uuid();

  XpService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Get user's total XP
  Future<int> getTotalXp() async {
    if (_userId == null) return 0;

    try {
      final response = await _supabase
          .from('user_xp')
          .select('total_xp')
          .eq('user_id', _userId!)
          .maybeSingle();

      if (response == null) return 0;
      return response['total_xp'] as int? ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching total XP: $e');
      }
      return 0;
    }
  }

  /// Get comprehensive XP summary
  Future<UserXpSummary> getXpSummary() async {
    if (_userId == null) return UserXpSummary.empty();

    try {
      // Get total XP
      final totalXp = await getTotalXp();

      // Get today's XP
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

      final todayEvents = await _supabase
          .from('xp_events')
          .select('xp_amount')
          .eq('user_id', _userId!)
          .gte('earned_at', todayStart.toIso8601String());

      int todayXp = 0;
      for (final event in todayEvents as List) {
        todayXp += event['xp_amount'] as int;
      }

      // Get this week's XP
      final weekEvents = await _supabase
          .from('xp_events')
          .select('xp_amount')
          .eq('user_id', _userId!)
          .gte('earned_at', weekStart.toIso8601String());

      int weekXp = 0;
      for (final event in weekEvents as List) {
        weekXp += event['xp_amount'] as int;
      }

      return UserXpSummary.fromTotalXp(
        totalXp,
        todayXp: todayXp,
        weekXp: weekXp,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching XP summary: $e');
      }
      return UserXpSummary.empty();
    }
  }

  /// Award XP to user
  Future<XpEvent?> awardXp({
    required XpEventType type,
    int? customAmount,
    String? sourceId,
    String? description,
  }) async {
    if (_userId == null) return null;

    try {
      final xpAmount = customAmount ?? type.baseXp;

      // Create XP event
      final event = XpEvent(
        id: _uuid.v4(),
        type: type,
        xpAmount: xpAmount,
        sourceId: sourceId,
        description: description,
        earnedAt: DateTime.now(),
      );

      // Insert event
      await _supabase.from('xp_events').insert({
        ...event.toJson(),
        'user_id': _userId,
      });

      // Update total XP (upsert)
      await _supabase.rpc('increment_user_xp', params: {
        'p_user_id': _userId,
        'p_xp_amount': xpAmount,
      });

      return event;
    } catch (e) {
      if (kDebugMode) {
        print('Error awarding XP: $e');
      }
      return null;
    }
  }

  /// Award XP for completing a question correctly
  Future<XpEvent?> awardQuestionXp(String lessonId) async {
    return awardXp(
      type: XpEventType.questionCorrect,
      sourceId: lessonId,
    );
  }

  /// Award XP for completing a lesson
  Future<XpEvent?> awardLessonCompleteXp(String lessonId, String lessonTitle) async {
    return awardXp(
      type: XpEventType.lessonComplete,
      sourceId: lessonId,
      description: 'Completed "$lessonTitle"',
    );
  }

  /// Award XP for completing a course
  Future<XpEvent?> awardCourseCompleteXp(String courseId, String courseTitle) async {
    return awardXp(
      type: XpEventType.courseComplete,
      sourceId: courseId,
      description: 'Completed "$courseTitle"',
    );
  }

  /// Award XP for review session
  Future<XpEvent?> awardReviewSessionXp(int itemsReviewed) async {
    final bonusXp = (itemsReviewed * 2).clamp(0, 50); // Max 50 bonus
    return awardXp(
      type: XpEventType.reviewSession,
      customAmount: XpConstants.perReviewSession + bonusXp,
      description: 'Reviewed $itemsReviewed items',
    );
  }

  /// Award streak bonus XP
  Future<XpEvent?> awardStreakBonusXp(int streakDays) async {
    final xpAmount = XpConstants.perStreakDay * streakDays;
    return awardXp(
      type: XpEventType.streakBonus,
      customAmount: xpAmount,
      description: '$streakDays day streak!',
    );
  }

  /// Get recent XP events
  Future<List<XpEvent>> getRecentEvents({int limit = 20}) async {
    if (_userId == null) return [];

    try {
      final response = await _supabase
          .from('xp_events')
          .select()
          .eq('user_id', _userId!)
          .order('earned_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((row) => XpEvent.fromJson(row))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching XP events: $e');
      }
      return [];
    }
  }
}

/// Provider for XpService
final xpServiceProvider = Provider<XpService>((ref) {
  return XpService();
});

/// Provider for user XP summary
final userXpSummaryProvider = FutureProvider<UserXpSummary>((ref) async {
  final service = ref.read(xpServiceProvider);
  return service.getXpSummary();
});

/// Provider for total XP only (lighter query)
final totalXpProvider = FutureProvider<int>((ref) async {
  final service = ref.read(xpServiceProvider);
  return service.getTotalXp();
});

/// Provider for recent XP events
final recentXpEventsProvider = FutureProvider<List<XpEvent>>((ref) async {
  final service = ref.read(xpServiceProvider);
  return service.getRecentEvents();
});

/// Notifier for tracking XP changes and level-ups
class XpNotifier extends StateNotifier<XpState> {
  final XpService _service;
  final Ref _ref;

  XpNotifier(this._service, this._ref) : super(const XpState());

  /// Award XP and check for level up
  Future<void> awardXp({
    required XpEventType type,
    int? customAmount,
    String? sourceId,
    String? description,
  }) async {
    final previousXp = state.totalXp;

    final event = await _service.awardXp(
      type: type,
      customAmount: customAmount,
      sourceId: sourceId,
      description: description,
    );

    if (event != null) {
      final newTotalXp = previousXp + event.xpAmount;
      final previousLevel = XpConstants.levelFromXp(previousXp);
      final newLevel = XpConstants.levelFromXp(newTotalXp);
      final leveledUp = newLevel > previousLevel;

      state = XpState(
        totalXp: newTotalXp,
        lastEvent: event,
        didLevelUp: leveledUp,
        newLevel: leveledUp ? newLevel : null,
      );

      // Invalidate providers to refresh data
      _ref.invalidate(userXpSummaryProvider);
      _ref.invalidate(totalXpProvider);
    }
  }

  void clearLevelUpNotification() {
    state = state.copyWith(didLevelUp: false, newLevel: null);
  }
}

/// State for XP tracking
class XpState {
  final int totalXp;
  final XpEvent? lastEvent;
  final bool didLevelUp;
  final int? newLevel;

  const XpState({
    this.totalXp = 0,
    this.lastEvent,
    this.didLevelUp = false,
    this.newLevel,
  });

  XpState copyWith({
    int? totalXp,
    XpEvent? lastEvent,
    bool? didLevelUp,
    int? newLevel,
  }) {
    return XpState(
      totalXp: totalXp ?? this.totalXp,
      lastEvent: lastEvent ?? this.lastEvent,
      didLevelUp: didLevelUp ?? this.didLevelUp,
      newLevel: newLevel,
    );
  }
}

/// Provider for XP notifier
final xpNotifierProvider = StateNotifierProvider<XpNotifier, XpState>((ref) {
  final service = ref.read(xpServiceProvider);
  return XpNotifier(service, ref);
});
