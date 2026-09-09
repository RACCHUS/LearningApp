class LessonJsonValidator {
  static ValidationResult validate(Map<String, dynamic> json) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check required top-level fields
    if (!json.containsKey('lesson')) {
      errors.add('Missing required field: "lesson"');
    } else {
      final lesson = json['lesson'];
      if (lesson is! Map<String, dynamic>) {
        errors.add('Field "lesson" must be an object');
      } else {
        _validateLesson(lesson, errors, warnings);
      }
    }

    if (!json.containsKey('content')) {
      errors.add('Missing required field: "content"');
    } else {
      final content = json['content'];
      if (content is! List) {
        errors.add('Field "content" must be an array');
      } else {
        _validateContent(content, errors, warnings);
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  static void _validateLesson(
    Map<String, dynamic> lesson,
    List<String> errors,
    List<String> warnings,
  ) {
    // Required fields
    if (!lesson.containsKey('title') || lesson['title'] == null) {
      errors.add('Lesson must have a "title" field');
    } else if (lesson['title'] is! String || 
               (lesson['title'] as String).trim().isEmpty) {
      errors.add('Lesson title must be a non-empty string');
    }

    // Optional but recommended fields
    if (!lesson.containsKey('description')) {
      warnings.add('Consider adding a description to your lesson');
    }

    if (!lesson.containsKey('tags')) {
      warnings.add('Consider adding tags to help categorize your lesson');
    } else if (lesson['tags'] is! List) {
      errors.add('Field "tags" must be an array');
    }

    // Check for unknown fields
    final knownFields = {'title', 'description', 'tags', 'createdBy', 'id'};
    for (final key in lesson.keys) {
      if (!knownFields.contains(key)) {
        warnings.add('Unknown lesson field: "$key"');
      }
    }
  }

  static void _validateContent(
    List content,
    List<String> errors,
    List<String> warnings,
  ) {
    if (content.isEmpty) {
      errors.add('Content array cannot be empty');
      return;
    }

    for (int i = 0; i < content.length; i++) {
      final item = content[i];
      if (item is! Map<String, dynamic>) {
        errors.add('Content item ${i + 1} must be an object');
        continue;
      }

      _validateContentItem(item, i + 1, errors, warnings);
    }
  }

  static void _validateContentItem(
    Map<String, dynamic> item,
    int index,
    List<String> errors,
    List<String> warnings,
  ) {
    // Required type field
    if (!item.containsKey('type')) {
      errors.add('Content item $index must have a "type" field');
      return;
    }

    final type = item['type'];
    if (type is! String) {
      errors.add('Content item $index: "type" must be a string');
      return;
    }

    // Validate based on content type
    switch (type) {
      case 'term':
        _validateTermContent(item, index, errors, warnings);
        break;
      case 'mcq':
        _validateMcqContent(item, index, errors, warnings);
        break;
      case 'concept':
        _validateConceptContent(item, index, errors, warnings);
        break;
      case 'text':
        _validateTextContent(item, index, errors, warnings);
        break;
      default:
        warnings.add('Content item $index: Unknown content type "$type"');
    }
  }

  static void _validateTermContent(
    Map<String, dynamic> item,
    int index,
    List<String> errors,
    List<String> warnings,
  ) {
    if (!item.containsKey('term') || item['term'] == null) {
      errors.add('Term content item $index must have a "term" field');
    }

    if (!item.containsKey('definition') || item['definition'] == null) {
      errors.add('Term content item $index must have a "definition" field');
    }

    if (!item.containsKey('example')) {
      warnings.add('Term content item $index: Consider adding an example');
    }
  }

  static void _validateMcqContent(
    Map<String, dynamic> item,
    int index,
    List<String> errors,
    List<String> warnings,
  ) {
    if (!item.containsKey('question') || item['question'] == null) {
      errors.add('MCQ content item $index must have a "question" field');
    }

    if (!item.containsKey('options')) {
      errors.add('MCQ content item $index must have an "options" field');
    } else {
      final options = item['options'];
      if (options is! List) {
        errors.add('MCQ content item $index: "options" must be an array');
      } else if (options.length < 2) {
        errors.add('MCQ content item $index: Must have at least 2 options');
      }
    }

    if (!item.containsKey('correctIndex')) {
      errors.add('MCQ content item $index must have a "correctIndex" field');
    } else {
      final correctIndex = item['correctIndex'];
      if (correctIndex is! int) {
        errors.add('MCQ content item $index: "correctIndex" must be a number');
      } else if (item.containsKey('options')) {
        final options = item['options'] as List?;
        if (options != null && (correctIndex < 0 || correctIndex >= options.length)) {
          errors.add('MCQ content item $index: "correctIndex" is out of range');
        }
      }
    }

    if (!item.containsKey('explanation')) {
      warnings.add('MCQ content item $index: Consider adding an explanation');
    }
  }

  static void _validateConceptContent(
    Map<String, dynamic> item,
    int index,
    List<String> errors,
    List<String> warnings,
  ) {
    if (!item.containsKey('title') || item['title'] == null) {
      errors.add('Concept content item $index must have a "title" field');
    }

    if (!item.containsKey('description') || item['description'] == null) {
      errors.add('Concept content item $index must have a "description" field');
    }

    if (item.containsKey('keyPoints')) {
      final keyPoints = item['keyPoints'];
      if (keyPoints is! List) {
        errors.add('Concept content item $index: "keyPoints" must be an array');
      }
    }
  }

  static void _validateTextContent(
    Map<String, dynamic> item,
    int index,
    List<String> errors,
    List<String> warnings,
  ) {
    if (!item.containsKey('text') || item['text'] == null) {
      errors.add('Text content item $index must have a "text" field');
    }
  }
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
}
