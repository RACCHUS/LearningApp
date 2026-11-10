import 'package:learning_pwa/services/analytics/product_analytics_service.dart';
import 'package:learning_pwa/services/analytics/product_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ProductEventIngest = Future<dynamic> Function(
    List<Map<String, dynamic>> events);

/// Optional transport for a future opted-in, bounded outbox.
///
/// NOT selected by default: ProductAnalyticsService uses NoopProductEventSink
/// until independent privacy, consent UI and outbox release gates are met.
class AckedProductEventSink implements ProductEventSink {
  final ProductEventIngest _ingest;

  AckedProductEventSink(this._ingest);

  factory AckedProductEventSink.supabase(SupabaseClient client) {
    return AckedProductEventSink((events) => client.rpc(
          'record_product_events',
          params: {'p_events': events},
        ));
  }

  @override
  Future<void> send(ProductEvent event) async {
    final raw = await _ingest([event.toJson()]);
    if (raw is! Map) {
      throw StateError('Product events RPC omitted response envelope');
    }
    final result = Map<String, dynamic>.from(raw);
    final acknowledgements = result['results'];
    if (result['status'] != 'success' ||
        result['processed_count'] != 1 ||
        acknowledgements is! List ||
        acknowledgements.length != 1 ||
        acknowledgements.single is! Map) {
      throw StateError('Product events RPC did not acknowledge the event');
    }
    final ack = Map<String, dynamic>.from(acknowledgements.single as Map);
    if (ack['event_id'] != event.eventId ||
        (ack['status'] != 'accepted' &&
            ack['status'] != 'duplicate_noop')) {
      throw StateError('Product event rejected or replay payload changed');
    }
  }
}
