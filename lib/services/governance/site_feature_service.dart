import 'package:supabase_flutter/supabase_flutter.dart';

/// One-time bootstrap, not a live operator toggle. Keep false until the
/// database migration is deployed and reviewed. Once enabled in a client
/// release, subsequent administrative switch changes need no redeploy.
abstract final class SiteFeatureRuntime {
  static const bool snapshotEnabled = bool.fromEnvironment(
    'SITE_FEATURE_RPC_READY',
    defaultValue: false,
  );
}

/// A public visibility hint, never a server-side authorization grant.
class SiteFeatureSetting {
  final bool enabled;
  final String maturity;
  final int revision;

  const SiteFeatureSetting({
    required this.enabled,
    required this.maturity,
    required this.revision,
  });

  factory SiteFeatureSetting.fromJson(Map<String, dynamic> json) {
    return SiteFeatureSetting(
      enabled: json['enabled'] == true,
      maturity: json['maturity'] == 'verified' ? 'verified' : 'experimental',
      revision: (json['revision'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminSiteFeature {
  final String key;
  final String label;
  final String category;
  final String kind;
  final String description;
  final bool enabled;
  final bool releaseReady;
  final String maturity;
  final int revision;

  const AdminSiteFeature({
    required this.key,
    required this.label,
    required this.category,
    required this.kind,
    required this.description,
    required this.enabled,
    required this.releaseReady,
    required this.maturity,
    required this.revision,
  });

  factory AdminSiteFeature.fromJson(Map<String, dynamic> json) =>
      AdminSiteFeature(
        key: json['feature_key'] as String,
        label: json['label'] as String? ?? '',
        category: json['category'] as String? ?? '',
        kind: json['kind'] as String? ?? 'release',
        description: json['description'] as String? ?? '',
        enabled: json['enabled'] == true,
        releaseReady: json['release_ready'] == true,
        maturity: json['maturity'] == 'verified' ? 'verified' : 'experimental',
        revision: (json['revision'] as num?)?.toInt() ?? 0,
      );
}

/// Private operator-only audit row. Public snapshots never contain reasons
/// or actor identifiers.
class AdminFeatureChange {
  final String key;
  final String reason;
  final bool priorEnabled;
  final bool nextEnabled;
  final String priorMaturity;
  final String nextMaturity;
  final int newRevision;
  final String? actorId;
  final DateTime? changedAt;

  const AdminFeatureChange({
    required this.key,
    required this.reason,
    required this.priorEnabled,
    required this.nextEnabled,
    required this.priorMaturity,
    required this.nextMaturity,
    required this.newRevision,
    this.actorId,
    this.changedAt,
  });

  factory AdminFeatureChange.fromJson(Map<String, dynamic> data) {
    return AdminFeatureChange(
      key: data['feature_key'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      priorEnabled: data['prior_enabled'] == true,
      nextEnabled: data['next_enabled'] == true,
      priorMaturity: data['prior_maturity'] as String? ?? 'experimental',
      nextMaturity: data['next_maturity'] as String? ?? 'experimental',
      newRevision: (data['new_revision'] as num?)?.toInt() ?? 0,
      actorId: data['actor_id'] as String?,
      changedAt: DateTime.tryParse(data['changed_at']?.toString() ?? ''),
    );
  }
}

/// RPC client for the private first-party control plane.
/// Authorization, CAS revision and audit are always enforced by the database.
class SiteFeatureService {
  final SupabaseClient? _providedClient;

  SiteFeatureService({SupabaseClient? client}) : _providedClient = client;

  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  Future<Map<String, SiteFeatureSetting>> loadPublicSnapshot() async {
    if (!SiteFeatureRuntime.snapshotEnabled) {
      return const <String, SiteFeatureSetting>{};
    }
    try {
      final raw = await _client.rpc('get_site_feature_snapshot');
      if (raw is! Map) return const <String, SiteFeatureSetting>{};
      final entries = <String, SiteFeatureSetting>{};
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is Map) {
          entries[entry.key as String] = SiteFeatureSetting.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
      return entries;
    } catch (_) {
      // Existing TEL Fast/Overview remain available if the registry is offline.
      // All new sensitive or cost-bearing features remain default OFF.
      return const <String, SiteFeatureSetting>{};
    }
  }

  Future<bool> isAdmin() async {
    if (_client.auth.currentUser == null) return false;
    try {
      return await _client.rpc('is_admin') == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<AdminSiteFeature>> listAdminFeatures() async {
    if (!await isAdmin()) throw StateError('Administrator access required.');
    final raw = await _client.rpc('admin_list_site_features');
    if (raw is! List) throw StateError('Feature registry is unavailable.');
    return raw
        .whereType<Map>()
        .map((entry) =>
            AdminSiteFeature.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  /// Audit entries are available only through the authenticated admin RPC.
  /// This call is never used by learner-facing code.
  Future<List<AdminFeatureChange>> listRecentChanges({int limit = 20}) async {
    if (!await isAdmin()) throw StateError('Administrator access required.');
    final raw = await _client.rpc('admin_recent_site_feature_changes',
        params: {'p_limit': limit.clamp(1, 100)});
    if (raw is! List) throw StateError('Feature audit is unavailable.');
    return raw
        .whereType<Map>()
        .map((entry) =>
            AdminFeatureChange.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<void> updateFeature({
    required AdminSiteFeature current,
    required bool enabled,
    required String maturity,
    required String reason,
  }) async {
    if (!await isAdmin()) throw StateError('Administrator access required.');
    if (reason.trim().length < 8) {
      throw ArgumentError('Audit reason must have at least eight characters.');
    }
    await _client.rpc('admin_set_site_feature', params: {
      'p_feature_key': current.key,
      'p_enabled': enabled,
      'p_maturity': maturity,
      'p_expected_revision': current.revision,
      'p_reason': reason.trim(),
    });
  }
}
