import 'package:learning_pwa/models/answer_key.dart';

/// The lesson source formats the app produces or accepts (master plan v2.6
/// §5.6 / Appendix H.2). Every personal-lesson route is normalized to the
/// flat personal shape before validation, preview, import and reopen.
enum LessonSourceDialect {
  /// P — top-level title/questions with integer `correct_answer`.
  flatPersonal,

  /// G — phased guided output (flat, plus transient `_needs_review`).
  guidedAssembled,

  /// B — `{lesson, content}` from JSON Import / Manual Builder with
  /// integer `correctIndex`.
  builderEnvelope,

  /// Q — `{lesson, content}` from the Quick Generate prompt with an exact
  /// textual `correct_answer`.
  quickGenerate,

  /// C — privileged curriculum manifest. Never imported as a personal
  /// lesson; it has its own guarded ingest.
  curriculumManifest,

  /// Nothing recognisable.
  unknown;

  String get label => switch (this) {
    LessonSourceDialect.flatPersonal => 'Personal lesson JSON',
    LessonSourceDialect.guidedAssembled => 'Guided generator output',
    LessonSourceDialect.builderEnvelope => 'Lesson Builder / JSON Import',
    LessonSourceDialect.quickGenerate => 'Quick Generate response',
    LessonSourceDialect.curriculumManifest => 'Curriculum manifest',
    LessonSourceDialect.unknown => 'Unknown format',
  };
}

/// A structural problem found while normalizing (reported with a path).
class LessonDialectIssue {
  const LessonDialectIssue(this.path, this.code, this.message);

  final String path;
  final String code;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Result of normalizing a pasted or built lesson into the flat personal
/// contract the importer validates.
class NormalizedLessonDraft {
  NormalizedLessonDraft({
    required this.dialect,
    required this.personal,
    required this.issues,
    required this.notSaved,
  });

  final LessonSourceDialect dialect;

  /// Flat personal-lesson JSON (`title`, `terms`, `concepts`, `questions`).
  /// Answer keys are zero-based integers, or null with `_answer_error` when
  /// they could not be resolved — the importer rejects those.
  final Map<String, dynamic> personal;

  /// Structural problems that block import (unsupported formats/types,
  /// conflicting answers). Answer/field validity is checked by the importer.
  final List<LessonDialectIssue> issues;

  /// Fields present in the source that personal lessons cannot store yet.
  /// Shown to the user so nothing is lost silently.
  final List<String> notSaved;
}

/// Converts every supported creation format to the flat personal contract.
///
/// Pure and deterministic: the same input always yields the same draft, so
/// preview, validation and import all see identical data.
class LessonDialectNormalizer {
  const LessonDialectNormalizer._();

  static const _questionTypes = {
    'mcq',
    'multiple_choice',
    'question',
    'true_false',
    'short_answer',
  };

  static LessonSourceDialect detect(Map<String, dynamic> json) {
    if (json.containsKey('target') &&
        (json.containsKey('domains') ||
            json.containsKey('source_releases') ||
            json.containsKey('source_release'))) {
      return LessonSourceDialect.curriculumManifest;
    }
    if (json['lesson'] is Map && json['content'] is List) {
      final content = json['content'] as List;
      final usesText = content.whereType<Map>().any(
        (item) =>
            (item['type'] == 'term' && item.containsKey('title')) ||
            (item['type'] == 'mcq' && item['correct_answer'] is String),
      );
      return usesText
          ? LessonSourceDialect.quickGenerate
          : LessonSourceDialect.builderEnvelope;
    }
    if (json.containsKey('lesson')) return LessonSourceDialect.unknown;
    // Anything else is treated as flat personal JSON; a missing title is
    // reported by the importer as "Lesson title is required".
    final questions = json['questions'];
    final guided =
        questions is List &&
        questions.whereType<Map>().any(
          (q) =>
              q.containsKey('_needs_review') || q.containsKey('_answer_error'),
        );
    return guided
        ? LessonSourceDialect.guidedAssembled
        : LessonSourceDialect.flatPersonal;
  }

