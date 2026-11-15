import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_part_practice_history_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../test_helpers/fake_supabase_client.dart';

const _owner = 'owner-aaaaaaaa-1111';
const _other = 'owner-bbbbbbbb-2222';
const _version = 'version-1';
const _part = 'part-a';

User _user(String id, {bool anonymous = false}) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-11-15T00:00:00Z',
      isAnonymous: anonymous,
    );

Map<String, dynamic> _row(
  String id, {
  String owner = _owner,
  String version = _version,
  String part = _part,
  int questions = 10,
  int correct = 7,
  int partial = 1,
  double score = 0.75,
}) =>
    {
      'id': id,
      'owner_id': owner,
      'target_id': 'target-1',
      'target_version_id': version,
      'exam_part_key': part,
      'curriculum_root_node_id': 'root-a',
      'practice_kind': 'mock',
      'completed_at': '2026-11-14T10:00:00Z',
      'question_count': questions,
      'fully_correct_count': correct,
      'partial_count': partial,
      'practice_score': score,
      'question_edition_fingerprint': 'fingerprint-0123456789',
    };

FakeSupabaseClient _client({User? user, List<Map<String, dynamic>>? rows}) {
  final fake = FakeSupabaseClient(currentUser: user ?? _user(_owner));
  fake.setTableData('exam_part_practice_attempts', rows ?? [
    _row('a1'),
    _row('a2'),
    _row('other-owner', owner: _other),
    _row('other-version', version: 'version-2'),
    _row('other-part', part: 'part-b'),
  ]);
  return fake;
}

void main() {
  group('ExamPartPracticeHistoryService owner gate', () {
    for (final entry in <String, User?>{
      'signed out': null,
      'anonymous guest': _user(_owner, anonymous: true),
      'different account': _user(_other),
    }.entries) {
      test('${entry.key} cannot read, export or erase', () async {
        final fake = FakeSupabaseClient(currentUser: entry.value);
        var rpcCalls = 0;
        fake.rpcHandler = (fn, {params}) => rpcCalls++;
        final service = ExamPartPracticeHistoryService(client: fake);

        await expectLater(
          service.readPart(
              expectedOwnerId: _owner,
              targetVersionId: _version,
              examPartKey: _part),
          throwsStateError,
        );
        await expectLater(
          service.exportPartJson(
              expectedOwnerId: _owner,
              targetVersionId: _version,
              examPartKey: _part),
          throwsStateError,
        );
        await expectLater(
          service.erasePart(
              expectedOwnerId: _owner,
              targetVersionId: _version,
              examPartKey: _part),
          throwsStateError,
        );
        expect(rpcCalls, 0, reason: 'erasure must not reach the server');
      });
    }
  });

  group('readPart', () {
    test('returns only the owner\'s rows for the exact version and part',
        () async {
      final service = ExamPartPracticeHistoryService(client: _client());
      final attempts = await service.readPart(
          expectedOwnerId: _owner,
          targetVersionId: _version,
          examPartKey: _part);
      expect(attempts.map((a) => a.id), ['a1', 'a2']);
      expect(attempts.first.practiceScore, 0.75);
    });

    test('rejects empty keys and unbounded pages before querying', () async {
      final service = ExamPartPracticeHistoryService(client: _client());
      for (final args in [
        ('', _part, 100),
        (_version, '', 100),
        (_version, _part, 0),
        (_version, _part, 501),
      ]) {
        await expectLater(
          service.readPart(
              expectedOwnerId: _owner,
              targetVersionId: args.$1,
              examPartKey: args.$2,
              limit: args.$3),
          throwsArgumentError,
          reason: 'args $args',
        );
      }
    });

    test('an invalid score row fails loudly', () async {
      final service = ExamPartPracticeHistoryService(
          client: _client(rows: [_row('bad', correct: 9, partial: 5)]));
      await expectLater(
        service.readPart(
            expectedOwnerId: _owner,
            targetVersionId: _version,
            examPartKey: _part),
        throwsFormatException,
      );
    });
  });

  group('exportPartJson', () {
    test('labels the export as practice and reports truncation', () async {
      final service = ExamPartPracticeHistoryService(client: _client());

      final full = jsonDecode(await service.exportPartJson(
          expectedOwnerId: _owner,
          targetVersionId: _version,
          examPartKey: _part)) as Map<String, dynamic>;
      expect(full['schema'], 'exm03-part-attempt-summary-v1');
      expect(full['official_exam_result'], isFalse);
      expect(full['possibly_truncated'], isFalse);
      expect((full['attempts'] as List).length, 2);

      final page = jsonDecode(await service.exportPartJson(
          expectedOwnerId: _owner,
          targetVersionId: _version,
          examPartKey: _part,
          limit: 2)) as Map<String, dynamic>;
      expect(page['page_limit'], 2);
      expect(page['possibly_truncated'], isTrue,
          reason: 'a full page may hide more rows');
    });
  });

  group('erasePart', () {
    test('calls the exact-part erase RPC with version and part', () async {
      final fake = _client();
      final calls = <(String, Map<String, dynamic>?)>[];
      fake.rpcHandler = (fn, {params}) => calls.add((fn, params));
      await ExamPartPracticeHistoryService(client: fake).erasePart(
          expectedOwnerId: _owner,
          targetVersionId: _version,
          examPartKey: _part);
      expect(calls, hasLength(1));
      expect(calls.single.$1, 'exm03_erase_part_attempts');
      expect(calls.single.$2,
          {'p_target_version_id': _version, 'p_exam_part_key': _part});
    });

    test('rejects empty keys without calling the server', () async {
      final fake = _client();
      var rpcCalls = 0;
      fake.rpcHandler = (fn, {params}) => rpcCalls++;
      final service = ExamPartPracticeHistoryService(client: fake);
      await expectLater(
        service.erasePart(
            expectedOwnerId: _owner, targetVersionId: '', examPartKey: _part),
        throwsArgumentError,
      );
      await expectLater(
        service.erasePart(
            expectedOwnerId: _owner, targetVersionId: _version, examPartKey: ''),
        throwsArgumentError,
      );
      expect(rpcCalls, 0);
    });

    test('an account switch during the call is reported, not swallowed',
        () async {
      final fake = _client();
      fake.rpcHandler = (fn, {params}) {
        fake.auth.currentUser = _user(_other);
        return null;
      };
      await expectLater(
        ExamPartPracticeHistoryService(client: fake).erasePart(
            expectedOwnerId: _owner,
            targetVersionId: _version,
            examPartKey: _part),
        throwsStateError,
      );
    });
  });
}
