import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_combined_practice_portability_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../test_helpers/fake_supabase_client.dart';

User _user(String id, {bool guest=false})=>User(
 id:id,isAnonymous:guest,appMetadata:const {},userMetadata:const {},
 aud:'authenticated',createdAt:'2026-10-21T00:00:00Z',
);

Map<String,dynamic> _inventory({String owner='learner-a',int events=0,
 int grades=0,int assignments=1,int attempts=1})=>{
 'scope':ExamPracticeInventory.scope,'owner_id':owner,
 'reference_events':events,'reference_grades':grades,
 'part_assignments':assignments,'part_attempts':attempts,
 'snapshot_fingerprint':'a'*32,'bound_per_store':5000,
};

Map<String,dynamic> _archive({String owner='learner-a'})=>{
 'format':'learningapp-exm-combined-practice-v1',
 'scope':'educational-practice-history-not-entire-account',
 'owner_id':owner,'generated_at':'2026-10-21T12:00:00Z',
 'snapshot_consistency':'single-stable-rpc-statement',
 'inventory':_inventory(owner:owner),
 'reference_practice':{
   'format':'learningapp-exm-reference-practice-account-v1',
   'scope':'reference-practice-all-editions','owner_auth_uid':owner,
   'record_count':0,'generated_at':'2026-10-21T12:00:00Z',
   'snapshot_consistency':'single-sql-statement','steps':<dynamic>[],
 },
 'part_practice':[{
   'assignment_id':'11111111-1111-4111-8111-111111111111',
   'target_id':'22222222-2222-4222-8222-222222222222',
   'target_version_id':'33333333-3333-4333-8333-333333333333',
   'exam_part_key':'part_a',
   'curriculum_root_node_id':'44444444-4444-4444-8444-444444444444',
   'manifest_revision_id':'55555555-5555-4555-8555-555555555555',
   'practice_kind':'diagnostic',
   'issued_at':'2026-10-21T11:00:00Z',
   'expires_at':'2026-10-21T12:30:00Z',
   'attempt':{
     'attempt_id':'66666666-6666-4666-8666-666666666666',
     'completed_at':'2026-10-21T11:30:00Z',
     'question_count':6,'fully_correct_count':4,'partial_count':0,
     'practice_score':0.666667,
     'question_edition_fingerprint':'b'*64,'official_exam_result':false,
   }
 }],
 'includes_unsubmitted_assignments':true,'official_exam_result':false,
};

Map<String,dynamic> _receipt()=> {
 'scope':ExamPracticeInventory.scope,'owner_id':'learner-a',
 'deleted_reference_events':0,'deleted_part_assignments':1,
 'remaining_reference_events':0,'remaining_reference_grades':0,
 'remaining_part_assignments':0,'remaining_part_attempts':0,
 'irreversible':true,
};

class _MutableClient implements SupabaseClient {
 final _MutableAuth active=_MutableAuth();
 @override GoTrueClient get auth=>active;
 @override dynamic noSuchMethod(Invocation i)=>throw UnimplementedError();
}
class _MutableAuth implements GoTrueClient {
 User? user;
 @override User? get currentUser=>user;
 @override dynamic noSuchMethod(Invocation i)=>throw UnimplementedError();
}

