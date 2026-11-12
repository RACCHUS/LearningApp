import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/answer_key.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:learning_pwa/services/lesson/lesson_dialect_normalizer.dart';
import 'package:uuid/uuid.dart';

/// One problem found while validating a lesson import payload.
@immutable
class LessonImportIssue {
  const LessonImportIssue({
    required this.path,
    required this.code,
    required this.message,
  });

  /// JSON path of the offending item, e.g. `questions[2].correct_answer`.
  final String path;

  /// Stable machine code, e.g. `missing_key`, `missing_field`.
  final String code;

  /// Plain-language description for the person repairing the draft.
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Thrown when the whole-payload preflight finds problems. Nothing has been
/// written; the caller still holds the original draft text.
class LessonImportValidationException implements Exception {
  LessonImportValidationException(this.issues);

  final List<LessonImportIssue> issues;

  @override
  String toString() {
    final shown = issues.take(5).map((i) => '• $i').join('\n');
    final more = issues.length > 5 ? '\n…and ${issues.length - 5} more' : '';
    return 'This lesson was not imported. Fix these items and try again:\n'
        '$shown$more';
  }
}

/// Thrown when a write fails after the lesson row was created. Client writes
/// are not atomic; this reports honestly what happened rather than claiming
/// a transaction. Cleanup is best-effort.
class LessonImportIncompleteException implements Exception {
  LessonImportIncompleteException({
    required this.lessonId,
    required this.stage,
    required this.cause,
    required this.cleanedUp,
  });

  final String lessonId;

  /// Which write failed: `terms`, `questions` or `concepts`.
  final String stage;
  final Object cause;

  /// Whether the partially written lesson was removed again.
  final bool cleanedUp;

  @override
  String toString() => cleanedUp
      ? 'Import failed while saving $stage, and the partial lesson was '
          'removed. Your draft is unchanged — try again. ($cause)'
      : 'Import failed while saving $stage. A partial lesson may remain in '
          'your library and should be deleted. Your draft is unchanged. '
          '($cause)';
}

/// Result of [LessonImportService.preview]: what would be imported.
class LessonImportPreview {
  const LessonImportPreview._(
    this.draft,
    this.issues,
    this.termCount,
    this.conceptCount,
    this.questionCount,
  );

  final NormalizedLessonDraft draft;
  final List<LessonImportIssue> issues;
  final int termCount;
  final int conceptCount;
  final int questionCount;

  bool get canImport => issues.isEmpty;
}

/// Validated, ready-to-write content for one lesson.
class _PreparedLesson {
  final List<Term> terms = [];
  final List<Question> questions = [];
  final List<Concept> concepts = [];
  final List<LessonImportIssue> issues = [];
}

/// Service for importing lessons from JSON
///
/// Every item in the payload is validated **before** any write (plan v2.6
/// §14.8 / Appendix G.3). Invalid items are reported with their path rather
/// than silently dropped, and answer keys are never defaulted to option 0.
class LessonImportService {
  final LessonCrudService _crudService;
  final LessonContentService _contentService;

  LessonImportService({
    LessonCrudService? crudService,
    LessonContentService? contentService,
  }) : _crudService = crudService ?? LessonCrudService(),
        _contentService = contentService ?? LessonContentService();

  static const _questionTypes = {
    'mcq',
    'multiple_choice',
    'question',
    'true_false',
    'short_answer',
  };

  /// Import a lesson from JSON string
  Future<Lesson> importLessonFromJson(String jsonString, String userId) async {
    debugPrint('🔍 DEBUG: Importing lesson from JSON for user: $userId');

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

    // Every creation route (flat, guided, Builder, Quick Generate) is
    // normalized to one personal contract before validation (plan §14.9).
    final draft = LessonDialectNormalizer.normalize(decoded);
    if (draft.issues.isNotEmpty) {
      throw LessonImportValidationException(_dialectIssues(draft));
    }
    final jsonData = draft.personal;

    final title = jsonData['title']?.toString();
    if (title == null || title.trim().isEmpty) {
      throw ArgumentError('Lesson title is required');
    }
    final description = jsonData['description']?.toString();
    final tags = jsonData['tags'] is List
        ? (jsonData['tags'] as List).map((t) => t.toString()).toList()
        : <String>[];

    // Preflight the whole payload before creating anything.
    final prepared = _prepareContent(jsonData, userId);
    if (prepared.issues.isNotEmpty) {
      throw LessonImportValidationException(prepared.issues);
    }

    debugPrint('🔍 DEBUG: Creating lesson: $title');
    final lesson = await _crudService.addLesson(
      title,
      description,
      userId,
      tags: tags,
    );

    await _writeContent(lesson.id, prepared);
    debugPrint('✅ Lesson imported successfully: ${lesson.id}');
    return lesson;
  }

