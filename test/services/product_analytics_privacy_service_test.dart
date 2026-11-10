import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/analytics/product_analytics_privacy_service.dart';

void main() {
  String user = 'synthetic-user';
  var consent = false;
  var pageCalls = 0;

  ProductAnalyticsPrivacyService fake({
    bool eligible = true,
    bool collectionActive = false,
    bool policyReady = false,
    bool guest = false,
  }) => ProductAnalyticsPrivacyService(
        currentUserId: () => user,
        rpc: (name,params) async {
          if (name == 'get_my_product_analytics_privacy_status') {
            return {
              'schema_version': 1,
              'eligible': eligible,
              'consented': consent,
              'is_anonymous': guest,
              'collection_active': collectionActive,
              'policy_ready': policyReady,
              'changed_at': null,
            };
          }
          if (name == 'set_product_analytics_consent') {
            consent = params?['p_consent'] == true;
            return {'consented': consent};
          }
          if (name == 'export_my_product_events_page') {
            pageCalls++;
            final id = params?['p_before_event_id'];
            if (id == null) {
              return {
                'events': [
                  {'event_id': 'event-a'},
                  {'event_id': 'event-b'},
                ],
                'has_more': true,
                'next_before_received_at': '2026-11-10T03:00:00Z',
                'next_before_event_id': 'event-b',
              };
            }
            if (id == 'event-b') {
              return {
                'events': [
                  {'event_id': 'event-c'},
                ],
                'has_more': false,
                'next_before_received_at': null,
                'next_before_event_id': null,
              };
            }
          }
          throw StateError('Unexpected RPC: $name');
        });

  setUp(() {
    user = 'synthetic-user';
    consent = false;
    pageCalls = 0;
  });

  test('unapproved consent and collection remain disabled by default',
      () async {
    final service = fake();
    final status = await service.status();
    expect(status.eligible, isTrue);
    expect(status.canCollect, isFalse);
    expect(status.canOptIn, isFalse);
    await expectLater(service.chooseConsent(true), throwsStateError);
    expect(consent, isFalse);
  });

  test('missing policyReady is not interpreted as approval', () {
    final state = ProductAnalyticsPrivacyStatus.fromJson({
      'schema_version': 1, 'eligible': true, 'consented': true,
      'is_anonymous': false, 'collection_active': true,
    });
    expect(state.policyReady, isFalse);
    expect(state.canCollect, isFalse);
  });

  test('reviewed eligible account can opt in only after release signals',
      () async {
    final service = fake(collectionActive:true,policyReady:true);
    expect((await service.chooseConsent(true)).consented, isTrue);
    expect((await service.status()).canCollect, isTrue);
    expect((await service.chooseConsent(false)).consented, isFalse);
  });

  test('withdrawal works even before policy approval', () async {
    consent = true;
    final service = fake();
    final next = await service.chooseConsent(false);
    expect(next.consented, isFalse);
  });

  test('guest cannot become collection-eligible', () async {
    final service = fake(
        guest:true,collectionActive:true,policyReady:true);
    final state = await service.status();
    expect(state.canCollect, isFalse);
    expect(state.canOptIn, isFalse);
  });

  test('export reads all pages, not just the first 100', () async {
    final service = fake();
    final json = jsonDecode(await service.exportJson()) as Map;
    expect((json['events'] as List).length, 3);
    expect(pageCalls, 2);
    expect(json['format'], 'learningapp-product-analytics-export');
  });

  test('account switch interrupts export before exposing prior account data',
      () async {
    final service = ProductAnalyticsPrivacyService(
      currentUserId: () => user,
      rpc: (name,params) async {
        user = 'another-user';
        return {
          'events': [], 'has_more': false,
          'next_before_received_at': null,'next_before_event_id': null,
        };
      },
    );
    await expectLater(service.exportJson(), throwsStateError);
  });

  test('malformed status is never silently interpreted as no consent', () {
    expect(() => ProductAnalyticsPrivacyStatus.fromJson({
      'eligible': false, 'consented': false,
    }), throwsFormatException);
  });
}
