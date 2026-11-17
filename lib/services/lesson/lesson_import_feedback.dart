import 'package:learning_pwa/services/lesson/lesson_import_service.dart';

/// Learner-facing wording for the lesson JSON import screen: error text,
/// fix suggestions, the preview summary and "time ago" labels.
///
/// Pure functions, moved unchanged from `EnhancedJsonImportWidget`
/// (code-efficiency plan §14, Phase 2). Whether a lesson can be imported is
/// decided by `LessonImportService.preview`, never here.
abstract final class LessonImportFeedback {
  static String formatValidationErrors(List<String> errors) {
    return errors.map((error) {
      // Add more context and helpful information to errors
      if (error.contains('required field')) {
        return '❌ $error\n   💡 This field is mandatory for lesson creation';
      } else if (error.contains('invalid format')) {
        return '❌ $error\n   💡 Check the expected format in the documentation';
      } else if (error.contains('length')) {
        return '❌ $error\n   💡 Adjust the content length to meet requirements';
      }
      return '❌ $error';
    }).join('\n\n');
  }

  static List<String> suggestionsFor(List<String> errors) {
    List<String> suggestions = [];
    
    for (String error in errors) {
      if (error.contains('title')) {
        suggestions.add('Add a descriptive title (5-100 characters)');
      } else if (error.contains('content')) {
        suggestions.add('Include at least one content item (term, concept, or MCQ)');
      } else if (error.contains('options')) {
        suggestions.add('MCQ questions must have exactly 4 options');
      } else if (error.contains('correct_answer')) {
        suggestions.add('Ensure correct_answer matches one of the options exactly');
      }
    }
    
    return suggestions;
  }

  static String formatJsonError(String error) {
    if (error.contains('Unexpected character')) {
      return '❌ JSON Syntax Error: Invalid character found\n💡 Check for missing quotes, commas, or brackets';
    } else if (error.contains('Unexpected end')) {
      return '❌ JSON Syntax Error: Incomplete JSON structure\n💡 Make sure all brackets and braces are properly closed';
    } else if (error.contains('duplicate key')) {
      return '❌ JSON Syntax Error: Duplicate field names\n💡 Each field name must be unique within an object';
    }
    return '❌ JSON Parsing Error: $error';
  }

  static List<String> jsonSuggestions(String error) {
    List<String> suggestions = [];
    
    if (error.contains('character')) {
      suggestions.add('Use a JSON validator to check syntax');
      suggestions.add('Ensure all strings are wrapped in double quotes');
    } else if (error.contains('end')) {
      suggestions.add('Check that all { } and [ ] are properly matched');
      suggestions.add('Remove any trailing commas');
    }
    
    return suggestions;
  }

  static Map<String, dynamic> previewSummary(
    Map<String, dynamic> json,
    LessonImportPreview preview,
  ) {
    final lesson = json['lesson'] is Map<String, dynamic>
        ? json['lesson'] as Map<String, dynamic>
        : json;
    final total =
        preview.termCount + preview.conceptCount + preview.questionCount;

    return {
      'title': lesson['title'] ?? 'Untitled Lesson',
      'description': lesson['description'] ?? 'No description provided',
      'difficulty': lesson['difficulty_level'] ?? 'beginner',
      'duration': lesson['estimated_duration_minutes'] ?? 30,
      'tags': lesson['tags'] ?? [],
      // Counts of what will actually be saved after normalization.
      'contentStats': {
        'total': total,
        'terms': preview.termCount,
        'concepts': preview.conceptCount,
        'mcqs': preview.questionCount,
        'text': 0,
      },
    };
  }

  static String timeAgo(DateTime dateTime, {DateTime? now}) {
    now ??= DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