  /// Validates every item and returns the issues found (empty when the
  /// payload is safe to import). Exposed for preview UIs and tests.
  List<LessonImportIssue> validatePayload(Map<String, dynamic> jsonData) =>
      preview(jsonData).issues;

  /// The exact normalization + validation the importer runs, without
  /// writing anything. Preview UIs use this so a green preview cannot end
  /// in an import error (plan §14.9 repair 5).
  static LessonImportPreview preview(Map<String, dynamic> raw) {
    final draft = LessonDialectNormalizer.normalize(raw);
    if (draft.issues.isNotEmpty) {
      return LessonImportPreview._(draft, _dialectIssues(draft), 0, 0, 0);
    }
    final title = draft.personal['title']?.toString();
    final prepared = _prepareContent(draft.personal, '');
    return LessonImportPreview._(
      draft,
      [
        if (title == null || title.trim().isEmpty)
          const LessonImportIssue(
            path: 'title',
            code: 'missing_field',
            message: 'Lesson title is required.',
          ),
        ...prepared.issues,
      ],
      prepared.terms.length,
      prepared.concepts.length,
      prepared.questions.length,
    );
  }

  static List<LessonImportIssue> _dialectIssues(NormalizedLessonDraft draft) =>
      draft.issues
          .map((i) => LessonImportIssue(
                path: i.path.isEmpty ? '(document)' : i.path,
                code: i.code,
                message: i.message,
              ))
          .toList();

  Future<void> _writeContent(String lessonId, _PreparedLesson prepared) async {
    final stages = <String, Future<void> Function()>{
      if (prepared.terms.isNotEmpty)
        'terms': () => _contentService.addTerms(lessonId, prepared.terms),
      if (prepared.questions.isNotEmpty)
        'questions': () =>
            _contentService.addQuestions(lessonId, prepared.questions),
      if (prepared.concepts.isNotEmpty)
        'concepts': () => _contentService.addConcepts(
              lessonId,
              prepared.concepts
                  .map((c) => Concept(
                        id: c.id,
                        lessonId: lessonId,
                        conceptText: c.conceptText,
                        exampleText: c.exampleText,
                        createdBy: c.createdBy,
                      ))
                  .toList(),
            ),
    };
    for (final entry in stages.entries) {
      try {
        await entry.value();
      } catch (e) {
        debugPrint('❌ ERROR: Import write failed at ${entry.key}: $e');
        var cleanedUp = false;
        try {
          await _crudService.deleteLessonFromSupabase(lessonId);
          cleanedUp = true;
        } catch (cleanupError) {
          debugPrint('⚠️ Partial-lesson cleanup failed: $cleanupError');
        }
        throw LessonImportIncompleteException(
          lessonId: lessonId,
          stage: entry.key,
          cause: e,
          cleanedUp: cleanedUp,
        );
      }
    }
  }

  /// Converts and validates all terms, questions, concepts and generic
  /// content items. Collects every problem instead of stopping at the first.
  static _PreparedLesson _prepareContent(Map<String, dynamic> jsonData, String userId) {
    final prepared = _PreparedLesson();

    void listOf(String key, void Function(Map<String, dynamic>, String) each) {
      // Normalized items carry their original location (e.g. content[3]).
      final raw = jsonData[key];
      if (raw == null) return;
      if (raw is! List) {
        prepared.issues.add(LessonImportIssue(
          path: key,
          code: 'invalid_format',
          message: '"$key" must be a list.',
        ));
        return;
      }
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        final sourcePath = item is Map ? item['_source_path'] : null;
        final path = sourcePath is String ? sourcePath : '$key[$i]';
        if (item is! Map<String, dynamic>) {
          prepared.issues.add(LessonImportIssue(
            path: path,
            code: 'invalid_format',
            message: 'Each item must be a JSON object.',
          ));
          continue;
        }
        each(item, path);
      }
    }

    listOf('terms', (t, path) => _prepareTerm(t, path, userId, prepared));
    listOf('questions',
        (q, path) => _prepareQuestion(q, path, userId, prepared));
    listOf('concepts', (c, path) => _prepareConcept(c, path, userId, prepared));
    listOf('content', (item, path) {
      final type = item['type']?.toString();
      if (type == 'term') {
        _prepareTerm(item, path, userId, prepared);
      } else if (type == 'concept') {
        _prepareConcept(item, path, userId, prepared);
      } else if (type != null && _questionTypes.contains(type)) {
        _prepareQuestion(item, path, userId, prepared);
      } else {
        prepared.issues.add(LessonImportIssue(
          path: '$path.type',
          code: AnswerKeyStatus.unsupportedType.code,
          message: 'Unsupported content type "${type ?? '(none)'}".',
        ));
      }
    });
    return prepared;
  }

