import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_part_reference_attempt_history_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

const version = 'b3000000-0000-4000-8000-000000000012';
const manifest = 'b3000000-0000-4000-8000-000000000016';
const attempt1 = 'b3000000-0000-4000-8000-000000000041';
const attempt2 = 'b3000000-0000-4000-8000-000000000042';

User _user(String id, {bool anonymous = false}) => User(
  id: id,
  isAnonymous: anonymous,
  appMetadata: const {}, userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-21T00:00:00Z',
);

class _MutableAuth implements GoTrueClient {
  User? active;
  @override
  User? get currentUser => active;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MutableClient implements SupabaseClient {
  final _MutableAuth fakeAuth = _MutableAuth();
  @override
  GoTrueClient get auth => fakeAuth;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, dynamic> _row({
  String id = attempt1,
  String owner = 'account-a',
  String part = 'project_management',
  String target = version,
  String edition = manifest,
  int steps = 4,
  int correct = 1,
  int incorrect = 1,
  int awaiting = 1,
  int skipped = 1,
  bool? completed,
  String recorded = '2027-03-01T12:00:00Z',
}) => {
  'owner_auth_uid': owner,
  'target_version_id': target,
  'exam_part_key': part,
  'client_attempt_id': id,
  'manifest_revision_id': edition,
  'manifest_revision': 2,
  'assessment_item_id': 'b3000000-0000-4000-8000-000000000017',
  'approved_binding_id': 'b3000000-0000-4000-8000-000000000018',
  'administration_date': '2027-07-01',
  'recorded_steps': steps,
  'graded_correct': correct,
  'graded_incorrect': incorrect,
  'awaiting_grade': awaiting,
  'skipped_steps': skipped,
  'first_recorded_at': '2027-03-01T11:00:00Z',
  'last_recorded_at': recorded,
  'completed_four_steps': completed ?? steps == 4,
};

void main() {
  test('saved four-step receipt counts graded, ungraded and skipped separately',
      () async {
    final client = FakeSupabaseClient(currentUser: _user('account-a'));
    final service = ExamPartReferenceAttemptHistoryService(
      client: client,
      testTransport: (v, p, l, t, id) async {
        expect(v, version);
        expect(p, 'project_management');
        expect(l, 20);
        expect(t, isNull);
        expect(id, isNull);
        return [
          _row(),
          _row(id: attempt2, steps: 3, correct: 0, incorrect: 1,
            awaiting: 1, skipped: 1,
            recorded: '2027-03-01T11:58:00Z'),
        ];
      },
    );
    final page = await service.load(
      expectedOwnerId: 'account-a',
      targetVersionId: version,
      examPartKey: 'project_management',
    );
    expect(page.completed, 1);
    expect(page.incomplete, 1);
    expect(page.attempts.first.correct, 1);
    expect(page.attempts.first.awaiting, 1);
    expect(page.attempts.first.skipped, 1);
    expect(page.mightHaveMore, isFalse);
    expect(page.attempts.last.completedFourSteps, isFalse);
    expect(page.attempts.first.lastRecordedAt.isUtc, isTrue);
  });

  test('guest and wrong owner never reach private RPC transport', () async {
    var calls = 0;
    final client = FakeSupabaseClient(currentUser: _user('guest', anonymous:true));
    final service = ExamPartReferenceAttemptHistoryService(
      client: client,
      testTransport: (_, __, ___, ____, _____) async {
        calls++;
        return [];
      },
    );
    await expectLater(service.load(
      expectedOwnerId: 'guest', targetVersionId: version,
      examPartKey: 'project_management'), throwsStateError);
    await expectLater(service.load(
      expectedOwnerId: 'account-a', targetVersionId: version,
      examPartKey: 'project_management'), throwsStateError);
    expect(calls, 0);
  });

  test('account switching during awaited RPC blocks old private results',
      () async {
    final client = _MutableClient()..fakeAuth.active = _user('account-a');
    final pending = Completer<dynamic>();
    final service = ExamPartReferenceAttemptHistoryService(
      client: client,
      testTransport: (_, __, ___, ____, _____) => pending.future,
    );
    final read = service.load(
      expectedOwnerId: 'account-a', targetVersionId: version,
      examPartKey: 'project_management');
    client.fakeAuth.active = _user('account-b');
    pending.complete([_row()]);
    await expectLater(read, throwsStateError);
  });

  test('malformed and cross-owner/part/version data fail closed', () async {
    final client = FakeSupabaseClient(currentUser: _user('account-a'));
    final bad = <Map<String,dynamic>>[
      _row(owner: 'account-b'),
      _row(part: 'part_b'),
      _row(target: 'another-version'),
      _row(edition: 'invalid'),
      _row(steps: 3), // counts sum to four
      _row(completed: false),
      _row()..['reviewer_private_key'] = 'secret',
      _row()..['graded_correct'] = 5,
      _row(recorded: 'invalid-time'),
      _row()..['administration_date'] = 'not-a-date',
    ];
    for (final row in bad) {
      final service = ExamPartReferenceAttemptHistoryService(
        client: client,
        testTransport: (_, __, ___, ____, _____) async => [row],
      );
      await expectLater(service.load(
        expectedOwnerId: 'account-a', targetVersionId: version,
        examPartKey: 'project_management'), throwsFormatException);
    }
  });

  test('duplicate IDs, unsorted pages and oversized responses are refused',
      () async {
    final client = FakeSupabaseClient(currentUser: _user('account-a'));
    final latest = _row();
    final older = _row(id: attempt2, steps: 3,
      correct: 0, incorrect: 1, awaiting: 1, skipped: 1,
      recorded: '2027-03-01T11:58:00Z');
    for (final rows in [
      [latest, latest],
      [older, latest],
    ]) {
      final service = ExamPartReferenceAttemptHistoryService(
        client: client,
        testTransport: (_, __, ___, ____, _____) async => rows,
      );
      await expectLater(service.load(
        expectedOwnerId: 'account-a', targetVersionId: version,
        examPartKey: 'project_management'), throwsFormatException);
    }
    final over = ExamPartReferenceAttemptHistoryService(
      client: client,
      testTransport: (_, __, ___, ____, _____) async => [latest, older],
    );
    await expectLater(over.load(
      expectedOwnerId: 'account-a', targetVersionId: version,
      examPartKey: 'project_management', limit:1), throwsFormatException);
  });

  test('keyset cursor excludes newest and validates query arguments', () async {
    final client = FakeSupabaseClient(currentUser: _user('account-a'));
    final service = ExamPartReferenceAttemptHistoryService(
      client: client,
      testTransport: (v, part, limit, before, id) async {
        expect(id, attempt1);
        expect(before, '2027-03-01T12:00:00.000Z');
        return [_row(id:attempt2,steps:3,correct:0,incorrect:1,
          awaiting:1,skipped:1, recorded:'2027-03-01T11:58:00Z')];
      },
    );
    final page = await service.load(
      expectedOwnerId:'account-a',targetVersionId:version,
      examPartKey:'project_management',
      beforeAt: DateTime.utc(2027,3,1,12),
      beforeAttemptId:attempt1,
    );
    expect(page.attempts.length,1);
    for (final fn in [
      () => service.load(expectedOwnerId:'account-a',
        targetVersionId:version,examPartKey:'part a'),
      () => service.load(expectedOwnerId:'account-a',
        targetVersionId:version,examPartKey:'project_management',limit:51),
      () => service.load(expectedOwnerId:'account-a',
        targetVersionId:version,examPartKey:'project_management',
        beforeAt:DateTime.utc(2027)),
    ]) {
      await expectLater(fn(),throwsFormatException);
    }
  });
}
