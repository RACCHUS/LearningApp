import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/models/governance/usage_quota.dart';
import 'package:learning_pwa/services/supabase_health_service.dart';

class ObservabilityHealthSnapshot {
  final SystemUsageTelemetry? telemetry;
  final SupabaseStatus supabaseStatus;
  final int pingLatencyMs;
  final DateTime timestamp;

  const ObservabilityHealthSnapshot({
    this.telemetry,
    required this.supabaseStatus,
    required this.pingLatencyMs,
    required this.timestamp,
  });
}

/// Service providing administrative telemetry and platform cost observability for ECO-00C.
class CostObservabilityService {
  final SupabaseClient? _injectedClient;
  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;
  final SupabaseHealthService? _injectedHealthService;
  SupabaseHealthService get _healthService =>
      _injectedHealthService ?? SupabaseHealthService(client: _injectedClient);
  final _logger = AppLogger('CostObservabilityService');

  CostObservabilityService({
    SupabaseClient? supabase,
    SupabaseHealthService? healthService,
  })  : _injectedClient = supabase,
        _injectedHealthService = healthService;

  /// Check whether the current user has administrator authorization for cost metrics.
  Future<bool> isAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      final response = await _supabase.rpc('is_admin');
      return response == true;
    } catch (_) {
      return false;
    }
  }

  /// Fetch aggregated platform usage telemetry for the past [hours].
  Future<SystemUsageTelemetry?> fetchSystemTelemetry({int hours = 24}) async {
    try {
      final response = await _supabase.rpc(
        'get_system_usage_telemetry',
        params: {'p_hours': hours},
      );
      if (response == null) return null;
      return SystemUsageTelemetry.fromJson(
        response as Map<String, dynamic>,
      );
    } catch (e) {
      _logger.warn('Failed to fetch system telemetry: $e');
      return null;
    }
  }

  /// Perform a health probe measuring backend ping latency and reachability.
  Future<ObservabilityHealthSnapshot> measureHealthSnapshot({int hours = 24}) async {
    final stopwatch = Stopwatch()..start();
    final status = await _healthService.check();
    stopwatch.stop();
    final pingLatency = stopwatch.elapsedMilliseconds;

    SystemUsageTelemetry? telemetry;
    try {
      telemetry = await fetchSystemTelemetry(hours: hours);
    } catch (_) {}

    return ObservabilityHealthSnapshot(
      telemetry: telemetry,
      supabaseStatus: status,
      pingLatencyMs: pingLatency,
      timestamp: DateTime.now(),
    );
  }
}
