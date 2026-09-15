import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_catalog_service.dart';

import '../../test_helpers/fake_supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog returns every lesson Supabase makes readable regardless of owner', () async {
    final client = FakeSupabaseClient();
    client.setTableData('lessons', [
      {
        'id': 'mine',
        'title': 'My Lesson',
        'description': null,
        'tags': <String>[],
        'user_id': 'current-user',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      },
      {
        'id': 'shared',
        'title': 'Shared Lesson',
        'description': null,
        'tags': <String>[],
        'user_id': 'another-user',
        'created_at': '2026-01-02T00:00:00.000Z',
        'updated_at': '2026-01-02T00:00:00.000Z',
      },
      {
        'id': 'legacy-public',
        'title': 'Legacy Public Lesson',
        'description': null,
        'tags': <String>[],
        'user_id': null,
        'created_at': '2026-01-03T00:00:00.000Z',
        'updated_at': '2026-01-03T00:00:00.000Z',
      },
    ]);

    final lessons = await LessonCatalogService(supabase: client).getReadableLessons();

    expect(lessons.map((lesson) => lesson.id).toSet(), {
      'mine',
      'shared',
      'legacy-public',
    });
  });
}