void main(){
 test('Strict inventory and fully-scoped archival JSON',() async {
   final s=ExamCombinedPracticePortabilityService(
     client:FakeSupabaseClient(currentUser:_user('learner-a')),
     testInventory:() async=>_inventory(),testExport:() async=>_archive());
   final pre=await s.inventory(expectedOwnerId:'learner-a');
   expect(pre.assignments,1); expect(pre.attempts,1);
   final output=await s.export(expectedOwnerId:'learner-a');
   final decoded=jsonDecode(output.toJson()) as Map<String,dynamic>;
   expect((decoded['part_practice'] as List).length,1);
   expect(output.toJson(),isNot(contains('scoring_spec')));
   expect(output.toJson(),isNot(contains('response_sha256')));
   expect(output.toJson(),isNot(contains('issued_session_id')));
   expect(output.toJson(),isNot(contains('assigned_items')));
 });
 test('Delete is explicit, preview-bound and never automatic',() async {
   var calls=0;
   final s=ExamCombinedPracticePortabilityService(
     client:FakeSupabaseClient(currentUser:_user('learner-a')),
     testInventory:() async=>_inventory(),
     testErase:(events,assignments,attempts,digest,phrase) async {
       calls++;
       expect([events,assignments,attempts],[0,1,1]);
       expect(digest,'a'*32);expect(phrase,'DELETE ALL EXAM PRACTICE');
       return _receipt();
     });
   final preview=await s.inventory(expectedOwnerId:'learner-a');
   expect(calls,0);
   await expectLater(s.erase(expectedOwnerId:'learner-a',preview:preview,
     exactConfirmation:'delete all exam practice'),throwsStateError);
   expect(calls,0);
   await s.erase(expectedOwnerId:'learner-a',preview:preview,
     exactConfirmation:'DELETE ALL EXAM PRACTICE');
   expect(calls,1);
 });
 test('Guests and wrong owner cannot read or erase',() async {
   var calls=0;
   final s=ExamCombinedPracticePortabilityService(
      client:FakeSupabaseClient(currentUser:_user('guest',guest:true)),
      testInventory:() async{calls++;return _inventory();},
      testExport:() async{calls++;return _archive();},
      testErase:(a,b,c,d,e) async{calls++;return _receipt();});
   await expectLater(s.inventory(expectedOwnerId:'guest'),throwsStateError);
   await expectLater(s.export(expectedOwnerId:'learner-a'),throwsStateError);
   await expectLater(s.erase(expectedOwnerId:'guest',
       preview:ExamPracticeInventory.parse(_inventory(),'learner-a'),
       exactConfirmation:'DELETE ALL EXAM PRACTICE'),throwsStateError);
   expect(calls,0);
 });
 test('Account switch during export invalidates response',() async {
   final client=_MutableClient()..active.user=_user('learner-a');
   final completer=Completer<dynamic>();
   final s=ExamCombinedPracticePortabilityService(
       client:client,testExport:()=>completer.future);
   final future=s.export(expectedOwnerId:'learner-a');
   client.active.user=_user('learner-b');
   completer.complete(_archive());
   await expectLater(future,throwsStateError);
 });
 test('Account switch during deletion invalidates receipt',() async {
   final client=_MutableClient()..active.user=_user('learner-a');
   final completer=Completer<dynamic>();
   final s=ExamCombinedPracticePortabilityService(
       client:client,testErase:(a,b,c,d,e)=>completer.future);
   final future=s.erase(expectedOwnerId:'learner-a',
       preview:ExamPracticeInventory.parse(_inventory(),'learner-a'),
       exactConfirmation:'DELETE ALL EXAM PRACTICE');
   client.active.user=_user('learner-b');
   completer.complete(_receipt());
   await expectLater(future,throwsStateError);
 });
 test('Rejects forged, oversized and incomplete inventory or export',() async {
   for(final p in [
     _inventory(owner:'learner-b'),
     _inventory(grades:1),
     _inventory(assignments:0,attempts:1),
     _inventory(events:5001),
     _inventory()..['private_scoring_key']='leak',
     _inventory()..['snapshot_fingerprint']='wrong',
   ]){
     expect(()=>ExamPracticeInventory.parse(p,'learner-a'),
         throwsFormatException);
   }
   for(final p in [
     _archive(owner:'learner-b'),
     _archive()..['scoring_spec']='secret',
     _archive()..['inventory']=_inventory(assignments:2),
     _archive()..['part_practice']=<dynamic>[],
     _archive()..['part_practice']=[
       {...Map<String,dynamic>.from((_archive()['part_practice'] as List).first as Map),
         'assigned_items':['secret']}
     ],
   ]){
     expect(()=>ExamPracticeArchive.parse(p,'learner-a'),
         throwsFormatException);
   }
 });
 test('Rejects tampered deletion receipt',() async {
   final client=FakeSupabaseClient(currentUser:_user('learner-a'));
   final preview=ExamPracticeInventory.parse(_inventory(),'learner-a');
   for(final p in [
     _receipt()..['owner_id']='other',
     _receipt()..['deleted_part_assignments']=0,
     _receipt()..['remaining_part_attempts']=1,
     _receipt()..['response_sha256']='leak',
   ]){
     final s=ExamCombinedPracticePortabilityService(
       client:client,testErase:(a,b,c,d,e) async=>p);
     await expectLater(s.erase(expectedOwnerId:'learner-a',
       preview:preview,exactConfirmation:'DELETE ALL EXAM PRACTICE'),
       throwsFormatException);
   }
 });

 test('50k per-store bound accepts 5001, rejects 50001',() {
   final large=_inventory(assignments:5001,attempts:0)
     ..['bound_per_store']=50000;
   expect(ExamPracticeInventory.parse(large,'learner-a').assignments,5001);
   final tooLarge=_inventory(assignments:50001,attempts:0)
     ..['bound_per_store']=50000;
   expect(()=>ExamPracticeInventory.parse(tooLarge,'learner-a'),
     throwsFormatException);
 });

 test('5011 private assignments are paged and verified before archive release',
     () async {
   const count=5011;
   final template=Map<String,dynamic>.from(
     (_archive()['part_practice'] as List).first as Map);
   final rows=List<Map<String,dynamic>>.generate(count,(i)=>{
     ...template,
     'assignment_id':'${(0xe5000000).toRadixString(16)}-0000-4000-8000-${i.toString().padLeft(12,'0')}',
     'issued_at':DateTime.utc(2026,10,23)
       .subtract(Duration(seconds:i)).toIso8601String(),
     'attempt':null,
   });
   final inventory=_inventory(assignments:count,attempts:0)
     ..['bound_per_store']=50000;
   int reads=0, pages=0, progressed=0;
   final service=ExamCombinedPracticePortabilityService(
     client:FakeSupabaseClient(currentUser:_user('learner-a')),
     testInventory:() async {reads++;return inventory;},
     testPartPage:(limit,at,id) async {
       pages++;
       final begin=id==null?0:
         rows.indexWhere((row)=>row['assignment_id']==id)+1;
       if(begin<0||begin>count)throw StateError('Invalid cursor');
       final page=rows.skip(begin).take(limit).toList();
       return {
         'scope':ExamPracticeInventory.scope,'owner_id':'learner-a',
         'row_count':page.length,'rows':page,
       };
     },
     testReferencePage:(limit,at,id) async =>
       throw StateError('No saved R1-R4 history expected'),
   );
   final archive=await service.export(expectedOwnerId:'learner-a',
      onProgress:(loaded,total){expect(total,count);progressed=loaded;});
   expect(archive.inventory.assignments,count);
   expect((jsonDecode(archive.toJson())['part_practice'] as List).length,count);
   expect(reads,2);
   expect(pages,21);
   expect(progressed,count);
   expect(archive.toJson(),isNot(contains('assigned_items')));
   expect(archive.toJson(),isNot(contains('issued_session_id')));
 });

 test('Paged export drops all rows when postflight digest changes',() async {
   final inventory=_inventory(assignments:1,attempts:1)
     ..['bound_per_store']=50000;
   var reads=0;
   final service=ExamCombinedPracticePortabilityService(
     client:FakeSupabaseClient(currentUser:_user('learner-a')),
     forcePagedForTests:true,
     testInventory:() async {
       reads++;
       return {...inventory,
         'snapshot_fingerprint':reads==1?'a'*32:'b'*32};
     },
     testPartPage:(limit,at,id) async => {
       'scope':ExamPracticeInventory.scope,'owner_id':'learner-a',
       'row_count':1,'rows':_archive()['part_practice'],
     },
   );
   await expectLater(service.export(expectedOwnerId:'learner-a'),
     throwsStateError);
   expect(reads,2);
 });

 test('Paged export respects cancellation with no completed archive',() async {
   final inventory=_inventory(assignments:1,attempts:1)
     ..['bound_per_store']=50000;
   var pages=0;
   final service=ExamCombinedPracticePortabilityService(
     client:FakeSupabaseClient(currentUser:_user('learner-a')),
     forcePagedForTests:true,
     testInventory:() async =>inventory,
     testPartPage:(limit,at,id) async {
       pages++;
       return {
         'scope':ExamPracticeInventory.scope,'owner_id':'learner-a',
         'row_count':1,'rows':_archive()['part_practice'],
       };
     },
   );
   var cancelled=false;
   await expectLater(service.export(expectedOwnerId:'learner-a',
     shouldCancel:()=>cancelled,
     onProgress:(loaded,total){cancelled=true;}),
     throwsStateError);
   expect(pages,1);
 });
}
