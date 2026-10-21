import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/assessment/exam_reference_practice_erasure_service.dart';
import 'package:learning_pwa/widgets/progress/reference_practice_erasure_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../test_helpers/fake_supabase_client.dart';

User _user(String id,{bool guest=false}) => User(
  id:id,isAnonymous:guest,
  appMetadata:const {},userMetadata:const {},
  aud:'authenticated',createdAt:'2026-10-21T00:00:00Z',
);

class _TestAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _TestAuth(super.initial);
  void switchTo(AuthState state)=>this.state=state;
  @override
  dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}

class _FakeErasure extends ExamReferencePracticeErasureService {
  _FakeErasure():super(client:FakeSupabaseClient());
  final requested=<String>[];
  int deletes=0;
  Completer<ReferencePracticeErasurePreview>? pending;
  bool stale=false;
  @override
  Future<ReferencePracticeErasurePreview> preview({
    required String expectedOwnerId,
  }) {
    requested.add(expectedOwnerId);
    if (pending!=null) return pending!.future;
    return Future.value(ReferencePracticeErasurePreview(
      ownerId:expectedOwnerId,events:3,grades:1,editions:2,
      fingerprint:'a' * 32,
    ));
  }
  @override
  Future<ReferencePracticeErasureReceipt> deletePreviewed({
    required String expectedOwnerId,
    required ReferencePracticeErasurePreview preview,
    required String exactConfirmation,
  }) async {
    deletes++;
    expect(expectedOwnerId,'owner-a');
    expect(preview.events,3);
    expect(exactConfirmation,
      ExamReferencePracticeErasureService.confirmationPhrase);
    if (stale) throw StateError('Records changed');
    return const ReferencePracticeErasureReceipt(deleted:3,remaining:0);
  }
}

Future<void> _mount(WidgetTester tester, _TestAuth auth,
    _FakeErasure service)=>tester.pumpWidget(ProviderScope(
  overrides:[authProvider.overrideWith((ref)=>auth)],
  child:MaterialApp(home:Scaffold(
    body:SingleChildScrollView(
      child:ReferencePracticeErasureCard(service:service),
    ),
  )),
));

void main() {
  testWidgets('Guest has no erasure controls or API requests',(tester) async {
    final auth=_TestAuth(GuestMode());
    final api=_FakeErasure();
    await _mount(tester,auth,api);
    expect(find.byKey(const Key('exm-erasure-card')),findsNothing);
    auth.switchTo(AuthSuccess(_user('guest',guest:true)));
    await tester.pump();
    expect(find.byKey(const Key('exm-erasure-card')),findsNothing);
    expect(api.requested,isEmpty);
  });

  testWidgets('Preview, typed phrase and second confirmation required',
      (tester) async {
    final auth=_TestAuth(AuthSuccess(_user('owner-a')));
    final api=_FakeErasure();
    await _mount(tester,auth,api);
    expect(api.requested,isEmpty);
    expect(find.byKey(const Key('exm-erasure-delete')),findsNothing);
    await tester.tap(find.text('Preview my saved EXM practice'));
    await tester.pumpAndSettle();
    expect(api.requested,['owner-a']);
    expect(find.textContaining('3 step(s) across 2 edition(s)'),
      findsOneWidget);
    final deleteButton=find.byKey(const Key('exm-erasure-delete'));
    expect(tester.widget<OutlinedButton>(deleteButton).onPressed,isNull);
    await tester.enterText(find.byKey(const Key('exm-erasure-phrase')),
      'delete reference practice');
    await tester.pump();
    expect(tester.widget<OutlinedButton>(deleteButton).onPressed,isNull);
    expect(api.deletes,0);
    await tester.enterText(find.byKey(const Key('exm-erasure-phrase')),
      'DELETE REFERENCE PRACTICE');
    await tester.pump();
    expect(tester.widget<OutlinedButton>(deleteButton).onPressed,isNotNull);
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Permanently delete saved reference practice?'),
      findsOneWidget);
    expect(api.deletes,0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.deletes,0);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permanently delete EXM practice'));
    await tester.pumpAndSettle();
    expect(api.deletes,1);
    expect(find.text('3 step(s) deleted.'),findsOneWidget);
    expect(find.byKey(const Key('exm-erasure-count')),findsNothing);
  });

  testWidgets('Owner switch while preview is loading discards A',
      (tester) async {
    final auth=_TestAuth(AuthSuccess(_user('owner-a')));
    final api=_FakeErasure();
    api.pending=Completer<ReferencePracticeErasurePreview>();
    await _mount(tester,auth,api);
    await tester.tap(find.text('Preview my saved EXM practice'));
    await tester.pump();
    auth.switchTo(AuthSuccess(_user('owner-b')));
    await tester.pump();
    api.pending!.complete(const ReferencePracticeErasurePreview(
      ownerId:'owner-a',events:3,grades:1,editions:2,
      fingerprint:'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-erasure-count')),findsNothing);
    expect(find.text('Preview my saved EXM practice'),findsOneWidget);
    expect(api.deletes,0);
  });

  testWidgets('Stale preview error forces a fresh preview',(tester) async {
    final auth=_TestAuth(AuthSuccess(_user('owner-a')));
    final api=_FakeErasure()..stale=true;
    await _mount(tester,auth,api);
    await tester.tap(find.text('Preview my saved EXM practice'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('exm-erasure-phrase')),
      'DELETE REFERENCE PRACTICE');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('exm-erasure-delete')));
    await tester.tap(find.byKey(const Key('exm-erasure-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permanently delete EXM practice'));
    await tester.pumpAndSettle();
    expect(api.deletes,1);
    expect(find.byKey(const Key('exm-erasure-error')),findsOneWidget);
    expect(find.byKey(const Key('exm-erasure-delete')),findsNothing);
    expect(find.byKey(const Key('exm-erasure-count')),findsNothing);
  });
}
