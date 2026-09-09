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
    late FakeSupabaseClient fakeClient;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      service = LessonContentService(supabase: fakeClient);
    });
    
    tearDown(() {
      fakeClient.clearData();
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
      test('accepts list of terms and tracks insert', () async {
        final terms = [
          Term(
            id: '',
            term: 'Hello',
            definition: 'Greeting',
            example: 'Hello, world!',
            createdBy: 'user-1',
          ),
        ];

        await service.addTerms('lesson-1', terms);
        
        // Verify the insert was tracked
        expect(fakeClient.insertedRecords, isNotEmpty);
      });

      test('handles empty terms list', () async {
        await service.addTerms('lesson-1', []);
        
        // No terms to insert
        expect(fakeClient.insertedRecords, isEmpty);
      });
    });

    group('addQuestions', () {
      test('accepts list of questions', () async {
        final questions = [
          Question(
            id: '',
            questionText: 'What is 2+2?',
            options: ['3', '4', '5'],
            correctAnswer: 1,
            type: 'multiple-choice',
            explanation: 'Basic math',
            createdBy: 'user-1',
          ),
        ];

        await service.addQuestions('lesson-1', questions);
        
        expect(fakeClient.insertedRecords, isNotEmpty);
      });
    });

    group('addConcepts', () {
      test('accepts list of concepts', () async {
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

        await service.addConcepts('lesson-1', concepts);
        
        expect(fakeClient.insertedRecords, isNotEmpty);
      });
    });

    group('removeContent', () {
      test('accepts lessonId parameter and tracks delete', () async {
        await service.removeContent(lessonId: 'lesson-1');
        
        // Delete was called with the lesson ID
        expect(fakeClient.deletedIds, contains('lesson-1'));
      });

      test('accepts termIds parameter', () async {
        await service.removeContent(termIds: ['term-1', 'term-2']);
        
        expect(fakeClient.deletedIds, containsAll(['term-1', 'term-2']));
      });

      test('accepts questionIds parameter', () async {
        await service.removeContent(questionIds: ['q-1']);
        
        expect(fakeClient.deletedIds, contains('q-1'));
      });

      test('accepts conceptIds parameter', () async {
        await service.removeContent(conceptIds: ['c-1']);
        
        expect(fakeClient.deletedIds, contains('c-1'));
      });
    });

    group('getContentCounts', () {
      test('returns map with content counts', () async {
        // Set up test data
        fakeClient.setTableData('terms', [
          {'id': 't1', 'lesson_id': 'lesson-1'},
          {'id': 't2', 'lesson_id': 'lesson-1'},
        ]);
        fakeClient.setTableData('questions', [
          {'id': 'q1', 'lesson_id': 'lesson-1'},
        ]);
        fakeClient.setTableData('concepts', []);
        
        final counts = await service.getContentCounts('lesson-1');

        expect(counts, isA<Map<String, int>>());
        expect(counts.containsKey('terms'), isTrue);
        expect(counts.containsKey('questions'), isTrue);
        expect(counts.containsKey('concepts'), isTrue);
      });

      test('returns zeros for empty lesson', () async {
        fakeClient.setTableData('terms', []);
        fakeClient.setTableData('questions', []);
        fakeClient.setTableData('concepts', []);
        
        final counts = await service.getContentCounts('non-existent');

        expect(counts['terms'], 0);
        expect(counts['questions'], 0);
        expect(counts['concepts'], 0);
      });
    });
  });
}
