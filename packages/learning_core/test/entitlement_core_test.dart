import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('EntitlementCore & TransactionLedgerEntry (ECO-12)', () {
    test('TransactionLedgerEntry.create calculates 85% creator net share accurately', () {
      final entry = TransactionLedgerEntry.create(
        id: 'tx-001',
        buyerId: 'learner-99',
        sellerId: 'educator-42',
        resourceId: 'res-anatomy-atlas',
        amountCents: 2000, // $20.00
        creatorShareRate: 0.85,
        idempotencyKey: 'idem-tx-001',
      );

      expect(entry.amountCents, equals(2000));
      expect(entry.creatorNetCents, equals(1700)); // 85% of $20 = $17
      expect(entry.platformFeeCents, equals(300));  // 15% fee = $3
      expect(entry.status, equals('completed'));
      expect(entry.currency, equals('USD'));
    });

    test('serializes and deserializes transaction ledger entry cleanly', () {
      final entry = TransactionLedgerEntry(
        id: 'tx-002',
        buyerId: 'buyer-1',
        sellerId: 'seller-1',
        amountCents: 1500,
        platformFeeCents: 225,
        creatorNetCents: 1275,
        idempotencyKey: 'idem-tx-002',
        createdAt: DateTime.utc(2026, 11, 6, 10, 0),
      );

      final json = entry.toJson();
      final roundTrip = TransactionLedgerEntry.fromJson(json);

      expect(roundTrip.id, equals('tx-002'));
      expect(roundTrip.creatorNetCents, equals(1275));
      expect(roundTrip.idempotencyKey, equals('idem-tx-002'));
    });

    test('ResourceEntitlement evaluates access validity and expiration correctly', () {
      final activePerpetual = ResourceEntitlement(
        id: 'ent-1',
        userId: 'user-1',
        resourceId: 'res-1',
        type: EntitlementType.resourceAccess,
        grantedAt: DateTime.now().toUtc(),
      );
      expect(activePerpetual.hasValidAccess, isTrue);

      final expired = ResourceEntitlement(
        id: 'ent-2',
        userId: 'user-2',
        resourceId: 'res-2',
        type: EntitlementType.subscriptionTier,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        grantedAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
      );
      expect(expired.isExpired, isTrue);
      expect(expired.hasValidAccess, isFalse);
    });
  });
}
