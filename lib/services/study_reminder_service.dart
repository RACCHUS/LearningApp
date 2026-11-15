import 'package:supabase_flutter/supabase_flutter.dart';

import 'notifications/web_push_stub.dart'
    if (dart.library.js_interop) 'notifications/web_push_web.dart' as push;
import 'notifications/web_push_types.dart';

export 'notifications/web_push_types.dart';

/// A study reminder (`public.study_reminders`). The server computes
/// [nextFireAt]; the browser never sets it.
class StudyReminder {
  const StudyReminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.daysOfWeek,
    required this.timezone,
    required this.isActive,
    this.nextFireAt,
  });

  final String id;
  final int hour;
  final int minute;

  /// ISO weekdays, 1 = Monday .. 7 = Sunday, sorted.
  final List<int> daysOfWeek;
  final String timezone;
  final bool isActive;
  final DateTime? nextFireAt;

  factory StudyReminder.fromJson(Map<String, dynamic> json) {
    final parts = (json['local_time'] as String).split(':');
    return StudyReminder(
      id: json['id'] as String,
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
      daysOfWeek: [
        for (final d in (json['days_of_week'] as List)) (d as num).toInt(),
      ]..sort(),
      timezone: json['timezone'] as String,
      isActive: json['is_active'] as bool? ?? true,
      nextFireAt: json['next_fire_at'] == null
          ? null
          : DateTime.parse(json['next_fire_at'] as String),
    );
  }

  String get localTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "Every day", "Weekdays", "Weekends" or "Mon, Wed, Fri".
  String get daysLabel {
    final days = daysOfWeek.toSet();
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll([1, 2, 3, 4, 5])) {
      return 'Weekdays';
    }
    if (days.length == 2 && days.containsAll([6, 7])) return 'Weekends';
    return [for (final d in daysOfWeek) _names[d - 1]].join(', ');
  }
}

/// Server reminders plus this browser's push subscription.
class StudyReminderService {
  StudyReminderService({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const maxReminders = 5;

  Future<List<StudyReminder>> list() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('study_reminders')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: true);
    return [
      for (final row in rows as List)
        StudyReminder.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<StudyReminder> save({
    String? id,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
    required String timezone,
    bool isActive = true,
  }) async {
    final row = await _client.rpc('save_study_reminder', params: {
      'p_id': id,
      'p_local_time':
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      'p_days': daysOfWeek,
      'p_timezone': timezone,
      'p_is_active': isActive,
    });
    return StudyReminder.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> delete(String id) =>
      _client.rpc('delete_study_reminder', params: {'p_id': id});

  Future<void> registerBrowser(WebPushSubscription subscription) =>
      _client.rpc('register_push_subscription', params: {
        'p_endpoint': subscription.endpoint,
        'p_p256dh': subscription.p256dh,
        'p_auth': subscription.auth,
      });

  Future<void> unregisterBrowser(String endpoint) => _client
      .rpc('unregister_push_subscription', params: {'p_endpoint': endpoint});
}

/// Thin seam over the browser Push API so widgets can be tested on the VM.
class WebPushClient {
  const WebPushClient();

  bool get supported => push.webPushSupported();
  String? get timeZone => push.browserTimeZone();
  Future<WebPushSubscription?> current() => push.currentWebPushSubscription();
  Future<WebPushSubscribeResult> subscribe(String vapidPublicKey) =>
      push.subscribeWebPush(vapidPublicKey);
  Future<String?> unsubscribe() => push.unsubscribeWebPush();
}
