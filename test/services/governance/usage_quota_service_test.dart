import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/governance/usage_quota.dart';
import 'package:learning_pwa/services/governance/usage_quota_service.dart';

void main() {
  group('ECO-00C: UsageQuota Model Tests', () {
    test('calculates remaining balances and low thresholds correctly', () {
      final quota = UsageQuota(
        userId: 'usr-123',
        serviceTier: ServiceTier.learner,
        aiTokensUsedToday: 13000,
        aiTokensDailyLimit: 15000,
        ttsCharsUsedToday: 8500,
        ttsCharsDailyLimit: 10000,
        storageBytesUsed: 10485760, // 10 MB
        storageBytesLimit: 52428800, // 50 MB
        windowResetAt: DateTime.parse('2026-10-22T00:00:00Z'),
        updatedAt: DateTime.parse('2026-10-21T12:00:00Z'),
      );

      expect(quota.aiTokensRemaining, 2000);
      expect(quota.ttsCharsRemaining, 1500);
      expect(quota.storageBytesRemaining, 41943040);

      // 13000 / 15000 = ~86.7% used, so remaining is 2000 <= 3000 (20% of 15000)
      expect(quota.isAiTokenLow, isTrue);
      // 8500 / 10000 = 85% used, remaining 1500 <= 2000 (20% of 10000)
      expect(quota.isTtsLow, isTrue);

      expect(quota.aiTokensPercentUsed, closeTo(0.866, 0.01));
      expect(quota.ttsCharsPercentUsed, closeTo(0.85, 0.01));
    });

    test('toJson and fromJson preserves all fields', () {
      final original = UsageQuota(
        userId: 'usr-456',
        serviceTier: ServiceTier.educator,
        aiTokensUsedToday: 500,
        aiTokensDailyLimit: 60000,
        ttsCharsUsedToday: 1200,
        ttsCharsDailyLimit: 30000,
        storageBytesUsed: 2048,
        storageBytesLimit: 52428800,
        windowResetAt: DateTime.parse('2026-10-22T00:00:00Z'),
        updatedAt: DateTime.parse('2026-10-21T12:00:00Z'),
      );

      final json = original.toJson();
      final revived = UsageQuota.fromJson(json);

      expect(revived.userId, original.userId);
      expect(revived.serviceTier, ServiceTier.educator);
      expect(revived.aiTokensUsedToday, 500);
      expect(revived.aiTokensDailyLimit, 60000);
      expect(revived.ttsCharsUsedToday, 1200);
      expect(revived.ttsCharsDailyLimit, 30000);
      expect(revived.storageBytesUsed, 2048);
    });

    test('UsageCheckResult deserializes correctly', () {
      final json = {
        'allowed': true,
        'service_type': 'ai_tokens',
        'quantity_requested': 500,
        'remaining_balance': 14500,
        'window_reset_at': '2026-10-22T00:00:00Z',
      };

      final result = UsageCheckResult.fromJson(json);
      expect(result.allowed, isTrue);
      expect(result.serviceType, 'ai_tokens');
      expect(result.quantityRequested, 500);
      expect(result.remainingBalance, 14500);
      expect(result.windowResetAt, isNotNull);
    });

    test('SystemUsageTelemetry deserializes correctly', () {
      final json = {
        'window_hours': 24,
        'since': '2026-10-20T00:00:00Z',
        'total_ai_tokens': 150000,
        'total_tts_chars': 80000,
        'total_storage_bytes': 104857600,
        'active_users': 42,
        'total_events': 128,
        'estimated_cost_usd': 1.3046,
      };

      final telemetry = SystemUsageTelemetry.fromJson(json);
      expect(telemetry.windowHours, 24);
      expect(telemetry.totalAiTokens, 150000);
      expect(telemetry.totalTtsChars, 80000);
      expect(telemetry.totalStorageBytes, 104857600);
      expect(telemetry.activeUsers, 42);
      expect(telemetry.totalEvents, 128);
      expect(telemetry.estimatedCostUsd, 1.3046);
    });
  });

  group('ECO-00C: UsageQuotaService Logic Tests', () {
    test('estimates token count using prompt context heuristic', () {
      final service = UsageQuotaService();
      // 40 characters -> ~10 tokens
      const text = '1234567890123456789012345678901234567890';
      expect(service.estimateTokens(text), 10);
    });

    test('shouldFallbackToOnDeviceTts triggers on null quota or low balance', () {
      final service = UsageQuotaService();

      // Guest / null quota should always fallback to on-device Web Speech
      expect(service.shouldFallbackToOnDeviceTts(null), isTrue);

      // Healthy quota (> 20% remaining) should NOT fallback
      final healthyQuota = UsageQuota(
        userId: 'usr-789',
        serviceTier: ServiceTier.learner,
        aiTokensUsedToday: 100,
        aiTokensDailyLimit: 15000,
        ttsCharsUsedToday: 500, // 5% used, 95% remaining
        ttsCharsDailyLimit: 10000,
        storageBytesUsed: 0,
        storageBytesLimit: 52428800,
        windowResetAt: DateTime.now().add(const Duration(days: 1)),
        updatedAt: DateTime.now(),
      );
      expect(service.shouldFallbackToOnDeviceTts(healthyQuota), isFalse);

      // Depleted quota (<= 20% remaining) SHOULD fallback
      final lowQuota = UsageQuota(
        userId: 'usr-789',
        serviceTier: ServiceTier.learner,
        aiTokensUsedToday: 100,
        aiTokensDailyLimit: 15000,
        ttsCharsUsedToday: 8500, // 85% used, 15% remaining
        ttsCharsDailyLimit: 10000,
        storageBytesUsed: 0,
        storageBytesLimit: 52428800,
        windowResetAt: DateTime.now().add(const Duration(days: 1)),
        updatedAt: DateTime.now(),
      );
      expect(service.shouldFallbackToOnDeviceTts(lowQuota), isTrue);
    });
  });
}
