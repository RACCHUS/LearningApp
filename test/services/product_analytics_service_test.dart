import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/analytics/product_event.dart';
import 'package:learning_pwa/services/analytics/product_analytics_service.dart';

class _CaptureSink implements ProductEventSink {
  final events = <ProductEvent>[];
  @override
  Future<void> send(ProductEvent event) async => events.add(event);
}

class _UnavailableSink implements ProductEventSink {
  @override
  Future<void> send(ProductEvent event) async {
    throw StateError('analytics network unavailable');
  }
}

void main() {
  group('ANA-101/102 consent-gated product analytics', () {
    test('default service never records activity', () async {
      final sink = _CaptureSink();
      final service = ProductAnalyticsService(sink: sink);
      await service.track(
        ProductEventKind.surfaceViewed,
        dimensions: const {'surface': 'learn'},
      );
      expect(sink.events, isEmpty);
    });

    test('requires enabled feature, eligibility AND consent', () async {
      final sink = _CaptureSink();
      for (final service in [
        ProductAnalyticsService(
          sink: sink, featureEnabled: false,
          eligibleAccount: true, consentGranted: true,
        ),
        ProductAnalyticsService(
          sink: sink, featureEnabled: true,
          eligibleAccount: false, consentGranted: true,
        ),
        ProductAnalyticsService(
          sink: sink, featureEnabled: true,
          eligibleAccount: true, consentGranted: false,
        ),
      ]) {
        await service.track(ProductEventKind.goalSelected,
            dimensions: const {'goal_type': 'exam'});
      }
      expect(sink.events, isEmpty);
    });

    test('approved events have version and bounded categorical fields', () async {
      final sink = _CaptureSink();
      final service = ProductAnalyticsService(
        sink: sink,
        featureEnabled: true,
        eligibleAccount: true,
        consentGranted: true,
      );
      await service.track(
        ProductEventKind.resourceSearchSubmitted,
        dimensions: const {
          'source_type': 'external',
          'query_category': 'exam',
        },
        occurredAt: DateTime.utc(2026, 11, 9, 20),
      );
      expect(sink.events, hasLength(1));
      final data = sink.events.single.toJson();
      expect(data['event_name'], 'resource_search_submitted');
      expect(data['schema_version'], 1);
      expect(data['properties'], {
        'source_type': 'external',
        'query_category': 'exam',
      });
      expect(data.containsKey('user_id'), isFalse);
      expect(data.containsKey('query'), isFalse);
      expect(data.containsKey('url'), isFalse);
      expect(data.containsKey('correct_answer'), isFalse);
    });

    test('raw query or URL dimension is rejected without disrupting learning', () async {
      final sink = _CaptureSink();
      final service = ProductAnalyticsService(
        sink: sink, featureEnabled: true,
        eligibleAccount: true, consentGranted: true,
      );
      await service.track(
        ProductEventKind.resourceSearchSubmitted,
        dimensions: const {'raw_query': 'my personal medical issue'},
      );
      await service.track(
        ProductEventKind.externalResourceClicked,
        dimensions: const {'provider_category': 'https://example.com/x'},
      );
      expect(sink.events, isEmpty);
    });

    test('failed delivery never throws back into learner action', () async {
      final service = ProductAnalyticsService(
        sink: _UnavailableSink(),
        featureEnabled: true,
        eligibleAccount: true,
        consentGranted: true,
      );
      await service.track(
        ProductEventKind.lessonEngaged,
        dimensions: const {'mode': 'lesson'},
      );
    });
  });
}
