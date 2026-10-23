import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_event_service.dart';
import 'package:learning_pwa/widgets/targets/saved_reference_drill_history_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../test_helpers/fake_supabase_client.dart';

class _AuthForTest extends StateNotifier<AuthState> implements AuthNotifier {
  _AuthForTest(super.initial);
  void switchTo(AuthState state) => this.state = state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHistoryService extends ExamReferenceDrillEventService {
  _FakeHistoryService() : super(client: FakeSupabaseClient());

  final requests = <String>[];
  final deletions = <String>[];
  final entries = <String, List<Map<String, dynamic>>>{};
  final pending = <String, Completer<List<Map<String, dynamic>>>>{};

  @override
  Future<List<Map<String, dynamic>>> listMyEvents({
    int limit = 100,
    String? manifestRevisionId,
    String? expectedOwnerId,
  }) {
    requests.add('${expectedOwnerId ?? 'unknown'}:${manifestRevisionId ?? 'none'}');
    if (pending.containsKey(expectedOwnerId)) {
      return pending[expectedOwnerId]!.future;
    }
    return Future.value(List.of(entries[expectedOwnerId] ?? const []));
  }

  @override
  Future<void> deleteMyAttempt(
    String clientAttemptId, {
    String? manifestRevisionId,
    String? expectedOwnerId,
  }) async {
    deletions.add('${expectedOwnerId ?? 'unknown'}:${manifestRevisionId ?? 'none'}:$clientAttemptId');
    entries[expectedOwnerId]?.removeWhere(
      (row) => row['client_attempt_id'] == clientAttemptId &&
          row['manifest_revision_id'] == manifestRevisionId,
    );
  }
}

void main() {
  User user(String id, {bool anonymous = false}) => User(
        id: id,
        isAnonymous: anonymous,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-20T00:00:00Z',
      );

  Map<String, dynamic> event(String owner, String attempt,
          {String manifest = 'manifest-27'}) =>
      {
        'owner_auth_uid': owner,
        'manifest_revision_id': manifest,
        'client_attempt_id': attempt,
        'administration_date': '2027-03-10',
        'drill_step': 'resource_choice',
      };

  Future<void> mount(
    WidgetTester tester,
    _AuthForTest notifier,
    _FakeHistoryService service,
  ) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SavedReferenceDrillHistoryCard(
              manifestRevisionId: 'manifest-27',
              eventService: service,
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('Guest and signed-out sessions never fetch private activity',
      (tester) async {
    final auth = _AuthForTest(GuestMode());
    final service = _FakeHistoryService();
    await mount(tester, auth, service);
    expect(find.textContaining('Sign in to save private'), findsOneWidget);
    expect(find.byKey(const Key('reference-drill-history')), findsNothing);

    auth.switchTo(AuthSuccess(user('guest', anonymous: true)));
    await tester.pump();
    expect(find.byKey(const Key('reference-drill-history')), findsNothing);
    expect(service.requests, isEmpty);
  });

  testWidgets('History is scoped to verified manifest and ignores foreign rows',
      (tester) async {
    final auth = _AuthForTest(AuthSuccess(user('account-a')));
    final service = _FakeHistoryService();
    service.entries['account-a'] = [
      event('account-a', 'valid'),
      event('account-a', 'wrong-edition', manifest: 'manifest-26'),
      event('account-b', 'wrong-owner'),
    ];
    await mount(tester, auth, service);
    expect(service.requests, isEmpty);
    await tester.tap(find.text('Saved reference practice'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-attempt:valid')), findsOneWidget);
    expect(find.byKey(const Key('practice-attempt:wrong-edition')), findsNothing);
    expect(find.byKey(const Key('practice-attempt:wrong-owner')), findsNothing);
    expect(service.requests, ['account-a:manifest-27']);
    expect(find.textContaining('not verified scores'), findsOneWidget);
  });

  testWidgets('A delayed response cannot leak into B after account switch',
      (tester) async {
    final auth = _AuthForTest(AuthSuccess(user('account-a')));
    final service = _FakeHistoryService();
    service.pending['account-a'] = Completer<List<Map<String, dynamic>>>();
    service.pending['account-b'] = Completer<List<Map<String, dynamic>>>();
    await mount(tester, auth, service);
    await tester.tap(find.text('Saved reference practice'));
    await tester.pump();
    expect(service.requests, ['account-a:manifest-27']);

    auth.switchTo(AuthSuccess(user('account-b')));
    await tester.pump();
    // Account B sees a NEW closed panel with no cached account A state.
    expect(find.byKey(const Key('practice-attempt:old-A')), findsNothing);
    await tester.tap(find.text('Saved reference practice'));
    await tester.pump();
    expect(service.requests.last, 'account-b:manifest-27');

    service.pending['account-a']!.complete([event('account-a', 'old-A')]);
    await tester.pump();
    expect(find.byKey(const Key('practice-attempt:old-A')), findsNothing);

    service.pending['account-b']!.complete([event('account-b', 'new-B')]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-attempt:new-B')), findsOneWidget);
    expect(find.byKey(const Key('practice-attempt:old-A')), findsNothing);
  });

  testWidgets('Account switch while delete dialog is open cannot delete A',
      (tester) async {
    final auth = _AuthForTest(AuthSuccess(user('account-a')));
    final service = _FakeHistoryService();
    service.entries['account-a'] = [event('account-a', 'attempt-A')];
    await mount(tester, auth, service);
    await tester.tap(find.text('Saved reference practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete saved practice'));
    await tester.pumpAndSettle();

    auth.switchTo(AuthSuccess(user('account-b')));
    await tester.pump();
    await tester.tap(find.text('Delete practice'));
    await tester.pumpAndSettle();
    expect(service.deletions, isEmpty);
    expect(find.byKey(const Key('practice-attempt:attempt-A')), findsNothing);
  });

  testWidgets('Delete requires confirmation and only targets current owner',
      (tester) async {
    final auth = _AuthForTest(AuthSuccess(user('account-a')));
    final service = _FakeHistoryService();
    service.entries['account-a'] = [event('account-a', 'attempt-1')];
    await mount(tester, auth, service);
    await tester.tap(find.text('Saved reference practice'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete saved practice'));
    await tester.pumpAndSettle();
    expect(find.text('Delete saved practice?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.deletions, isEmpty);

    await tester.tap(find.byTooltip('Delete saved practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete practice'));
    await tester.pumpAndSettle();
    expect(service.deletions, ['account-a:manifest-27:attempt-1']);
    expect(find.byKey(const Key('practice-attempt:attempt-1')), findsNothing);
    expect(find.text('No saved reference practice for this edition.'),
        findsOneWidget);
  });
}
