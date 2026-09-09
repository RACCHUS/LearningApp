import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:learning_pwa/core/logging/app_logger.dart';

/// Reachability of the Supabase backend, independent of device connectivity.
///
/// [unreachable] specifically means the device has a network but the Supabase
/// project did not answer in time — most commonly because a free-tier project
/// was paused after inactivity, or a transient outage.
enum SupabaseStatus { unknown, reachable, unreachable }

/// Pings Supabase with a cheap, timeout-bounded query to tell whether the
/// backend is actually answering (not just whether the device is online).
class SupabaseHealthService {
  SupabaseHealthService({SupabaseClient? client, Duration? timeout})
      : _client = client ?? Supabase.instance.client,
        _timeout = timeout ?? const Duration(seconds: 6);

  final SupabaseClient _client;
  final Duration _timeout;
  final _logger = AppLogger('SupabaseHealthService');

  /// Performs a single lightweight reachability probe.
  ///
  /// Reads one id from the public `lessons` table (public rows are readable
  /// under RLS). An empty result still counts as reachable; only a network
  /// error or timeout counts as [SupabaseStatus.unreachable].
  Future<SupabaseStatus> check() async {
    try {
      await _client
          .from('lessons')
          .select('id')
          .limit(1)
          .timeout(_timeout);
      return SupabaseStatus.reachable;
    } on TimeoutException catch (e) {
      _logger.warn('Supabase health probe timed out: $e');
      return SupabaseStatus.unreachable;
    } catch (e) {
      // A PostgrestException with an HTTP status means the server DID answer,
      // so the backend is reachable even if this particular query was rejected.
      if (e is PostgrestException && e.code != null) {
        return SupabaseStatus.reachable;
      }
      _logger.warn('Supabase unreachable: $e');
      return SupabaseStatus.unreachable;
    }
  }
}
