import 'dart:math';

/// Domain models for ECO-00C: Cost, Quotas & Observability Architecture.
/// Canonical database contract aligned with `public.usage_quotas` and `public.usage_events`.

enum ServiceTier {
  learner('learner', 'Learner'),
  educator('educator', 'Educator'),
  admin('admin', 'Administrator');

  const ServiceTier(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static ServiceTier fromDb(String? value) {
    if (value == null) return ServiceTier.learner;
    return ServiceTier.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => ServiceTier.learner,
    );
  }
}

enum QuotaServiceType {
  aiTokens('ai_tokens', 'AI Tokens'),
  ttsChars('tts_chars', 'TTS Characters'),
  sttSeconds('stt_seconds', 'STT Seconds'),
  storageBytes('storage_bytes', 'Storage Bytes');

  const QuotaServiceType(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static QuotaServiceType fromDb(String? value) {
    if (value == null) {
      throw ArgumentError.notNull('serviceType');
    }
    return QuotaServiceType.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => throw FormatException('Unknown quota service type: $value'),
    );
  }
}

class UsageQuota {
  final String userId;
  final ServiceTier serviceTier;
  final int aiTokensUsedToday;
  final int aiTokensDailyLimit;
  final int ttsCharsUsedToday;
  final int ttsCharsDailyLimit;
  final int sttSecondsUsedToday;
  final int sttSecondsDailyLimit;
  final int storageBytesUsed;
  final int storageBytesLimit;
  final int eventsRecordedToday;
  final int eventsDailyLimit;
  final DateTime windowResetAt;
  final DateTime updatedAt;

  const UsageQuota({
    required this.userId,
    required this.serviceTier,
    required this.aiTokensUsedToday,
    required this.aiTokensDailyLimit,
    required this.ttsCharsUsedToday,
    required this.ttsCharsDailyLimit,
    this.sttSecondsUsedToday = 0,
    this.sttSecondsDailyLimit = 3600,
    required this.storageBytesUsed,
    required this.storageBytesLimit,
    this.eventsRecordedToday = 0,
    this.eventsDailyLimit = 1000,
    required this.windowResetAt,
    required this.updatedAt,
  });

  int get aiTokensRemaining => max(0, aiTokensDailyLimit - aiTokensUsedToday);
  int get ttsCharsRemaining => max(0, ttsCharsDailyLimit - ttsCharsUsedToday);
  int get sttSecondsRemaining => max(0, sttSecondsDailyLimit - sttSecondsUsedToday);
  int get storageBytesRemaining => max(0, storageBytesLimit - storageBytesUsed);
  int get eventsRemaining => max(0, eventsDailyLimit - eventsRecordedToday);

  double get aiTokensPercentUsed =>
      aiTokensDailyLimit > 0 ? (aiTokensUsedToday / aiTokensDailyLimit).clamp(0.0, 1.0) : 0.0;

  double get ttsCharsPercentUsed =>
      ttsCharsDailyLimit > 0 ? (ttsCharsUsedToday / ttsCharsDailyLimit).clamp(0.0, 1.0) : 0.0;

  double get sttSecondsPercentUsed =>
      sttSecondsDailyLimit > 0 ? (sttSecondsUsedToday / sttSecondsDailyLimit).clamp(0.0, 1.0) : 0.0;

  double get storagePercentUsed =>
      storageBytesLimit > 0 ? (storageBytesUsed / storageBytesLimit).clamp(0.0, 1.0) : 0.0;

  double get eventsPercentUsed =>
      eventsDailyLimit > 0 ? (eventsRecordedToday / eventsDailyLimit).clamp(0.0, 1.0) : 0.0;

  bool get isAiTokenLow => aiTokensRemaining <= (aiTokensDailyLimit * 0.2);
  bool get isTtsLow => ttsCharsRemaining <= (ttsCharsDailyLimit * 0.2);
  bool get isSttLow => sttSecondsRemaining <= (sttSecondsDailyLimit * 0.2);
  bool get isEventsNearLimit => eventsRecordedToday >= (eventsDailyLimit * 0.8);

