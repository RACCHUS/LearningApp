import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_assigned_practice_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const ownerA = 'e5010000-0000-4000-8000-000000000001';
const ownerB = 'e5010000-0000-4000-8000-000000000002';
const sessionA = 'e5020000-0000-4000-8000-000000000001';
const sessionB = 'e5020000-0000-4000-8000-000000000002';
const version = 'e5030000-0000-4000-8000-000000000001';
const assignmentId = 'e5040000-0000-4000-8000-000000000001';

class _Client implements SupabaseClient {
  final _Auth stub = _Auth();
  @override
  GoTrueClient get auth => stub;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Auth implements GoTrueClient {
  User? user;
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

User _user(String id, {bool guest = false}) => User(
  id: id, appMetadata: const {}, userMetadata: const {},
  aud: 'authenticated', isAnonymous: guest,
  createdAt: '2026-10-23T00:00:00Z',
);

String _id(int n) => 'e5050000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

Map<String, dynamic> _issued() => {
  'assignment_id': assignmentId,
  'target_version_id': version,
  'exam_part_key': 'part_a',
  'expires_at': '2099-01-01T12:00:00Z',
  'practice_only': true,
  'question_count': 6,
  'questions': [
    for (var i = 1; i <= 6; i++)
      {
        'id': _id(i),
        'interaction_type': 'single_choice',
        'prompt': 'Fictional reviewed practice question $i?',
        'response_spec': {'options': ['Answer A', 'Answer B']},
      },
  ],
};

Map<String, dynamic> _receipt({bool replay = false}) => {
  'attempt_id': 'e5060000-0000-4000-8000-000000000001',
  'target_version_id': version,
  'exam_part_key': 'part_a',
  'question_count': 6,
  'fully_correct_count': 4,
  'partial_count': 0,
  'practice_score': 0.666667,
  'already_recorded': replay,
  'official_exam_result': false,
};

void main() {
  late _Client client;
  late String activeSession;

  setUp(() {
    client = _Client();
    client.stub.user = _user(ownerA);
    activeSession = sessionA;
  });

  ExamAssignedPracticeService service({
    Future<dynamic> Function(String, String)? issue,
    Future<dynamic> Function(String, Map<String, int>)? submit,
  }) => ExamAssignedPracticeService(
    client: client, testSessionId: () => activeSession,
    testIssue: issue ?? (v, p) async => _issued(),
    testSubmit: submit ?? (a, r) async => _receipt(),
  );

  test('safe exact issuer projection and canonical result are returned', () async {
    var requests = 0;
    final api = service(
      issue: (v, p) async {
        expect(v, version);
        expect(p, 'part_a');
        requests++;
        return _issued();
      },
      submit: (a, r) async {
        expect(a, assignmentId);
        expect(r, {for (var i = 1; i <= 6; i++) _id(i): i % 2});
        requests++;
        return _receipt();
      },
    );
    final issued = await api.issue(
      expectedOwnerId: ownerA, targetVersionId: version,
      examPartKey: 'part_a',
    );
    expect(issued.questions.length, 6);
    expect(issued.questions.first.options, ['Answer A', 'Answer B']);
    final result = await api.submit(
      expectedOwnerId: ownerA, assignment: issued,
      responses: {for (var i = 1; i <= 6; i++) _id(i): i % 2},
    );
    expect(result.questionCount, 6);
    expect(result.fullyCorrectCount, 4);
    expect(result.practiceScore, closeTo(2 / 3, 0.000001));
    expect(result.alreadyRecorded, false);
    expect(requests, 2);
  });

  test('guest, different account, missing session rejected before network', () async {
    var requests = 0;
    final api = service(issue: (v, p) async {
      requests++;
      return _issued();
    });
    client.stub.user = _user(ownerA, guest: true);
    await expectLater(api.issue(expectedOwnerId: ownerA,
      targetVersionId: version, examPartKey: 'part_a'), throwsStateError);
    client.stub.user = _user(ownerB);
    await expectLater(api.issue(expectedOwnerId: ownerA,
      targetVersionId: version, examPartKey: 'part_a'), throwsStateError);
    client.stub.user = _user(ownerA);
    activeSession = '';
    await expectLater(api.issue(expectedOwnerId: ownerA,
      targetVersionId: version, examPartKey: 'part_a'), throwsStateError);
    expect(requests, 0);
  });

  test('in-flight account or session switch cannot reveal issued questions',
      () async {
    final delayed = Completer<dynamic>();
    final api = service(issue: (v, p) => delayed.future);
    final pending = api.issue(expectedOwnerId: ownerA,
      targetVersionId: version, examPartKey: 'part_a');
    activeSession = sessionB;
    delayed.complete(_issued());
    await expectLater(pending, throwsStateError);
    final delayed2 = Completer<dynamic>();
    activeSession = sessionA;
    final api2 = service(issue: (v, p) => delayed2.future);
    final pending2 = api2.issue(expectedOwnerId: ownerA,
      targetVersionId: version, examPartKey: 'part_a');
    client.stub.user = _user(ownerB);
    delayed2.complete(_issued());
    await expectLater(pending2, throwsStateError);
  });

  test('issuer cannot smuggle answer key, nested options or duplicate items',
      () async {
    final unsafe = <Map<String, dynamic>>[];
    unsafe.add(_issued()..['scoring_spec'] = {'correct_index': 0});
    unsafe.add(_issued()..['question_count'] = 5);
    unsafe.add(_issued()..['target_version_id'] = _id(33));
    unsafe.add(_issued()..['practice_only'] = false);
    final nested = _issued();
    (nested['questions'] as List)[0]['response_spec'] = {
      'options': [{'text': 'A', 'isCorrect': true}, 'B'],
    };
    unsafe.add(nested);
    final duplicate = _issued();
    (duplicate['questions'] as List)[1]['id'] = _id(1);
    unsafe.add(duplicate);
    final extra = _issued();
    (extra['questions'] as List)[0]['correct_index'] = 0;
    unsafe.add(extra);
    for (final payload in unsafe) {
      final api = service(issue: (v, p) async => payload);
      await expectLater(api.issue(expectedOwnerId: ownerA,
        targetVersionId: version, examPartKey: 'part_a'),
        throwsFormatException);
    }
  });

  test('submission requires exact issued six indices and same session', () async {
    var submitCount = 0;
    final api = service(submit: (a, r) async {
      submitCount++;
      return _receipt();
    });
    final issued = await api.issue(expectedOwnerId: ownerA,
      targetVersionId: version, examPartKey: 'part_a');
    await expectLater(api.submit(expectedOwnerId: ownerA,
      assignment: issued, responses: {_id(1): 0}), throwsStateError);
    await expectLater(api.submit(expectedOwnerId: ownerA,
      assignment: issued,
      responses: {for (var i = 1; i <= 6; i++) _id(i): 99}),
      throwsArgumentError);
    await expectLater(api.submit(expectedOwnerId: ownerA,
      assignment: issued,
      responses: {for (var i = 1; i <= 5; i++) _id(i): 0, _id(99): 0}),
      throwsArgumentError);
    activeSession = sessionB;
    await expectLater(api.submit(expectedOwnerId: ownerA,
      assignment: issued,
      responses: {for (var i = 1; i <= 6; i++) _id(i): 0}),
      throwsStateError);
    expect(submitCount, 0);
  });

  test('in-flight submission drops response after auth switch', () async {
    final delayed = Completer<dynamic>();
    final api = service(submit: (a, r) => delayed.future);
    final issued = await api.issue(expectedOwnerId: ownerA,
      targetVersionId: version, examPartKey: 'part_a');
    final pending = api.submit(expectedOwnerId: ownerA,
      assignment: issued,
      responses: {for (var i = 1; i <= 6; i++) _id(i): 0});
    client.stub.user = _user(ownerB);
    delayed.complete(_receipt());
    await expectLater(pending, throwsStateError);
  });

  test('submission rejects untrusted or impossible scoring receipts', () async {
    final api = service();
    final issued = await api.issue(expectedOwnerId: ownerA,
      targetVersionId: version, examPartKey: 'part_a');
    final bad = <Map<String, dynamic>>[
      _receipt()..['official_exam_result'] = true,
      _receipt()..['response_sha256'] = 'secret',
      _receipt()..['fully_correct_count'] = 7,
      _receipt()..['practice_score'] = 1.0,
      _receipt()..['target_version_id'] = _id(88),
    ];
    for (final receipt in bad) {
      final testApi = service(submit: (a, r) async => receipt);
      await expectLater(testApi.submit(expectedOwnerId: ownerA,
        assignment: issued,
        responses: {for (var i = 1; i <= 6; i++) _id(i): 0}),
        throwsFormatException);
    }
    final replayApi = service(submit: (a, r) async => _receipt(replay: true));
    final replay = await replayApi.submit(expectedOwnerId: ownerA,
      assignment: issued,
      responses: {for (var i = 1; i <= 6; i++) _id(i): 0});
    expect(replay.alreadyRecorded, true);
  });
}
