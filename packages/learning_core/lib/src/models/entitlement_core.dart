/// Type of entitlement granted to a learner (ECO-12).
enum EntitlementType {
  resourceAccess,
  tutoringSession,
  subscriptionTier;

  static EntitlementType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'tutoring_session':
      case 'tutoringsession':
      case 'tutoring':
        return EntitlementType.tutoringSession;
      case 'subscription_tier':
      case 'subscriptiontier':
      case 'subscription':
        return EntitlementType.subscriptionTier;
      case 'resource_access':
      case 'resourceaccess':
      default:
        return EntitlementType.resourceAccess;
    }
  }

  String toDbString() {
    switch (this) {
      case EntitlementType.resourceAccess:
        return 'resource_access';
      case EntitlementType.tutoringSession:
        return 'tutoring_session';
      case EntitlementType.subscriptionTier:
        return 'subscription_tier';
    }
  }
}

/// Immutable ledger entry recording a marketplace transaction with revenue share (ECO-12).
class TransactionLedgerEntry {
  final String id;
  final String buyerId;
  final String sellerId;
  final String? resourceId;
  final int amountCents;
  final String currency;
  final int platformFeeCents;
  final int creatorNetCents;
  final String status;
  final String idempotencyKey;
  final DateTime createdAt;

  const TransactionLedgerEntry({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    this.resourceId,
    required this.amountCents,
    this.currency = 'USD',
    required this.platformFeeCents,
    required this.creatorNetCents,
    this.status = 'completed',
    required this.idempotencyKey,
    required this.createdAt,
  });

  /// Calculates revenue share breakdown: creator receives [creatorShareRate] (default 85%).
  factory TransactionLedgerEntry.create({
    required String id,
    required String buyerId,
    required String sellerId,
    String? resourceId,
    required int amountCents,
    String currency = 'USD',
    double creatorShareRate = 0.85,
    required String idempotencyKey,
  }) {
    final net = (amountCents * creatorShareRate).round();
    final fee = amountCents - net;

    return TransactionLedgerEntry(
      id: id,
      buyerId: buyerId,
      sellerId: sellerId,
      resourceId: resourceId,
      amountCents: amountCents,
      currency: currency,
      platformFeeCents: fee,
      creatorNetCents: net,
      status: 'completed',
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now().toUtc(),
    );
  }

  factory TransactionLedgerEntry.fromJson(Map<String, dynamic> json) {
    return TransactionLedgerEntry(
      id: json['id'] as String? ?? '',
      buyerId: json['buyer_id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      resourceId: json['resource_id'] as String?,
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      platformFeeCents: (json['platform_fee_cents'] as num?)?.toInt() ?? 0,
      creatorNetCents: (json['creator_net_cents'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'completed',
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'buyer_id': buyerId,
        'seller_id': sellerId,
        if (resourceId != null) 'resource_id': resourceId,
        'amount_cents': amountCents,
        'currency': currency,
        'platform_fee_cents': platformFeeCents,
        'creator_net_cents': creatorNetCents,
        'status': status,
        'idempotency_key': idempotencyKey,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

/// An access entitlement authorizing a learner to access a premium resource or service (ECO-12).
class ResourceEntitlement {
  final String id;
  final String userId;
  final String resourceId;
  final EntitlementType type;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime grantedAt;

  const ResourceEntitlement({
    required this.id,
    required this.userId,
    required this.resourceId,
    required this.type,
    this.expiresAt,
    this.isActive = true,
    required this.grantedAt,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!);

  bool get hasValidAccess => isActive && !isExpired;

  factory ResourceEntitlement.fromJson(Map<String, dynamic> json) {
    return ResourceEntitlement(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      resourceId: json['resource_id'] as String? ?? '',
      type: EntitlementType.fromString(
          json['type'] as String? ?? 'resource_access'),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      grantedAt: DateTime.parse(
          json['granted_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'resource_id': resourceId,
        'type': type.toDbString(),
        if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
        'is_active': isActive,
        'granted_at': grantedAt.toUtc().toIso8601String(),
      };
}
