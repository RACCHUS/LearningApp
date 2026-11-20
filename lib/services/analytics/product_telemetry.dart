import 'dart:async';

import 'package:learning_pwa/services/analytics/product_analytics_privacy_service.dart';
import 'package:learning_pwa/services/analytics/product_event.dart';
import 'package:learning_pwa/services/analytics/product_event_outbox.dart';
import 'package:uuid/uuid.dart';

/// The one place the app records optional product analytics (basic level).
///
/// It records nothing unless all of these hold, checked in this order:
/// the `analytics.product_events` switch is on, a permanent (non-guest)
/// account is signed in, and the server says this account is eligible,
/// opted in and collection is released (the cached privacy status). Events
/// are the existing allowlisted kinds with categorical values only: never
/// answers, typed text, AI replies or lesson content. The durable outbox
/// re-checks consent before storing and before sending, and withdrawal
/// deletes server events (see the privacy screen).
class ProductTelemetry {
  ProductTelemetry({
    required bool Function() enabled,
    required String? Function() currentUserId,
    required bool Function() isGuest,
    required Future<ProductAnalyticsPrivacyStatus> Function() fetchPrivacy,
    required ProductEventOutbox Function(
      Future<ProductAnalyticsPrivacyStatus> Function() privacy,
    )
    outbox,
    DateTime Function()? now,
    Duration privacyTtl = const Duration(minutes: 10),
    Duration flushDelay = const Duration(seconds: 5),
  }) : _enabled = enabled,
       _currentUserId = currentUserId,
       _isGuest = isGuest,
       _fetchPrivacy = fetchPrivacy,
       _now = now ?? DateTime.now,
       _privacyTtl = privacyTtl,
       _flushDelay = flushDelay {
    _outbox = outbox(_privacy);
  }

  final bool Function() _enabled;
  final String? Function() _currentUserId;
  final bool Function() _isGuest;
  final Future<ProductAnalyticsPrivacyStatus> Function() _fetchPrivacy;
  final DateTime Function() _now;
  final Duration _privacyTtl;
  final Duration _flushDelay;
  late final ProductEventOutbox _outbox;

  /// One id per app run.
  final String sessionId = const Uuid().v4();

  ProductAnalyticsPrivacyStatus? _cached;
  String? _cachedFor;
  DateTime? _cachedAt;
  Timer? _flushTimer;
  bool _sessionStarted = false;

  Future<ProductAnalyticsPrivacyStatus> _privacy() async {
    final user = _currentUserId();
    final fresh =
        _cached != null &&
        _cachedFor == user &&
        _cachedAt != null &&
        _now().difference(_cachedAt!) < _privacyTtl;
    if (fresh) return _cached!;
    final status = await _fetchPrivacy();
    _cached = status;
    _cachedFor = user;
    _cachedAt = _now();
    return status;
  }

  /// Forget the cached status (after the learner changes their choice).
  void invalidate() {
    _cached = null;
    _cachedAt = null;
  }

  Future<bool> _mayCollect() async {
    if (!_enabled()) return false;
    final user = _currentUserId();
    if (user == null || user.isEmpty || _isGuest()) return false;
    try {
      return (await _privacy()).canCollect;
    } catch (_) {
      return false;
    }
  }

  /// Records one event if allowed. Never throws and never blocks the UI.
  Future<void> track(
    ProductEventKind kind, [
    Map<String, String> dimensions = const {},
  ]) async {
    try {
      if (!await _mayCollect()) return;
      await _outbox.enqueue(
        ProductEvent(
          eventId: const Uuid().v4(),
          sessionId: sessionId,
          kind: kind,
          occurredAt: _now(),
          dimensions: dimensions,
        ),
      );
      _scheduleFlush();
    } catch (_) {
      // Telemetry must never affect learning.
    }
  }

  /// `app_session_started`, once per app run.
  Future<void> sessionStarted(String surface) async {
    if (_sessionStarted) return;
    _sessionStarted = true;
    await track(ProductEventKind.appSessionStarted, {'surface': surface});
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, () async {
      try {
        await _outbox.flush();
      } catch (_) {}
    });
  }

  /// Sends anything queued on this device now (e.g. after sign-in).
  Future<void> flushNow() async {
    try {
      if (await _mayCollect()) await _outbox.flush();
    } catch (_) {}
  }

  void dispose() => _flushTimer?.cancel();
}
