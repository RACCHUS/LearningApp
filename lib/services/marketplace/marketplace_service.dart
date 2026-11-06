import 'package:learning_core/learning_core.dart';
import 'package:uuid/uuid.dart';
import '../../models/learning_event.dart';

/// Service managing marketplace transactions, entitlements, and tutoring bookings (ECO-12, ECO-13).
class MarketplaceService {
  final List<TransactionLedgerEntry> _ledger = [];
  final List<ResourceEntitlement> _entitlements = [];
  final List<TutoringSessionCore> _sessions = [];
  final List<LearningEvent> _emittedEvents = [];

  List<TransactionLedgerEntry> get ledger => List.unmodifiable(_ledger);
  List<ResourceEntitlement> get entitlements => List.unmodifiable(_entitlements);
  List<TutoringSessionCore> get sessions => List.unmodifiable(_sessions);
  List<LearningEvent> get emittedEvents => List.unmodifiable(_emittedEvents);

  /// Executes an idempotent transaction purchase and grants the corresponding entitlement.
  TransactionLedgerEntry purchaseResource({
    required String buyerId,
    required String sellerId,
    required String resourceId,
    required int amountCents,
    String currency = 'USD',
    double creatorShareRate = 0.85,
    String? idempotencyKey,
  }) {
    final key = idempotencyKey ?? const Uuid().v4();

    // Idempotency check: if transaction with this key exists, return it
    final existing = _ledger.where((tx) => tx.idempotencyKey == key).firstOrNull;
    if (existing != null) {
      return existing;
    }

    final entry = TransactionLedgerEntry.create(
      id: const Uuid().v4(),
      buyerId: buyerId,
      sellerId: sellerId,
      resourceId: resourceId,
      amountCents: amountCents,
      currency: currency,
      creatorShareRate: creatorShareRate,
      idempotencyKey: key,
    );
    _ledger.add(entry);

    // Grant access entitlement
    final entitlement = ResourceEntitlement(
      id: const Uuid().v4(),
      userId: buyerId,
      resourceId: resourceId,
      type: EntitlementType.resourceAccess,
      grantedAt: DateTime.now().toUtc(),
    );
    _entitlements.add(entitlement);

    final event = LearningEvent(
      userId: buyerId,
      eventType: 'transaction_recorded',
      itemType: 'marketplace_purchase',
      itemId: resourceId,
      score: 1.0,
      metadata: {
        'transaction_id': entry.id,
        'seller_id': sellerId,
        'amount_cents': amountCents,
        'creator_net_cents': entry.creatorNetCents,
        'platform_fee_cents': entry.platformFeeCents,
        'idempotency_key': key,
      },
    );
    _emittedEvents.add(event);

    return entry;
  }

  /// Checks if [userId] has active entitlement access to [resourceId].
  bool hasEntitlement(String userId, String resourceId) {
    return _entitlements.any((e) =>
        e.userId == userId && e.resourceId == resourceId && e.hasValidAccess);
  }

  /// Registers an available tutoring session slot.
  void registerTutoringSlot(TutoringSessionCore session) {
    _sessions.add(session);
  }

  /// Books an available tutoring slot for a learner.
  TutoringSessionCore bookSession({
    required String sessionId,
    required String learnerId,
  }) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) {
      throw ArgumentError('Session not found: $sessionId');
    }

    final old = _sessions[index];
    if (old.isBooked) {
      throw StateError('Session is already booked: $sessionId');
    }

    final updated = TutoringSessionCore(
      id: old.id,
      tutorId: old.tutorId,
      tutorName: old.tutorName,
      targetDomain: old.targetDomain,
      sessionType: old.sessionType,
      scheduledStartTime: old.scheduledStartTime,
      scheduledEndTime: old.scheduledEndTime,
      hourlyRateCents: old.hourlyRateCents,
      bookedLearnerId: learnerId,
      meetingUrl: old.meetingUrl ?? 'https://meet.learningapp.io/room-$sessionId',
      isConfirmed: true,
      sessionNotes: old.sessionNotes,
    );

    _sessions[index] = updated;

    final event = LearningEvent(
      userId: learnerId,
      eventType: 'tutoring_session_scheduled',
      itemType: 'tutoring_booking',
      itemId: sessionId,
      metadata: {
        'tutor_id': old.tutorId,
        'target_domain': old.targetDomain,
        'session_type': old.sessionType.toDbString(),
        'start_time': old.scheduledStartTime.toIso8601String(),
        'duration_minutes': old.durationMinutes,
      },
    );
    _emittedEvents.add(event);

    return updated;
  }
}
