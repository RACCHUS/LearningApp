import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_progress_service.dart';
import 'package:learning_pwa/widgets/targets/reference_drill_progress_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../test_helpers/fake_supabase_client.dart';

const manifest = '33333333-3333-4333-8333-333333333333';

User user(String id, {bool guest = false}) => User(
  id: id, isAnonymous: guest, appMetadata: const {},
  userMetadata: const {}, aud: 'authenticated',
  createdAt: '2026-10-20T00:00:00Z',
);

class _AuthForTest extends StateNotifier<AuthState> implements AuthNotifier {
  _AuthForTest(super.initial);
  void switchTo(AuthState state) => this.state = state;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReferenceDrillEvidence evidence(String step, {bool? correct, bool responded=true}) {
  final at=DateTime.utc(2027,3,1,12);
  return ReferenceDrillEvidence(
    id:'event-$step',ownerId:'account-a',manifestId:manifest,
    attemptId:'attempt-a',itemId:'item-a',bindingId:'binding-a',
    partKey:'project_management',examDate:'2027-06-01',
    itemRevision:1,answerRevision:2,step:step,
    responded:responded,appElapsedMs:1000,selfReportedBookMs:null,
    startedAt:at.subtract(const Duration(seconds:2)),
    completedAt:at.subtract(const Duration(seconds:1)),
    recordedAt:at,isCorrect:correct,
    scoringVersion:correct == null ? null : 1,
    gradedAt:correct == null ? null : at,
  );
}

class _FakeProgress extends ExamReferenceDrillProgressService {
  _FakeProgress():super(client:FakeSupabaseClient());
  final requests=<String>[];
  final pending=<String,Completer<ReferenceDrillProgressSnapshot>>{};
  @override
  Future<ReferenceDrillProgressSnapshot> loadComplete({
    required String expectedOwnerId,
    required String manifestRevisionId,
    int maxRecords=5000,
  }) {
    requests.add('$expectedOwnerId:$manifestRevisionId');
    if(pending[expectedOwnerId]!=null) return pending[expectedOwnerId]!.future;
    return Future.value(ReferenceDrillProgressSnapshot(
      ownerId:expectedOwnerId,manifestId:manifestRevisionId,
      events:expectedOwnerId=='account-a' ? [
        evidence('resource_choice',correct:true),
        evidence('section_location',responded:false),
        evidence('interpretation'),
      ]:[],
    ));
  }
}

Future<void> mount(
  WidgetTester tester,_AuthForTest auth,_FakeProgress service
) => tester.pumpWidget(ProviderScope(
  overrides:[authProvider.overrideWith((ref)=>auth)],
  child:MaterialApp(home:Scaffold(
    body:SingleChildScrollView(child:ReferenceDrillProgressCard(
      manifestRevisionId:manifest, progressService:service,
    )),
  )),
));

void main() {
  testWidgets('Guest cannot load or copy private progress', (tester) async {
    final auth=_AuthForTest(GuestMode());
    final service=_FakeProgress();
    await mount(tester,auth,service);
    expect(find.byKey(const Key('reference-drill-progress')),findsNothing);
    auth.switchTo(AuthSuccess(user('guest',guest:true)));
    await tester.pump();
    expect(find.byKey(const Key('reference-drill-progress')),findsNothing);
    expect(service.requests,isEmpty);
  });

  testWidgets('Shows server checked responses separately from ungraded',
      (tester) async {
    final auth=_AuthForTest(AuthSuccess(user('account-a')));
    final service=_FakeProgress();
    await mount(tester,auth,service);
    expect(service.requests,isEmpty);
    await tester.tap(find.text('Load private progress'));
    await tester.pumpAndSettle();
    expect(service.requests,['account-a:$manifest']);
    expect(find.text('3 saved step observation(s)'),findsOneWidget);
    expect(find.textContaining('1 correct, 0 incorrect'),findsOneWidget);
    expect(find.textContaining('1 awaiting score'),findsOneWidget);
    expect(find.textContaining('1 skipped'),findsOneWidget);
    expect(find.textContaining('Not an official score'),findsOneWidget);

    await tester.ensureVisible(find.byKey(
      const Key('reference-progress-export-json')));
    await tester.tap(find.byKey(const Key('reference-progress-export-json')));
    await tester.pumpAndSettle();
    expect(find.text('Copy private practice data?'),findsOneWidget);
    expect(find.textContaining('Clipboard content can'),findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Copy private practice data?'),findsNothing);
  });

  testWidgets('Delayed owner A results cannot populate account B', (tester) async {
    final auth=_AuthForTest(AuthSuccess(user('account-a')));
    final service=_FakeProgress();
    service.pending['account-a']=Completer<ReferenceDrillProgressSnapshot>();
    await mount(tester,auth,service);
    await tester.tap(find.text('Load private progress'));
    await tester.pump();
    auth.switchTo(AuthSuccess(user('account-b')));
    await tester.pump();
    service.pending['account-a']!.complete(ReferenceDrillProgressSnapshot(
      ownerId:'account-a',manifestId:manifest,
      events:[evidence('resource_choice',correct:true)],
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 correct'),findsNothing);
    expect(find.text('Load private progress'),findsOneWidget);
    await tester.tap(find.text('Load private progress'));
    await tester.pumpAndSettle();
    expect(find.text('0 saved step observation(s)'),findsOneWidget);
    expect(service.requests,['account-a:$manifest','account-b:$manifest']);
  });
}
