import 'package:supabase_flutter/supabase_flutter.dart';

/// The server is the sole source for administrative product-event totals.
/// Raw event records are not exposed to the client or admin UI.
class ProductAnalyticsOverview {
  final String status;
  final int days;
  final DateTime asOf;
  final String coverage;
  final int? activeUsers;
  final int? eventCount;
  final int? sessionStarts;
  final int? resourceOpens;
  final int? externalClicks;

  const ProductAnalyticsOverview({
    required this.status,
    required this.days,
    required this.asOf,
    required this.coverage,
    required this.activeUsers,
    required this.eventCount,
    required this.sessionStarts,
    required this.resourceOpens,
    required this.externalClicks,
  });

  factory ProductAnalyticsOverview.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String?;
    if (status != 'not_measured' &&
        status != 'small_cohort_suppressed' &&
        status != 'measured') {
      throw FormatException('Unknown product analytics measurement status');
    }
    final days = json['window_days'];
    final asOf = DateTime.tryParse(json['as_of']?.toString() ?? '');
    if (days is! int || asOf == null) {
      throw FormatException('Missing analytics freshness or window');
    }
    int? count(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is int && value >= 0) return value;
      throw FormatException('Invalid aggregate count');
    }

    final data = ProductAnalyticsOverview(
      status: status!,
      days: days,
      asOf: asOf.toUtc(),
      coverage: json['coverage'] as String? ?? 'unknown',
      activeUsers: count('unique_active_users'),
      eventCount: count('event_count'),
      sessionStarts: count('session_starts'),
      resourceOpens: count('resource_opens'),
      externalClicks: count('external_clicks'),
    );
    if (status != 'measured' &&
        (data.activeUsers != null || data.eventCount != null ||
            data.sessionStarts != null || data.resourceOpens != null ||
            data.externalClicks != null)) {
      throw FormatException('Suppressed or missing data must not include counts');
    }
    if (status == 'measured' &&
        (data.activeUsers == null || data.eventCount == null)) {
      throw FormatException('Measured analytics requires verified totals');
    }
    return data;
  }
}

class ProductAnalyticsOverviewService {
  final SupabaseClient? _injectedClient;

  ProductAnalyticsOverviewService({SupabaseClient? supabase})
      : _injectedClient = supabase;

  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  Future<bool> isAdmin() async {
    if (_client.auth.currentUser == null) return false;
    try {
      return await _client.rpc('is_admin') == true;
    } catch (_) {
      return false;
    }
  }

  Future<ProductAnalyticsOverview> fetch({int days = 7}) async {
    if (days != 1 && days != 7 && days != 30) {
      throw ArgumentError.value(days, 'days', 'Only 1, 7 or 30 day windows');
    }
    // This RPC checks public.is_admin() on the server every call.
    final result = await _client.rpc(
      'get_product_analytics_overview',
      params: {'p_days': days},
    );
    if (result is! Map) {
      throw StateError('Admin analytics response is unavailable');
    }
    return ProductAnalyticsOverview.fromJson(
      Map<String, dynamic>.from(result),
    );
  }
}
