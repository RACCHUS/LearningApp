import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/user_curriculum_resource_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test_helpers/fake_supabase_client.dart';

void main() {
  final owner = User(
    id: 'owner-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-10-01T00:00:00Z',
  );

  test('listForNodes skips the database for an empty set', () async {
    final service = UserCurriculumResourceService(
      supabase: FakeSupabaseClient(currentUser: owner),
    );
    expect(await service.listForNodes(const <String>{}), isEmpty);
  });

  test('listForNodes includes joined lesson titles for selected nodes', () async {
    final fake = FakeSupabaseClient(currentUser: owner);
    fake.setTableData('user_curriculum_resources', [
      {
        'id': 'attachment-1',
        'user_id': 'owner-1',
        'curriculum_node_id': 'node-1',
        'lesson_id': 'lesson-1',
        'relationship': 'personal_study',
        'sort_order': 2,
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
        'lessons': {'title': 'My Phishing Review'},
      },
      {
        'id': 'attachment-2',
        'user_id': 'owner-1',
        'curriculum_node_id': 'other-node',
        'lesson_id': 'lesson-2',
        'relationship': 'personal_study',
        'sort_order': 0,
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
        'lessons': {'title': 'Other'},
      },
    ]);

    final rows = await UserCurriculumResourceService(supabase: fake)
        .listForNodes({'node-1'});

    expect(rows, hasLength(1));
    expect(rows.single.lessonTitle, 'My Phishing Review');
    expect(rows.single.curriculumNodeId, 'node-1');
  });

  test('attach sends typed IDs and personal_study relationship', () async {
    final fake = FakeSupabaseClient(currentUser: owner);
    final attached = await UserCurriculumResourceService(supabase: fake)
        .attachPersonalLesson(curriculumNodeId: 'node-1', lessonId: 'lesson-1');

    expect(fake.insertedRecords, hasLength(1));
    expect(fake.insertedRecords.single['user_id'], 'owner-1');
    expect(fake.insertedRecords.single['curriculum_node_id'], 'node-1');
    expect(fake.insertedRecords.single['lesson_id'], 'lesson-1');
    expect(fake.insertedRecords.single['relationship'], 'personal_study');
    expect(attached.lessonId, 'lesson-1');
  });

  test('remove deletes the attachment, not the lesson', () async {
    final fake = FakeSupabaseClient(currentUser: owner);
    fake.setTableData('user_curriculum_resources', [
      {
        'id': 'attachment-1',
        'user_id': 'owner-1',
        'curriculum_node_id': 'node-1',
        'lesson_id': 'lesson-1',
      },
    ]);
    await UserCurriculumResourceService(supabase: fake)
        .removePersonalLesson(curriculumNodeId: 'node-1', lessonId: 'lesson-1');

    expect(fake.deletedIds, isNotEmpty);
    expect(fake.insertedRecords, isEmpty);
  });
}
