import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_progress_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

const manifest = '33333333-3333-4333-8333-333333333333';
const eventOne = '11111111-1111-4111-8111-111111111111';
const eventTwo = '22222222-2222-4222-8222-222222222222';
const eventThree = '44444444-4444-4444-8444-444444444444';

User user(String id, {bool guest = false}) => User(
  id: id, isAnonymous: guest, appMetadata: const {},
  userMetadata: const {}, aud: 'authenticated',
  createdAt: '2026-10-20T00:00:00Z',
);

Map<String,dynamic> row(String id, String step, {
  String owner = 'account-a', String edition = manifest,
  bool responded = true, bool? correct, int? version,
  String recorded = '2027-03-01T12:00:00Z',
}) => {
  'event_id': id, 'owner_auth_uid': owner,
  'client_attempt_id': '55555555-5555-4555-8555-555555555555',
  'assessment_item_id': '66666666-6666-4666-8666-666666666666',
  'approved_binding_id': '77777777-7777-4777-8777-777777777777',
  'manifest_revision_id': edition,
  'exam_part_key': 'project_management',
  'administration_date': '2027-06-01',
  'item_content_revision': 1, 'answer_location_revision': 2,
  'drill_step': step, 'responded': responded, 'app_elapsed_ms': 1000,
  'self_reported_book_ms': null,
  'started_at': '2027-03-01T11:59:55Z',
  'completed_at': '2027-03-01T11:59:59Z',
  'recorded_at': recorded,
  'verification_state': 'unverified',
  'is_correct': correct,
  'scoring_version': version,
  'graded_at': correct == null ? null : '2027-03-01T12:00:01Z',
};

void main() {
  test('Cursor pages yield all evidence with precise checked/skipped counts',
      () async {
    final client = FakeSupabaseClient(currentUser: user('account-a'));
    var calls = 0;
    final service = ExamReferenceDrillProgressService(
      client: client,
      testTransport: (m, limit, before, beforeId) async {
        expect(m,manifest);
        calls++;
        if (calls == 1) {
          expect(before,isNull);
          return [
            row(eventThree,'application', responded:false,
              recorded:'2027-03-01T12:00:02Z'),
            row(eventTwo,'section_location',
              recorded:'2027-03-01T12:00:01Z'),
          ];
        }
        expect(beforeId,eventTwo);
        return [
          row(eventOne,'resource_choice',correct:true,version:3),
        ];
      },
    );
    // 2 records then one page: use maxRecords=2? would reject; a
    // 100-record first page is needed for an actual cursor continuation.
    final events = <Map<String,dynamic>>[
      for (var i = 100; i >= 1; i--)
        row(
          'a${i.toString().padLeft(7,'0')}-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          i == 100 ? 'resource_choice' : 'interpretation',
          correct: i == 100 ? true : null,
          version: i == 100 ? 3 : null,
          recorded: '2027-03-01T12:00:00Z',
        ),
      row(eventOne,'section_location',responded:false,
        recorded:'2027-02-28T12:00:00Z'),
    ];
    final paged = ExamReferenceDrillProgressService(
      client: client,
      testTransport: (m, limit, before, beforeId) async {
        if (before == null) return events.take(limit).toList();
        return events.skip(100).toList();
      },
    );
    final result = await paged.loadComplete(
      expectedOwnerId: 'account-a',manifestRevisionId:manifest);
    expect(result.events.length,101);
    expect(result.skills.first.correct,1);
    expect(result.skills[1].skipped,1);
    expect(result.skills[2].awaitingScore,99);
    final exported = jsonDecode(result.toJsonExport(
      generatedAt:DateTime.utc(2027,3,2))) as Map<String,dynamic>;
    expect(exported['complete'],true);
    expect((exported['steps'] as List).length,101);
    expect((exported['steps'] as List).first['scoring_version'],3);
    expect(exported.toString().contains('step_tokens'),false);
    expect(exported.toString().contains('reviewer_ref'),false);
    expect(exported.toString().contains('correct_index'),false);
  });

  test('Owner changes across await fail closed', () async {
    final client = FakeSupabaseClient(currentUser:user('account-a'));
    final pending = Completer<dynamic>();
    final service = ExamReferenceDrillProgressService(
      client:client, testTransport:(m,l,t,i)=>pending.future);
    final loading=service.loadComplete(
      expectedOwnerId:'account-a',manifestRevisionId:manifest);
    client.auth.setCurrentUser(user('account-b'));
    pending.complete([row(eventOne,'resource_choice',correct:true,version:1)]);
    await expectLater(loading,throwsStateError);
  });

  test('Guest cannot request private progress', () async {
    final client=FakeSupabaseClient(currentUser:user('anonymous',guest:true));
    var invoked=false;
    final service=ExamReferenceDrillProgressService(
      client:client,testTransport:(m,l,t,i) async {invoked=true;return [];});
    await expectLater(service.loadComplete(
      expectedOwnerId:'anonymous',manifestRevisionId:manifest),throwsStateError);
    expect(invoked,false);
  });

  test('Foreign, wrong-edition, private-field and fabricated grade fail closed',
      () async {
    final client=FakeSupabaseClient(currentUser:user('account-a'));
    for (final bad in [
      row(eventOne,'resource_choice',owner:'account-b'),
      row(eventOne,'resource_choice',edition:'wrong-edition'),
      row(eventOne,'resource_choice')..['step_tokens']=['private'],
      row(eventOne,'resource_choice',correct:true,version:null),
      row(eventOne,'resource_choice',responded:false,correct:true,version:1),
    ]) {
      final service=ExamReferenceDrillProgressService(client:client,
        testTransport:(m,l,t,i) async=>[bad]);
      await expectLater(service.loadComplete(
        expectedOwnerId:'account-a',manifestRevisionId:manifest),
        throwsFormatException);
    }
  });

  test('Overflow, duplicate cursors and out-of-order pages never export', () async {
    final client=FakeSupabaseClient(currentUser:user('account-a'));
    final rows=[
      row(eventTwo,'resource_choice',recorded:'2027-03-02T12:00:00Z'),
      row(eventOne,'resource_choice',recorded:'2027-03-01T12:00:00Z'),
    ];
    final overflow=ExamReferenceDrillProgressService(client:client,
      testTransport:(m,l,t,i) async=>rows.take(l).toList());
    await expectLater(overflow.loadComplete(
      expectedOwnerId:'account-a',manifestRevisionId:manifest,maxRecords:1),
      throwsStateError);
    final duplicate=ExamReferenceDrillProgressService(client:client,
      testTransport:(m,l,t,i) async=>[rows.first,rows.first]);
    await expectLater(duplicate.loadComplete(
      expectedOwnerId:'account-a',manifestRevisionId:manifest),
      throwsFormatException);
    final backward=ExamReferenceDrillProgressService(client:client,
      testTransport:(m,l,t,i) async=>rows.reversed.toList());
    await expectLater(backward.loadComplete(
      expectedOwnerId:'account-a',manifestRevisionId:manifest),
      throwsFormatException);
  });
}
