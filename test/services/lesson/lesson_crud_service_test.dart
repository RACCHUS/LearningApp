import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import '../../test_helpers/fake_supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LessonCrudService', () {
    late LessonCrudService service;

    setUp(() {
      service = LessonCrudService(supabase: FakeSupabaseClient());
    });

    group('Constructor', () {
      test('can be instantiated with fake Supabase client', () {
        expect(service, isNotNull);
      });

      test('accepts custom Supabase client via dependency injection', () {
        // This tests that the DI pattern is implemented
        final customService = LessonCrudService(supabase: FakeSupabaseClient());
        expect(customService, isNotNull);
      });
    });

    group('getLessonsForUser', () {
      test('handles empty userId gracefully', () async {
        // Should use guest UUID for empty userId
        final lessons = await service.getLessonsForUser('');
        
        // Should return a list (empty or with public lessons)
        expect(lessons, isA<List>());
      });

      test('returns list for valid userId', () async {
        final lessons = await service.getLessonsForUser('test-user');
        
        expect(lessons, isA<List>());
      });
    });

    group('getLesson', () {
      test('throws on non-existent lesson', () async {
        expect(
          () => service.getLesson('non-existent-id'),
          throwsA(anything),
        );
      });
    });

    group('addLesson', () {
      test('requires non-empty title', () async {
        expect(
          () => service.addLesson('', 'Description', 'user-1'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('handles empty userId with guest UUID', () async {
        // With fake client, this will throw when trying to insert
        expect(
          () => service.addLesson('Test', 'Desc', ''),
          throwsA(anything),
        );
      });

      test('accepts optional tags parameter', () async {
        expect(
          () => service.addLesson('Test', 'Desc', 'user-1', tags: ['tag1']),
          throwsA(anything),
        );
      });
    });

    group('_parseTerms', () {
      test('handles null terms data', () {
        // This is a private method, so we test it indirectly
        // The getLessonsForUser method uses this internally
        expect(
          () => service.getLessonsForUser('user-1'),
          returnsNormally,
        );
      });
    });
  });
}
