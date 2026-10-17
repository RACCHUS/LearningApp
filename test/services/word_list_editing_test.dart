import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/word_learning.dart';
import 'package:learning_pwa/services/word_list_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test_helpers/fake_supabase_client.dart';

void main() {
  final original = WordFormIdentity.formKey(word: 'liability');
  final changed = WordFormIdentity.formKey(word: 'reluctant');

  User testUser() => User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-16T00:00:00Z',
      );

  Map<String, dynamic> entryJson() => {
        'id': 'word-1',
        'list_id': 'list-1',
        'word': 'liability',
        'form_key': original,
        'locale': 'en-US',
        'entry_kind': 'ordinary',
        'case_policy': 'ignore_case',
        'accepted_forms': ['liabilities'],
        'pronunciation_hint': 'lie-ah-bility',
        'sort_order': 0,
      };

  test('new target identity resets word-specific exceptions, not review history',
      () async {
    final fake = FakeSupabaseClient(currentUser: testUser());
    fake.setTableData('word_list_entries', [entryJson()]);
    final service = WordListService(client: fake);
    await service.changeWordSpelling(
      WordListEntry.fromJson(entryJson()), 'reluctant',
    );
    final updated = (await service.getEntries('list-1')).single;
    expect(updated.word, 'reluctant');
    expect(updated.formKey, changed);
    expect(updated.acceptedForms, isEmpty);
    expect(updated.pronunciationHint, isNull);
    // No operation on review_items was performed: the old form's history is
    // retained for use in other lists.
    expect(fake.deletedIds, isEmpty);
  });

  test('cosmetic case edit retains stable identity and user preferences',
      () async {
    final fake = FakeSupabaseClient(currentUser: testUser());
    fake.setTableData('word_list_entries', [entryJson()]);
    final service = WordListService(client: fake);
    await service.changeWordSpelling(
      WordListEntry.fromJson(entryJson()), 'Liability',
    );
    final updated = (await service.getEntries('list-1')).single;
    expect(updated.formKey, original);
    expect(updated.acceptedForms, ['liabilities']);
    expect(updated.pronunciationHint, 'lie-ah-bility');
  });

  test('empty target spelling fails before any writes', () async {
    final fake = FakeSupabaseClient(currentUser: testUser());
    fake.setTableData('word_list_entries', [entryJson()]);
    final service = WordListService(client: fake);
    await expectLater(
      service.changeWordSpelling(WordListEntry.fromJson(entryJson()), ' '),
      throwsArgumentError,
    );
    final unchanged = (await service.getEntries('list-1')).single;
    expect(unchanged.formKey, original);
  });

  test('list title edit changes title without touching word entries', () async {
    final fake = FakeSupabaseClient(currentUser: testUser());
    fake.setTableData('word_lists', [{
      'id': 'list-1',
      'user_id': 'user-1',
      'title': 'Week 1',
      'description': null,
    }]);
    fake.setTableData('word_list_entries', [entryJson()]);
    final service = WordListService(client: fake);
    await service.renameList('list-1', 'Week 2');
    expect((await service.getLists()).single.title, 'Week 2');
    expect((await service.getEntries('list-1')).single.formKey, original);
  });
}
