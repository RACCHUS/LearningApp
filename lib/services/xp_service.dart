import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/models/achievement.dart';
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

  /// Claims server-awarded XP for a finished activity (`claim_activity_xp`).
  ///
  /// The server fixes the amount, applies cooldowns, daily limits and the
  /// `learning.xp_achievements` gate, and returns any achievements this
  /// claim earned. Returns null when signed out, offline or refused; XP is
  /// a motivation extra and never blocks the learning flow.
  Future<ActivityXpResult?> claimActivityXp({
    required ActivityXpKind kind,
    required String sourceId,
    String? eventId,
  }) async {
    final client = _client;
    if (client == null || _userId == null || sourceId.trim().isEmpty) {
      return null;
    }
    try {
      final result = await client.rpc('claim_activity_xp', params: {
        'p_event_id': eventId ?? _uuid.v4(),
        'p_kind': kind.wireName,
        'p_source_id': sourceId,
      });
      if (result is! Map) return null;
      return ActivityXpResult.fromJson(Map<String, dynamic>.from(result));
    } catch (e) {
      if (kDebugMode) {
        print('XP claim skipped: $e');
      }
      return null;
    }
  }

  /// The signed-in learner's earned achievement keys, oldest first.
  Future<List<EarnedAchievementRecord>> getAchievements() async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return const [];
    try {
      final rows = await client
          .from('user_achievements')
          .select('achievement_key, earned_at')
          .eq('user_id', userId)
          .order('earned_at', ascending: true);
      return (rows as List)
          .map((row) => EarnedAchievementRecord.fromJson(
              Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching achievements: $e');
      }
      return const [];
    }
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

/// Earned achievements for the signed-in learner.
final userAchievementsProvider =
    FutureProvider<List<EarnedAchievementRecord>>((ref) async {
  return ref.read(xpServiceProvider).getAchievements();
});
