import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_scoring_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const event = 'b3000000-0000-4000-8000-000000000051';

class _MutableClient implements SupabaseClient {
  final _MutableAuth authStub = _MutableAuth();

  @override
  GoTrueClient get auth => authStub;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Unexpected network call in scoring unit test');
  }
}

class _MutableAuth implements GoTrueClient {
  User? current;

  @override
  User? get currentUser => current;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

User _account(String id, {bool guest = false}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-20T00:00:00Z',
  isAnonymous: guest,
);

Map<String, dynamic> _response({
  String step = 'resource_choice',
  bool correct = true,
}) => {
  'drill_step': step,
  'is_correct': correct,
  'scoring_version': 2,
  'graded_at': '2027-01-01T10:00:00Z',
};

void main() {
  test('Refuses signed out and anonymous guests before any request', () async {
    final client = _MutableClient();
    var requests = 0;
    final scorer = ExamReferenceDrillScoringService(
      client: client,
      testTransport: (id, token) async {
        requests++;
        return [_response()];
      },
    );
    await expectLater(
      scorer.scoreRecordedStep(
        expectedOwnerId: 'account-a',
        eventId: event,
        answerToken: 'example_book',
      ),
      throwsStateError,
    );
    client.authStub.current = _account('account-a', guest: true);
    await expectLater(
      scorer.scoreRecordedStep(
        expectedOwnerId: 'account-a',
        eventId: event,
        answerToken: 'example_book',
      ),
      throwsStateError,
    );
    expect(requests, 0);
  });

  test('Requests server grade only; accepts no private key data', () async {
    final client = _MutableClient();
    client.authStub.current = _account('account-a');
    String? sentEvent, sentToken;
    final scorer = ExamReferenceDrillScoringService(
      client: client,
      testTransport: (id, token) async {
        sentEvent = id;
        sentToken = token;
        return [_response(step: 'section_location', correct: false)];
      },
    );
    final grade = await scorer.scoreRecordedStep(
      expectedOwnerId: 'account-a',
      eventId: event,
      answerToken: ' 1.1 ',
    );
    expect(sentEvent, event);
    expect(sentToken, '1.1');
    expect(grade.step, 'section_location');
    expect(grade.isCorrect, false);
    expect(grade.scoringVersion, 2);
    expect(grade.gradedAt, DateTime.utc(2027, 1, 1, 10));
  });

  test('Rejects account switch during the asynchronous scoring call', () async {
    final client = _MutableClient();
    client.authStub.current = _account('account-a');
    final completer = Completer<dynamic>();
    final scorer = ExamReferenceDrillScoringService(
      client: client,
      testTransport: (id, token) => completer.future,
    );
    final pending = scorer.scoreRecordedStep(
      expectedOwnerId: 'account-a',
      eventId: event,
      answerToken: 'a',
    );
    client.authStub.current = _account('account-b');
    completer.complete([_response()]);
    await expectLater(pending, throwsStateError);
  });

  test('Never issues scoring network requests for invalid IDs or tokens', () async {
    final client = _MutableClient();
    client.authStub.current = _account('account-a');
    var requests = 0;
    final scorer = ExamReferenceDrillScoringService(
      client: client,
      testTransport: (id, token) async {
        requests++;
        return [_response()];
      },
    );
    await expectLater(
      scorer.scoreRecordedStep(
        expectedOwnerId: 'account-a',
        eventId: 'not-a-uuid',
        answerToken: 'a',
      ),
      throwsArgumentError,
    );
    await expectLater(
      scorer.scoreRecordedStep(
        expectedOwnerId: 'account-a',
        eventId: event,
        answerToken: 'no answer ✨',
      ),
      throwsArgumentError,
    );
    expect(requests, 0);
  });

  test('Malformed RPC response never becomes a verified grade', () async {
    final client = _MutableClient();
    client.authStub.current = _account('account-a');
    final scorer = ExamReferenceDrillScoringService(
      client: client,
      testTransport: (id, token) async => [{
        ..._response(),
        'is_correct': 'true',
      }],
    );
    await expectLater(
      scorer.scoreRecordedStep(
        expectedOwnerId: 'account-a',
        eventId: event,
        answerToken: 'a',
      ),
      throwsFormatException,
    );
  });
}
