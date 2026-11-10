import 'package:learning_pwa/services/analytics/product_event.dart';
import 'package:uuid/uuid.dart';

/// No vendor SDK, background polling or network I/O by default.
abstract class ProductEventSink {
  Future<void> send(ProductEvent event);
}

class NoopProductEventSink implements ProductEventSink {
  const NoopProductEventSink();

  @override
  Future<void> send(ProductEvent event) async {}
}

/// Client-side gates are a *defense in depth*, not authorization. A future
/// trusted RPC must verify permanent account, age/consent and current privileges
/// independently on every batch; never trust these booleans from the browser.
///
/// This service is intentionally disabled until a verified server ingest,
/// bounded outbox, consent model and erasure policy are deployed.
class ProductAnalyticsService {
  final ProductEventSink _sink;
  final bool featureEnabled;
  final bool eligibleAccount;
  final bool consentGranted;
  final String sessionId;

  ProductAnalyticsService({
    ProductEventSink sink = const NoopProductEventSink(),
    this.featureEnabled = false,
    this.eligibleAccount = false,
    this.consentGranted = false,
    String? sessionId,
  })  : _sink = sink,
        sessionId = sessionId ?? const Uuid().v4();

  Future<void> track(
    ProductEventKind kind, {
    Map<String, String> dimensions = const {},
    DateTime? occurredAt,
  }) async {
    if (!featureEnabled || !eligibleAccount || !consentGranted) return;

    try {
      final event = ProductEvent(
        eventId: const Uuid().v4(),
        sessionId: sessionId,
        kind: kind,
        occurredAt: occurredAt ?? DateTime.now(),
        dimensions: dimensions,
      );
      await _sink.send(event);
    } catch (_) {
      // Telemetry must never block a lesson, throw into app UI or claim
      // delivery when the sink/network does not acknowledge a write.
      // Error monitoring can count this locally without logging payloads.
    }
  }
}
