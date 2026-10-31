import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/screens/assessment/secure_exam_part_practice_screen.dart';
import 'package:learning_pwa/services/assessment/exam_assigned_practice_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../test_helpers/fake_supabase_client.dart';

const ownerA='b6110000-0000-4000-8000-000000000001';
const ownerB='b6110000-0000-4000-8000-000000000002';
const session='b6120000-0000-4000-8000-000000000001';
const target='b6130000-0000-4000-8000-000000000001';
const assignment='b6140000-0000-4000-8000-000000000001';
String _id(int i)=>'b6150000-0000-4000-8000-${i.toString().padLeft(12,'0')}';

User _user(String id)=>User(id:id,appMetadata:const {},userMetadata:const {},
 aud:'authenticated',isAnonymous:false,createdAt:'2026-10-23T00:00:00Z');

Map<String,dynamic> _issued()=>{
 'assignment_id':assignment,'target_version_id':target,'exam_part_key':'part_a',
 'administration_date':'2027-04-15',
 'expires_at':'2099-01-01T00:00:00Z','practice_only':true,
 'question_count':6,
 'questions':[
   for(var i=1;i<=6;i++)
     {'id':_id(i),'interaction_type':'single_choice',
      'prompt':'Reviewed synthetic prompt $i',
      'response_spec':{'options':['Option A','Option B']}},
 ],
};
Map<String,dynamic> _score()=>{
 'attempt_id':'b6160000-0000-4000-8000-000000000001',
 'target_version_id':target,'exam_part_key':'part_a',
 'question_count':6,'fully_correct_count':4,'partial_count':0,
 'practice_score':0.666667,'already_recorded':false,
 'official_exam_result':false,
};
class _AuthController extends StateNotifier<AuthState> implements AuthNotifier {
 _AuthController(AuthState initial):super(initial);
 void switchTo(AuthState next)=>state=next;
 @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

void main(){
 testWidgets('protected practice shows server questions and canonical score only',
     (tester)async {
   final auth=_AuthController(AuthSuccess(_user(ownerA)));
   final client=FakeSupabaseClient(currentUser:_user(ownerA));
   var issuedRequests=0, scoringRequests=0;
   final service=ExamAssignedPracticeService(
     client:client,testSessionId:()=>session,
     testIssue:(v,p,d) async {
       issuedRequests++;
       expect([v,p,d],[target,'part_a','2027-04-15']);
       return _issued();
     },
     testSubmit:(id,answers) async {
       scoringRequests++;
       expect(id,assignment);
       expect(answers.length,6);
       expect(answers.values,everyElement(0));
       return _score();
     },
   );
   await tester.pumpWidget(ProviderScope(
     overrides:[authProvider.overrideWith((ref)=>auth)],
     child:MaterialApp(home:SecureExamPartPracticeScreen(
       targetVersionId:target,examPartKey:'part_a',administrationDate:DateTime.utc(2027,4,15),service:service,
     )),
   ));
   await tester.pumpAndSettle();
   expect(find.text('Reviewed synthetic prompt 1'),findsOneWidget);
   expect(find.textContaining('correct_index'),findsNothing);
   expect(issuedRequests,1);
   for(var i=1;i<=6;i++){
     await tester.tap(find.byKey(const Key('secure-exm-part-choice-0')));
     await tester.pumpAndSettle();
     if(i<6){
       await tester.tap(find.byKey(const Key('secure-exm-part-next')));
       await tester.pumpAndSettle();
     }
   }
   await tester.tap(find.byKey(const Key('secure-exm-part-submit')));
   await tester.pumpAndSettle();
   expect(find.text('Verified educational practice score: 4 of 6'),
     findsOneWidget);
   expect(find.textContaining('not an official exam'),findsWidgets);
   expect(scoringRequests,1);
 });

 testWidgets('account switch discards an in-flight original question response',
     (tester)async {
   final auth=_AuthController(AuthSuccess(_user(ownerA)));
   final client=FakeSupabaseClient(currentUser:_user(ownerA));
   final gate=Completer<dynamic>();
   final service=ExamAssignedPracticeService(
     client:client,testSessionId:()=>session,
     testIssue:(v,p,d)=>gate.future,
     testSubmit:(id,answer) async=>_score(),
   );
   await tester.pumpWidget(ProviderScope(
     overrides:[authProvider.overrideWith((ref)=>auth)],
     child:MaterialApp(home:SecureExamPartPracticeScreen(
       targetVersionId:target,examPartKey:'part_a',administrationDate:DateTime.utc(2027,4,15),service:service,
     )),
   ));
   await tester.pump();
   auth.switchTo(AuthInitial());
   await tester.pumpAndSettle();
   gate.complete(_issued());
   await tester.pumpAndSettle();
   expect(find.text('Reviewed synthetic prompt 1'),findsNothing);
   expect(find.textContaining('Sign in with a permanent account'),
     findsOneWidget);
 });
}
