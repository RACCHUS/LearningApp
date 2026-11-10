import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/analytics/product_event.dart';
import 'package:learning_pwa/services/analytics/product_event_rpc_sink.dart';

void main() {
  final event = ProductEvent(
    eventId: 'a1020000-0000-4000-8000-000000000101',
    sessionId: 'a1020000-0000-4000-8000-000000000102',
    kind: ProductEventKind.surfaceViewed,
    occurredAt: DateTime.utc(2026, 11, 9),
    dimensions: const {'surface': 'learn'},
  );

  test('ACK-verified transport sends only the allowlisted event', () async {
    final sink = AckedProductEventSink((events) async {
      expect(events, hasLength(1));
      expect(events.single.containsKey('user_id'), isFalse);
      expect(events.single['event_name'], 'surface_viewed');
      return {
        'status': 'success',
        'processed_count': 1,
        'results': [
          {'event_id': event.eventId, 'status': 'accepted'}
        ],
      };
    });
    await sink.send(event);
  });

  test('idempotent duplicate ACK is an accepted retry', () async {
    final sink = AckedProductEventSink((_) async => {
          'status': 'success',
          'processed_count': 1,
          'results': [
            {'event_id': event.eventId, 'status': 'duplicate_noop'}
          ],
        });
    await sink.send(event);
  });

  test('mismatched/rejected ACK must never claim delivery', () async {
    final sink = AckedProductEventSink((_) async => {
          'status': 'success',
          'processed_count': 1,
          'results': [
            {'event_id': event.eventId, 'status': 'idempotency_payload_mismatch'}
          ],
        });
    await expectLater(sink.send(event), throwsStateError);
  });

  test('missing or incorrect RPC envelope must fail closed', () async {
    final sink = AckedProductEventSink((_) async => {
          'status': 'success',
          'processed_count': 0,
          'results': [],
        });
    await expectLater(sink.send(event), throwsStateError);
  });
}
