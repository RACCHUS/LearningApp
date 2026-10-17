import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/word_learning.dart';
import 'package:learning_pwa/services/word_list_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test_helpers/fake_supabase_client.dart';

void main() {
  User currentUser() => User(
        id: 'student-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-16T00:00:00Z',
      );

  WordListEntry entry(String id, String word) => WordListEntry(
        id: id,
        listId: 'list-1',
        word: word,
        formKey: WordFormIdentity.formKey(word: word),
      );

  test('unreviewed words are due and previously mastered word is not', () async {
    final existing = entry('word-1', 'liability');
    final newWord = entry('word-2', 'reluctant');
    final fake = FakeSupabaseClient(currentUser: currentUser());
    fake.setTableData('review_items', [
      // An older review from an unrelated lesson must not affect these words.
      {
        'user_id': 'student-1',
        'content_type': 'term',
        'content_id': existing.formKey,
        'next_review_date': '2026-09-01T00:00:00Z',
      },
      {
        'user_id': 'student-1',
        'content_type': 'word_skill',
        'content_id': WordFormIdentity.spellingReviewContentId(existing.formKey),
        'next_review_date': '2026-11-01T00:00:00Z',
      },
    ]);

    final due = await WordListService(client: fake).dueSpellingKeys(
      [existing, newWord],
      now: DateTime.utc(2026, 10, 17),
    );
    expect(due, {newWord.formKey});
  });

  test('due-word query with no entries is a no-op', () async {
    final fake = FakeSupabaseClient(currentUser: currentUser());
    final due = await WordListService(client: fake)
        .dueSpellingKeys([], now: DateTime.utc(2026, 10, 17));
    expect(due, isEmpty);
  });

  test('a due word stays scheduled consistently across separate lists', () async {
    final wordA = entry('word-1', 'color');
    final wordB = WordListEntry(
      id: 'word-2',
      listId: 'list-2',
      word: 'COLOR',
      formKey: WordFormIdentity.formKey(word: 'COLOR'),
    );
    final fake = FakeSupabaseClient(currentUser: currentUser());
    fake.setTableData('review_items', [{
      'user_id': 'student-1',
      'content_type': 'word_skill',
      'content_id': WordFormIdentity.spellingReviewContentId(wordA.formKey),
      'next_review_date': '2026-10-15T00:00:00Z',
    }]);
    final due = await WordListService(client: fake).dueSpellingKeys(
      [wordA, wordB],
      now: DateTime.utc(2026, 10, 17),
    );
    expect(due, {wordA.formKey});
    expect(wordB.formKey, wordA.formKey);
  });

  test('forget is deliberately scoped to a word skill, never a list', () async {
    final fake = FakeSupabaseClient(currentUser: currentUser());
    final target = entry('word-1', 'liability');
    fake.setTableData('review_items', [{
      'user_id': 'student-1',
      'content_id': WordFormIdentity.spellingReviewContentId(target.formKey),
      'content_type': 'word_skill',
    }]);
    await WordListService(client: fake).forgetSpellingProgress(target);
    expect(
      fake.deletedIds,
      contains(WordFormIdentity.spellingReviewContentId(target.formKey)),
    );
  });
}
