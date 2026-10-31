import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_context_progress_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

const targetVersion = 'b3000000-0000-4000-8000-000000000012';
const otherVersion = 'b3000000-0000-4000-8000-000000000099';
const manifest = 'b3000000-0000-4000-8000-000000000016';

User _user(String id, {bool guest = false}) => User(
  id: id, isAnonymous: guest,
  appMetadata: const {}, userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-21T00:00:00Z',
);

class _MutableClient implements SupabaseClient {
  final _MutableAuth stub = _MutableAuth();
  @override
  GoTrueClient get auth => stub;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MutableAuth implements GoTrueClient {
  User? current;
  @override
  User? get currentUser => current;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, dynamic> _record({
  String step = 'resource_choice',
  String target = targetVersion,
  String edition = manifest,
  int total = 3,
  int correct = 1,
  int incorrect = 1,
  int awaiting = 1,
  int skipped = 0,
}) => {
  'target_version_id': target,
  'manifest_revision_id': edition,
  'exam_part_key': 'project_management',
  'manifest_revision': 1,
  'drill_step': step,
  'recorded_steps': total,
  'graded_correct': correct,
  'graded_incorrect': incorrect,
  'awaiting_grade': awaiting,
  'skipped_steps': skipped,
  'last_recorded_at': '2027-03-01T12:00:00Z',
};

void main() {
  test('Published edition R1–R4 aggregates remain separate from mastery',
      () async {
    final client = FakeSupabaseClient(currentUser: _user('account-a'));
    final service = ExamReferenceContextProgressService(
      client: client,
      testTransport: (v) async {
        expect(v, targetVersion);
        return [
          _record(),
          _record(step:'interpretation',total:1,correct:0,
              incorrect:0,awaiting:0,skipped:1),
        ];
      },
    );
    final data = await service.load(
      expectedOwnerId:'account-a',targetVersionId:targetVersion,
    );
    expect(data.ownerId,'account-a');
    expect(data.editions.length,1);
    expect(data.editions.single.total,4);
    expect(data.editions.single.correct,1);
    expect(data.editions.single.incorrect,1);
    expect(data.editions.single.awaiting,1);
    expect(data.editions.single.skipped,1);
    expect(data.editions.single.steps.keys,
        containsAll(['resource_choice','interpretation']));
  });

  test('Unknown published reference edition is represented by an empty list',
      () async {
    final client=FakeSupabaseClient(currentUser:_user('account-a'));
    final service=ExamReferenceContextProgressService(
      client:client, testTransport:(v) async=>[],
    );
    final data=await service.load(
      expectedOwnerId:'account-a',targetVersionId:targetVersion);
    expect(data.editions,isEmpty);
  });

  test('Guest and foreign owner cannot request learner evidence',() async {
    var queried=0;
    final client=FakeSupabaseClient(currentUser:_user('guest',guest:true));
    final service=ExamReferenceContextProgressService(
      client:client,testTransport:(v) async {queried++;return [];},
    );
    await expectLater(service.load(
      expectedOwnerId:'guest',targetVersionId:targetVersion),
      throwsStateError);
    await expectLater(service.load(
      expectedOwnerId:'account-a',targetVersionId:targetVersion),
      throwsStateError);
    expect(queried,0);
  });

  test('Account switch during RPC cannot return previous owner data',
      () async {
    final client=_MutableClient()..stub.current=_user('account-a');
    final future=Completer<dynamic>();
    final service=ExamReferenceContextProgressService(
      client:client,testTransport:(v)=>future.future);
    final pending=service.load(
      expectedOwnerId:'account-a',targetVersionId:targetVersion);
    client.stub.current=_user('account-b');
    future.complete([_record()]);
    await expectLater(pending,throwsStateError);
  });

  test('Foreign version, malformed counts and unreviewed answer fields fail',
      () async {
    final client=FakeSupabaseClient(currentUser:_user('account-a'));
    for (final bad in [
      _record(target:otherVersion),
      _record(total:1,correct:2,incorrect:0,awaiting:0),
      _record()..['step_tokens']=['reviewer-secret'],
      _record()..['drill_step']='unknown_step',
      _record()..['recorded_steps']='3',
    ]) {
      final service=ExamReferenceContextProgressService(
        client:client,testTransport:(v) async=>[bad]);
      await expectLater(service.load(
        expectedOwnerId:'account-a',targetVersionId:targetVersion),
        throwsFormatException);
    }
  });

  test('Duplicate step or conflicting manifest metadata fails closed',
      () async {
    final client=FakeSupabaseClient(currentUser:_user('account-a'));
    for (final rows in [
      [_record(),_record()],
      [_record(), _record(step:'interpretation')..['manifest_revision']=2],
    ]) {
      final service=ExamReferenceContextProgressService(
        client:client,testTransport:(v) async=>rows);
      await expectLater(service.load(
        expectedOwnerId:'account-a',targetVersionId:targetVersion),
        throwsFormatException);
    }
  });
}
