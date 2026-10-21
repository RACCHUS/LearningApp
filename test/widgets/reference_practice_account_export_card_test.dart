import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_account_export_service.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_progress_service.dart';
import 'package:learning_pwa/widgets/progress/reference_practice_account_export_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../test_helpers/fake_supabase_client.dart';

User _user(String id, {bool guest=false})=>User(
  id:id,isAnonymous:guest,appMetadata:const {},userMetadata:const {},
  aud:'authenticated',createdAt:'2026-10-21T00:00:00Z',
);

class _FakeAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuth(super.initial);
  void become(AuthState state)=>this.state=state;
  @override
  dynamic noSuchMethod(Invocation call)=>super.noSuchMethod(call);
}

ReferencePracticeAccountExport _export(String owner)=>ReferencePracticeAccountExport(
  ownerId:owner,generatedAt:DateTime.utc(2027,3,1),
  events:[
    ReferenceDrillEvidence(
      id:'11111111-1111-4111-8111-111111111111',
      ownerId:owner,
      manifestId:'33333333-3333-4333-8333-333333333333',
      attemptId:'22222222-2222-4222-8222-222222222222',
      itemId:'44444444-4444-4444-8444-444444444444',
      bindingId:'55555555-5555-4555-8555-555555555555',
      partKey:'project_management',examDate:'2027-06-01',
      itemRevision:1,answerRevision:1,
      step:'resource_choice',responded:true,appElapsedMs:1200,
      selfReportedBookMs:null,
      startedAt:DateTime.utc(2027,2,28,23,59,56),
      completedAt:DateTime.utc(2027,2,28,23,59,58),
      recordedAt:DateTime.utc(2027,3,1),
      isCorrect:true,scoringVersion:1,
      gradedAt:DateTime.utc(2027,3,1),
    ),
  ],
);

class _FakeService extends ExamReferenceDrillAccountExportService {
  _FakeService():super(client:FakeSupabaseClient());
  final requested=<String>[];
  Completer<ReferencePracticeAccountExport>? pending;
  bool fail=false;
  @override
  Future<ReferencePracticeAccountExport> load({
    required String expectedOwnerId,int maxRecords=5000,
  }) async {
    requested.add(expectedOwnerId);
    if (pending!=null) return pending!.future;
    if (fail) throw StateError('unavailable');
    return _export(expectedOwnerId);
  }
}

Future<void> _mount(WidgetTester tester,_FakeAuth auth,_FakeService service)=>
  tester.pumpWidget(ProviderScope(
    overrides:[authProvider.overrideWith((ref)=>auth)],
    child:MaterialApp(home:Scaffold(
      body:SingleChildScrollView(
        child:ReferencePracticeAccountExportCard(exportService:service),
      ),
    )),
  ));

void main() {
  testWidgets('Guest is not offered account export', (tester) async {
    final auth=_FakeAuth(GuestMode());
    final service=_FakeService();
    await _mount(tester,auth,service);
    expect(find.byKey(const Key('exm-account-export-card')),findsNothing);
    auth.become(AuthSuccess(_user('guest',guest:true)));
    await tester.pump();
    expect(find.byKey(const Key('exm-account-export-card')),findsNothing);
    expect(service.requested,isEmpty);
  });

  testWidgets('Load and copy are two separate opt-in actions', (tester) async {
    final auth=_FakeAuth(AuthSuccess(_user('account-a')));
    final service=_FakeService();
    String? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform,(call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard=(call.arguments as Map)['text'] as String?;
        }
        return null;
      });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform,null));

    await _mount(tester,auth,service);
    expect(service.requested,isEmpty);
    await tester.tap(find.text('Prepare all reference-practice data'));
    await tester.pumpAndSettle();
    expect(service.requested,['account-a']);
    expect(find.textContaining('1 saved steps across'),findsOneWidget);
    expect(clipboard,isNull);
    await tester.ensureVisible(find.byKey(
      const Key('exm-account-export-copy')));
    await tester.tap(find.byKey(const Key('exm-account-export-copy')));
    await tester.pumpAndSettle();
    expect(find.text('Copy all saved reference-practice evidence?'),findsOneWidget);
    expect(clipboard,isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(clipboard,isNull);

    await tester.tap(find.byKey(const Key('exm-account-export-copy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy reference-practice JSON'));
    await tester.pumpAndSettle();
    expect(clipboard,contains('reference-practice-all-editions'));
    expect(clipboard,contains('not a whole LearningApp account archive'));
    expect(clipboard, isNot(contains('step_tokens')));
    expect(clipboard, isNot(contains('scoring_spec')));
  });

  testWidgets('In-flight owner A export never appears after switching to B',
      (tester) async {
    final auth=_FakeAuth(AuthSuccess(_user('account-a')));
    final service=_FakeService();
    service.pending=Completer<ReferencePracticeAccountExport>();
    await _mount(tester,auth,service);
    await tester.tap(find.text('Prepare all reference-practice data'));
    await tester.pump();
    auth.become(AuthSuccess(_user('account-b')));
    await tester.pump();
    service.pending!.complete(_export('account-a'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-account-export-copy')),findsNothing);
    expect(find.text('Prepare all reference-practice data'),findsOneWidget);
    expect(service.requested,['account-a']);
  });

  testWidgets('Failed server read cannot copy a partial export',
      (tester) async {
    final auth=_FakeAuth(AuthSuccess(_user('account-a')));
    final service=_FakeService()..fail=true;
    await _mount(tester,auth,service);
    await tester.tap(find.text('Prepare all reference-practice data'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-account-export-error')),findsOneWidget);
    expect(find.byKey(const Key('exm-account-export-copy')),findsNothing);
  });
}
