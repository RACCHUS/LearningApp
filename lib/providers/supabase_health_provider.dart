import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_pwa/providers/connectivity_provider.dart';
import 'package:learning_pwa/services/supabase_health_service.dart';

final supabaseHealthServiceProvider = Provider<SupabaseHealthService>((ref) {
  return SupabaseHealthService();
});

/// Tracks whether the Supabase backend is answering, refreshing periodically
/// and skipping probes while the device itself is offline.
final supabaseHealthProvider =
    StateNotifierProvider<SupabaseHealthNotifier, SupabaseStatus>((ref) {
  return SupabaseHealthNotifier(ref.watch(supabaseHealthServiceProvider), ref);
});

class SupabaseHealthNotifier extends StateNotifier<SupabaseStatus> {
  SupabaseHealthNotifier(this._service, this._ref)
      : super(SupabaseStatus.unknown) {
    _start();
  }

  final SupabaseHealthService _service;
  final Ref _ref;
  Timer? _timer;

  static const Duration _interval = Duration(minutes: 2);

  void _start() {
    refresh();
    _timer = Timer.periodic(_interval, (_) => refresh());
  }

  /// Re-probe the backend now (e.g. from a "Retry" button).
  Future<void> refresh() async {
    // Device-offline is a separate, more specific banner — don't double-report.
    final deviceOnline = _ref.read(connectivityProvider);
    if (!deviceOnline) {
      if (mounted) state = SupabaseStatus.unknown;
      return;
    }
    final result = await _service.check();
    if (mounted) state = result;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
