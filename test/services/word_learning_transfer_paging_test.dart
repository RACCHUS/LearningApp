import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/word_learning.dart';
import 'package:learning_pwa/services/word_learning_transfer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test_helpers/fake_supabase_client.dart';

void main() {
  test('private export contains all words and review history beyond API row cap',
      () async {
    const learner = '11111111-1111-4111-8111-111111111111';
    const listId = '22222222-2222-4222-8222-222222222222';
    final fake = FakeSupabaseClient(
      currentUser: User(
        id: learner,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-17T00:00:00Z',
      ),
    );
    fake.setTableData('word_lists', [
      {
        'id': listId,
        'user_id': learner,
        'title': 'Lots of words',
        'description': null,
      },
    ]);
    fake.setTableData('word_list_entries', [
      for (var i = 0; i < 1001; i++)
        {
          'id': 'entry-$i',
          'list_id': listId,
          'word': 'word$i',
          'form_key': WordFormIdentity.formKey(word: 'word$i'),
          'locale': 'en-US',
          'entry_kind': 'ordinary',
          'case_policy': 'ignore_case',
          'accepted_forms': <String>[],
          'pronunciation_hint': null,
          'sort_order': i,
        },
    ]);
    fake.setTableData('review_items', [
      for (var i = 0; i < 1001; i++)
        {
          'user_id': learner,
          'content_type': 'word_skill',
          'content_id': WordFormIdentity.spellingReviewContentId(
            WordFormIdentity.formKey(word: 'word$i'),
          ),
          'title': 'word$i',
          'repetition_level': 1,
          'ease_factor': 2.5,
          'next_review_date': '2026-11-01T00:00:00Z',
          'last_reviewed_at': '2026-10-17T00:00:00Z',
          'total_reviews': 1,
          'correct_reviews': 1,
        },
    ]);

    final raw = await WordLearningTransfer(client: fake).exportJson();
    final result = WordLearningTransfer.validate(raw);
    final lists = result['lists'] as List;
    expect((lists.single['entries'] as List), hasLength(1001));
    expect(result['reviews'], hasLength(1001));
    expect(jsonDecode(raw)['format'], WordLearningTransfer.format);
  });
}
