import 'dart:async';
import 'dart:convert';

import 'package:learning_pwa/services/analytics/product_analytics_privacy_service.dart';
import 'package:learning_pwa/services/analytics/product_analytics_service.dart';
import 'package:learning_pwa/services/analytics/product_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// This-device, per-account durable queue. Each immutable event has its own
/// storage key so a transient failure cannot overwrite unrelated event data.
///
/// Not connected to the default analytics service until release authorization:
/// server status must explicitly show eligibility, consent, policy and
/// collection readiness; the current production contract returns false.
class ProductEventOutbox {
  static const int maxQueuedEvents = 100;
  static const int maxEventBytes = 2048;
  static const Duration expiry = Duration(days: 7);
  static const String _prefix = 'learningapp.product_events.v1.';

  final ProductEventSink _sender;
  final Future<ProductAnalyticsPrivacyStatus> Function() _getPrivacy;
  final String? Function() _currentUserId;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  Future<void> _last = Future<void>.value();

  ProductEventOutbox({
    required ProductEventSink sender,
    required Future<ProductAnalyticsPrivacyStatus> Function() getPrivacy,
    String? Function()? currentUserId,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  })  : _sender = sender,
        _getPrivacy = getPrivacy,
        _currentUserId = currentUserId ??
            (() => Supabase.instance.client.auth.currentUser?.id),
        _preferences = preferences ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  Future<T> _locked<T>(Future<T> Function() action) async {
    final preceding = _last;
    final done = Completer<void>();
    _last = done.future;
    await preceding;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }

  String _user() {
    final value = _currentUserId();
    if (value == null || value.isEmpty ||
        !RegExp(r'^[A-Za-z0-9-]{1,64}$').hasMatch(value)) {
      throw StateError('A signed-in account is required for telemetry storage.');
    }
    return value;
  }

  void _sameUser(String userId) {
    if (_user() != userId) {
      throw StateError('Analytics account changed; queue action was stopped.');
    }
  }

  String _userPrefix(String userId) => '$_prefix$userId.';
  String _eventKey(String userId, String eventId) =>
      '${_userPrefix(userId)}$eventId';

  Future<SharedPreferences> _reload() async {
    final prefs = await _preferences();
    // The default cached API must refresh before enumerating this account's
    // events. A multi-tab device still requires release-level integration tests.
    await prefs.reload();
    return prefs;
  }

  Future<List<_PendingEvent>> _load(
      SharedPreferences prefs, String userId) async {
    final result = <_PendingEvent>[];
    for (final key in prefs.getKeys().where(
        (key) => key.startsWith(_userPrefix(userId)))) {
      final raw = prefs.getString(key);
      if (raw == null) {
        throw StateError('Stored product-event record is not readable.');
      }
      late final Map<String, dynamic> envelope;
      try {
        envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        throw StateError('Stored product-event record is invalid.');
      }
      if ((envelope['version'] != 1 && envelope['version'] != 2) ||
          envelope['saved_at'] is! String ||
          envelope['event'] is! Map ||
          utf8.encode(raw).length > maxEventBytes) {
        throw StateError('Stored product-event record failed validation.');
      }
      final when = DateTime.tryParse(envelope['saved_at'] as String);
      if (when == null) {
        throw StateError('Stored product-event timestamp is invalid.');
      }
      // Legacy v1 entries are readable for deletion but never replayed:
      // they were not bound to a specific consent period.
      DateTime? consentChangedAt;
      if (envelope['version'] == 2) {
        final rawConsentTime = envelope['consent_changed_at'];
        if (rawConsentTime is! String ||
            DateTime.tryParse(rawConsentTime) == null) {
          throw StateError('Stored product-event consent revision invalid.');
        }
        consentChangedAt = DateTime.parse(rawConsentTime).toUtc();
      }
      final event = ProductEvent.fromJson(
          Map<String, dynamic>.from(envelope['event'] as Map));
      if (key != _eventKey(userId, event.eventId)) {
        throw StateError('Stored product-event account key is inconsistent.');
      }
      result.add(_PendingEvent(key, event, when.toUtc(), consentChangedAt));
    }
    result.sort((a,b) =>
        a.event.occurredAt.compareTo(b.event.occurredAt));
    return result;
  }

  Future<int> _purgeExpired(
      SharedPreferences prefs, List<_PendingEvent> rows) async {
    var count = 0;
    for (final row in rows) {
      if (_now().toUtc().difference(row.event.occurredAt) > expiry) {
        if (!await prefs.remove(row.key)) {
          throw StateError('Could not purge expired queued product event.');
        }
        count++;
      }
    }
    return count;
  }

  // A withdrawal, re-consent or policy update invalidates the old consent
  // timestamp. Even if the client missed the intervening withdrawal while
  // offline, old records are erased, not sent under the new consent.
  Future<int> _discardStaleConsent(SharedPreferences prefs,
      List<_PendingEvent> rows, String user, DateTime? consentRevision) async {
    var discarded = 0;
    for (final row in rows) {
      if (consentRevision == null || row.consentChangedAt == null ||
          !row.consentChangedAt!.isAtSameMomentAs(consentRevision)) {
        _sameUser(user);
        if (!await prefs.remove(row.key)) {
          throw StateError('Could not erase event from a prior consent.');
        }
        discarded++;
      }
    }
    return discarded;
  }