  static NormalizedLessonDraft normalize(Map<String, dynamic> json) {
    final dialect = detect(json);
    final issues = <LessonDialectIssue>[];
    final notSaved = <String>[];

    switch (dialect) {
      case LessonSourceDialect.flatPersonal:
      case LessonSourceDialect.guidedAssembled:
        _noteUnsavedLessonFields(json, '', notSaved);
        return NormalizedLessonDraft(
          dialect: dialect,
          personal: json,
          issues: issues,
          notSaved: notSaved,
        );
      case LessonSourceDialect.curriculumManifest:
        issues.add(
          const LessonDialectIssue(
            '',
            'privileged_manifest',
            'This is a curriculum manifest. Manifests are published through '
                'the reviewed curriculum ingest, not imported as a personal '
                'lesson.',
          ),
        );
        return NormalizedLessonDraft(
          dialect: dialect,
          personal: const {},
          issues: issues,
          notSaved: notSaved,
        );
      case LessonSourceDialect.unknown:
        issues.add(
          LessonDialectIssue(
            json['lesson'] is Map ? 'content' : 'lesson',
            'unknown_format',
            json['lesson'] is Map
                ? 'A lesson with a "lesson" object also needs a "content" list.'
                : '"lesson" must be an object with a "title".',
          ),
        );
        return NormalizedLessonDraft(
          dialect: dialect,
          personal: const {},
          issues: issues,
          notSaved: notSaved,
        );
      case LessonSourceDialect.builderEnvelope:
      case LessonSourceDialect.quickGenerate:
        break;
    }

    final lesson = Map<String, dynamic>.from(json['lesson'] as Map);
    final personal = <String, dynamic>{
      if (lesson['title'] != null) 'title': lesson['title'],
      if (lesson['description'] != null) 'description': lesson['description'],
      if (lesson['tags'] != null) 'tags': lesson['tags'],
    };
    _noteUnsavedLessonFields(lesson, 'lesson.', notSaved);

    final terms = <Map<String, dynamic>>[];
    final concepts = <Map<String, dynamic>>[];
    final questions = <Map<String, dynamic>>[];
    final content = json['content'] as List;
    for (var i = 0; i < content.length; i++) {
      final raw = content[i];
      final path = 'content[$i]';
      if (raw is! Map) {
        issues.add(
          LessonDialectIssue(
            path,
            'invalid_format',
            'Each content item must be an object.',
          ),
        );
        continue;
      }
      final item = Map<String, dynamic>.from(raw);
      final type = item['type']?.toString();
      if (item['emoji'] != null) notSaved.add('$path.emoji');
      if (item['tags'] != null) notSaved.add('$path.tags');
      if (type == 'term') {
        terms.add({..._term(item), '_source_path': path});
      } else if (type == 'concept') {
        concepts.add({..._concept(item), '_source_path': path});
      } else if (type != null && _questionTypes.contains(type)) {
        questions.add({..._question(item), '_source_path': path});
      } else {
        issues.add(
          LessonDialectIssue(
            '$path.type',
            AnswerKeyStatus.unsupportedType.code,
            type == 'text'
                ? 'Free "text" items cannot be saved in a personal lesson yet. '
                      'Change them to a "concept" (title + content).'
                : 'Unsupported content type "${type ?? '(none)'}".',
          ),
        );
      }
    }
    if (terms.isNotEmpty) personal['terms'] = terms;
    if (concepts.isNotEmpty) personal['concepts'] = concepts;
    if (questions.isNotEmpty) personal['questions'] = questions;

    return NormalizedLessonDraft(
      dialect: dialect,
      personal: personal,
      issues: issues,
      notSaved: notSaved,
    );
  }

  static void _noteUnsavedLessonFields(
    Map<String, dynamic> lesson,
    String prefix,
    List<String> notSaved,
  ) {
    for (final field in const [
      'estimated_duration_minutes',
      'difficulty_level',
    ]) {
      if (lesson[field] != null) notSaved.add('$prefix$field');
    }
  }

