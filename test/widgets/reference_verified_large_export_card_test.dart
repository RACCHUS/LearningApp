import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_account_export_service.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_progress_service.dart';
import 'package:learning_pwa/services/assessment/exam_reference_verified_large_export_service.dart';
import 'package:learning_pwa/services/assessment/reference_practice_json_download.dart';
import 'package:learning_pwa/widgets/progress/reference_practice_account_export_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../test_helpers/fake_supabase_client.dart';

User user(String id,{bool guest=false})=>User(
  id:id,isAnonymous:guest,
  appMetadata:const {},userMetadata:const {},aud:'authenticated',
  createdAt:'2026-10-21T00:00:00Z',
);
class FakeAuth extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuth(super.initial);
  void change(AuthState state)=>this.state=state;
  @override
  dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
ReferencePracticeAccountExport export(String owner)=>
  ReferencePracticeAccountExport(
    ownerId:owner,generatedAt:DateTime.utc(2027,3,1),
    snapshotConsistency:'pre-and-post-inventory-verified-not-atomic',
    events:[ReferenceDrillEvidence(
      id:'11111111-1111-4111-8111-111111111111',
      ownerId:owner,
      manifestId:'33333333-3333-4333-8333-333333333333',
      attemptId:'22222222-2222-4222-8222-222222222222',
      itemId:'44444444-4444-4444-8444-444444444444',
      bindingId:'55555555-5555-4555-8555-555555555555',
      partKey:'project_management',examDate:'2027-06-01',
      itemRevision:1,answerRevision:1,
      step:'resource_choice',responded:true,
      appElapsedMs:1000,selfReportedBookMs:null,
      startedAt:DateTime.utc(2027,2,28,23,59,55),
      completedAt:DateTime.utc(2027,2,28,23,59,59),
      recordedAt:DateTime.utc(2027,3,1),
      isCorrect:true,scoringVersion:1,
      gradedAt:DateTime.utc(2027,3,1),
    )],
  );
