import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/models/governance/usage_quota.dart';
import 'package:learning_pwa/services/prompt_context_compressor.dart';

/// Service providing client operations for ECO-00C Cost Quotas & Rate Limiting.
class UsageQuotaService {
  final _logger = AppLogger('UsageQuotaService');

  final _quotaController = StreamController<UsageQuota?>.broadcast();
  Stream<UsageQuota?> get quotaStream => _quotaController.stream;

  UsageQuota? _lastKnownQuota;
  UsageQuota? get lastKnownQuota => _lastKnownQuota;

  final SupabaseClient? _injectedClient;
  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;

  UsageQuotaService({SupabaseClient? supabase})
      : _injectedClient = supabase;

  /// Estimate tokens for text using ~4 characters per token heuristic.
  int estimateTokens(String text) => PromptContextCompressor.estimateTokens(text);

  /// Fetch the current user's active quota balances.
  Future<UsageQuota?> fetchMyQuota() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _lastKnownQuota = null;
      _quotaController.add(null);
      return null;
    }

    try {
      final response = await _supabase
          .from('usage_quotas')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        // Trigger initial record creation via zero-impact read probe
        _lastKnownQuota = UsageQuota(
          userId: user.id,
          serviceTier: ServiceTier.learner,
          aiTokensUsedToday: 0,
          aiTokensDailyLimit: 15000,
          ttsCharsUsedToday: 0,
          ttsCharsDailyLimit: 10000,
          storageBytesUsed: 0,
          storageBytesLimit: 52428800,
          windowResetAt: DateTime.now().add(const Duration(days: 1)),
          updatedAt: DateTime.now(),
        );
      } else {
        _lastKnownQuota = UsageQuota.fromJson(response);
      }

      _quotaController.add(_lastKnownQuota);
      return _lastKnownQuota;
    } catch (e) {
      _logger.warn('Failed to fetch usage quota: $e');
      return _lastKnownQuota;
    }
  }

  /// Atomic check and deduction against user quota.
  /// Returns [UsageCheckResult] with allowance status and remaining balance.
  Future<UsageCheckResult> checkAndRecordUsage({
    required QuotaServiceType serviceType,
    required int quantity,
    String provider = 'internal',
    Map<String, dynamic>? metadata,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      // Unauthenticated / Guest sessions have 0 cloud quota
      return UsageCheckResult(
        allowed: false,
        serviceType: serviceType.dbValue,
        quantityRequested: quantity,
        remainingBalance: 0,
      );
    }

    try {
      final response = await _supabase.rpc(
        'check_and_record_usage',
        params: {
          'p_service_type': serviceType.dbValue,
          'p_quantity': quantity,
          'p_provider': provider,
          'p_metadata': metadata ?? {},
        },
      );

      final result = UsageCheckResult.fromJson(
        response as Map<String, dynamic>,
      );

      // Refresh in background if allowed
      if (result.allowed) {
        unawaited(fetchMyQuota());
      }

      return result;
    } catch (e) {
      _logger.error('Quota check failed: $e');
      // In case of backend connectivity issues, fail-safe to on-device fallbacks
      return UsageCheckResult(
        allowed: false,
        serviceType: serviceType.dbValue,
        quantityRequested: quantity,
        remainingBalance: 0,
      );
    }
  }

  /// Determines whether TTS should gracefully degrade to on-device Web Speech API.
  bool shouldFallbackToOnDeviceTts(UsageQuota? quota) {
    if (quota == null) return true; // Guests default to local Web Speech
    return quota.isTtsLow || quota.ttsCharsRemaining <= 0;
  }

  void dispose() {
    _quotaController.close();
  }
}
