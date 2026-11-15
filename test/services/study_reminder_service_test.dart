import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/study_reminder_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../test_helpers/fake_supabase_client.dart';

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-11-15T00:00:00Z',
    );

Map<String, dynamic> _row(String id, String owner,
        {List<int> days = const [1, 3], bool active = true}) =>
    {
      'id': id,
      'user_id': owner,
      'local_time': '07:05:00',
      'days_of_week': days,
      'timezone': 'Europe/London',
      'is_active': active,
      'next_fire_at': active ? '2026-11-16T07:05:00+00:00' : null,
      'created_at': '2026-11-15T00:00:00Z',
    };

void main() {
  group('StudyReminder', () {
    test('parses server rows', () {
      final r = StudyReminder.fromJson(_row('r1', 'u', days: [3, 1]));
      expect(r.localTime, '07:05');
      expect(r.daysOfWeek, [1, 3]);
      expect(r.timezone, 'Europe/London');
      expect(r.nextFireAt, DateTime.utc(2026, 11, 16, 7, 5));
    });

    test('day labels', () {
      String label(List<int> d) =>
          StudyReminder.fromJson(_row('r', 'u', days: d)).daysLabel;
      expect(label([1, 2, 3, 4, 5, 6, 7]), 'Every day');
      expect(label([1, 2, 3, 4, 5]), 'Weekdays');
      expect(label([6, 7]), 'Weekends');
      expect(label([1, 3, 5]), 'Mon, Wed, Fri');
    });
  });

  group('StudyReminderService', () {
    test('lists only the signed-in learner reminders', () async {
      final client = FakeSupabaseClient(currentUser: _user('u1'))
        ..setTableData('study_reminders', [_row('a', 'u1'), _row('b', 'u2')]);
      final list = await StudyReminderService(client: client).list();
      expect(list.map((r) => r.id), ['a']);
    });

    test('signed out lists nothing', () async {
      final client = FakeSupabaseClient()
        ..setTableData('study_reminders', [_row('a', 'u1')]);
      expect(await StudyReminderService(client: client).list(), isEmpty);
    });

    test('save sends time, days and zone; never a fire time', () async {
      final calls = <(String, Map<String, dynamic>?)>[];
      final client = FakeSupabaseClient(currentUser: _user('u1'))
        ..rpcHandler = (fn, {params}) {
          calls.add((fn, params));
          return _row('new', 'u1');
        };
      final saved = await StudyReminderService(client: client).save(
        hour: 7,
        minute: 5,
        daysOfWeek: [1, 3],
        timezone: 'Europe/London',
      );
      expect(calls.single.$1, 'save_study_reminder');
      expect(calls.single.$2, {
        'p_id': null,
        'p_local_time': '07:05',
        'p_days': [1, 3],
        'p_timezone': 'Europe/London',
        'p_is_active': true,
      });
      expect(saved.id, 'new');
    });

    test('browser registration sends endpoint and keys', () async {
      final calls = <(String, Map<String, dynamic>?)>[];
      final client = FakeSupabaseClient(currentUser: _user('u1'))
        ..rpcHandler = (fn, {params}) => calls.add((fn, params));
      final service = StudyReminderService(client: client);
      await service.registerBrowser(const WebPushSubscription(
        endpoint: 'https://push.example.invalid/x',
        p256dh: 'p256dh-key',
        auth: 'auth-key',
      ));
      await service.unregisterBrowser('https://push.example.invalid/x');
      await service.delete('r1');
      expect(calls.map((c) => c.$1), [
        'register_push_subscription',
        'unregister_push_subscription',
        'delete_study_reminder',
      ]);
      expect(calls.first.$2, {
        'p_endpoint': 'https://push.example.invalid/x',
        'p_p256dh': 'p256dh-key',
        'p_auth': 'auth-key',
      });
    });
  });
}