  factory UsageQuota.fromJson(Map<String, dynamic> json) {
    return UsageQuota(
      userId: json['user_id'] as String,
      serviceTier: ServiceTier.fromDb(json['service_tier'] as String?),
      aiTokensUsedToday: (json['ai_tokens_used_today'] as num?)?.toInt() ?? 0,
      aiTokensDailyLimit: (json['ai_tokens_daily_limit'] as num?)?.toInt() ?? 15000,
      ttsCharsUsedToday: (json['tts_chars_used_today'] as num?)?.toInt() ?? 0,
      ttsCharsDailyLimit: (json['tts_chars_daily_limit'] as num?)?.toInt() ?? 10000,
      sttSecondsUsedToday: (json['stt_seconds_used_today'] as num?)?.toInt() ?? 0,
      sttSecondsDailyLimit: (json['stt_seconds_daily_limit'] as num?)?.toInt() ?? 3600,
      storageBytesUsed: (json['storage_bytes_used'] as num?)?.toInt() ?? 0,
      storageBytesLimit: (json['storage_bytes_limit'] as num?)?.toInt() ?? 52428800,
      eventsRecordedToday: (json['events_recorded_today'] as num?)?.toInt() ?? 0,
      eventsDailyLimit: (json['events_daily_limit'] as num?)?.toInt() ?? 1000,
      windowResetAt: DateTime.parse(
        json['window_reset_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'service_tier': serviceTier.dbValue,
      'ai_tokens_used_today': aiTokensUsedToday,
      'ai_tokens_daily_limit': aiTokensDailyLimit,
      'tts_chars_used_today': ttsCharsUsedToday,
      'tts_chars_daily_limit': ttsCharsDailyLimit,
      'stt_seconds_used_today': sttSecondsUsedToday,
      'stt_seconds_daily_limit': sttSecondsDailyLimit,
      'storage_bytes_used': storageBytesUsed,
      'storage_bytes_limit': storageBytesLimit,
      'events_recorded_today': eventsRecordedToday,
      'events_daily_limit': eventsDailyLimit,
      'window_reset_at': windowResetAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class UsageCheckResult {
  final bool allowed;
  final String serviceType;
  final int quantityRequested;
  final int remainingBalance;
  final DateTime? windowResetAt;

  const UsageCheckResult({
    required this.allowed,
    required this.serviceType,
    required this.quantityRequested,
    required this.remainingBalance,
    this.windowResetAt,
  });

  factory UsageCheckResult.fromJson(Map<String, dynamic> json) {
    return UsageCheckResult(
      allowed: json['allowed'] as bool? ?? false,
      serviceType: json['service_type'] as String? ?? '',
      quantityRequested: (json['quantity_requested'] as num?)?.toInt() ?? 0,
      remainingBalance: (json['remaining_balance'] as num?)?.toInt() ?? 0,
      windowResetAt: json['window_reset_at'] != null
          ? DateTime.tryParse(json['window_reset_at'] as String)
          : null,
    );
  }
}

class SystemUsageTelemetry {
  final int windowHours;
  final DateTime since;
  final int totalAiTokens;
  final int totalTtsChars;
  final int totalSttSeconds;
  final int totalStorageBytes;
  final int activeUsers;
  final int totalEvents;
  final double estimatedCostUsd;

  const SystemUsageTelemetry({
    required this.windowHours,
    required this.since,
    required this.totalAiTokens,
    required this.totalTtsChars,
    this.totalSttSeconds = 0,
    required this.totalStorageBytes,
    required this.activeUsers,
    required this.totalEvents,
    required this.estimatedCostUsd,
  });

  factory SystemUsageTelemetry.fromJson(Map<String, dynamic> json) {
    return SystemUsageTelemetry(
      windowHours: (json['window_hours'] as num?)?.toInt() ?? 24,
      since: DateTime.parse(
        json['since'] as String? ?? DateTime.now().toIso8601String(),
      ),
      totalAiTokens: (json['total_ai_tokens'] as num?)?.toInt() ?? 0,
      totalTtsChars: (json['total_tts_chars'] as num?)?.toInt() ?? 0,
      totalSttSeconds: (json['total_stt_seconds'] as num?)?.toInt() ?? 0,
      totalStorageBytes: (json['total_storage_bytes'] as num?)?.toInt() ?? 0,
      activeUsers: (json['active_users'] as num?)?.toInt() ?? 0,
      totalEvents: (json['total_events'] as num?)?.toInt() ?? 0,
      estimatedCostUsd: (json['estimated_cost_usd'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
