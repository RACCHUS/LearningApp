import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_practice_erasure_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

User _user(String id, {bool guest = false}) => User(
  id: id, isAnonymous: guest, appMetadata: const {},
  userMetadata: const {}, aud: 'authenticated',
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

Map<String, dynamic> _preview({
  String owner = 'owner-a',
  int count = 3,
  int grades = 2,
  int editions = 2,
}) => {
  'scope': 'reference-practice-all-editions',
  'owner_auth_uid': owner,
  'event_count': count,
  'graded_count': grades,
  'edition_count': editions,
  'snapshot_fingerprint': 'a' * 32,
};

Map<String, dynamic> _receipt({String owner='owner-a', int deleted=3,
    int remaining=0}) => {
  'scope':'reference-practice-all-editions',
  'owner_auth_uid':owner,
  'deleted_events':deleted,
  'remaining_events':remaining,
};

void main() {
  test('Preview and explicit confirmation exactly pin the server deletion',
      () async {
    final client=FakeSupabaseClient(currentUser:_user('owner-a'));
    var calls=0;
    final api=ExamReferencePracticeErasureService(
      client:client,
      testPreview:() async=>_preview(),
      testErase:(count,fingerprint,phrase) async {
        calls++;
        expect(count,3);
        expect(fingerprint,'a' * 32);
        expect(phrase,ExamReferencePracticeErasureService.confirmationPhrase);
        return _receipt(remaining:1);
      },
    );
    final preview=await api.preview(expectedOwnerId:'owner-a');
    expect(preview.grades,2);
    expect(preview.editions,2);
    expect(calls,0);
    await expectLater(api.deletePreviewed(
      expectedOwnerId:'owner-a',preview:preview,
      exactConfirmation:'delete reference practice',
    ),throwsStateError);
    expect(calls,0);
    final result=await api.deletePreviewed(
      expectedOwnerId:'owner-a',preview:preview,
      exactConfirmation:ExamReferencePracticeErasureService.confirmationPhrase,
    );
    expect(result.deleted,3);
    expect(result.remaining,1);
    expect(calls,1);
  });

  test('Guest/wrong account fails before preview or erase request',() async {
    final client=FakeSupabaseClient(currentUser:_user('guest',guest:true));
    var calls=0;
    final api=ExamReferencePracticeErasureService(
      client:client,
      testPreview:() async {calls++;return _preview();},
      testErase:(n,f,p) async {calls++;return _receipt();},
    );
    await expectLater(api.preview(expectedOwnerId:'guest'),throwsStateError);
    await expectLater(api.deletePreviewed(
      expectedOwnerId:'guest',
      preview:ReferencePracticeErasurePreview.parse(_preview(),'owner-a'),
      exactConfirmation:ExamReferencePracticeErasureService.confirmationPhrase,
    ),throwsStateError);
    expect(calls,0);
  });

  test('In-flight account switch does not return private inventory',() async {
    final client=_MutableClient()..stub.current=_user('owner-a');
    final pending=Completer<dynamic>();
    final api=ExamReferencePracticeErasureService(
      client:client,testPreview:()=>pending.future);
    final result=api.preview(expectedOwnerId:'owner-a');
    client.stub.current=_user('owner-b');
    pending.complete(_preview());
    await expectLater(result,throwsStateError);
  });

  test('Malformed preview and fabricated deletion receipt fail closed',
      () async {
    final client=FakeSupabaseClient(currentUser:_user('owner-a'));
    for(final invalid in [
      _preview(owner:'owner-b'),
      _preview(count:1,grades:2,editions:1),
      _preview(count:0,grades:0,editions:1),
      _preview()..['private_scoring_key']='secret',
      _preview()..['snapshot_fingerprint']='invalid',
    ]) {
      final api=ExamReferencePracticeErasureService(
        client:client,testPreview:() async=>invalid);
      await expectLater(api.preview(expectedOwnerId:'owner-a'),
          throwsFormatException);
    }
    final valid=ReferencePracticeErasurePreview.parse(_preview(),'owner-a');
    for(final invalid in [
      _receipt(owner:'owner-b'),
      _receipt(deleted:2),
      _receipt(remaining:-1),
      _receipt()..['unexpected']='private',
    ]) {
      final api=ExamReferencePracticeErasureService(
        client:client,testErase:(n,f,p) async=>invalid);
      await expectLater(api.deletePreviewed(
        expectedOwnerId:'owner-a',preview:valid,
        exactConfirmation:ExamReferencePracticeErasureService.confirmationPhrase,
      ),throwsFormatException);
    }
  });

  test('Post-call account switch invalidates deletion receipt',() async {
    final client=_MutableClient()..stub.current=_user('owner-a');
    final pending=Completer<dynamic>();
    final api=ExamReferencePracticeErasureService(
      client:client,testErase:(n,f,p)=>pending.future);
    final valid=ReferencePracticeErasurePreview.parse(_preview(),'owner-a');
    final deleting=api.deletePreviewed(
      expectedOwnerId:'owner-a',preview:valid,
      exactConfirmation:ExamReferencePracticeErasureService.confirmationPhrase);
    client.stub.current=_user('owner-b');
    pending.complete(_receipt());
    await expectLater(deleting,throwsStateError);
  });
}