  /// Term: Quick Generate uses `title`/`content`; Builder uses
  /// `term`/`definition`.
  static Map<String, dynamic> _term(Map<String, dynamic> item) => {
    if (item['id'] != null) 'id': item['id'],
    'term': item['term'] ?? item['title'],
    'definition': item['definition'] ?? item['content'],
    if (item['example'] != null) 'example': item['example'],
  };

  /// Concept: the title becomes the concept text; the explanation, key
  /// points and examples are kept together in the example text so no
  /// meaning is dropped (the personal concept model has two text fields).
  static Map<String, dynamic> _concept(Map<String, dynamic> item) {
    String? bullets(Object? list) {
      if (list is! List) return null;
      final lines = list
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .map((e) => '• $e')
          .toList();
      return lines.isEmpty ? null : lines.join('\n');
    }

    final parts = <String>[
      if ((item['content'] ?? item['description']) != null)
        (item['content'] ?? item['description']).toString().trim(),
      if (bullets(item['key_points'] ?? item['keyPoints']) case final kp?)
        'Key points:\n$kp',
      if (bullets(item['examples']) case final ex?) 'Examples:\n$ex',
      if (item['example'] is String &&
          (item['example'] as String).trim().isNotEmpty)
        'Example: ${(item['example'] as String).trim()}',
    ].where((p) => p.isNotEmpty).toList();

    return {
      if (item['id'] != null) 'id': item['id'],
      'concept_text': item['concept_text'] ?? item['title'],
      if (parts.isNotEmpty) 'example_text': parts.join('\n\n'),
    };
  }

  /// Question: resolves `correctIndex` (integer) and/or `correct_answer`
  /// (integer index or exact option text) to one zero-based index. A
  /// conflict or an unresolvable key is left null with `_answer_error`.
  static Map<String, dynamic> _question(Map<String, dynamic> item) {
    final options = item['options'] is List
        ? (item['options'] as List).map((o) => o?.toString() ?? '').toList()
        : null;
    final result = <String, dynamic>{
      if (item['id'] != null) 'id': item['id'],
      'type': item['type'],
      'question': item['question'] ?? item['question_text'],
      'options': item['options'],
      if (item['explanation'] != null) 'explanation': item['explanation'],
      if (item['accepted_answers'] != null)
        'accepted_answers': item['accepted_answers'],
      if (item['grading_method'] != null)
        'grading_method': item['grading_method'],
      if (item['numeric_tolerance'] != null)
        'numeric_tolerance': item['numeric_tolerance'],
    };
    if (item['type'] == 'short_answer') {
      if (item.containsKey('correct_answer')) {
        result['correct_answer'] = item['correct_answer'];
      }
      return result;
    }

    final hasIndex = item.containsKey('correctIndex');
    final hasAnswer = item.containsKey('correct_answer');
    final opts = options ?? const <String>[];
    final AnswerKeyResult? fromIndex = hasIndex
        ? AnswerKey.fromIndex(item['correctIndex'], opts)
        : null;
    final rawAnswer = item['correct_answer'];
    final AnswerKeyResult? fromAnswer = !hasAnswer
        ? null
        : rawAnswer is int
        ? AnswerKey.fromIndex(rawAnswer, opts)
        : AnswerKey.fromText(rawAnswer, opts);

    if (fromIndex != null &&
        fromAnswer != null &&
        fromIndex.isScorable &&
        fromAnswer.isScorable &&
        fromIndex.index != fromAnswer.index) {
      result['correct_answer'] = null;
      result['_answer_error'] = 'conflicting_answer';
      result['_answer_error_detail'] =
          '"correctIndex" (${fromIndex.index}) and "correct_answer" '
          '("$rawAnswer") point at different options.';
      return result;
    }

    final key = fromIndex ?? fromAnswer;
    if (key == null) {
      // Leave absent so the importer reports missing_key at this path.
      return result;
    }
    if (key.isScorable) {
      result['correct_answer'] = key.index;
    } else {
      result['correct_answer'] = null;
      result['_answer_error'] = key.status.code;
      result['_answer_error_detail'] = key.detail;
    }
    return result;
  }
}
