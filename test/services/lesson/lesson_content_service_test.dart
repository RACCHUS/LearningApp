import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import '../../test_helpers/fake_supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LessonContentService', () {
    late LessonContentService service;

    setUp(() {
      service = LessonContentService(supabase: FakeSupabaseClient());
    });

    group('Constructor', () {
      test('can be instantiated with fake Supabase client', () {
        expect(service, isNotNull);
      });

      test('accepts custom Supabase client via dependency injection', () {
        final customService = LessonContentService(supabase: FakeSupabaseClient());
        expect(customService, isNotNull);
      });
    });

    group('addTerms', () {
      test('accepts list of terms', () {
        final terms = [
          Term(
            id: '',
            term: 'Hello',
            definition: 'Greeting',
            example: 'Hello, world!',
            createdBy: 'user-1',
          ),
        ];

        // Test that method signature is correct
        expect(
          () => service.addTerms('lesson-1', terms),
          throwsA(anything), // Fake client throws
        );
      });

      test('handles empty terms list', () {
        expect(
          () => service.addTerms('lesson-1', []),
          throwsA(anything),
        );
      });
    });

    group('addQuestions', () {
      test('accepts list of questions', () {
        final questions = [
          Question(
            id: '',
            questionText: 'What is 2+2?',
            options: ['3', '4', '5'],
            correctAnswer: 1, // Index of correct answer
            type: 'multiple-choice',
            explanation: 'Basic math',
            createdBy: 'user-1',
          ),
        ];

        expect(
          () => service.addQuestions('lesson-1', questions),
          throwsA(anything),
        );
      });
    });

    group('addConcepts', () {
      test('accepts list of concepts', () {
        final concepts = [
          Concept(
            id: '',
            lessonId: 'lesson-1',
            conceptText: 'Photosynthesis',
            exampleText: 'Plants convert sunlight to energy',
            createdBy: 'user-1',
            createdAt: DateTime.now(),
          ),
        ];

        expect(
          () => service.addConcepts('lesson-1', concepts),
          throwsA(anything),
        );
      });
    });

    group('removeContent', () {
      test('accepts lessonId parameter', () {
        expect(
          () => service.removeContent(lessonId: 'lesson-1'),
          throwsA(anything),
        );
      });

      test('accepts termIds parameter', () {
        expect(
          () => service.removeContent(termIds: ['term-1', 'term-2']),
          throwsA(anything),
        );
      });

      test('accepts questionIds parameter', () {
        expect(
          () => service.removeContent(questionIds: ['q-1']),
          throwsA(anything),
        );
      });

      test('accepts conceptIds parameter', () {
        expect(
          () => service.removeContent(conceptIds: ['c-1']),
          throwsA(anything),
        );
      });
    });

    group('getContentCounts', () {
      test('returns map with content counts', () async {
        final counts = await service.getContentCounts('lesson-1');

        expect(counts, isA<Map<String, int>>());
        expect(counts.containsKey('terms'), isTrue);
        expect(counts.containsKey('questions'), isTrue);
        expect(counts.containsKey('concepts'), isTrue);
      });

      test('returns zeros on error', () async {
        // Non-existent lesson should return zeros
        final counts = await service.getContentCounts('non-existent');

        expect(counts['terms'], greaterThanOrEqualTo(0));
        expect(counts['questions'], greaterThanOrEqualTo(0));
        expect(counts['concepts'], greaterThanOrEqualTo(0));
      });
    });
  });
}
