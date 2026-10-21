import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_practice_batch_erasure_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

User user(String id,{bool guest=false})=>User(
  id:id,isAnonymous:guest,appMetadata:const {},userMetadata:const {},
  aud:'authenticated',createdAt:'2026-10-21T00:00:00Z',
);

Map<String,dynamic> preview({
  String owner='owner-a',int total=5001,int events=1000,
  int grades=1,int editions=1,int limit=1000,
})=> {
  'scope':'reference-practice-next-batch',
  'owner_auth_uid':owner,
  'total_events':total,
  'batch_events':events,
  'batch_grades':grades,
  'batch_editions':editions,
  'batch_limit':limit,
  'batch_fingerprint':'a'*32,
};

Map<String,dynamic> receipt({
  String owner='owner-a',int deleted=1000,int remaining=4001,
})=> {
  'scope':'reference-practice-next-batch',
  'owner_auth_uid':owner,
  'deleted_events':deleted,
  'remaining_events':remaining,
};

class _MutableClient implements SupabaseClient {
  final _MutableAuth mutableAuth=_MutableAuth();
  @override
  GoTrueClient get auth=>mutableAuth;
  @override
  dynamic noSuchMethod(Invocation i)=>throw UnimplementedError();
}
class _MutableAuth implements GoTrueClient {
  User? owner;
  @override
  User? get currentUser=>owner;
  @override
  dynamic noSuchMethod(Invocation i)=>throw UnimplementedError();
}

void main() {
  test('Never deletes automatically; one checked batch only',() async {
    final client=FakeSupabaseClient(currentUser:user('owner-a'));
    var deletions=0;
    final service=ExamReferencePracticeBatchErasureService(
      client:client,
      testPreview:(size) async{
        expect(size,1000);
        return preview();
      },
      testDelete:(limit,count,fingerprint,phrase) async{
        deletions++;
        expect(limit,1000);
        expect(count,1000);
        expect(fingerprint,'a'*32);
        expect(phrase,'DELETE NEXT BATCH');
        return receipt();
      },
    );
    final prepared=await service.preview(expectedOwnerId:'owner-a');
    expect(prepared.totalEvents,5001);
    expect(prepared.batchEvents,1000);
    expect(deletions,0);
    await expectLater(service.deleteOneBatch(
      expectedOwnerId:'owner-a',preview:prepared,
      exactConfirmation:'delete next batch',
    ),throwsStateError);
    expect(deletions,0);
    final result=await service.deleteOneBatch(
      expectedOwnerId:'owner-a',preview:prepared,
      exactConfirmation:'DELETE NEXT BATCH',
    );
    expect(result.deleted,1000);
    expect(result.remaining,4001);
    expect(deletions,1);
  });

  test('Guest, unsigned, and wrong owner fail before transport',() async {
    var calls=0;
    final client=FakeSupabaseClient(currentUser:user('anonymous',guest:true));
    final service=ExamReferencePracticeBatchErasureService(
      client:client,testPreview:(l) async{calls++;return preview();},
      testDelete:(l,c,f,p) async{calls++;return receipt();},
    );
    await expectLater(service.preview(expectedOwnerId:'anonymous'),
      throwsStateError);
    await expectLater(service.preview(expectedOwnerId:'owner-a'),
      throwsStateError);
    final owned=ReferencePracticeBatchPreview.fromRpc(
      preview(),'owner-a',1000);
    await expectLater(service.deleteOneBatch(
      expectedOwnerId:'anonymous',preview:owned,
      exactConfirmation:'DELETE NEXT BATCH',
    ),throwsStateError);
    expect(calls,0);
  });

  test('Account switch while reading denies old preview',() async {
    final client=_MutableClient()..mutableAuth.owner=user('owner-a');
    final pending=Completer<dynamic>();
    final service=ExamReferencePracticeBatchErasureService(
      client:client,testPreview:(limit)=>pending.future);
    final request=service.preview(expectedOwnerId:'owner-a');
    client.mutableAuth.owner=user('owner-b');
    pending.complete(preview());
    await expectLater(request,throwsStateError);
  });

  test('Account switch during destructive call denies receipt',() async {
    final client=_MutableClient()..mutableAuth.owner=user('owner-a');
    final pending=Completer<dynamic>();
    final service=ExamReferencePracticeBatchErasureService(
      client:client,testDelete:(l,c,f,p)=>pending.future);
    final p=ReferencePracticeBatchPreview.fromRpc(preview(),'owner-a',1000);
    final request=service.deleteOneBatch(
      expectedOwnerId:'owner-a',preview:p,
      exactConfirmation:'DELETE NEXT BATCH');
    client.mutableAuth.owner=user('owner-b');
    pending.complete(receipt());
    await expectLater(request,throwsStateError);
  });

  test('Extra fields, inconsistent counts and invalid owner fail closed',() async {
    final client=FakeSupabaseClient(currentUser:user('owner-a'));
    final invalid=[
      preview(owner:'other-owner'),
      preview(total:4,events:1000),
      preview(events:1001),
      preview(events:0,total:5001),
      preview(grades:1001),
      preview(editions:1001),
      preview(limit:1),
      preview()..['private_answer']='never',
      preview()..['batch_fingerprint']='wrong',
    ];
    for(final record in invalid) {
      final service=ExamReferencePracticeBatchErasureService(
        client:client,testPreview:(limit) async=>record);
      await expectLater(service.preview(expectedOwnerId:'owner-a'),
        throwsFormatException);
    }
    final good=ReferencePracticeBatchPreview.fromRpc(preview(),'owner-a',1000);
    for(final response in [
      receipt(owner:'other-owner'),
      receipt(deleted:999),
      receipt(remaining:-1),
      receipt()..['private_reviewer']='never',
    ]) {
      final service=ExamReferencePracticeBatchErasureService(
        client:client,testDelete:(l,c,f,p) async=>response);
      await expectLater(service.deleteOneBatch(
        expectedOwnerId:'owner-a',preview:good,
        exactConfirmation:'DELETE NEXT BATCH',
      ),throwsFormatException);
    }
  });

  test('Empty account is safe and cannot issue a deletion',() async {
    final client=FakeSupabaseClient(currentUser:user('owner-a'));
    var called=0;
    final service=ExamReferencePracticeBatchErasureService(
      client:client,
      testPreview:(n) async=>preview(
        total:0,events:0,grades:0,editions:0),
      testDelete:(a,b,c,d) async{called++;return receipt();},
    );
    final p=await service.preview(expectedOwnerId:'owner-a');
    expect(p.batchEvents,0);
    await expectLater(service.deleteOneBatch(
      expectedOwnerId:'owner-a',preview:p,
      exactConfirmation:'DELETE NEXT BATCH',
    ),throwsStateError);
    expect(called,0);
  });
}
