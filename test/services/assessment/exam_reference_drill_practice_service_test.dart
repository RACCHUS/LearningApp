import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_practice_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const manifest = '33333333-3333-4333-8333-333333333333';
const item = '11111111-1111-4111-8111-111111111111';
const binding = '22222222-2222-4222-8222-222222222222';

class _SwitchableSupabase implements SupabaseClient {
  final _SwitchableAuth stub = _SwitchableAuth();
  @override
  GoTrueClient get auth => stub;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SwitchableAuth implements GoTrueClient {
  User? user;
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

User _user(String id, {bool guest = false}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  isAnonymous: guest,
  createdAt: '2026-10-20T00:00:00Z',
);

Map<String, dynamic> safePractice() => {
  'assessment_item_id': item,
  'approved_binding_id': binding,
  'manifest_revision_id': manifest,
  'exam_part_key': 'project_management',
  'administration_date': '2027-06-01',
  'item_content_revision': 1,
  'answer_location_revision': 2,
  'steps': {
    for (final step in const [
      'resource_choice','section_location','interpretation','application'
    ])
      step: {
        'prompt': 'Original fictional reviewed prompt for $step?',
        'choices': [
          {'value': 'choice_a', 'label': 'First choice'},
          {'value': 'choice_b', 'label': 'Second choice'},
        ],
      },
  },
};

void main() {
  final date = DateTime.utc(2027, 6, 1);

  test('Permanent owner receives only exact-edition safe prompt model', () async {
    final client = _SwitchableSupabase();
    client.stub.user = _user('A');
    final service = ExamReferenceDrillPracticeService(
      client: client,
      testTransport: (m, p, d) async {
        expect(m, manifest);
        expect(p, 'project_management');
        expect(d, '2027-06-01');
        return safePractice();
      },
    );
    final result = await service.fetch(
      expectedOwnerId: 'A', manifestRevisionId: manifest,
      examPartKey: 'project_management', administrationDate: date,
    );
    expect(result, isNotNull);
    expect(result!.binding.answerLocationRevision, 2);
    expect(result.steps.length, 4);
    expect(result.steps['resource_choice']!.choices[0].label, 'First choice');
  });

  test('Unknown/unreviewed practice remains unavailable, never invented', () async {
    final client = _SwitchableSupabase();
    client.stub.user = _user('A');
    final service = ExamReferenceDrillPracticeService(
      client: client, testTransport: (m,p,d) async => null,
    );
    expect(await service.fetch(expectedOwnerId: 'A',
      manifestRevisionId: manifest, examPartKey: 'project_management',
      administrationDate: date), isNull);
  });

  test('Guest and wrong account fail before any request', () async {
    final client = _SwitchableSupabase();
    var requests = 0;
    final service = ExamReferenceDrillPracticeService(
      client: client, testTransport: (m,p,d) async {
        requests++; return safePractice();
      },
    );
    client.stub.user = _user('A', guest: true);
    await expectLater(service.fetch(expectedOwnerId: 'A',
      manifestRevisionId: manifest, examPartKey: 'project_management',
      administrationDate: date), throwsStateError);
    client.stub.user = _user('B');
    await expectLater(service.fetch(expectedOwnerId: 'A',
      manifestRevisionId: manifest, examPartKey: 'project_management',
      administrationDate: date), throwsStateError);
    expect(requests, 0);
  });

  test('In-flight account A data cannot be returned after switching to B',
      () async {
    final client = _SwitchableSupabase();
    client.stub.user = _user('A');
    final completer = Completer<dynamic>();
    final service = ExamReferenceDrillPracticeService(
      client: client, testTransport: (m,p,d) => completer.future,
    );
    final pending = service.fetch(expectedOwnerId: 'A',
      manifestRevisionId: manifest, examPartKey: 'project_management',
      administrationDate: date);
    client.stub.user = _user('B');
    completer.complete(safePractice());
    await expectLater(pending, throwsStateError);
  });

  test('Any private answer/reviewer field or mismatched date fails closed',
      () async {
    final client = _SwitchableSupabase();
    client.stub.user = _user('A');
    final payload = safePractice()..['scoring_spec'] = {'correct_index':0};
    final service = ExamReferenceDrillPracticeService(
      client: client, testTransport: (m,p,d) async => payload,
    );
    await expectLater(service.fetch(expectedOwnerId: 'A',
      manifestRevisionId: manifest, examPartKey: 'project_management',
      administrationDate: date), throwsFormatException);
    payload.remove('scoring_spec');
    payload['administration_date'] = '2026-06-01';
    await expectLater(service.fetch(expectedOwnerId: 'A',
      manifestRevisionId: manifest, examPartKey: 'project_management',
      administrationDate: date), throwsFormatException);
  });
}
