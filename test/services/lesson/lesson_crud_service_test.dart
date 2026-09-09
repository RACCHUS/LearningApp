import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import '../../test_helpers/fake_supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LessonCrudService', () {
    late LessonCrudService service;
    late FakeSupabaseClient fakeClient;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      service = LessonCrudService(supabase: fakeClient);
    });
    
    tearDown(() {
      fakeClient.clearData();
    });

    group('Constructor', () {
      test('can be instantiated with fake Supabase client', () {
        expect(service, isNotNull);
      });

      test('accepts custom Supabase client via dependency injection', () {
        final customService = LessonCrudService(supabase: FakeSupabaseClient());
        expect(customService, isNotNull);
      });
    });

    group('getLessonsForUser', () {
      test('returns lessons for valid userId', () async {
        // Setup test data
        fakeClient.setTableData('lessons', [
          {
            'id': 'lesson-1',
            'title': 'Test Lesson 1',
            'description': 'Description 1',
            'tags': ['tag1'],
            'user_id': 'test-user',
            'created_at': '2025-01-01T00:00:00.000Z',
            'updated_at': '2025-01-01T00:00:00.000Z',
          },
          {
            'id': 'lesson-2',
            'title': 'Test Lesson 2',
            'description': 'Description 2',
            'tags': [],
            'user_id': 'test-user',
            'created_at': '2025-01-02T00:00:00.000Z',
            'updated_at': '2025-01-02T00:00:00.000Z',
          },
        ]);
        
        final lessons = await service.getLessonsForUser('test-user');
        
        expect(lessons, isA<List>());
        expect(lessons.length, 2);
        expect(lessons[0].title, 'Test Lesson 1');
        expect(lessons[1].title, 'Test Lesson 2');
      });
      
      test('returns empty list when no lessons exist', () async {
        fakeClient.setTableData('lessons', []);
        
        final lessons = await service.getLessonsForUser('test-user');
        
        expect(lessons, isEmpty);
      });

      test('handles empty userId by using guest UUID', () async {
        fakeClient.setTableData('lessons', [
          {
            'id': 'public-lesson',
            'title': 'Public Lesson',
            'description': 'A public lesson',
            'tags': [],
            'user_id': '00000000-0000-0000-0000-000000000000',
            'created_at': '2025-01-01T00:00:00.000Z',
            'updated_at': '2025-01-01T00:00:00.000Z',
          },
        ]);
        
        // Should not throw, should use guest UUID
        final lessons = await service.getLessonsForUser('');
        expect(lessons, isA<List>());
      });
    });

    group('getLesson', () {
      test('returns lesson with full content when found', () async {
        fakeClient.setTableData('lessons', [
          {
            'id': 'lesson-1',
            'title': 'Test Lesson',
            'description': 'Description',
            'tags': ['vocabulary'],
            'user_id': 'user-1',
            'created_at': '2025-01-01T00:00:00.000Z',
            'updated_at': '2025-01-01T00:00:00.000Z',
            'terms': [
              {'id': 'term-1', 'term': 'hello', 'definition': 'greeting'}
            ],
            'questions': [],
            'concepts': [],
          },
        ]);
        
        final lesson = await service.getLesson('lesson-1');
        
        expect(lesson.id, 'lesson-1');
        expect(lesson.title, 'Test Lesson');
        expect(lesson.terms.length, 1);
        expect(lesson.terms[0].term, 'hello');
      });
      
      test('throws when lesson not found', () async {
        fakeClient.setTableData('lessons', []);
        
        // The service wraps errors in AppException
        try {
          await service.getLesson('non-existent-id');
          fail('Expected an exception to be thrown');
        } catch (e) {
          expect(e, isA<AppException>());
        }
      });
    });

    group('addLesson', () {
      test('throws AppException for empty title', () async {
        expect(
          () => service.addLesson('', 'Description', 'user-1'),
          throwsA(isA<AppException>()),
        );
      });

      test('inserts lesson with correct data structure', () async {
        // The insert will add to insertedRecords, then select().single() needs data
        fakeClient.setTableData('lessons', [
          {
            'id': 'new-lesson-id',
            'title': 'New Lesson',
            'description': 'New Description',
            'tags': ['tag1'],
            'user_id': 'user-1',
            'created_at': '2025-01-01T00:00:00.000Z',
            'updated_at': '2025-01-01T00:00:00.000Z',
          },
        ]);
        
        final lesson = await service.addLesson('New Lesson', 'New Description', 'user-1', tags: ['tag1']);
        
        expect(lesson.title, 'New Lesson');
        expect(lesson.description, 'New Description');
        expect(fakeClient.insertedRecords, isNotEmpty);
        expect(fakeClient.insertedRecords.first['title'], 'New Lesson');
      });

      test('throws AuthenticationException when userId is empty and no session', () async {
        // Guests now use real anonymous auth sessions; an empty userId with no
        // active session must be rejected rather than falling back to a magic UUID.
        expect(
          () => service.addLesson('Guest Lesson', 'Desc', ''),
          throwsA(isA<AuthenticationException>()),
        );
      });
    });

    group('deleteLessonFromSupabase', () {
      test('deletes lesson by id', () async {
        fakeClient.setTableData('lessons', [
          {
            'id': 'lesson-to-delete',
            'title': 'Delete Me',
            'description': 'Will be deleted',
            'tags': [],
            'user_id': 'user-1',
            'created_at': '2025-01-01T00:00:00.000Z',
            'updated_at': '2025-01-01T00:00:00.000Z',
          },
        ]);
        
        await service.deleteLessonFromSupabase('lesson-to-delete');
        
        expect(fakeClient.deletedIds, contains('lesson-to-delete'));
      });
    });
  });
}
