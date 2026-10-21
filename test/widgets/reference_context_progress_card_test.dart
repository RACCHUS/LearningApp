import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/assessment/exam_reference_context_progress_service.dart';
import 'package:learning_pwa/widgets/progress/reference_context_progress_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../test_helpers/fake_supabase_client.dart';

const targetVersion='b3000000-0000-4000-8000-000000000012';
const manifest='b3000000-0000-4000-8000-000000000016';

User _user(String id, {bool guest=false})=>User(
  id:id,isAnonymous:guest,
  appMetadata:const {},userMetadata:const {},aud:'authenticated',
  createdAt:'2026-10-21T00:00:00Z',
);
LearningContext _context(String user, {
  ContextRootType root=ContextRootType.target,
})=>LearningContext(
  id:'context-1',userId:user,rootType:root,
  rootId:'some-exam-goal',targetVersionId:targetVersion,
  label:'Reviewed exam preparation',
  lastActiveAt:DateTime.utc(2026,10,21),
);
class _TestAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _TestAuth(super.initial);
  void become(AuthState state) => this.state=state;
  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

class _FakeContextService extends ExamReferenceContextProgressService {
  _FakeContextService():super(client:FakeSupabaseClient());
  final requests=<String>[];
  final pending=<String,Completer<ReferenceContextProgress>>{};
  @override
  Future<ReferenceContextProgress> load({
    required String expectedOwnerId,
    required String targetVersionId,
  }) {
    requests.add('$expectedOwnerId:$targetVersionId');
    final ongoing=pending[expectedOwnerId];
    if(ongoing!=null) return ongoing.future;
    return Future.value(ReferenceContextProgress(
      ownerId:expectedOwnerId,targetVersionId:targetVersionId,
      editions:expectedOwnerId=='account-a'
          ? [ReferenceContextEdition(
              manifestId:manifest,partKey:'project_management',revision:2,
              steps:{
                'resource_choice':ReferenceContextSkillCount(
                  step:'resource_choice',recorded:4,correct:2,incorrect:1,
                  awaiting:1,skipped:0,
                  lastRecordedAt:DateTime.utc(2027,3,1),
                ),
              },
            )] : [],
    ));
  }
}

Future<void> _mount(
  WidgetTester tester,_TestAuth auth,_FakeContextService service,
  LearningContext selected,
) =>tester.pumpWidget(ProviderScope(
  overrides:[authProvider.overrideWith((ref)=>auth)],
  child:MaterialApp(home:Scaffold(
    body:SingleChildScrollView(
      child:ReferenceContextProgressCard(
        activeContext:selected,service:service,
      ),
    ),
  )),
));

void main(){
  testWidgets('Guest or mismatched context never fetches other account data',
      (tester) async {
    final auth=_TestAuth(GuestMode());
    final service=_FakeContextService();
    await _mount(tester,auth,service,_context('account-a'));
    expect(find.byKey(const Key('exam-context-progress')),findsNothing);
    auth.become(AuthSuccess(_user('guest',guest:true)));
    await tester.pump();
    expect(find.byKey(const Key('exam-context-progress')),findsNothing);
    auth.become(AuthSuccess(_user('account-b')));
    await tester.pump();
    expect(find.byKey(const Key('exam-context-progress')),findsNothing);
    expect(service.requests,isEmpty);
  });

  testWidgets('Only target contexts carry exam evidence, not generic mastery',
      (tester) async {
    final auth=_TestAuth(AuthSuccess(_user('account-a')));
    final service=_FakeContextService();
    await _mount(tester,auth,service,
      _context('account-a',root:ContextRootType.course));
    expect(find.byKey(const Key('exam-context-progress')),findsNothing);
    expect(service.requests,isEmpty);
  });

  testWidgets('Progress is explicit and shows exact edition R1 data',
      (tester) async {
    final auth=_TestAuth(AuthSuccess(_user('account-a')));
    final service=_FakeContextService();
    await _mount(tester,auth,service,_context('account-a'));
    expect(service.requests,isEmpty);
    expect(find.text('Load exam practice evidence'),findsOneWidget);
    await tester.tap(find.text('Load exam practice evidence'));
    await tester.pumpAndSettle();
    expect(service.requests,['account-a:$targetVersion']);
    expect(find.byKey(Key('exam-context-edition:$manifest')),findsOneWidget);
    expect(find.byKey(Key('exam-context-skill:$manifest:resource_choice')),
      findsOneWidget);
    expect(find.textContaining('2 correct, 1 incorrect'),findsWidgets);
    expect(find.textContaining('not licensing-exam scores'),findsOneWidget);
    expect(find.textContaining('Separate from concept mastery'),findsOneWidget);
  });

  testWidgets('A delayed A response cannot show on switched B account',
      (tester) async {
    final auth=_TestAuth(AuthSuccess(_user('account-a')));
    final service=_FakeContextService();
    service.pending['account-a']=Completer<ReferenceContextProgress>();
    await _mount(tester,auth,service,_context('account-a'));
    await tester.tap(find.text('Load exam practice evidence'));
    await tester.pump();
    auth.become(AuthSuccess(_user('account-b')));
    await tester.pump();
    service.pending['account-a']!.complete(ReferenceContextProgress(
      ownerId:'account-a',targetVersionId:targetVersion,
      editions:[ReferenceContextEdition(
        manifestId:manifest,partKey:'project_management',
        revision:1,steps:{},
      )],
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('exam-context-edition:$manifest')),findsNothing);
    expect(service.requests,['account-a:$targetVersion']);
  });

  testWidgets('No published edition evidence is reported as empty',
      (tester) async {
    final auth=_TestAuth(AuthSuccess(_user('account-b')));
    final service=_FakeContextService();
    await _mount(tester,auth,service,_context('account-b'));
    await tester.tap(find.text('Load exam practice evidence'));
    await tester.pumpAndSettle();
    expect(find.text('No saved reference practice for this target version.'),
      findsOneWidget);
    expect(find.textContaining('0 correct'),findsNothing);
  });
}
