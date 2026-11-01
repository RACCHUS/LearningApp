import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/models/user_xp.dart';
import 'package:uuid/uuid.dart';

/// Service for managing user XP and levels
class XpService {
  final SupabaseClient? _injectedClient;
  static const _uuid = Uuid();

  XpService({SupabaseClient? supabase}) : _injectedClient = supabase;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _userId => _client?.auth.currentUser?.id;

  /// Get user's total XP
  Future<int> getTotalXp() async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return 0;

    try {
      final response = await client
          .from('user_xp')
          .select('total_xp')
          .eq('user_id', userId)
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
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return UserXpSummary.empty();

    try {
      // Get total XP
      final totalXp = await getTotalXp();

      // Get today's XP
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

      final todayEvents = await client
          .from('xp_events')
          .select('xp_amount')
          .eq('user_id', userId)
          .gte('earned_at', todayStart.toIso8601String());

      int todayXp = 0;
      for (final event in todayEvents as List) {
        todayXp += event['xp_amount'] as int;
      }

      // Get this week's XP
      final weekEvents = await client
          .from('xp_events')
          .select('xp_amount')
          .eq('user_id', userId)
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

  /// Award XP to user via transactional, idempotent RPC
  Future<XpEvent?> awardXp({
    required XpEventType type,
    int? customAmount,
    String? sourceId,
    String? description,
    String? eventId,
  }) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return null;

    try {
      final xpAmount = customAmount ?? type.baseXp;
      final effectiveEventId = eventId ?? _uuid.v4();

      final result = await client.rpc('record_xp_award', params: {
        'p_event_id': effectiveEventId,
        'p_event_type': type.name,
        'p_xp_amount': xpAmount,
        'p_source_id': sourceId,
        'p_description': description,
      });

      final awardedXp = (result is Map)
          ? (result['awarded_xp'] as int? ?? xpAmount)
          : xpAmount;

      return XpEvent(
        id: effectiveEventId,
        type: type,
        xpAmount: awardedXp,
        sourceId: sourceId,
        description: description,
        earnedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error awarding XP: $e');
      }
      return null;
    }
  }

  /// Award XP for completing a question correctly.
  /// [lessonId] and [questionId] are both required to construct a stable source
  /// identifier ('$lessonId:$questionId'), ensuring distinct questions do not collide
  /// and repeated attempts for the same question adhere to replay cooldowns.
  Future<XpEvent?> awardQuestionXp(
    String lessonId, {
    required String questionId,
    String? eventId,
  }) async {
    final source = '$lessonId:$questionId';
    return awardXp(
      type: XpEventType.questionCorrect,
      sourceId: source,
      eventId: eventId,
    );
  }

  /// Award XP for completing a lesson
  Future<XpEvent?> awardLessonCompleteXp(String lessonId, String lessonTitle, {String? eventId}) async {
    return awardXp(
      type: XpEventType.lessonComplete,
      sourceId: lessonId,
      eventId: eventId,
      description: 'Completed "$lessonTitle"',
    );
  }

  /// Award XP for completing a course
  Future<XpEvent?> awardCourseCompleteXp(String courseId, String courseTitle, {String? eventId}) async {
    return awardXp(
      type: XpEventType.courseComplete,
      sourceId: courseId,
      eventId: eventId,
      description: 'Completed "$courseTitle"',
    );
  }

  /// Award XP for review session.
  /// [contextId] is required to ensure callers provide a stable session identifier,
  /// preventing retries or re-renders from bypassing the 15-minute replay cooldown.
  Future<XpEvent?> awardReviewSessionXp(
    int itemsReviewed, {
    required String contextId,
    String? eventId,
  }) async {
    final bonusXp = (itemsReviewed * 2).clamp(0, 50); // Max 50 bonus
    return awardXp(
      type: XpEventType.reviewSession,
      customAmount: XpConstants.perReviewSession + bonusXp,
      sourceId: contextId,
      eventId: eventId,
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
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return [];

    try {
      final response = await client
          .from('xp_events')
          .select()
          .eq('user_id', userId)
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
    String? eventId,
  }) async {
    final previousXp = state.totalXp;

    final event = await _service.awardXp(
      type: type,
      customAmount: customAmount,
      sourceId: sourceId,
      description: description,
      eventId: eventId,
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

  /// Award XP for question completion via notifier
  Future<void> awardQuestionXp(
    String lessonId, {
    required String questionId,
    String? eventId,
  }) async {
    await awardXp(
      type: XpEventType.questionCorrect,
      sourceId: '$lessonId:$questionId',
      eventId: eventId,
    );
  }

  /// Award XP for review session completion via notifier
  Future<void> awardReviewSessionXp(
    int itemsReviewed, {
    required String contextId,
    String? eventId,
  }) async {
    final bonusXp = (itemsReviewed * 2).clamp(0, 50);
    await awardXp(
      type: XpEventType.reviewSession,
      customAmount: XpConstants.perReviewSession + bonusXp,
      sourceId: contextId,
      eventId: eventId,
      description: 'Reviewed $itemsReviewed items',
    );
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
