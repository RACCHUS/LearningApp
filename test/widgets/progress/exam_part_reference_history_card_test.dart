import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/services/assessment/exam_part_reference_attempt_history_service.dart';
import 'package:learning_pwa/widgets/progress/exam_part_reference_history_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

const version = 'b3000000-0000-4000-8000-000000000012';

User _user(String id) => User(
  id:id, isAnonymous:false, appMetadata:const {}, userMetadata:const {},
  aud:'authenticated', createdAt:'2026-10-21T00:00:00Z',
);

Map<String,dynamic> _record(int index, {String owner='owner-a'}) => {
  'owner_auth_uid': owner,
  'target_version_id': version,
  'exam_part_key': 'part_a',
  'client_attempt_id':
      'b3000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
  'manifest_revision_id': 'b3000000-0000-4000-8000-000000000016',
  'manifest_revision': 1,
  'assessment_item_id': 'b3000000-0000-4000-8000-000000000017',
  'approved_binding_id': 'b3000000-0000-4000-8000-000000000018',
  'administration_date': '2027-07-01',
  'recorded_steps':4, 'graded_correct':1, 'graded_incorrect':1,
  'awaiting_grade':1, 'skipped_steps':1,
  'first_recorded_at':'2027-03-01T11:59:00Z',
  'last_recorded_at':
      '2027-03-01T12:${index.toString().padLeft(2,'0')}:00Z',
  'completed_four_steps':true,
};

Widget _page() => const MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: ExamPartReferenceHistoryCard(
        ownerId:'owner-a',
        targetVersionId:version,
        examPartKey:'part_a',
      ),
    ),
  ),
);

void main() {
  testWidgets('opt-in history shows four-stage, graded and skipped separately',
      (tester) async {
    final service = ExamPartReferenceAttemptHistoryService(
      client: FakeSupabaseClient(currentUser:_user('owner-a')),
      testTransport: (_, __, ___, ____, _____) async => [_record(1)],
    );
    await tester.pumpWidget(ProviderScope(overrides:[
      learnerIdProvider.overrideWith((ref)=>'owner-a'),
      examPartReferenceHistoryServiceProvider.overrideWithValue(service),
    ],child:_page()));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 recent saved'),findsNothing);
    await tester.tap(find.byKey(const Key('exam-part-history-load')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 recent saved'),findsOneWidget);
    expect(find.textContaining('1 graded correct'),findsOneWidget);
    expect(find.textContaining('1 graded incorrect'),findsOneWidget);
    expect(find.textContaining('1 awaiting'),findsOneWidget);
    expect(find.textContaining('1 skipped'),findsOneWidget);
    expect(find.textContaining('do not establish an official exam'),findsOneWidget);
  });

  testWidgets('part history disappears when learner identity changes',
      (tester) async {
    final owner = StateProvider<String>((ref)=>'owner-a');
    final service = ExamPartReferenceAttemptHistoryService(
      client: FakeSupabaseClient(currentUser:_user('owner-a')),
      testTransport: (_, __, ___, ____, _____) async => [_record(1)],
    );
    await tester.pumpWidget(ProviderScope(overrides:[
      learnerIdProvider.overrideWith((ref)=>ref.watch(owner)),
      examPartReferenceHistoryServiceProvider.overrideWithValue(service),
    ],child:_page()));
    await tester.tap(find.byKey(const Key('exam-part-history-load')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 recent saved'),findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ExamPartReferenceHistoryCard)));
    container.read(owner.notifier).state='owner-b';
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exam-part-saved-reference-history')),
      findsNothing);
    expect(find.textContaining('1 recent saved'),findsNothing);
  });

  testWidgets('network result arriving after user switch remains private',
      (tester) async {
    final owner = StateProvider<String>((ref)=>'owner-a');
    final deferred=Completer<dynamic>();
    final service=ExamPartReferenceAttemptHistoryService(
      client:FakeSupabaseClient(currentUser:_user('owner-a')),
      testTransport:(_, __, ___, ____, _____)=>deferred.future,
    );
    await tester.pumpWidget(ProviderScope(overrides:[
      learnerIdProvider.overrideWith((ref)=>ref.watch(owner)),
      examPartReferenceHistoryServiceProvider.overrideWithValue(service),
    ],child:_page()));
    await tester.tap(find.byKey(const Key('exam-part-history-load')));
    await tester.pump();
    final container=ProviderScope.containerOf(
      tester.element(find.byType(ExamPartReferenceHistoryCard)));
    container.read(owner.notifier).state='owner-b';
    deferred.complete([_record(1)]);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 recent saved'),findsNothing);
    expect(find.byKey(const Key('exam-part-history-error')),findsNothing);
  });

  testWidgets('private malformed row is never shown as saved history',
      (tester) async {
    final service=ExamPartReferenceAttemptHistoryService(
      client:FakeSupabaseClient(currentUser:_user('owner-a')),
      testTransport:(_, __, ___, ____, _____) async => [
        _record(1,owner:'another-owner'),
      ],
    );
    await tester.pumpWidget(ProviderScope(overrides:[
      learnerIdProvider.overrideWith((ref)=>'owner-a'),
      examPartReferenceHistoryServiceProvider.overrideWithValue(service),
    ],child:_page()));
    await tester.tap(find.byKey(const Key('exam-part-history-load')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exam-part-history-error')),findsOneWidget);
    expect(find.textContaining('recent saved drill'),findsNothing);
  });
}
