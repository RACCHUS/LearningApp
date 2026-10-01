import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../test_helpers/fake_supabase_client.dart';

void main() {
  test(
    'flashcard-only set is not empty and contributes to item count',
    () async {
      final fake = FakeSupabaseClient();
      fake.setTableData('study_sets', [
        {
          'id': 'set-1',
          'user_id': 'user-1',
          'title': 'Standalone cards',
          'created_at': '2026-09-29T00:00:00Z',
          'updated_at': '2026-09-29T00:00:00Z',
          'study_set_flashcards': [
            {'flashcard_id': 'flashcard-1'},
          ],
        },
      ]);

      final set = await SavedStudySetService(
        supabase: fake,
      ).getStudySet('set-1');

      expect(set.totalItems, 1);
      expect(set.isEmpty, isFalse);
    },
  );

  test('standalone study-set flashcard appears in flashcard content', () async {
    final fake = FakeSupabaseClient();
    fake.setTableData('study_set_flashcards', [
      {
        'study_set_id': 'set-1',
        'sort_order': 0,
        'flashcards': {
          'id': 'flashcard-1',
          'front': 'What is a subnet?',
          'back': 'A logical subdivision of a network.',
          'user_id': 'user-1',
        },
      },
    ]);
    final set = SavedStudySet(
      id: 'set-1',
      userId: 'user-1',
      title: 'Networking',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final content = await SavedStudySetService(
      supabase: fake,
    ).fetchStudySetContent(set);

    expect(content.terms, hasLength(1));
    expect(content.terms.single.term, 'What is a subnet?');
    expect(
      content.terms.single.definition,
      'A logical subdivision of a network.',
    );
    expect(content.totalItems, 1);
  });

  test('duplicating a set keeps standalone flashcard links', () async {
    final fake = FakeSupabaseClient(
      currentUser: User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-09-29T00:00:00Z',
      ),
    );
    fake.setTableData('study_sets', [
      {
        'id': 'set-1',
        'user_id': 'user-1',
        'title': 'Networking',
        'lesson_ids': ['lesson-1'],
        'created_at': '2026-09-29T00:00:00Z',
        'updated_at': '2026-09-29T00:00:00Z',
        'study_set_flashcards': [
          {'flashcard_id': 'flashcard-2', 'sort_order': 20},
          {'flashcard_id': 'flashcard-1', 'sort_order': 10},
        ],
      },
    ]);

    final duplicate = await SavedStudySetService(
      supabase: fake,
    ).duplicateStudySet('set-1');

    expect(duplicate.flashcardIds, ['flashcard-1', 'flashcard-2']);
    expect(duplicate.lessonIds, ['lesson-1']);
    expect(
      fake.insertedRecords,
      contains(containsPair('study_set_id', duplicate.id)),
    );
    expect(
      fake.insertedRecords,
      contains(containsPair('flashcard_id', 'flashcard-1')),
    );
    final copiedLinks = fake.insertedRecords
        .where((row) => row['study_set_id'] == duplicate.id)
        .toList();
    expect(copiedLinks.map((row) => row['flashcard_id']), [
      'flashcard-1',
      'flashcard-2',
    ]);
    expect(copiedLinks.map((row) => row['sort_order']), [0, 1]);
  });
}
