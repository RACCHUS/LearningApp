import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/settings/product_analytics_privacy_screen.dart';
import 'package:learning_pwa/services/analytics/product_analytics_privacy_service.dart';

class _PrivacyStub extends ProductAnalyticsPrivacyService {
  ProductAnalyticsPrivacyStatus value;
  bool fail = false;
  int withdrawalCalls = 0;

  _PrivacyStub(this.value) : super(currentUserId: () => 'synthetic-user');

  @override
  Future<ProductAnalyticsPrivacyStatus> status() async {
    if (fail) throw StateError('backend unavailable');
    return value;
  }

  @override
  Future<ProductAnalyticsPrivacyStatus> chooseConsent(bool consent) async {
    if (consent) throw StateError('not available');
    withdrawalCalls++;
    value = ProductAnalyticsPrivacyStatus(
      eligible: value.eligible,
      consented: false,
      isAnonymous: value.isAnonymous,
      collectionActive: false,
      policyReady: false,
    );
    return value;
  }

  @override
  Future<String> exportJson({int maximumRecords = 10000}) async {
    return '{"events":[]}';
  }
}

void main() {
  const ineligible = ProductAnalyticsPrivacyStatus(
    eligible: false,consented: false,isAnonymous: true,
    collectionActive: false,policyReady: false);
  const optedIn = ProductAnalyticsPrivacyStatus(
    eligible: true,consented: true,isAnonymous: false,
    collectionActive: false,policyReady: false);

  Future<void> show(WidgetTester tester, _PrivacyStub service,
      {Future<int> Function()? clear}) async {
    await tester.pumpWidget(MaterialApp(
      home: ProductAnalyticsPrivacyScreen(
        service: service,
        currentUserId: () => 'synthetic-user',
        clearLocalEvents: clear ?? () async => 0,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('guest sees disabled collection and cannot opt in',
      (tester) async {
    await show(tester, _PrivacyStub(ineligible));
    expect(find.textContaining('Off — not collecting'), findsOneWidget);
    final enable = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Opt in to optional analytics'));
    expect(enable.onPressed, isNull);
    expect(find.textContaining('Enrollment not yet available'),
        findsOneWidget);
  });

  testWidgets('explicit withdrawal erases local queue before server action',
      (tester) async {
    var cleared = false;
    final stub = _PrivacyStub(optedIn);
    await show(tester, stub,clear: () async {
      cleared = true;
      return 2;
    });
    await tester.scrollUntilVisible(
      find.text('Withdraw consent and erase server events'), 200);
    await tester.tap(
      find.text('Withdraw consent and erase server events'));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
    expect(stub.withdrawalCalls, 1);
    expect(find.textContaining('Consent withdrawn'), findsOneWidget);
    expect(stub.value.consented, isFalse);
  });

  testWidgets('unavailable backend never becomes guessed opt-out',
      (tester) async {
    final stub = _PrivacyStub(optedIn)..fail = true;
    await show(tester, stub);
    expect(find.textContaining('privacy controls are unavailable'),
        findsOneWidget);
    expect(find.text('Opt in to optional analytics'), findsNothing);
    expect(find.text('Withdraw consent and erase server events'), findsNothing);
  });

  testWidgets('device erasure works without server enrollment',
      (tester) async {
    var count = 0;
    await show(tester, _PrivacyStub(ineligible),clear: () async {
      count++;
      return 1;
    });
    await tester.scrollUntilVisible(
      find.text('Erase queued events on this device'), 200);
    await tester.tap(find.text('Erase queued events on this device'));
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(find.textContaining('Cleared 1 queued'), findsOneWidget);
  });
}
