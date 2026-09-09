import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/audio_lesson/content_processor.dart';
import '../../test_fixtures.dart';

void main() {
  group('ContentProcessor', () {
    late ContentProcessor processor;

    setUp(() {
      processor = ContentProcessor();
    });

    group('extractLessonTexts()', () {
      test('includes title and description', () {
        final lesson = TestFixtures.createTestLesson(
          title: 'Test Lesson Title',
          description: 'Test lesson description',
        );

        final texts = processor.extractLessonTexts(lesson);

        expect(texts, contains('Starting lesson: Test Lesson Title'));
        expect(texts, contains('Test lesson description'));
      });

      test('extracts concept text', () {
        final lesson = TestFixtures.createTestLesson(
          concepts: [
            TestFixtures.createTestConcept(conceptText: 'Important concept'),
          ],
        );

        final texts = processor.extractLessonTexts(lesson);

        expect(texts, contains('Concept: Important concept'));
      });

      test('extracts concept example text', () {
        final lesson = TestFixtures.createTestLesson(
          concepts: [
            TestFixtures.createTestConcept(
              conceptText: 'Test concept',
              exampleText: 'Example text here',
            ),
          ],
        );

        final texts = processor.extractLessonTexts(lesson);

        expect(texts, contains('Example: Example text here'));
      });

      test('includes completion message', () {
        final lesson = TestFixtures.createTestLesson();

        final texts = processor.extractLessonTexts(lesson);

        expect(texts, contains('Lesson completed. Well done!'));
      });

      test('handles lesson with no description', () {
        final lesson = TestFixtures.createTestLesson(
          title: 'Title Only',
          description: null,
        );

        final texts = processor.extractLessonTexts(lesson);

        expect(texts, contains('Starting lesson: Title Only'));
        expect(texts, isNot(contains(null)));
      });

      test('handles multiple concepts', () {
        final lesson = TestFixtures.createTestLesson(
          concepts: [
            TestFixtures.createTestConcept(conceptText: 'Concept 1'),
            TestFixtures.createTestConcept(conceptText: 'Concept 2'),
            TestFixtures.createTestConcept(conceptText: 'Concept 3'),
          ],
        );

        final texts = processor.extractLessonTexts(lesson);

        expect(texts, contains('Concept: Concept 1'));
        expect(texts, contains('Concept: Concept 2'));
        expect(texts, contains('Concept: Concept 3'));
      });

      test('filters out empty strings', () {
        final lesson = TestFixtures.createTestLesson(
          title: 'Test',
          description: '',
        );

        final texts = processor.extractLessonTexts(lesson);

        expect(texts.every((text) => text.trim().isNotEmpty), isTrue);
      });
    });

    group('cleanTextForTTS()', () {
      test('removes special characters', () {
        final cleaned = processor.cleanTextForTTS('Test @#\$ text!');

        expect(cleaned, 'Test text!');
      });

      test('preserves basic punctuation', () {
        final cleaned = processor.cleanTextForTTS('Hello, world. How are you?');

        expect(cleaned, 'Hello, world. How are you?');
      });

      test('normalizes whitespace', () {
        final cleaned = processor.cleanTextForTTS('Text   with    spaces');

        expect(cleaned, 'Text with spaces');
      });

      test('trims leading and trailing whitespace', () {
        final cleaned = processor.cleanTextForTTS('  Text  ');

        expect(cleaned, 'Text');
      });

      test('handles empty string', () {
        final cleaned = processor.cleanTextForTTS('');

        expect(cleaned, '');
      });

      test('preserves colons and semicolons', () {
        final cleaned = processor.cleanTextForTTS('Note: This; is important.');

        expect(cleaned, 'Note: This; is important.');
      });
    });

    group('estimateReadingTime()', () {
      test('calculates based on word count', () {
        final texts = ['This is a test', 'with ten words total here now'];
        
        final duration = processor.estimateReadingTime(texts);

        // 10 words at 150 wpm = 0.0667 minutes = ~4 seconds
        expect(duration.inSeconds, greaterThan(0));
        expect(duration.inSeconds, lessThan(10));
      });

      test('handles single word', () {
        final texts = ['Word'];
        
        final duration = processor.estimateReadingTime(texts);

        expect(duration.inMilliseconds, greaterThan(0));
      });

      test('handles empty list', () {
        final texts = <String>[];
        
        final duration = processor.estimateReadingTime(texts);

        expect(duration.inMilliseconds, 0);
      });

      test('estimates longer text correctly', () {
        // Create text with ~150 words (should be ~1 minute)
        final words = List.generate(150, (i) => 'word$i').join(' ');
        final texts = [words];
        
        final duration = processor.estimateReadingTime(texts);

        // Should be around 60 seconds
        expect(duration.inSeconds, greaterThan(50));
        expect(duration.inSeconds, lessThan(70));
      });
    });

    group('validateLesson()', () {
      test('rejects empty title', () {
        final lesson = TestFixtures.createTestLesson(title: '');

        final isValid = processor.validateLesson(lesson);

        expect(isValid, isFalse);
      });

      test('rejects empty concepts', () {
        final lesson = TestFixtures.createTestLesson(concepts: []);

        final isValid = processor.validateLesson(lesson);

        expect(isValid, isFalse);
      });

      test('accepts valid lesson', () {
        final lesson = TestFixtures.createTestLesson(
          title: 'Valid Lesson',
          concepts: [TestFixtures.createTestConcept()],
        );

        final isValid = processor.validateLesson(lesson);

        expect(isValid, isTrue);
      });
    });

    group('validateConcept()', () {
      test('rejects empty conceptText', () {
        final concept = TestFixtures.createTestConcept(conceptText: '');

        final isValid = processor.validateConcept(concept);

        expect(isValid, isFalse);
      });

      test('accepts valid concept', () {
        final concept = TestFixtures.createTestConcept(
          conceptText: 'Valid concept text',
        );

        final isValid = processor.validateConcept(concept);

        expect(isValid, isTrue);
      });

      test('accepts concept with only conceptText (no example)', () {
        final concept = TestFixtures.createTestConcept(
          conceptText: 'Concept without example',
          exampleText: null,
        );

        final isValid = processor.validateConcept(concept);

        expect(isValid, isTrue);
      });
    });

    group('Integration scenarios', () {
      test('processes full lesson correctly', () {
        final lesson = TestFixtures.createFullTestLesson();

        final texts = processor.extractLessonTexts(lesson);
        final cleaned = texts.map((t) => processor.cleanTextForTTS(t)).toList();
        final duration = processor.estimateReadingTime(cleaned);

        expect(texts, isNotEmpty);
        expect(cleaned.every((t) => t.trim().isNotEmpty), isTrue);
        expect(duration.inSeconds, greaterThan(0));
      });
    });
  });
}
