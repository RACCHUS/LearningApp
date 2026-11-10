import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/analytics/product_analytics_overview_service.dart';

void main() {
  final asOf = DateTime.utc(2026, 11, 9, 20);

  Map<String, dynamic> response(String status) => {
        'status': status,
        'window_days': 7,
        'as_of': asOf.toIso8601String(),
        'coverage': 'opted_in_eligible_accounts_only',
        'unique_active_users': status == 'measured' ? 5 : null,
        'event_count': status == 'measured' ? 20 : null,
        'session_starts': status == 'measured' ? 10 : null,
        'resource_opens': status == 'measured' ? 3 : null,
        'external_clicks': status == 'measured' ? 1 : null,
      };

  group('ANA-108 strict admin overview response', () {
    test('not measured does not invent DAU or sessions', () {
      final result = ProductAnalyticsOverview.fromJson(
        response('not_measured'));
      expect(result.status, 'not_measured');
      expect(result.activeUsers, isNull);
      expect(result.eventCount, isNull);
      expect(result.sessionStarts, isNull);
      expect(result.days, 7);
      expect(result.asOf, asOf);
    });

    test('small cohort must not expose counts', () {
      final result = ProductAnalyticsOverview.fromJson(
        response('small_cohort_suppressed'));
      expect(result.activeUsers, isNull);
      expect(result.eventCount, isNull);
    });

    test('measured values require real verified aggregate fields', () {
      final result = ProductAnalyticsOverview.fromJson(response('measured'));
      expect(result.activeUsers, 5);
      expect(result.eventCount, 20);
      expect(result.externalClicks, 1);
    });

    test('bad or unrecognized counts fail closed', () {
      expect(() => ProductAnalyticsOverview.fromJson(
        {...response('measured'), 'event_count': 'unverified'}),
        throwsFormatException);
      expect(() => ProductAnalyticsOverview.fromJson(
        {...response('not_measured'), 'event_count': 1}),
        throwsFormatException);
      expect(() => ProductAnalyticsOverview.fromJson(
        response('unsupported')), throwsFormatException);
    });

    test('missing server timestamp is an error, never a fabricated now', () {
      expect(() => ProductAnalyticsOverview.fromJson(
        {...response('measured'), 'as_of': null}), throwsFormatException);
    });
  });
}
