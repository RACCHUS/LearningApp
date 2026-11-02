import 'package:uuid/uuid.dart';

/// Represents a discrete learning event logged to the append-only event stream (ARCH-1, ARCH-3, FIX-2).
class LearningEvent {
  final String id;
  final String? userId;
  final DateTime occurredAt;
  final String eventType;
  final String itemType;
  final String itemId;
  final String? itemVersion;
  final String? contextId;
  final String? sessionId;
  final int? rating;
  final double? score;
  final dynamic response;
  final List<int>? presentedOrder;
  final int? latencyMs;
  final int hintsUsed;
  final int? confidence;
  final Map<String, dynamic>? schedulerStateBefore;
  final Map<String, dynamic>? schedulerStateAfter;
  final Map<String, dynamic> metadata;
  final String? appVersion;

  LearningEvent({
    String? id,
    this.userId,
    DateTime? occurredAt,
    required this.eventType,
    required this.itemType,
    required this.itemId,
    this.itemVersion,
    this.contextId,
    this.sessionId,
    this.rating,
    this.score,
    this.response,
    this.presentedOrder,
    this.latencyMs,
    this.hintsUsed = 0,
    this.confidence,
    this.schedulerStateBefore,
    this.schedulerStateAfter,
    this.metadata = const {},
    this.appVersion,
  })  : id = id ?? const Uuid().v4(),
        occurredAt = occurredAt ?? DateTime.now().toUtc();

  factory LearningEvent.fromJson(Map<String, dynamic> json) {
    return LearningEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      occurredAt: json['occurred_at'] != null
          ? DateTime.parse(json['occurred_at'] as String)
          : DateTime.now().toUtc(),
      eventType: json['event_type'] as String,
      itemType: json['item_type'] as String? ?? 'unknown',
      itemId: json['item_id'] as String,
      itemVersion: json['item_version'] as String?,
      contextId: json['context_id'] as String?,
      sessionId: json['session_id'] as String?,
      rating: json['rating'] as int?,
      score: (json['score'] as num?)?.toDouble(),
      response: json['response'],
      presentedOrder: (json['presented_order'] as List?)?.map((e) => e as int).toList(),
      latencyMs: json['latency_ms'] as int?,
      hintsUsed: json['hints_used'] as int? ?? 0,
      confidence: json['confidence'] as int?,
      schedulerStateBefore: json['scheduler_state_before'] != null
          ? Map<String, dynamic>.from(json['scheduler_state_before'] as Map)
          : null,
      schedulerStateAfter: json['scheduler_state_after'] != null
          ? Map<String, dynamic>.from(json['scheduler_state_after'] as Map)
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      appVersion: json['app_version'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'occurred_at': occurredAt.toIso8601String(),
      'event_type': eventType,
      'item_type': itemType,
      'item_id': itemId,
      if (itemVersion != null) 'item_version': itemVersion,
      if (contextId != null) 'context_id': contextId,
      if (sessionId != null) 'session_id': sessionId,
      if (rating != null) 'rating': rating,
      if (score != null) 'score': score,
      if (response != null) 'response': response,
      if (presentedOrder != null) 'presented_order': presentedOrder,
      if (latencyMs != null) 'latency_ms': latencyMs,
      'hints_used': hintsUsed,
      if (confidence != null) 'confidence': confidence,
      if (schedulerStateBefore != null) 'scheduler_state_before': schedulerStateBefore,
      if (schedulerStateAfter != null) 'scheduler_state_after': schedulerStateAfter,
      'metadata': metadata,
      if (appVersion != null) 'app_version': appVersion,
    };
  }
}
