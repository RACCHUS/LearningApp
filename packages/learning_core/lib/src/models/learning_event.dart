import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Client-submitted and server-verified learning event envelope conforming to
/// Learning Science §5 and docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md.
class LearningEventCore {
  final String id;
  final String idempotencyKey;
  final String sessionId;
  final int clientSeq;
  final String? userId;
  final String eventType;
  final DateTime clientOccurredAt;
  final Map<String, dynamic> payload;

  const LearningEventCore({
    required this.id,
    required this.idempotencyKey,
    required this.sessionId,
    required this.clientSeq,
    this.userId,
    required this.eventType,
    required this.clientOccurredAt,
    required this.payload,
  });

  /// Computes the server-equivalent canonical payload SHA-256 digest over
  /// the client-controlled payload keys.
  String computeCanonicalPayloadSha256() {
    // Sort keys deterministically
    final sortedKeys = payload.keys.toList()..sort();
    final sortedMap = <String, dynamic>{};
    for (final key in sortedKeys) {
      sortedMap[key] = payload[key];
    }
    final jsonStr = jsonEncode(sortedMap);
    final bytes = utf8.encode(jsonStr);
    return sha256.convert(bytes).toString();
  }

  factory LearningEventCore.fromJson(Map<String, dynamic> json) {
    return LearningEventCore(
      id: json['id'] as String? ?? '',
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      clientSeq: json['client_seq'] as int? ?? 1,
      userId: json['user_id'] as String?,
      eventType: json['event_type'] as String? ?? 'review_completed',
      clientOccurredAt: DateTime.tryParse(json['client_occurred_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idempotency_key': idempotencyKey,
      'session_id': sessionId,
      'client_seq': clientSeq,
      if (userId != null) 'user_id': userId,
      'event_type': eventType,
      'client_occurred_at': clientOccurredAt.toUtc().toIso8601String(),
      'payload': payload,
    };
  }
}

