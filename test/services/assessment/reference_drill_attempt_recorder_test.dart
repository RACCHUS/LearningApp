import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/reference_drill_engine.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_event_service.dart';
import 'package:learning_pwa/services/assessment/reference_drill_attempt_recorder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

void main() {
  User user({bool guest = false, String id = 'owner-account'}) => User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-10-20T00:00:00Z',
    isAnonymous: guest,
  );

  const itemId = '11111111-1111-4111-8111-111111111111';
  const bindingId = '22222222-2222-4222-8222-222222222222';
  const manifestId = '33333333-3333-4333-8333-333333333333';
  const attemptId = '44444444-4444-4444-8444-444444444444';

  ReferenceDrillBindingSnapshot binding({String manifest = manifestId}) =>
      ReferenceDrillBindingSnapshot(
        assessmentItemId: itemId,
        approvedBindingId: bindingId,
        manifestRevisionId: manifest,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 2, 12),
        itemContentRevision: 2,
        answerLocationRevision: 3,
      );

  test('R1-R4 are recorded with one version-pinned attempt and no answers',
      () async {
    final fake = FakeSupabaseClient(currentUser: user());
    var now = DateTime.utc(2027, 1, 10, 12);
    final recorder = ReferenceDrillAttemptRecorder(
      eventService: ExamReferenceDrillEventService(client: fake),
      binding: binding(),
      expectedOwnerId: 'owner-account',
      clientAttemptId: attemptId,
      now: () => now,
    );
    for (final step in ReferenceDrillStep.values) {
      expect(recorder.nextStep, step);
      now = now.add(const Duration(seconds: 10));
      await recorder.submitStep(
        step: step,
        responded: step != ReferenceDrillStep.interpretation,
        appElapsed: const Duration(seconds: 9),
        selfReportedBookTime: step == ReferenceDrillStep.sectionLocation
            ? const Duration(minutes: 2)
            : null,
      );
    }

    expect(recorder.isComplete, isTrue);
    expect(recorder.recordedStepCount, 4);
    expect(fake.insertedRecords.length, 4);
    expect(fake.insertedRecords.map((e) => e['drill_step']), [
      'resource_choice', 'section_location', 'interpretation', 'application',
    ]);
    for (final row in fake.insertedRecords) {
      expect(row['client_attempt_id'], attemptId);
      expect(row['owner_auth_uid'], 'owner-account');
      expect(row['approved_binding_id'], bindingId);
      expect(row['manifest_revision_id'], manifestId);
      expect(row['administration_date'], '2027-02-12');
      expect(row['item_content_revision'], 2);
      expect(row['answer_location_revision'], 3);
      expect(row.containsKey('answer'), isFalse);
      expect(row.containsKey('expected_answers'), isFalse);
      expect(row.containsKey('correctness'), isFalse);
      expect(row.containsKey('score'), isFalse);
    }
    expect(fake.insertedRecords[2]['responded'], isFalse);
    expect(fake.insertedRecords[1]['self_reported_book_ms'], 120000);
    expect(fake.insertedRecords[0]['self_reported_book_ms'], isNull);
    await expectLater(recorder.submitStep(
      step: ReferenceDrillStep.application,
      responded: true,
      appElapsed: Duration.zero,
    ), throwsStateError);
  });

  test('Standalone R2 records only location, never synthesizes R1', () async {
    final fake = FakeSupabaseClient(currentUser: user());
    var now = DateTime.utc(2027, 1, 1);
    final recorder = ReferenceDrillAttemptRecorder(
      eventService: ExamReferenceDrillEventService(client: fake),
      binding: binding(),
      expectedOwnerId: 'owner-account',
      permittedSteps: {ReferenceDrillStep.sectionLocation},
      now: () => now,
    );
    expect(recorder.nextStep, ReferenceDrillStep.sectionLocation);
    now = now.add(const Duration(seconds: 3));
    await recorder.submitStep(
      step: ReferenceDrillStep.sectionLocation,
      responded: false,
      appElapsed: const Duration(seconds: 3),
    );
    expect(recorder.isComplete, isTrue);
    expect(fake.insertedRecords.single['drill_step'], 'section_location');
    expect(fake.insertedRecords.single['responded'], isFalse);
  });

  test('Wrong account cannot receive an old account attempt', () async {
    final fake = FakeSupabaseClient(currentUser: user(id: 'account-b'));
    final recorder = ReferenceDrillAttemptRecorder(
      eventService: ExamReferenceDrillEventService(client: fake),
      binding: binding(),
      expectedOwnerId: 'account-a',
      now: () => DateTime.utc(2027, 1, 1),
    );
    await expectLater(recorder.submitStep(
      step: ReferenceDrillStep.resourceChoice,
      responded: true,
      appElapsed: Duration.zero,
    ), throwsStateError);
    expect(recorder.hasPendingWrite, isTrue);
    await expectLater(recorder.retryPending(), throwsStateError);
    expect(fake.insertedRecords, isEmpty);
  });

  test('Anonymous guest is barred even when binding IDs look valid', () async {
    final fake = FakeSupabaseClient(currentUser: user(guest: true));
    final recorder = ReferenceDrillAttemptRecorder(
      eventService: ExamReferenceDrillEventService(client: fake),
      binding: binding(),
      expectedOwnerId: 'owner-account',
      now: () => DateTime.utc(2027, 1, 1),
    );
    await expectLater(recorder.submitStep(
      step: ReferenceDrillStep.resourceChoice,
      responded: true,
      appElapsed: Duration.zero,
    ), throwsStateError);
    expect(fake.insertedRecords, isEmpty);
  });

  test('Invalid edition IDs and reordered steps fail before writing', () async {
    final fake = FakeSupabaseClient(currentUser: user());
    expect(() => ReferenceDrillAttemptRecorder(
      eventService: ExamReferenceDrillEventService(client: fake),
      binding: binding(manifest: 'unreviewed'),
      expectedOwnerId: 'owner-account',
    ), throwsFormatException);
    final recorder = ReferenceDrillAttemptRecorder(
      eventService: ExamReferenceDrillEventService(client: fake),
      binding: binding(),
      expectedOwnerId: 'owner-account',
      now: () => DateTime.utc(2027, 1, 1),
    );
    await expectLater(recorder.submitStep(
      step: ReferenceDrillStep.application,
      responded: true,
      appElapsed: Duration.zero,
    ), throwsStateError);
    expect(fake.insertedRecords, isEmpty);
  });
}
