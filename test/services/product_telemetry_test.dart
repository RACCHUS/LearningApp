import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/analytics/product_analytics_privacy_service.dart';
import 'package:learning_pwa/services/analytics/product_analytics_service.dart';
import 'package:learning_pwa/services/analytics/product_event.dart';
import 'package:learning_pwa/services/analytics/product_event_outbox.dart';
import 'package:learning_pwa/services/analytics/product_telemetry.dart';
import 'package:learning_pwa/widgets/analytics/analytics_opt_in_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sink implements ProductEventSink {
  final sent = <ProductEvent>[];

  @override
  Future<void> send(ProductEvent event) async => sent.add(event);
}

final _now = DateTime.utc(2026, 11, 19, 12);

ProductAnalyticsPrivacyStatus status({
  bool eligible = true,
  bool consented = true,
  bool released = true,
}) => ProductAnalyticsPrivacyStatus(
  eligible: eligible,
  consented: consented,
  isAnonymous: false,
  policyReady: released,
  collectionActive: released,
  changedAt: _now,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _Sink sink;
  late int fetches;

  ProductTelemetry make({
    bool enabled = true,
    String? user = 'u-1',
    bool guest = false,
    ProductAnalyticsPrivacyStatus? privacy,
    bool privacyFails = false,
  }) {
    sink = _Sink();
    fetches = 0;
    return ProductTelemetry(
      enabled: () => enabled,
      currentUserId: () => user,
      isGuest: () => guest,
      fetchPrivacy: () async {
        fetches++;
        if (privacyFails) throw StateError('offline');
        return privacy ?? status();
      },
      outbox: (p) => ProductEventOutbox(
        sender: sink,
        getPrivacy: p,
        currentUserId: () => user,
        now: () => _now,
      ),
      now: () => _now,
      flushDelay: Duration.zero,
    );
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test(
    'records and sends an allowlisted event when everything allows it',
    () async {
      final t = make();
      await t.track(ProductEventKind.surfaceViewed, {'surface': 'library'});
      await settle();
      expect(sink.sent.single.kind, ProductEventKind.surfaceViewed);
      expect(sink.sent.single.dimensions, {'surface': 'library'});
    },
  );

  for (final (name, t) in [
    ('switch off', () => make(enabled: false)),
    ('signed out', () => make(user: null)),
    ('guest', () => make(guest: true)),
    ('not eligible', () => make(privacy: status(eligible: false))),
    ('not opted in', () => make(privacy: status(consented: false))),
    ('not released', () => make(privacy: status(released: false))),
    ('privacy check fails', () => make(privacyFails: true)),
  ]) {
    test('records nothing when $name', () async {
      final tel = t();
      await tel.track(ProductEventKind.surfaceViewed, {'surface': 'learn'});
      await settle();
      expect(sink.sent, isEmpty);
    });
  }

  test('the server privacy check is cached, not repeated per event', () async {
    final t = make();
    for (var i = 0; i < 5; i++) {
      await t.track(ProductEventKind.surfaceViewed, {'surface': 'learn'});
    }
    expect(fetches, 1);
    t.invalidate();
    await t.track(ProductEventKind.surfaceViewed, {'surface': 'learn'});
    expect(fetches, 2);
  });

  test(
    'the session start is recorded once; bad dimensions never throw',
    () async {
      final t = make();
      await t.sessionStarted('learn');
      await t.sessionStarted('learn');
      await t.track(ProductEventKind.lessonEngaged, {'answer': 'secret'});
      await settle();
      expect(
        sink.sent.where((e) => e.kind == ProductEventKind.appSessionStarted),
        hasLength(1),
      );
      expect(
        sink.sent.where((e) => e.kind == ProductEventKind.lessonEngaged),
        isEmpty,
        reason: 'non-allowlisted keys are refused by ProductEvent',
      );
    },
  );

  group('opt-in card', () {
    Future<void> pump(
      WidgetTester tester,
      ProductAnalyticsPrivacyStatus? s,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsOptInStatusProvider.overrideWith((ref) async => s),
          ],
          child: const MaterialApp(home: Scaffold(body: AnalyticsOptInCard())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('invites someone who can opt in, with a plain disclosure', (
      tester,
    ) async {
      await pump(tester, status(consented: false));
      expect(find.byKey(const Key('analytics_opt_in_card')), findsOneWidget);
      expect(find.textContaining('never record your answers'), findsOneWidget);
    });

    testWidgets('hidden when not eligible, already opted in, or unknown', (
      tester,
    ) async {
      for (final s in [
        status(eligible: false, consented: false),
        status(),
        null,
      ]) {
        await pump(tester, s);
        expect(find.byKey(const Key('analytics_opt_in_card')), findsNothing);
      }
    });

    testWidgets('"No thanks" is remembered on this device', (tester) async {
      await pump(tester, status(consented: false));
      await tester.tap(find.byKey(const Key('analytics_opt_in_dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('analytics_opt_in_card')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AnalyticsOptInCard.dismissedKey), isTrue);
    });
  });
}
