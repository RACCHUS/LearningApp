import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/word_learning.dart';
import 'package:learning_pwa/services/word_learning_transfer.dart';
import 'package:learning_pwa/services/word_list_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test_helpers/fake_supabase_client.dart';

void main() {
  const originUser = '11111111-1111-4111-8111-111111111111';
  const destUser = '99999999-9999-4999-8999-999999999999';
  const sourceListId = '22222222-2222-4222-8222-222222222222';
  const destListId = 'dest-list-1';

  final keyLiability = WordFormIdentity.formKey(word: 'liability');
  final keyReluctant = WordFormIdentity.formKey(word: 'reluctant');
  final reviewLiability = WordFormIdentity.spellingReviewContentId(keyLiability);
  final reviewReluctant = WordFormIdentity.spellingReviewContentId(keyReluctant);

  final backupJson = jsonEncode({
    'format': WordLearningTransfer.format,
    'version': 1,
    'source_user_id': originUser,
    'exported_at': DateTime.utc(2026, 10, 16).toIso8601String(),
    'lists': [
      {
        'source_id': sourceListId,
        'title': 'Vocabulary List',
        'description': 'Important words',
        'entries': [
          {
            'word': 'liability',
            'form_key': keyLiability,
            'locale': 'en-US',
            'entry_kind': 'ordinary',
            'case_policy': 'ignore_case',
            'accepted_forms': <String>[],
            'pronunciation_hint': null,
            'meaning': 'Financial or legal obligation',
            'sort_order': 0,
          },
          {
            'word': 'reluctant',
            'form_key': keyReluctant,
            'locale': 'en-US',
            'entry_kind': 'ordinary',
            'case_policy': 'ignore_case',
            'accepted_forms': <String>[],
            'pronunciation_hint': null,
            'meaning': 'Unwilling and hesitant',
            'sort_order': 1,
          },
        ],
      }
    ],
    'reviews': [
      {
        'content_id': reviewLiability,
        'title': 'liability',
        'repetition_level': 1,
        'ease_factor': 2.5,
        'next_review_date': DateTime.utc(2026, 10, 20).toIso8601String(),
        'last_reviewed_at': DateTime.utc(2026, 10, 16).toIso8601String(),
        'total_reviews': 1,
        'correct_reviews': 1,
      },
      {
        'content_id': reviewReluctant,
        'title': 'reluctant',
        'repetition_level': 2,
        'ease_factor': 2.5,
        'next_review_date': DateTime.utc(2026, 10, 28).toIso8601String(),
        'last_reviewed_at': DateTime.utc(2026, 10, 16).toIso8601String(),
        'total_reviews': 2,
        'correct_reviews': 2,
      },
    ],
  });

  test('interrupted import recovery: resumes cleanly, avoids duplicates, preserves existing data',
      () async {
    final fake = FakeSupabaseClient(
      currentUser: User(
        id: destUser,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-18T00:00:00Z',
      ),
    );

    // Simulate database state after an INTERRUPTED partial import:
    // - The destination list was created with import_origin
    // - Only the first entry ('liability') was written
    // - Only the first review ('liability') was written
    // - The transfer died before 'reluctant' entry & review were processed
    fake.setTableData('word_lists', [
      {
        'id': destListId,
        'user_id': destUser,
        'title': 'Vocabulary List',
        'description': 'Important words',
        'import_origin': '$originUser:$sourceListId',
      },
    ]);

    fake.setTableData('word_list_entries', [
      {
        'id': 'entry-liability',
        'list_id': destListId,
        'word': 'liability',
        'form_key': keyLiability,
        'locale': 'en-US',
        'entry_kind': 'ordinary',
        'case_policy': 'ignore_case',
        'accepted_forms': <String>[],
        'pronunciation_hint': null,
        'meaning': 'Financial or legal obligation',
        'sort_order': 0,
      },
    ]);

    fake.setTableData('review_items', [
      {
        'id': 'review-liability',
        'user_id': destUser,
        'content_type': 'word_skill',
        'content_id': reviewLiability,
        'title': 'liability',
        'repetition_level': 1,
        'ease_factor': 2.5,
        'next_review_date': '2026-10-20T00:00:00Z',
        'last_reviewed_at': '2026-10-16T00:00:00Z',
        'total_reviews': 1,
        'correct_reviews': 1,
      },
    ]);

    // Retry import using the same backup
    final transfer = WordLearningTransfer(
      client: fake,
      lists: WordListService(client: fake),
    );
    final recoveryResult = await transfer.importJson(backupJson);

    // Assertions for Recovery:
    // 1. Did NOT recreate the existing list
    expect(recoveryResult.listsCreated, 0,
        reason: 'Existing list matched by import_origin must not be duplicated');

    // 2. Only inserted the 1 remaining word entry ('reluctant')
    expect(recoveryResult.wordsCreated, 1,
        reason: 'Only the unimported word should be created');

    // 3. Only inserted the 1 remaining review item ('reluctant')
    expect(recoveryResult.reviewsCreated, 1,
        reason: 'Only the unimported review item should be created');

    // 4. Preserved existing liability entry and review without clobbering
    expect(recoveryResult.destinationConflictsPreserved, greaterThanOrEqualTo(2),
        reason: 'Existing liability entry and review should be preserved');

    // Verify database inserts: exactly 1 entry and 1 review were added
    final addedEntries = fake.insertedRecords
        .where((r) => r.containsKey('form_key') && r['form_key'] == keyReluctant);
    expect(addedEntries, hasLength(1),
        reason: 'Exactly one missing entry was inserted');

    final addedReviews = fake.insertedRecords
        .where((r) => r.containsKey('content_id') && r['content_id'] == reviewReluctant);
    expect(addedReviews, hasLength(1),
        reason: 'Exactly one missing review was inserted');

    // Verify NO duplicate liability record was inserted
    final dupEntries = fake.insertedRecords
        .where((r) => r.containsKey('form_key') && r['form_key'] == keyLiability);
    expect(dupEntries, isEmpty,
        reason: 'Pre-existing entry must never be re-inserted');

    final dupReviews = fake.insertedRecords
        .where((r) => r.containsKey('content_id') && r['content_id'] == reviewLiability);
    expect(dupReviews, isEmpty,
        reason: 'Pre-existing review must never be re-inserted');
  });

  test('idempotent full re-import: subsequent retry makes 0 writes and creates 0 duplicates',
      () async {
    final fake = FakeSupabaseClient(
      currentUser: User(
        id: destUser,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-18T00:00:00Z',
      ),
    );

    // Both words and reviews are already present in destination
    fake.setTableData('word_lists', [
      {
        'id': destListId,
        'user_id': destUser,
        'title': 'Vocabulary List',
        'description': 'Important words',
        'import_origin': '$originUser:$sourceListId',
      },
    ]);

    fake.setTableData('word_list_entries', [
      {
        'id': 'entry-liability',
        'list_id': destListId,
        'word': 'liability',
        'form_key': keyLiability,
        'locale': 'en-US',
        'entry_kind': 'ordinary',
        'case_policy': 'ignore_case',
        'accepted_forms': <String>[],
        'pronunciation_hint': null,
        'meaning': 'Financial or legal obligation',
        'sort_order': 0,
      },
      {
        'id': 'entry-reluctant',
        'list_id': destListId,
        'word': 'reluctant',
        'form_key': keyReluctant,
        'locale': 'en-US',
        'entry_kind': 'ordinary',
        'case_policy': 'ignore_case',
        'accepted_forms': <String>[],
        'pronunciation_hint': null,
        'meaning': 'Unwilling and hesitant',
        'sort_order': 1,
      },
    ]);

    fake.setTableData('review_items', [
      {
        'id': 'review-liability',
        'user_id': destUser,
        'content_type': 'word_skill',
        'content_id': reviewLiability,
        'title': 'liability',
        'repetition_level': 1,
        'ease_factor': 2.5,
        'next_review_date': '2026-10-20T00:00:00Z',
        'last_reviewed_at': '2026-10-16T00:00:00Z',
        'total_reviews': 1,
        'correct_reviews': 1,
      },
      {
        'id': 'review-reluctant',
        'user_id': destUser,
        'content_type': 'word_skill',
        'content_id': reviewReluctant,
        'title': 'reluctant',
        'repetition_level': 2,
        'ease_factor': 2.5,
        'next_review_date': '2026-10-28T00:00:00Z',
        'last_reviewed_at': '2026-10-16T00:00:00Z',
        'total_reviews': 2,
        'correct_reviews': 2,
      },
    ]);

    final transfer = WordLearningTransfer(
      client: fake,
      lists: WordListService(client: fake),
    );
    final result = await transfer.importJson(backupJson);

    expect(result.listsCreated, 0);
    expect(result.wordsCreated, 0);
    expect(result.reviewsCreated, 0);
    expect(result.destinationConflictsPreserved, 4,
        reason: 'All 2 entries and 2 reviews should be recognized as conflicts and preserved');
    expect(fake.insertedRecords, isEmpty,
        reason: 'Zero new rows should be inserted during an idempotent re-run');
  });
}
