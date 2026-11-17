import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_import_feedback.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';

/// Wording shown on the lesson JSON import screen. Importability itself is
/// decided by LessonImportService.preview, not by these helpers.
void main() {
  group('LessonImportFeedback', () {
    test('validation errors get a marker and a hint where one applies', () {
      final text = LessonImportFeedback.formatValidationErrors([
        'title is a required field',
        'something else',
      ]);
      expect(text, contains('❌ title is a required field\n   💡 This field is mandatory'));
      expect(text, contains('❌ something else'));
      expect(text.split('\n\n'), hasLength(2));
    });

    test('suggestions follow the fields named in errors', () {
      expect(
        LessonImportFeedback.suggestionsFor(['missing title', 'bad options']),
        [
          'Add a descriptive title (5-100 characters)',
          'MCQ questions must have exactly 4 options',
        ],
      );
      expect(LessonImportFeedback.suggestionsFor(['unrelated']), isEmpty);
    });

    test('JSON syntax errors are explained', () {
      expect(LessonImportFeedback.formatJsonError('Unexpected character (at 3)'),
          startsWith('❌ JSON Syntax Error: Invalid character'));
      expect(LessonImportFeedback.formatJsonError('Unexpected end of input'),
          startsWith('❌ JSON Syntax Error: Incomplete'));
      expect(LessonImportFeedback.formatJsonError('weird'), '❌ JSON Parsing Error: weird');
      expect(LessonImportFeedback.jsonSuggestions('Unexpected end'),
          contains('Remove any trailing commas'));
    });

    test('preview summary uses the lesson envelope and saved counts', () {
      final json = {
        'lesson': {
          'title': 'Cells',
          'terms': [
            {'term': 'Cell', 'definition': 'The basic unit of life.'},
          ],
        },
      };
      final preview = LessonImportService.preview(json);
      final summary = LessonImportFeedback.previewSummary(json, preview);
      expect(summary['title'], 'Cells');
      expect(summary['description'], 'No description provided');
      final stats = summary['contentStats'] as Map;
      expect(stats['terms'], preview.termCount);
      expect(stats['total'],
          preview.termCount + preview.conceptCount + preview.questionCount);
    });

    test('time-ago labels', () {
      final now = DateTime(2026, 11, 17, 12);
      String ago(Duration d) => LessonImportFeedback.timeAgo(now.subtract(d), now: now);
      expect(ago(const Duration(seconds: 10)), 'Just now');
      expect(ago(const Duration(minutes: 5)), '5m ago');
      expect(ago(const Duration(hours: 3)), '3h ago');
      expect(ago(const Duration(days: 2)), '2d ago');
      expect(ago(const Duration(days: 30)), '10/18/2026');
    });
  });
}
