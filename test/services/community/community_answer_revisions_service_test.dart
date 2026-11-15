import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_answer_revision.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../test_helpers/fake_supabase_client.dart';

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-11-15T00:00:00Z',
    );

Map<String, dynamic> _row(String answerId, int n, {String? reason}) => {
      'id': 'rev-$answerId-$n',
      'answer_id': answerId,
      'revision_number': n,
      'body_markdown': 'Version $n of $answerId',
      'editor_id': 'u1',
      'edit_reason': reason,
      'source_answer_id': 'src-$n',
      'created_at': '2026-11-0${n}T10:00:00Z',
    };

/// learning.answer_revisions: the service only talks to the two RPCs and
/// never throws into the Q&A sheet.
void main() {
  test('model parses server rows, including the source answer', () {
    final r = CommunityAnswerRevision.fromJson(_row('a1', 2, reason: 'Add an example.'));
    expect(r.answerId, 'a1');
    expect(r.revisionNumber, 2);
    expect(r.editReason, 'Add an example.');
    expect(r.sourceAnswerId, 'src-2');
    expect(r.createdAt, DateTime.utc(2026, 11, 2, 10));
    expect(CommunityAnswerRevision.fromJson(r.toJson()).sourceAnswerId, 'src-2');
  });

  test('fetch groups by answer, newest version first', () async {
    final calls = <(String, Map<String, dynamic>?)>[];
    final client = FakeSupabaseClient(currentUser: _user('u1'))
      ..rpcHandler = (fn, {params}) {
        calls.add((fn, params));
        return [_row('a1', 1), _row('b1', 1), _row('a1', 2)];
      };
    final map = await CommunityQaService(supabase: client)
        .fetchAnswerRevisions(['a1', 'b1', 'a1']);

    expect(calls.single.$1, 'list_community_answer_revisions');
    expect(calls.single.$2, {'p_answer_ids': ['a1', 'b1']}, reason: 'deduplicated');
    expect(map['a1']!.map((r) => r.revisionNumber), [2, 1]);
    expect(map['b1']!.single.bodyMarkdown, 'Version 1 of b1');
  });

  test('asks about at most the server cap of answers', () async {
    Map<String, dynamic>? sent;
    final client = FakeSupabaseClient(currentUser: _user('u1'))
      ..rpcHandler = (fn, {params}) {
        sent = params;
        return <dynamic>[];
      };
    await CommunityQaService(supabase: client)
        .fetchAnswerRevisions([for (var i = 0; i < 150; i++) 'a$i']);
    expect((sent!['p_answer_ids'] as List).length,
        CommunityQaService.maxAnswersPerRequest);
  });

  test('no request when signed out or nothing to ask about', () async {
    var called = 0;
    final signedOut = FakeSupabaseClient()
      ..rpcHandler = (fn, {params}) => called++;
    expect(await CommunityQaService(supabase: signedOut).fetchAnswerRevisions(['a1']), isEmpty);
    final signedIn = FakeSupabaseClient(currentUser: _user('u1'))
      ..rpcHandler = (fn, {params}) => called++;
    expect(await CommunityQaService(supabase: signedIn).fetchAnswerRevisions([]), isEmpty);
    expect(called, 0);
  });

  test('a refused or failed fetch yields no history instead of throwing', () async {
    final client = FakeSupabaseClient(currentUser: _user('u1'))
      ..rpcHandler = (fn, {params}) => throw Exception('feature_disabled');
    expect(await CommunityQaService(supabase: client).fetchAnswerRevisions(['a1']), isEmpty);
  });

  test('link sends both answer ids and returns the version count', () async {
    final calls = <(String, Map<String, dynamic>?)>[];
    final client = FakeSupabaseClient(currentUser: _user('u1'))
      ..rpcHandler = (fn, {params}) {
        calls.add((fn, params));
        return 2;
      };
    final n = await CommunityQaService(supabase: client)
        .linkAnswerResubmission(answerId: 'new', previousAnswerId: 'old');
    expect(n, 2);
    expect(calls.single.$1, 'link_community_answer_resubmission');
    expect(calls.single.$2, {'p_answer_id': 'new', 'p_previous_answer_id': 'old'});
  });

  test('a failed link is logged, not thrown: the resubmission is already saved', () async {
    final client = FakeSupabaseClient(currentUser: _user('u1'))
      ..rpcHandler = (fn, {params}) => throw Exception('already_linked');
    expect(
      await CommunityQaService(supabase: client)
          .linkAnswerResubmission(answerId: 'new', previousAnswerId: 'old'),
      isNull,
    );
  });
}
