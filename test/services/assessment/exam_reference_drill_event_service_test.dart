import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_event_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

void main() {
  User account({bool anonymous = false, String id = 'account-a'}) => User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-10-20T00:00:00Z',
    isAnonymous: anonymous,
  );

  final start = DateTime.utc(2027, 1, 2, 10, 0, 0);
  final end = start.add(const Duration(seconds: 10));

  Future<Map<String, dynamic>> submit(
    ExamReferenceDrillEventService service, {
    Duration elapsed = const Duration(seconds: 10),
    String step = 'section_location',
    String? expectedOwnerId,
  }) => service.recordStep(
    expectedOwnerId: expectedOwnerId,
    clientAttemptId: '11111111-1111-4111-8111-111111111111',
    assessmentItemId: '22222222-2222-4222-8222-222222222222',
    approvedBindingId: '33333333-3333-4333-8333-333333333333',
    manifestRevisionId: '44444444-4444-4444-8444-444444444444',
    examPartKey: 'project_management',
    administrationDate: DateTime.utc(2027, 2, 12),
    itemContentRevision: 1,
    answerLocationRevision: 2,
    step: step,
    responded: true,
    appElapsed: elapsed,
    selfReportedBookTime: const Duration(minutes: 2),
    startedAt: start,
    completedAt: end,
  );

  test('Signed-out users cannot create durable attempts', () async {
    final fake = FakeSupabaseClient();
    final service = ExamReferenceDrillEventService(client: fake);
    await expectLater(submit(service), throwsStateError);
    expect(fake.insertedRecords, isEmpty);
  });

  test('Anonymous Supabase Auth users never write durable attempts', () async {
    final fake = FakeSupabaseClient(currentUser: account(anonymous: true));
    final service = ExamReferenceDrillEventService(client: fake);
    await expectLater(submit(service), throwsStateError);
    await expectLater(service.listMyEvents(), throwsStateError);
    await expectLater(
      service.deleteMyAttempt('11111111-1111-4111-8111-111111111111'),
      throwsStateError,
    );
    expect(fake.insertedRecords, isEmpty);
  });

  test('Permanent account writes observations with no scoring or answer text', () async {
    final fake = FakeSupabaseClient(currentUser: account());
    final event = await submit(ExamReferenceDrillEventService(client: fake));
    expect(event['owner_auth_uid'], 'account-a');
    expect(event['administration_date'], '2027-02-12');
    expect(event['manifest_revision_id'],
        '44444444-4444-4444-8444-444444444444');
    expect(event['app_elapsed_ms'], 10000);
    expect(event['self_reported_book_ms'], 120000);
    expect(event['drill_step'], 'section_location');
    expect(event.containsKey('correctness'), isFalse);
    expect(event.containsKey('expected_locations'), isFalse);
    expect(event.containsKey('verification_state'), isFalse);
  });

  test('Invalid elapsed time rejected before making an API request', () async {
    final fake = FakeSupabaseClient(currentUser: account());
    final service = ExamReferenceDrillEventService(client: fake);
    await expectLater(
      submit(service, elapsed: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
    await expectLater(submit(service, step: 'not_a_step'), throwsArgumentError);
    expect(fake.insertedRecords, isEmpty);
  });

  test('A mismatched expected owner cannot request or delete records', () async {
    final fake = FakeSupabaseClient(currentUser: account(id: 'account-a'));
    final service = ExamReferenceDrillEventService(client: fake);
    await expectLater(
      service.listMyEvents(
        expectedOwnerId: 'account-b',
        manifestRevisionId: 'manifest-27',
      ),
      throwsStateError,
    );
    await expectLater(
      service.deleteMyAttempt(
        'attempt-id',
        expectedOwnerId: 'account-b',
        manifestRevisionId: 'manifest-27',
      ),
      throwsStateError,
    );
    expect(fake.deletedIds, isEmpty);
  });

  test('Recording refuses a different session owner before the insert', () async {
    final fake = FakeSupabaseClient(currentUser: account(id: 'account-b'));
    final service = ExamReferenceDrillEventService(client: fake);
    await expectLater(submit(service, expectedOwnerId: 'account-a'),
        throwsStateError);
    expect(fake.insertedRecords, isEmpty);
  });

  test('History query filters both owner and exact manifest revision', () async {
    final fake = FakeSupabaseClient(currentUser: account(id: 'account-a'));
    fake.setTableData('exam_reference_drill_events', [
      {'id': 'right', 'owner_auth_uid': 'account-a',
       'manifest_revision_id': 'manifest-27', 'recorded_at': '2027-01-01'},
      {'id': 'old-edition', 'owner_auth_uid': 'account-a',
       'manifest_revision_id': 'manifest-26', 'recorded_at': '2026-01-01'},
      {'id': 'foreign', 'owner_auth_uid': 'account-b',
       'manifest_revision_id': 'manifest-27', 'recorded_at': '2027-01-02'},
    ]);
    final rows = await ExamReferenceDrillEventService(client: fake)
        .listMyEvents(manifestRevisionId: 'manifest-27',
                      expectedOwnerId: 'account-a');
    expect(rows.map((row) => row['id']).toList(), ['right']);
  });

  test('Signed-in retrieval is scoped by auth subject and capped', () async {
    final fake = FakeSupabaseClient(currentUser: account());
    fake.setTableData('exam_reference_drill_events', [
      {'id':'a','owner_auth_uid':'account-a','recorded_at':'2026-10-20T00:00:00Z'},
      {'id':'b','owner_auth_uid':'account-b','recorded_at':'2026-10-19T00:00:00Z'},
    ]);
    final rows = await ExamReferenceDrillEventService(client: fake)
        .listMyEvents(limit: 10);
    expect(rows.length, 1);
    expect(rows.single['id'], 'a');
    await expectLater(
      ExamReferenceDrillEventService(client: fake).listMyEvents(limit: 101),
      throwsRangeError,
    );
  });
}