  /// Explicit opt-in alone cannot start collection: trusted release readiness
  /// must be true too. A full queue fails visibly, never silently evicts data.
  Future<void> enqueue(ProductEvent event) => _locked(() async {
    final user = _user();
    final privacy = await _getPrivacy();
    _sameUser(user);
    if (!privacy.canCollect || privacy.changedAt == null) {
      throw StateError('Product event capture requires current server consent.');
    }
    final now = _now().toUtc();
    if (event.occurredAt.isAfter(now.add(const Duration(minutes: 5))) ||
        now.difference(event.occurredAt) > expiry) {
      throw StateError('Product event timestamp is outside the offline window.');
    }
    final prefs = await _reload();
    _sameUser(user);
    final rows = await _load(prefs, user);
    await _purgeExpired(prefs, rows);
    final afterExpiry = await _load(await _reload(), user);
    await _discardStaleConsent(
        prefs, afterExpiry, user, privacy.changedAt);
    final after = await _load(await _reload(), user);
    final key = _eventKey(user, event.eventId);
    final existing = after.where((e) => e.key == key);
    if (existing.isNotEmpty) {
      if (jsonEncode(existing.single.event.toJson()) !=
          jsonEncode(event.toJson())) {
        throw StateError('Event ID reused with a changed payload.');
      }
      return;
    }
    if (after.length >= maxQueuedEvents) {
      throw StateError('Product event outbox full; collection not accepted.');
    }
    final raw = jsonEncode({
      'version': 2,
      'saved_at': now.toIso8601String(),
      'consent_changed_at': privacy.changedAt!.toUtc().toIso8601String(),
      'event': event.toJson(),
    });
    if (utf8.encode(raw).length > maxEventBytes) {
      throw StateError('Product event exceeds the local size limit.');
    }
    _sameUser(user);
    if (!await prefs.setString(key,raw)) {
      throw StateError('Product event was not durably stored.');
    }
  });

  /// Only an accepted or duplicate-noop ACK permits deletion. Any network,
  /// authorization or replay mismatch preserves the event for explicit retry.
  Future<OutboxFlushResult> flush() => _locked(() async {
    final user = _user();
    final prefs = await _reload();
    final existing = await _load(prefs,user);
    final expired = await _purgeExpired(prefs, existing);
    _sameUser(user);
    final privacy = await _getPrivacy();
    _sameUser(user);
    final pending = await _load(await _reload(),user);
    final blocked = !privacy.canCollect || privacy.changedAt == null;
    final discarded = await _discardStaleConsent(
        prefs, pending, user, blocked ? null : privacy.changedAt);
    if (blocked) {
      return OutboxFlushResult(
        acknowledged: 0, remaining: 0, expired: expired,
        discardedConsent: discarded, blocked: true);
    }
    final deliverable = await _load(await _reload(), user);

    var acked = 0;
    for (final item in deliverable) {
      _sameUser(user);
      // A capped network wait avoids holding the queue lock indefinitely.
      // A timed-out RPC may still have succeeded; retry uses the same ID.
      try {
        await _sender.send(item.event)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        return OutboxFlushResult(
          acknowledged: acked, remaining: deliverable.length-acked,
          expired: expired, discardedConsent: discarded,
          blocked: false, deliveryFailed: true);
      }
      _sameUser(user);
      if (!await prefs.remove(item.key)) {
        throw StateError('Acknowledged event could not be removed locally.');
      }
      acked++;
    }
    return OutboxFlushResult(
      acknowledged: acked, remaining: 0, expired: expired,
      discardedConsent: discarded, blocked:false);
  });

  Future<int> pendingCount() => _locked(() async {
    final user = _user();
    final prefs = await _reload();
    _sameUser(user);
    return (await _load(prefs,user)).length;
  });

  /// Always available even without server deployment or consent. A user who
  /// withdraws consent must be able to purge their on-device queue first.
  Future<int> clearCurrentAccount() => _locked(() async {
    final user = _user();
    final prefs = await _reload();
    _sameUser(user);
    final keys = prefs.getKeys().where(
        (key) => key.startsWith(_userPrefix(user))).toList();
    for (final key in keys) {
      _sameUser(user);
      if (!await prefs.remove(key)) {
        throw StateError('Unable to erase an on-device product event.');
      }
    }
    return keys.length;
  });
}

class _PendingEvent {
  final String key;
  final ProductEvent event;
  final DateTime storedAt;
  final DateTime? consentChangedAt;
  const _PendingEvent(this.key,this.event,this.storedAt,
      this.consentChangedAt);
}

class OutboxFlushResult {
  final int acknowledged;
  final int remaining;
  final int expired;
  final int discardedConsent;
  final bool blocked;
  final bool deliveryFailed;

  const OutboxFlushResult({
    required this.acknowledged,
    required this.remaining,
    required this.expired,
    this.discardedConsent = 0,
    required this.blocked,
    this.deliveryFailed = false,
  });
}
