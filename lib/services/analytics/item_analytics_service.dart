import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/analytics/item_analytics.dart';

/// Service interfacing with Supabase item analytics RPCs and tables.
class ItemAnalyticsService {
  final SupabaseClient _supabase;

  ItemAnalyticsService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Fetches psychometric analytics for a specific assessment question.
  Future<ItemAnalytics?> fetchItemAnalytics(String itemId) async {
    try {
      final res = await _supabase.rpc(
        'get_item_analytics',
        params: {'p_item_id': itemId},
      );
      if (res == null) return null;
      return ItemAnalytics.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      debugPrint('⚠️ Error fetching item analytics for $itemId: $e');
      return null;
    }
  }

  /// Triggers a background batch calculation of item psychometrics and auto-flags
  /// defective items into the moderation queue.
  Future<Map<String, dynamic>> computeAnalytics({int minResponses = 5}) async {
    try {
      final res = await _supabase.rpc(
        'compute_item_analytics',
        params: {'p_min_responses': minResponses},
      );
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('⚠️ Error computing item analytics: $e');
      rethrow;
    }
  }

  /// Fetches all items currently auto-flagged for psychometric defects.
  Future<List<ItemAnalytics>> fetchFlaggedItems() async {
    try {
      final res = await _supabase
          .from('item_analytics')
          .select()
          .eq('auto_flagged', true)
          .order('last_calculated_at', ascending: false);

      return (res as List)
          .map((row) => ItemAnalytics.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching flagged items: $e');
      return const [];
    }
  }
}

