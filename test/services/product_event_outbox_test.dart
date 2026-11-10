import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/analytics/product_analytics_privacy_service.dart';
import 'package:learning_pwa/services/analytics/product_analytics_service.dart';
import 'package:learning_pwa/services/analytics/product_event.dart';
import 'package:learning_pwa/services/analytics/product_event_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sink implements ProductEventSink {
  final sent = <String>[];
  bool fail = false;

  @override
  Future<void> send(ProductEvent event) async {
    if (fail) throw StateError('Temporary network failure');
    sent.add(event.eventId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final anchor = DateTime.utc(2026, 11, 10, 3);
  String eventId(int n) =>
      'a1030000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
  ProductEvent event(int n, {DateTime? at}) => ProductEvent(
        eventId: eventId(n),
        sessionId: 'a1030000-0000-4000-8000-000000000202',
        kind: ProductEventKind.surfaceViewed,
        occurredAt: at ?? anchor,
        dimensions: const {'surface': 'learn'},
      );

  final allowed = ProductAnalyticsPrivacyStatus(
    eligible: true, consented: true, isAnonymous: false,
    policyReady: true, collectionActive: true, changedAt: anchor);
  const blocked = ProductAnalyticsPrivacyStatus(
    eligible: true, consented: false, isAnonymous: false,
    policyReady: true, collectionActive: true);

  late String user;
  late DateTime now;
  late ProductAnalyticsPrivacyStatus privacy;
  late _Sink sink;
  ProductEventOutbox create() => ProductEventOutbox(
        sender: sink,
        getPrivacy: () async => privacy,
        currentUserId: () => user,
        now: () => now,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    user = 'user-a';
    now = anchor;
    privacy = allowed;
    sink = _Sink();
  });

  test('persisted immutable event survives instance restart until ACK', () async {
    final first = create();
    await first.enqueue(event(1));
    expect(await first.pendingCount(), 1);

    final second = create();
    final result = await second.flush();
    expect(result.acknowledged, 1);
    expect(result.remaining, 0);
    expect(sink.sent, [eventId(1)]);
    expect(await first.pendingCount(), 0);
  });

  test('transient failure retains original ID for exactly-once replay', () async {
    final queue = create();
    await queue.enqueue(event(2));
    sink.fail = true;
    final failed = await queue.flush();
    expect(failed.deliveryFailed, isTrue);
    expect(failed.remaining, 1);
    sink.fail = false;
    final good = await queue.flush();
    expect(good.acknowledged, 1);
    expect(sink.sent, [eventId(2)]);
    expect(await queue.pendingCount(), 0);
  });

  test('account switch cannot deliver or delete old-user queue', () async {
    final queue = create();
    await queue.enqueue(event(3));
    user = 'user-b';
    expect(await queue.pendingCount(), 0);
    expect((await queue.flush()).acknowledged, 0);
    await queue.enqueue(event(4));
    expect(await queue.clearCurrentAccount(), 1);
    user = 'user-a';
    expect(await queue.pendingCount(), 1);
    expect((await queue.flush()).acknowledged, 1);
    expect(sink.sent, [eventId(3)]);
  });

  test('policy withdrawal blocks any queueing or replay', () async {
    final queue = create();
    await queue.enqueue(event(5));
    privacy = blocked;
    final result = await queue.flush();
    expect(result.blocked, isTrue);
    expect(result.discardedConsent, 1);
    expect(await queue.pendingCount(), 0);
    await expectLater(queue.enqueue(event(6)), throwsStateError);
    expect(await queue.clearCurrentAccount(), 0);
    expect(sink.sent, isEmpty);
  });

  test('offline withdrawal followed by re-consent cannot replay old events',
      () async {
    final queue = create();
    await queue.enqueue(event(11));
    // This client never observes the withdrawal: the next server status is
    // already opted back in. A changed consent timestamp still invalidates it.
    privacy = ProductAnalyticsPrivacyStatus(
      eligible: true, consented: true, isAnonymous: false,
      policyReady: true, collectionActive: true,
      changedAt: anchor.add(const Duration(seconds: 1)),
    );
    final result = await queue.flush();
    expect(result.discardedConsent, 1);
    expect(result.acknowledged, 0);
    expect(await queue.pendingCount(), 0);
    expect(sink.sent, isEmpty);
    await queue.enqueue(event(12));
    expect((await queue.flush()).acknowledged, 1);
    expect(sink.sent, [eventId(12)]);
  });

  test('legacy unversioned-consent records are discarded, never delivered',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('learningapp.product_events.v1.user-a.${eventId(13)}',
        jsonEncode({
          'version': 1,
          'saved_at': anchor.toIso8601String(),
          'event': event(13).toJson(),
        }));
    final queue = create();
    expect(await queue.pendingCount(), 1);
    final result = await queue.flush();
    expect(result.discardedConsent, 1);
    expect(result.acknowledged, 0);
    expect(sink.sent, isEmpty);
  });

  test('a missing consent revision cannot authorize offline capture',
      () async {
    privacy = const ProductAnalyticsPrivacyStatus(
      eligible: true, consented: true, isAnonymous: false,
      policyReady: true, collectionActive: true,
    );
    await expectLater(create().enqueue(event(14)), throwsStateError);
  });

  test('expiry is accounted for and not transmitted to server', () async {
    final queue = create();
    await queue.enqueue(event(7));
    now = anchor.add(const Duration(days: 8));
    final result = await queue.flush();
    expect(result.expired, 1);
    expect(result.remaining, 0);
    expect(sink.sent, isEmpty);
  });

  test('queue pressure is rejected instead of silently discarding events',
      () async {
    final queue = create();
    for (var i = 1; i <= ProductEventOutbox.maxQueuedEvents; i++) {
      await queue.enqueue(event(i));
    }
    expect(await queue.pendingCount(), ProductEventOutbox.maxQueuedEvents);
    await expectLater(queue.enqueue(event(201)), throwsStateError);
    expect(await queue.pendingCount(), ProductEventOutbox.maxQueuedEvents);
  });

  test('reused event ID with altered payload fails closed', () async {
    final queue = create();
    await queue.enqueue(event(8));
    final altered = ProductEvent(
      eventId: eventId(8),
      sessionId: 'a1030000-0000-4000-8000-000000000202',
      kind: ProductEventKind.surfaceViewed,
      occurredAt: anchor,
      dimensions: const {'surface': 'library'},
    );
    await expectLater(queue.enqueue(altered), throwsStateError);
    expect(await queue.pendingCount(), 1);
  });

  test('unrecognized queued event content is never sent', () {
    final invalid = event(9).toJson()..['user_id'] = 'spoofed';
    expect(() => ProductEvent.fromJson(invalid), throwsFormatException);
    expect(() => ProductEvent.fromJson({
      ...event(9).toJson(),
      'schema_version': 2,
    }), throwsFormatException);
  });
}