  static void _prepareTerm(Map<String, dynamic> t, String path, String userId,
      _PreparedLesson prepared) {
    final term = t['term']?.toString() ?? '';
    final definition = t['definition']?.toString() ?? '';
    if (term.trim().isEmpty || definition.trim().isEmpty) {
      prepared.issues.add(LessonImportIssue(
        path: path,
        code: 'missing_field',
        message: 'A term needs both "term" and "definition".',
      ));
      return;
    }
    prepared.terms.add(Term(
      id: t['id']?.toString() ?? const Uuid().v4(),
      term: term,
      definition: definition,
      example: t['example']?.toString(),
      createdBy: t['created_by']?.toString() ?? userId,
    ));
  }

  static void _prepareConcept(Map<String, dynamic> c, String path, String userId,
      _PreparedLesson prepared) {
    final text = c['concept_text']?.toString() ?? c['title']?.toString() ?? '';
    if (text.trim().isEmpty) {
      prepared.issues.add(LessonImportIssue(
        path: path,
        code: 'missing_field',
        message: 'A concept needs "concept_text".',
      ));
      return;
    }
    prepared.concepts.add(Concept(
      id: c['id']?.toString() ?? const Uuid().v4(),
      lessonId: '',
      conceptText: text,
      exampleText: c['example_text']?.toString() ?? c['example']?.toString(),
      createdBy: c['created_by']?.toString() ?? userId,
    ));
  }

  static void _prepareQuestion(Map<String, dynamic> q, String path, String userId,
      _PreparedLesson prepared) {
    void issue(String field, String code, String message) =>
        prepared.issues.add(LessonImportIssue(
          path: field.isEmpty ? path : '$path.$field',
          code: code,
          message: message,
        ));

    final text =
        q['question_text']?.toString() ?? q['question']?.toString() ?? '';
    if (text.trim().isEmpty) {
      issue('question', 'missing_field', 'The question text is empty.');
    }
    final rawOptions = q['options'];
    if (rawOptions != null && rawOptions is! List) {
      issue('options', 'invalid_format', '"options" must be a list.');
    }
    final options = rawOptions is List
        ? rawOptions.map((o) => o?.toString() ?? '').toList()
        : <String>[];
    final acceptedAnswers = (q['accepted_answers'] as List?)
        ?.map((e) => e.toString())
        .where((a) => a.trim().isNotEmpty)
        .toList();
    final declaredType = q['type']?.toString();
    final type = (declaredType == null || declaredType == 'question')
        ? (q['accepted_answers'] is List ? 'short_answer' : 'mcq')
        : declaredType;

    // An unresolved key flagged by the guided assembler stays unresolved.
    final flagged = q['_answer_error']?.toString();
    if (flagged != null) {
      issue(
          'correct_answer',
          flagged,
          q['_answer_error_detail']?.toString() ??
              'This question has no clear correct answer. Choose one '
                  'before importing.');
      return;
    }

    int correctIndex = AnswerKey.unscorableIndex;
    List<String>? accepted = acceptedAnswers;
    if (type == 'short_answer') {
      if (accepted == null || accepted.isEmpty) {
        // Legacy fallback only when the keyed option is genuinely valid.
        final key = q.containsKey('correct_answer')
            ? AnswerKey.fromIndex(q['correct_answer'], options)
            : null;
        if (key != null && key.isScorable) {
          accepted = [options[key.index!]];
          correctIndex = key.index!;
        } else {
          issue('accepted_answers', AnswerKeyStatus.missingKey.code,
              'A short-answer question needs at least one accepted answer.');
          return;
        }
      }
    } else {
      final key = AnswerKey.fromIndex(q['correct_answer'], options);
      if (!key.isScorable) {
        issue('correct_answer', key.status.code,
            key.detail ?? 'The correct answer is not valid.');
        return;
      }
      if (type == 'true_false' && !TrueFalseKey.hasValidLabels(options)) {
        issue('options', AnswerKeyStatus.unsupportedType.code,
            'True/false options must be one "True" and one "False".');
        return;
      }
      correctIndex = key.index!;
    }
    if (text.trim().isEmpty) return;

    prepared.questions.add(Question(
      id: q['id']?.toString() ?? const Uuid().v4(),
      questionText: text,
      options: options,
      correctAnswer: correctIndex,
      type: type,
      explanation: q['explanation']?.toString(),
      acceptedAnswers: accepted,
      gradingMethod: q['grading_method']?.toString(),
      numericTolerance: (q['numeric_tolerance'] as num?)?.toDouble(),
      createdBy: q['created_by']?.toString() ?? userId,
    ));
  }

  /// Validate JSON structure
  bool validateLessonJson(String jsonString) {
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Check required fields
      if (jsonData['title'] == null || jsonData['title'].toString().trim().isEmpty) {
        return false;
      }

      // Check content structure
      if (jsonData['content'] is List ||
          jsonData['terms'] is List ||
          jsonData['questions'] is List ||
          jsonData['concepts'] is List) {
        return validatePayload(jsonData).isEmpty;
      }

      return false;
    } catch (e) {
      debugPrint('❌ ERROR: Invalid JSON structure: $e');
      return false;
    }
  }
}
