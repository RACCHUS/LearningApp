import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/utils/lesson_json_validator.dart';

void main() {
  group('LessonJsonValidator', () {
    group('Top-level validation', () {
      test('validate() requires "lesson" field', () {
        final json = {
          'content': [],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Missing required field: "lesson"'));
      });

      test('validate() requires "content" field', () {
        final json = {
          'lesson': {'title': 'Test'},
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Missing required field: "content"'));
      });

      test('validate() errors when "lesson" is not an object', () {
        final json = {
          'lesson': 'invalid',
          'content': [],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Field "lesson" must be an object'));
      });

      test('validate() errors when "content" is not an array', () {
        final json = {
          'lesson': {'title': 'Test'},
          'content': 'invalid',
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Field "content" must be an array'));
      });

      test('validate() errors on empty content array', () {
        final json = {
          'lesson': {'title': 'Test'},
          'content': [],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Content array cannot be empty'));
      });
    });

    group('Lesson field validation', () {
      test('_validateLesson() requires non-empty title', () {
        final json = {
          'lesson': {'title': ''},
          'content': [
            {'type': 'term', 'term': 'Test', 'definition': 'Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors,
            contains('Lesson title must be a non-empty string'));
      });

      test('_validateLesson() requires title field exists', () {
        final json = {
          'lesson': {'description': 'test'},
          'content': [
            {'type': 'term', 'term': 'Test', 'definition': 'Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Lesson must have a "title" field'));
      });

      test('_validateLesson() warns on missing description', () {
        final json = {
          'lesson': {'title': 'Test Lesson'},
          'content': [
            {'type': 'term', 'term': 'Test', 'definition': 'Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.warnings,
            contains('Consider adding a description to your lesson'));
      });

      test('_validateLesson() warns on missing tags', () {
        final json = {
          'lesson': {'title': 'Test Lesson', 'description': 'Desc'},
          'content': [
            {'type': 'term', 'term': 'Test', 'definition': 'Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(
            result.warnings,
            contains(
                'Consider adding tags to help categorize your lesson'));
      });

      test('_validateLesson() errors when tags is not an array', () {
        final json = {
          'lesson': {
            'title': 'Test Lesson',
            'description': 'Desc',
            'tags': 'invalid'
          },
          'content': [
            {'type': 'term', 'term': 'Test', 'definition': 'Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Field "tags" must be an array'));
      });

      test('_validateLesson() warns on unknown fields', () {
        final json = {
          'lesson': {
            'title': 'Test Lesson',
            'unknownField': 'value',
          },
          'content': [
            {'type': 'term', 'term': 'Test', 'definition': 'Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.warnings,
            contains('Unknown lesson field: "unknownField"'));
      });
    });

    group('Content validation', () {
      test('_validateContentItem() requires type field', () {
        final json = {
          'lesson': {'title': 'Test'},
          'content': [
            {'term': 'Test', 'definition': 'Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(
            result.errors, contains('Content item 1 must have a "type" field'));
      });

      test('validate() validates term content structure', () {
        final json = {
          'lesson': {'title': 'Test'},
          'content': [
            {'type': 'term', 'term': 'Test Term', 'definition': 'Test Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isTrue);
      });

      test('validate() validates mcq content structure', () {
        final json = {
          'lesson': {'title': 'Test'},
          'content': [
            {
              'type': 'mcq',
              'question': 'What is 2+2?',
              'options': ['2', '3', '4', '5'],
              'correctIndex': 2
            }
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isTrue);
      });

      test('validate() validates concept content structure', () {
        final json = {
          'lesson': {'title': 'Test'},
          'content': [
            {'type': 'concept', 'title': 'Concept', 'description': 'Desc'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isTrue);
      });

      test('validate() errors when content item is not an object', () {
        final json = {
          'lesson': {'title': 'Test'},
          'content': ['invalid'],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Content item 1 must be an object'));
      });
    });

    group('ValidationResult', () {
      test('returns isValid=true when no errors', () {
        final json = {
          'lesson': {
            'title': 'Valid Lesson',
            'description': 'Valid description',
            'tags': ['test']
          },
          'content': [
            {'type': 'term', 'term': 'Test', 'definition': 'Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('returns isValid=false when errors exist', () {
        final json = {
          'lesson': {},
          'content': [],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
      });

      test('can have warnings without errors', () {
        final json = {
          'lesson': {'title': 'Test'},
          'content': [
            {'type': 'term', 'term': 'Test', 'definition': 'Def'}
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.warnings, isNotEmpty);
      });
    });

    group('Complex validation scenarios', () {
      test('validates multiple content items', () {
        final json = {
          'lesson': {
            'title': 'Multi-content Lesson',
            'description': 'Has multiple items',
            'tags': ['test']
          },
          'content': [
            {'type': 'term', 'term': 'Term 1', 'definition': 'Def 1'},
            {
              'type': 'mcq',
              'question': 'Q1',
              'options': ['a', 'b'],
              'correctIndex': 0
            },
            {'type': 'concept', 'title': 'C1', 'description': 'D1'},
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isTrue);
      });

      test('accumulates errors from multiple issues', () {
        final json = {
          'lesson': {},
          'content': [
            {'term': 'Missing type'},
          ],
        };

        final result = LessonJsonValidator.validate(json);

        expect(result.isValid, isFalse);
        expect(result.errors.length, greaterThanOrEqualTo(2));
      });
    });
  });
}
