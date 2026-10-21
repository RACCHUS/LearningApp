import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/assessment/exam_reference_practice_batch_erasure_service.dart';
import 'package:learning_pwa/widgets/progress/reference_practice_batch_erasure_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../test_helpers/fake_supabase_client.dart';

User user(String id,{bool guest=false})=>User(
  id:id,isAnonymous:guest,appMetadata:const {},userMetadata:const {},
  aud:'authenticated',createdAt:'2026-10-21T00:00:00Z',
);
class _FakeAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuth(super.initial);
  void change(AuthState next)=>state=next;
  @override
  dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}

class _FakeBatches extends ExamReferencePracticeBatchErasureService {
  _FakeBatches():super(client:FakeSupabaseClient());
  final owners=<String>[];
  int deletions=0;
  bool fail=false;
  Completer<ReferencePracticeBatchPreview>? pending;
  @override
  Future<ReferencePracticeBatchPreview> preview({
    required String expectedOwnerId,int limit=1000,
  }) {
    owners.add(expectedOwnerId);
    if(pending!=null)return pending!.future;
    return Future.value(ReferencePracticeBatchPreview(
      ownerId:expectedOwnerId,totalEvents:5001,batchEvents:1000,
      batchGrades:1,batchEditions:2,limit:1000,fingerprint:'a'*32,
    ));
  }
  @override
  Future<ReferencePracticeBatchReceipt> deleteOneBatch({
    required String expectedOwnerId,
    required ReferencePracticeBatchPreview preview,
    required String exactConfirmation,
  }) async {
    deletions++;
    expect(preview.batchEvents,1000);
    expect(exactConfirmation,'DELETE NEXT BATCH');
    if(fail)throw StateError('stale or network failure');
    return const ReferencePracticeBatchReceipt(
      deleted:1000,remaining:4001,
    );
  }
}

Future<void> mount(WidgetTester tester,_FakeAuth auth,_FakeBatches service)=>
 tester.pumpWidget(ProviderScope(
   overrides:[authProvider.overrideWith((ref)=>auth)],
   child:MaterialApp(home:Scaffold(
     body:SingleChildScrollView(
       child:ReferencePracticeBatchErasureCard(service:service),
     ),
   )),
 ));

void main() {
  testWidgets('Guests never see batch controls',(tester) async {
    final auth=_FakeAuth(GuestMode());
    final api=_FakeBatches();
    await mount(tester,auth,api);
    expect(find.byKey(const Key('exm-batch-erasure-card')),findsNothing);
    auth.change(AuthSuccess(user('guest',guest:true)));
    await tester.pump();
    expect(find.byKey(const Key('exm-batch-erasure-card')),findsNothing);
    expect(api.owners,isEmpty);
  });

  testWidgets('Every bounded batch requires preview, phrase and second consent',
      (tester) async {
    final auth=_FakeAuth(AuthSuccess(user('owner-a')));
    final api=_FakeBatches();
    await mount(tester,auth,api);
    expect(api.owners,isEmpty);
    expect(find.byKey(const Key('exm-batch-delete')),findsNothing);
    await tester.tap(find.text('Preview next EXM batch'));
    await tester.pumpAndSettle();
    expect(api.owners,['owner-a']);
    expect(find.textContaining('5001 total saved steps'),findsOneWidget);
    final delete=find.byKey(const Key('exm-batch-delete'));
    expect(tester.widget<OutlinedButton>(delete).onPressed,isNull);
    await tester.enterText(find.byKey(const Key('exm-batch-confirmation')),
      'delete next batch');
    await tester.pump();
    expect(tester.widget<OutlinedButton>(delete).onPressed,isNull);
    await tester.enterText(find.byKey(const Key('exm-batch-confirmation')),
      'DELETE NEXT BATCH');
    await tester.pump();
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('Delete this practice batch?'),findsOneWidget);
    expect(api.deletions,0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.deletions,0);

    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete this batch permanently'));
    await tester.pumpAndSettle();
    expect(api.deletions,1);
    expect(find.byKey(const Key('exm-batch-result')),findsOneWidget);
    expect(find.textContaining('4001 remaining at confirmation'),findsOneWidget);
    expect(delete,findsNothing);
    // A second batch NEVER starts automatically.
    expect(api.owners,['owner-a']);
    await tester.tap(find.text('Preview next EXM batch'));
    await tester.pumpAndSettle();
    expect(api.owners,['owner-a','owner-a']);
    expect(api.deletions,1);
    expect(tester.widget<OutlinedButton>(delete).onPressed,isNull);
  });

  testWidgets('Stale batch clears confirmation and requires new inventory',
      (tester) async {
    final auth=_FakeAuth(AuthSuccess(user('owner-a')));
    final api=_FakeBatches()..fail=true;
    await mount(tester,auth,api);
    await tester.tap(find.text('Preview next EXM batch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('exm-batch-confirmation')),
      'DELETE NEXT BATCH');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('exm-batch-delete')));
    await tester.tap(find.byKey(const Key('exm-batch-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete this batch permanently'));
    await tester.pumpAndSettle();
    expect(api.deletions,1);
    expect(find.byKey(const Key('exm-batch-error')),findsOneWidget);
    expect(find.byKey(const Key('exm-batch-delete')),findsNothing);
  });

  testWidgets('Owner switch during preview discards previous account data',
      (tester) async {
    final auth=_FakeAuth(AuthSuccess(user('owner-a')));
    final api=_FakeBatches();
    api.pending=Completer<ReferencePracticeBatchPreview>();
    await mount(tester,auth,api);
    await tester.tap(find.text('Preview next EXM batch'));
    await tester.pump();
    auth.change(AuthSuccess(user('owner-b')));
    await tester.pump();
    api.pending!.complete(const ReferencePracticeBatchPreview(
      ownerId:'owner-a',totalEvents:5001,batchEvents:1000,
      batchGrades:1,batchEditions:2,limit:1000,
      fingerprint:'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-batch-count')),findsNothing);
    expect(api.deletions,0);
    expect(find.text('Preview next EXM batch'),findsOneWidget);
  });
}
