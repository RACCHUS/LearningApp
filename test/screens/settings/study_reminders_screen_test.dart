import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/study_reminders_provider.dart';
import 'package:learning_pwa/screens/settings/study_reminders_screen.dart';
import 'package:learning_pwa/services/study_reminder_service.dart';

class _FakePush extends WebPushClient {
  _FakePush({this.isSupported = true, this.result});

  final bool isSupported;
  final WebPushSubscribeResult? result;
  WebPushSubscription? existing;
  int subscribeCalls = 0;
  int unsubscribeCalls = 0;

  @override
  bool get supported => isSupported;
  @override
  String? get timeZone => 'Europe/Paris';
  @override
  Future<WebPushSubscription?> current() async => existing;
  @override
  Future<WebPushSubscribeResult> subscribe(String vapidPublicKey) async {
    subscribeCalls++;
    final r = result ?? const WebPushSubscribeResult.failed();
    existing = r.subscription ?? existing;
    return r;
  }

  @override
  Future<String?> unsubscribe() async {
    unsubscribeCalls++;
    final endpoint = existing?.endpoint;
    existing = null;
    return endpoint;
  }
}

class _FakeService extends StudyReminderService {
  _FakeService(this.reminders);

  final List<StudyReminder> reminders;
  final registered = <String>[];
  final unregistered = <String>[];
  final saves = <Map<String, Object?>>[];

  @override
  Future<List<StudyReminder>> list() async => List.of(reminders);

  @override
  Future<StudyReminder> save({
    String? id,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
    required String timezone,
    bool isActive = true,
  }) async {
    saves.add({
      'id': id,
      'hour': hour,
      'minute': minute,
      'days': daysOfWeek,
      'timezone': timezone,
      'active': isActive,
    });
    final r = StudyReminder(
      id: id ?? 'new-${saves.length}',
      hour: hour,
      minute: minute,
      daysOfWeek: daysOfWeek,
      timezone: timezone,
      isActive: isActive,
    );
    reminders.removeWhere((x) => x.id == r.id);
    reminders.add(r);
    return r;
  }

  @override
  Future<void> registerBrowser(WebPushSubscription subscription) async =>
      registered.add(subscription.endpoint);

  @override
  Future<void> unregisterBrowser(String endpoint) async =>
      unregistered.add(endpoint);

  @override
  Future<void> delete(String id) async =>
      reminders.removeWhere((r) => r.id == id);
}

const _sub = WebPushSubscription(
  endpoint: 'https://push.example.invalid/me',
  p256dh: 'p256dh-key',
  auth: 'auth-key',
);

StudyReminder _reminder(String id, {bool active = true}) => StudyReminder(
      id: id,
      hour: 18,
      minute: 30,
      daysOfWeek: const [1, 2, 3, 4, 5],
      timezone: 'Europe/Paris',
      isActive: active,
    );

void main() {
  Future<(_FakePush, _FakeService)> pump(
    WidgetTester tester, {
    bool enabled = true,
    String vapid = 'BPublicKey',
    _FakePush? push,
    List<StudyReminder>? reminders,
  }) async {
    final p = push ?? _FakePush();
    final s = _FakeService(reminders ?? []);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        studyRemindersEnabledProvider.overrideWithValue(enabled),
        webPushVapidPublicKeyProvider.overrideWithValue(vapid),
        webPushClientProvider.overrideWithValue(p),
        studyReminderServiceProvider.overrideWithValue(s),
      ],
      child: const MaterialApp(home: StudyRemindersScreen()),
    ));
    await tester.pumpAndSettle();
    return (p, s);
  }

  testWidgets('gate OFF shows planned, not yet connected', (tester) async {
    final (push, _) = await pump(tester, enabled: false);
    expect(find.text('Study reminders are planned and not yet connected.'),
        findsOneWidget);
    expect(find.text('Turn on'), findsNothing);
    expect(push.subscribeCalls, 0);
  });

  testWidgets('no VAPID key says the server is not set up', (tester) async {
    await pump(tester, vapid: '');
    expect(find.byKey(const ValueKey('reminders-not-configured')),
        findsOneWidget);
  });

  testWidgets('unsupported browser explains the Home Screen step',
      (tester) async {
    await pump(tester, push: _FakePush(isSupported: false));
    expect(find.byKey(const ValueKey('reminders-unsupported')), findsOneWidget);
  });

  testWidgets('turning on subscribes and registers this browser',
      (tester) async {
    final (push, service) = await pump(
      tester,
      push: _FakePush(result: const WebPushSubscribeResult.subscribed(_sub)),
    );
    expect(find.text('Off for this browser'), findsOneWidget);
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(push.subscribeCalls, 1);
    expect(service.registered, [_sub.endpoint]);
    expect(find.text('On for this browser'), findsOneWidget);
  });

  testWidgets('blocked permission registers nothing and says why',
      (tester) async {
    final (_, service) = await pump(
      tester,
      push: _FakePush(result: const WebPushSubscribeResult.denied()),
    );
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(service.registered, isEmpty);
    expect(find.textContaining('Notifications are blocked'), findsOneWidget);
  });

  testWidgets('turning off unsubscribes and unregisters', (tester) async {
    final (push, service) =
        await pump(tester, push: _FakePush()..existing = _sub);
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(push.unsubscribeCalls, 1);
    expect(service.unregistered, [_sub.endpoint]);
  });

  testWidgets('adding a reminder saves weekdays at 18:00 in the browser zone',
      (tester) async {
    final (_, service) = await pump(tester);
    expect(find.text('No reminders yet.'), findsOneWidget);
    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.saves.single, {
      'id': null,
      'hour': 18,
      'minute': 0,
      'days': [1, 2, 3, 4, 5],
      'timezone': 'Europe/Paris',
      'active': true,
    });
    expect(find.text('Weekdays'), findsOneWidget);
  });

  testWidgets('the pause switch saves is_active=false', (tester) async {
    final (_, service) = await pump(tester, reminders: [_reminder('r1')]);
    expect(find.text('18:30'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(service.saves.single['id'], 'r1');
    expect(service.saves.single['active'], false);
  });

  testWidgets('five reminders disable Add', (tester) async {
    await pump(tester, reminders: [
      for (var i = 0; i < 5; i++) _reminder('r$i'),
    ]);
    final button = tester.widget<OutlinedButton>(find.ancestor(
        of: find.text('Add reminder'), matching: find.byType(OutlinedButton)));
    expect(button.onPressed, isNull);
    expect(find.text('You can have up to 5 reminders.'), findsOneWidget);
  });
}
