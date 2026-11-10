import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Trusted server state, never a browser authorization claim. The current
/// server intentionally reports collection_active=false pending policy review.
class ProductAnalyticsPrivacyStatus {
  final bool eligible;
  final bool consented;
  final bool isAnonymous;
  final bool collectionActive;
  final bool policyReady;
  final DateTime? changedAt;

  const ProductAnalyticsPrivacyStatus({
    required this.eligible,
    required this.consented,
    required this.isAnonymous,
    required this.collectionActive,
    required this.policyReady,
    this.changedAt,
  });

  bool get canCollect =>
      eligible && consented && !isAnonymous && policyReady &&
      collectionActive;

  bool get canOptIn =>
      eligible && !isAnonymous && policyReady && collectionActive;

  factory ProductAnalyticsPrivacyStatus.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1 ||
        json['eligible'] is! bool ||
        json['consented'] is! bool ||
        json['is_anonymous'] is! bool ||
        json['collection_active'] is! bool) {
      throw const FormatException('Unrecognized product privacy status');
    }
    final changed = json['changed_at'];
    final parsed = changed == null
        ? null
        : DateTime.tryParse(changed.toString());
    if (changed != null && parsed == null) {
      throw const FormatException('Invalid privacy status timestamp');
    }
    return ProductAnalyticsPrivacyStatus(
      eligible: json['eligible'] as bool,
      consented: json['consented'] as bool,
      isAnonymous: json['is_anonymous'] as bool,
      collectionActive: json['collection_active'] as bool,
      // The server does not yet signal approved disclosures. An absent value
      // is FALSE, never permission to begin telemetry or solicit opt-in.
      policyReady: json['policy_ready'] == true,
      changedAt: parsed?.toUtc(),
    );
  }
}

typedef ProductPrivacyRpc = Future<dynamic> Function(
    String functionName, Map<String, dynamic>? params);

/// Explicit privacy controls. No caller-supplied user id is passed to an RPC.
/// Failures must be displayed, never interpreted as a withdrawn opt-in.
class ProductAnalyticsPrivacyService {
  final ProductPrivacyRpc _rpc;
  final String? Function() _currentUserId;

  ProductAnalyticsPrivacyService({
    SupabaseClient? supabase,
    ProductPrivacyRpc? rpc,
    String? Function()? currentUserId,
  }) : _rpc = rpc ?? ((name, params) =>
            (supabase ?? Supabase.instance.client)
                .rpc(name, params: params)),
       _currentUserId = currentUserId ??
            (() => (supabase ?? Supabase.instance.client).auth.currentUser?.id);

  String _requireUser() {
    final id = _currentUserId();
    if (id == null || id.isEmpty) {
      throw StateError('Sign in to manage optional product analytics.');
    }
    return id;
  }

  void _sameUser(String id) {
    if (_requireUser() != id) {
      throw StateError('Account changed during product privacy action.');
    }
  }

  Future<ProductAnalyticsPrivacyStatus> status() async {
    final user = _requireUser();
    final result = await _rpc(
      'get_my_product_analytics_privacy_status', null);
    _sameUser(user);
    if (result is! Map) {
      throw StateError('Product analytics privacy controls unavailable.');
    }
    return ProductAnalyticsPrivacyStatus.fromJson(
      Map<String, dynamic>.from(result));
  }

  /// Consent is not yet enrollable: policyReady & collectionActive will stay
  /// false until an independently reviewed activation. Withdrawal stays usable.
  Future<ProductAnalyticsPrivacyStatus> chooseConsent(bool consent) async {
    final user = _requireUser();
    if (consent) {
      final current = await status();
      if (!current.canOptIn) {
        throw StateError('Product analytics enrollment is not available.');
      }
    }
    _sameUser(user);
    final raw = await _rpc('set_product_analytics_consent',
      {'p_consent': consent});
    _sameUser(user);
    if (raw is! Map || raw['consented'] != consent) {
      throw StateError('Privacy consent choice was not acknowledged.');
    }
    final state = await status();
    _sameUser(user);
    if (state.consented != consent) {
      throw StateError('Server privacy status did not confirm the change.');
    }
    return state;
  }

  /// Keyset pagination, no OFFSET gap, and repeated identity checks.
  /// A large export fails visibly instead of pretending 100 rows is complete.
  /// Caller can request individual pages directly for arbitrary record volume.
  Future<String> exportJson({int maximumRecords = 10000}) async {
    if (maximumRecords < 100 || maximumRecords > 100000) {
      throw ArgumentError.value(maximumRecords, 'maximumRecords');
    }
    final user = _requireUser();
    final events = <Map<String, dynamic>>[];
    String? beforeTime;
    String? beforeId;
    final seen = <String>{};

    while (true) {
      _sameUser(user);
      final result = await _rpc('export_my_product_events_page', {
        'p_before_received_at': beforeTime,
        'p_before_event_id': beforeId,
        'p_limit': 100,
      });
      _sameUser(user);
      if (result is! Map) {
        throw StateError('Product analytics export is unavailable.');
      }
      final page = Map<String, dynamic>.from(result);
      final rows = page['events'];
      final more = page['has_more'];
      if (rows is! List || more is! bool || rows.length > 100) {
        throw StateError('Product analytics export page is malformed.');
      }
      for (final item in rows) {
        if (item is! Map) {
          throw StateError('Product analytics export record is malformed.');
        }
        final row = Map<String, dynamic>.from(item);
        final id = row['event_id'];
        if (id is! String || !seen.add(id)) {
          throw StateError('Repeated or unidentifiable export record.');
        }
        events.add(row);
        if (events.length > maximumRecords) {
          throw StateError('Export exceeds in-app limit; use paginated export.');
        }
      }
      if (!more) break;
      final nextTime = page['next_before_received_at'];
      final nextId = page['next_before_event_id'];
      if (nextTime is! String || nextId is! String ||
          (nextTime == beforeTime && nextId == beforeId)) {
        throw StateError('Incomplete or repeated export cursor.');
      }
      beforeTime = nextTime;
      beforeId = nextId;
    }
    _sameUser(user);
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'learningapp-product-analytics-export',
      'schema_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'events': events,
    });
  }
}