class FakeLarge extends ExamReferenceVerifiedLargeExportService {
  FakeLarge():super(client:FakeSupabaseClient());
  final owners=<String>[];
  bool fail=false;
  Completer<ReferencePracticeAccountExport>? pending;
  @override
  Future<ReferencePracticeAccountExport> loadComplete({
    required String expectedOwnerId,
    void Function(int loaded, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    owners.add(expectedOwnerId);
    if (shouldCancel?.call() == true) {
      throw const ReferencePracticeExportCancelled();
    }
    onProgress?.call(0,1);
    final result = pending != null
        ? await pending!.future
        : fail
            ? throw StateError('changed during export')
            : export(expectedOwnerId);
    if (shouldCancel?.call() == true) {
      throw const ReferencePracticeExportCancelled();
    }
    onProgress?.call(1,1);
    return result;
  }
}
class FakeFileDownload extends ReferencePracticeJsonDownload {
  bool supported = true;
  bool fail = false;
  final files = <({String filename, String json})>[];

  @override
  bool get isSupported => supported;

  @override
  void requestDownload({required String filename, required String json}) {
    throw StateError('Unexpected legacy full-string download');
  }

  @override
  void requestChunkedDownload({
    required String filename,
    required Iterable<String> chunks,
  }) {
    if (fail) throw StateError('Browser denied download');
    files.add((filename: filename, json: chunks.join()));
  }
}

Future<void> mount(WidgetTester tester,FakeAuth auth,FakeLarge large,
    {FakeFileDownload? downloader})=>
  tester.pumpWidget(ProviderScope(
    overrides:[authProvider.overrideWith((ref)=>auth)],
    child:MaterialApp(home:Scaffold(
      body:SingleChildScrollView(
        child:ReferencePracticeAccountExportCard(
          largeExportService:large,fileDownload:downloader),
      ),
    )),
  ));

void main(){
  testWidgets('Guest never offered large-history export',(tester) async {
    final auth=FakeAuth(GuestMode()),large=FakeLarge();
    await mount(tester,auth,large);
    expect(find.byKey(const Key('exm-large-export-load')),findsNothing);
    auth.change(AuthSuccess(user('guest',guest:true)));
    await tester.pump();
    expect(find.byKey(const Key('exm-large-export-load')),findsNothing);
    expect(large.owners,isEmpty);
  });

  testWidgets('Large history prepares only on click and copies after consent',
      (tester) async {
    final auth=FakeAuth(AuthSuccess(user('owner-a')));
    final large=FakeLarge();
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform,(call) async {
        if(call.method=='Clipboard.setData'){
          copied=(call.arguments as Map)['text'] as String?;
        }
        return null;
      });
    addTearDown(()=>TestDefaultBinaryMessengerBinding.instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform,null));
    await mount(tester,auth,large);
    expect(large.owners,isEmpty);
    final button=find.byKey(const Key('exm-large-export-load'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(large.owners,['owner-a']);
    expect(find.textContaining('not a single database transaction'),
      findsOneWidget);
    expect(copied,isNull);
    final copy=find.byKey(const Key('exm-account-export-copy'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied,isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(copied,isNull);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy reference-practice JSON'));
    await tester.pumpAndSettle();
    expect(copied,contains('pre-and-post-inventory-verified-not-atomic'));
    expect(copied,isNot(contains('private_key')));
    expect(copied,isNot(contains('scoring_spec')));
  });

  testWidgets('Stale export cannot enable clipboard copy',(tester) async {
    final auth=FakeAuth(AuthSuccess(user('owner-a')));
    final large=FakeLarge()..fail=true;
    await mount(tester,auth,large);
    await tester.ensureVisible(find.byKey(const Key('exm-large-export-load')));
    await tester.tap(find.byKey(const Key('exm-large-export-load')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-account-export-error')),findsOneWidget);
    expect(find.byKey(const Key('exm-account-export-copy')),findsNothing);
  });

  testWidgets('Account B does not see in-flight A export',(tester) async {
    final auth=FakeAuth(AuthSuccess(user('owner-a')));
    final large=FakeLarge()..pending=Completer<ReferencePracticeAccountExport>();
    await mount(tester,auth,large);
    await tester.ensureVisible(find.byKey(const Key('exm-large-export-load')));
    await tester.tap(find.byKey(const Key('exm-large-export-load')));
    await tester.pump();
    auth.change(AuthSuccess(user('owner-b')));
    await tester.pump();
    large.pending!.complete(export('owner-a'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-account-export-copy')),findsNothing);
    expect(large.owners,['owner-a']);
  });


  testWidgets('Cancelling in-flight large export leaves no prepared file',
      (tester) async {
    final auth=FakeAuth(AuthSuccess(user('owner-a')));
    final large=FakeLarge()..pending=Completer<ReferencePracticeAccountExport>();
    final download=FakeFileDownload();
    await mount(tester,auth,large,downloader:download);
    await tester.ensureVisible(find.byKey(const Key('exm-large-export-load')));
    await tester.tap(find.byKey(const Key('exm-large-export-load')));
    await tester.pump();
    expect(find.byKey(const Key('exm-large-export-progress')),findsOneWidget);
    final cancel=find.byKey(const Key('exm-large-export-cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    expect(find.textContaining('Cancelling after'),findsOneWidget);
    large.pending!.complete(export('owner-a'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Large-history export cancelled.'),findsOneWidget);
    expect(find.byKey(const Key('exm-account-export-download')),findsNothing);
    expect(find.byKey(const Key('exm-account-export-copy')),findsNothing);
    expect(download.files,isEmpty);
  });

  testWidgets('Browser save requires loaded evidence and separate click consent',
      (tester) async {
    final auth=FakeAuth(AuthSuccess(user('owner-a')));
    final large=FakeLarge(),download=FakeFileDownload();
    await mount(tester,auth,large,downloader:download);
    expect(find.byKey(const Key('exm-account-export-download')),findsNothing);
    expect(download.files,isEmpty);

    await tester.ensureVisible(find.byKey(const Key('exm-large-export-load')));
    await tester.tap(find.byKey(const Key('exm-large-export-load')));
    await tester.pumpAndSettle();
    final save=find.byKey(const Key('exm-account-export-download'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Download your reference-practice JSON?'),findsOneWidget);
    expect(download.files,isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(download.files,isEmpty);

    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exm-json-download-confirm')));
    await tester.pumpAndSettle();
    expect(download.files,hasLength(1));
    final file=download.files.single;
    expect(file.filename,startsWith('learningapp-exm-reference-practice-'));
    expect(file.filename,endsWith('Z.json'));
    expect(file.filename,isNot(contains('owner-a')));
    expect(file.json,contains('pre-and-post-inventory-verified-not-atomic'));
    expect(file.json,contains('reference-practice-all-editions'));
    expect(file.json,isNot(contains('scoring_spec')));
    expect(find.textContaining('JSON download requested.'),findsOneWidget);
  });

  testWidgets('File save failure never reports file saved',(tester) async {
    final auth=FakeAuth(AuthSuccess(user('owner-a')));
    final large=FakeLarge(),download=FakeFileDownload()..fail=true;
    await mount(tester,auth,large,downloader:download);
    await tester.ensureVisible(find.byKey(const Key('exm-large-export-load')));
    await tester.tap(find.byKey(const Key('exm-large-export-load')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('exm-account-export-download')));
    await tester.tap(find.byKey(const Key('exm-account-export-download')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exm-json-download-confirm')));
    await tester.pumpAndSettle();
    expect(download.files,isEmpty);
    expect(find.text('Could not request JSON download.'),findsOneWidget);
    expect(find.textContaining('JSON download requested.'),findsNothing);
  });

  testWidgets('Unsupported download leaves clipboard fallback',(tester) async {
    final auth=FakeAuth(AuthSuccess(user('owner-a')));
    final large=FakeLarge(),download=FakeFileDownload()..supported=false;
    await mount(tester,auth,large,downloader:download);
    await tester.ensureVisible(find.byKey(const Key('exm-large-export-load')));
    await tester.tap(find.byKey(const Key('exm-large-export-load')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-account-export-download')),findsNothing);
    expect(find.byKey(const Key('exm-account-export-copy')),findsOneWidget);
    expect(find.textContaining('File download is available in a supported web'),
        findsOneWidget);
  });

  testWidgets('Account switch while save dialog open prevents cross-owner download',
      (tester) async {
    final auth=FakeAuth(AuthSuccess(user('owner-a')));
    final large=FakeLarge(),download=FakeFileDownload();
    await mount(tester,auth,large,downloader:download);
    await tester.ensureVisible(find.byKey(const Key('exm-large-export-load')));
    await tester.tap(find.byKey(const Key('exm-large-export-load')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('exm-account-export-download')));
    await tester.tap(find.byKey(const Key('exm-account-export-download')));
    await tester.pumpAndSettle();
    auth.change(AuthSuccess(user('owner-b')));
    await tester.pump();
    final confirm=find.byKey(const Key('exm-json-download-confirm'));
    if(confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    }
    expect(download.files,isEmpty);
  });

  testWidgets('Failed inventory export cannot enable file download',
      (tester) async {
    final auth=FakeAuth(AuthSuccess(user('owner-a')));
    final large=FakeLarge()..fail=true,download=FakeFileDownload();
    await mount(tester,auth,large,downloader:download);
    await tester.ensureVisible(find.byKey(const Key('exm-large-export-load')));
    await tester.tap(find.byKey(const Key('exm-large-export-load')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-account-export-error')),findsOneWidget);
    expect(find.byKey(const Key('exm-account-export-download')),findsNothing);
    expect(download.files,isEmpty);
  });
}
