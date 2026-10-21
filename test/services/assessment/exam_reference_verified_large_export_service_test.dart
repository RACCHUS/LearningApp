import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_verified_large_export_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

const owner='owner-a';
const manifest='33333333-3333-4333-8333-333333333333';
User user(String id,{bool guest=false})=>User(
  id:id,isAnonymous:guest,appMetadata:const {},
  userMetadata:const {},aud:'authenticated',
  createdAt:'2026-10-21T00:00:00Z',
);
String eventId(int i)=>'e0000000-0000-4000-8000-${i.toString().padLeft(12,'0')}';
DateTime time(int i)=>DateTime.utc(2027,3,1).subtract(Duration(milliseconds:i));
Map<String,dynamic> record(int index,{
  String ownerId=owner,
  bool? isCorrect,
})=> {
  'event_id':eventId(index),
  'owner_auth_uid':ownerId,
  'client_attempt_id':'a0000000-0000-4000-8000-${index.toString().padLeft(12,'0')}',
  'assessment_item_id':'77777777-7777-4777-8777-777777777777',
  'approved_binding_id':'88888888-8888-4888-8888-888888888888',
  'manifest_revision_id':manifest,
  'exam_part_key':'project_management',
  'administration_date':'2027-06-01',
  'item_content_revision':1,
  'answer_location_revision':1,
  'drill_step':'resource_choice',
  'responded':true,
  'app_elapsed_ms':900,
  'self_reported_book_ms':null,
  'started_at':'2027-02-28T11:59:55Z',
  'completed_at':'2027-02-28T11:59:56Z',
  'recorded_at':time(index).toIso8601String(),
  'verification_state':'unverified',
  'is_correct':isCorrect,
  'scoring_version':isCorrect==null?null:1,
  'graded_at':isCorrect==null?null:'2027-03-01T12:00:01Z',
};
Map<String,dynamic> inventory(int count,{String digest='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String ownerId=owner})=> {
    'scope':'reference-practice-all-editions',
    'owner_auth_uid':ownerId,
    'record_count':count,
    'record_fingerprint':digest,
    'verification':'pre-and-post-inventory-digest-v1',
  };
Map<String,dynamic> page(List<Map<String,dynamic>> records,{
  String ownerId=owner,
})=> {
    'scope':'reference-practice-all-editions',
    'owner_auth_uid':ownerId,
    'row_count':records.length,
    'rows':records,
  };

class MutableClient implements SupabaseClient {
  final MutableAuth authStub=MutableAuth();
  @override
  GoTrueClient get auth=>authStub;
  @override
  dynamic noSuchMethod(Invocation i)=>throw UnimplementedError();
}
class MutableAuth implements GoTrueClient {
  User? active;
  @override
  User? get currentUser=>active;
  @override
  dynamic noSuchMethod(Invocation i)=>throw UnimplementedError();
}

void main() {
  test('5001 events are fully collected and declared non-atomic but verified',
      () async {
    final client=FakeSupabaseClient(currentUser:user(owner));
    final all=List.generate(5001,(i)=>record(i+1));
    var checks=0;
    var pages=0;
    final service=ExamReferenceVerifiedLargeExportService(
      client:client,
      testInventory:() async {checks++;return inventory(all.length);},
      testPage:(limit,at,id) async {
        pages++;
        final next=id==null?0:int.parse(id.substring(id.length-12));
        final rows=all.skip(next).take(limit).toList();
        expect(limit,lessThanOrEqualTo(250));
        return page(rows);
      },
    );
    final result=await service.loadComplete(expectedOwnerId:owner);
    expect(checks,2);
    expect(pages,21);
    expect(result.events.length,5001);
    expect(result.manifestCount,1);
    expect(result.snapshotConsistency,
        'pre-and-post-inventory-verified-not-atomic');
    final json=jsonDecode(result.toJsonExport()) as Map<String,dynamic>;
    expect(json['record_count'],5001);
    expect(json['complete_within_limit'],true);
    expect(json['snapshot_consistency'],
        'pre-and-post-inventory-verified-not-atomic');
    expect(json.toString(),isNot(contains('step_tokens')));
    expect(json.toString(),isNot(contains('scoring_spec')));
  });

  test('Mid-export grade change with same row count rejects completeness',
      () async {
    final client=FakeSupabaseClient(currentUser:user(owner));
    var checks=0;
    final service=ExamReferenceVerifiedLargeExportService(
      client:client,
      testInventory:() async {
        checks++;
        return inventory(2,digest:checks==1?'a'*32:'b'*32);
      },
      testPage:(limit,at,id) async {
        if(id==null)return page([record(1),record(2)]);
        return page([]);
      },
    );
    await expectLater(service.loadComplete(expectedOwnerId:owner),
      throwsStateError);
    expect(checks,2);
  });

  test('Missing pages, duplicates, wrong order and foreign owners fail closed',
      () async {
    final client=FakeSupabaseClient(currentUser:user(owner));
    for(final invalid in [
      page([record(1)],ownerId:'other'),
      page([record(1),record(1)]),
      page([record(2),record(1)]),
      page([record(1,ownerId:'other'),record(2)]),
      page([record(1)..['step_tokens']='secret',record(2)]),
      {...page([record(1),record(2)]),'row_count':1},
      {...page([record(1),record(2)]),'private_rubric':'secret'},
      page([]),
    ]) {
      final service=ExamReferenceVerifiedLargeExportService(
        client:client,
        testInventory:() async=>inventory(2),
        testPage:(limit,at,id) async=>invalid,
      );
      await expectLater(service.loadComplete(expectedOwnerId:owner),
        throwsFormatException);
    }
  });

  test('Inventories above 50000 are rejected before any page read',() async {
    final client=FakeSupabaseClient(currentUser:user(owner));
    var calls=0;
    final service=ExamReferenceVerifiedLargeExportService(
      client:client,testInventory:() async=>inventory(50001),
      testPage:(l,t,i) async {calls++;return page([]);},
    );
    await expectLater(service.loadComplete(expectedOwnerId:owner),
      throwsFormatException);
    expect(calls,0);
  });

  test('Guest cannot start inventory and switched account discards page',
      () async {
    var calls=0;
    final guestClient=FakeSupabaseClient(currentUser:user('guest',guest:true));
    final guestApi=ExamReferenceVerifiedLargeExportService(
      client:guestClient,
      testInventory:() async {calls++;return inventory(0);},
    );
    await expectLater(guestApi.loadComplete(expectedOwnerId:'guest'),
      throwsStateError);
    expect(calls,0);

    final client=MutableClient()..authStub.active=user(owner);
    final pending=Completer<dynamic>();
    final api=ExamReferenceVerifiedLargeExportService(
      client:client,
      testInventory:() async=>inventory(1),
      testPage:(l,t,i)=>pending.future,
    );
    final future=api.loadComplete(expectedOwnerId:owner);
    await Future<void>.delayed(Duration.zero);
    client.authStub.active=user('owner-b');
    pending.complete(page([record(1)]));
    await expectLater(future,throwsStateError);
  });

  test('Account switching before final digest refuses private export',
      () async {
    final client=MutableClient()..authStub.active=user(owner);
    final finalCheck=Completer<dynamic>();
    var checks=0;
    final api=ExamReferenceVerifiedLargeExportService(
      client:client,
      testInventory:() {
        checks++;
        if(checks==2)return finalCheck.future;
        return Future.value(inventory(1));
      },
      testPage:(l,t,i) async=>page([record(1)]),
    );
    final future=api.loadComplete(expectedOwnerId:owner);
    while(checks<2){await Future<void>.delayed(Duration.zero);}
    client.authStub.active=user('owner-b');
    finalCheck.complete(inventory(1));
    await expectLater(future,throwsStateError);
  });
}
