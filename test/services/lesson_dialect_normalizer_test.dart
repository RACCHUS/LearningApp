// PR-0b: existing creation paths normalize to one validated personal lesson
// (master plan v2.6 §14.9, Appendix H.2/H.5).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/services/ai_prompt_service.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import 'package:learning_pwa/services/lesson/lesson_dialect_normalizer.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';

import '../fixtures/lesson_dialects.dart';

class _Crud implements LessonCrudService {
  final lessons = <Lesson>[];

  @override
  Future<Lesson> addLesson(
    String title,
    String? description,
    String userId, {
    List<String>? tags,
  }) async {
    final lesson = Lesson(
      id: 'lesson-${lessons.length + 1}',
      title: title,
      description: description,
      tags: tags ?? [],
      userId: userId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      terms: [],
      questions: [],
      concepts: [],
    );
    lessons.add(lesson);
    return lesson;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Content implements LessonContentService {
  final terms = <Term>[];
  final questions = <Question>[];
  final concepts = <Concept>[];

  @override
  Future<void> addTerms(String lessonId, List<Term> t) async => terms.addAll(t);
  @override
  Future<void> addQuestions(String lessonId, List<Question> q) async =>
      questions.addAll(q);
  @override
  Future<void> addConcepts(String lessonId, List<Concept> c) async =>
      concepts.addAll(c);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _copy(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

void main() {
  late _Crud crud;
  late _Content content;
  late LessonImportService service;

  setUp(() {
    crud = _Crud();
    content = _Content();
    service = LessonImportService(crudService: crud, contentService: content);
  });

  Future<Object?> importError(Map<String, dynamic> json) async {
    try {
      await service.importLessonFromJson(jsonEncode(json), 'u');
      return null;
    } catch (e) {
      return e;
    }
  }

  test('Quick Generate prompt still documents the shape the adapter reads', () {
    final prompt = AiPromptService.generateLessonCreationPrompt(
      subject: 'Percent change',
      targetAudience: 'adults',
      durationMinutes: 20,
      difficulty: 'beginner',
      contentFocus: 'balanced',
    );
    for (final marker in [
      '"lesson": {',
      '"content": [',
      '"type": "term"',
      '"type": "concept"',
      '"key_points"',
      '"type": "mcq"',
      '"correct_answer": "string (required, must match one option exactly)"',
    ]) {
      expect(prompt, contains(marker), reason: marker);
    }
  });

  group('dialect detection', () {
    test('identifies each producer', () {
      expect(
        LessonDialectNormalizer.detect(_copy(quickGenerateResponse)),
        LessonSourceDialect.quickGenerate,
      );
      expect(
        LessonDialectNormalizer.detect(_copy(builderOutput)),
        LessonSourceDialect.builderEnvelope,
      );
      expect(
        LessonDialectNormalizer.detect(_copy(flatPersonal)),
        LessonSourceDialect.flatPersonal,
      );
      expect(
        LessonDialectNormalizer.detect({
          'title': 'G',
          'questions': [
            {'_needs_review': true},
          ],
        }),
        LessonSourceDialect.guidedAssembled,
      );
      expect(
        LessonDialectNormalizer.detect({
          'target': {'slug': 'x'},
          'domains': [],
        }),
        LessonSourceDialect.curriculumManifest,
      );
    });
  });

  group('Quick Generate → import → reopen', () {
    test('saves terms, concepts and exact answers without loss', () async {
      final lesson = await service.importLessonFromJson(
        jsonEncode(quickGenerateResponse),
        'u',
      );

      expect(lesson.title, 'Percent Change Basics');
      expect(lesson.tags, ['math', 'percent']);
      expect(content.terms.single.term, 'Percent change');
      expect(content.terms.single.definition, startsWith('The difference'));
      expect(content.terms.single.example, 'From 50 to 60 is a 20% increase.');

      final concept = content.concepts.single;
      expect(concept.conceptText, 'Increase versus decrease');
      expect(concept.exampleText, contains('A positive result'));
      expect(concept.exampleText, contains('• Always divide by the original'));
      expect(concept.exampleText, contains('• 80 → 60 is −25%'));

      expect(content.questions.map((q) => q.correctAnswer), [0, 2]);
      // Reopen through the stored representation.
      for (final q in content.questions) {
        final reopened = Question.fromJson({
          ...q.toJson(),
          'created_at': '2026-01-01T00:00:00Z',
        });
        expect(reopened.answerKey.isScorable, isTrue);
      }
      expect(
        content.questions[1].options[content.questions[1].correctAnswer],
        '−25%',
      );
    });

    test('preview reports unsaved fields and the same counts', () {
      final preview = LessonImportService.preview(_copy(quickGenerateResponse));
      expect(preview.canImport, isTrue);
      expect(preview.termCount, 1);
      expect(preview.conceptCount, 1);
      expect(preview.questionCount, 2);
      expect(
        preview.draft.notSaved,
        containsAll([
          'lesson.estimated_duration_minutes',
          'lesson.difficulty_level',
          'content[0].emoji',
          'content[0].tags',
        ]),
      );
    });

    test(
      'textual answer that matches no option is rejected at its path',
      () async {
        final json = _copy(quickGenerateResponse);
        ((json['content'] as List)[2] as Map)['correct_answer'] = '2';
        final error = await importError(json);
        final issue = (error as LessonImportValidationException).issues.single;
        expect(issue.path, 'content[2].correct_answer');
        expect(issue.code, 'invalid_key');
        expect(crud.lessons, isEmpty);
      },
    );

    test('textual answer matching duplicate options is ambiguous', () async {
      final json = _copy(quickGenerateResponse);
      final mcq = (json['content'] as List)[2] as Map;
      mcq['options'] = ['20%', '20 %', '20%', '60%'];
      final error = await importError(json);
      expect(
        (error as LessonImportValidationException).issues.single.code,
        'ambiguous_options',
      );
    });
  });

  group('Manual Builder → import → reopen', () {
    test('saves correctIndex (including 0) and concept key points', () async {
      final lesson = await service.importLessonFromJson(
        jsonEncode(builderOutput),
        'u',
      );
      expect(lesson.title, 'Spreadsheet Formatting');
      expect(content.questions.map((q) => q.correctAnswer), [0, 2]);
      expect(content.questions.map((q) => q.id), ['b-mcq-1', 'b-mcq-2']);
      expect(content.terms.single.term, 'Percent format');
      expect(
        content.concepts.single.exampleText,
        contains('• Formulas use the stored value'),
      );
    });

    test('rejects missing, non-integer or out-of-range correctIndex', () async {
      for (final bad in <Object?>[null, '1', 1.0, 3, -1]) {
        crud.lessons.clear();
        final json = _copy(builderOutput);
        final mcq = (json['content'] as List)[1] as Map;
        if (bad == null) {
          mcq.remove('correctIndex');
        } else {
          mcq['correctIndex'] = bad;
        }
        final error = await importError(json);
        expect(error, isA<LessonImportValidationException>(), reason: '$bad');
        expect(
          (error as LessonImportValidationException).issues.single.path,
          'content[1].correct_answer',
          reason: '$bad',
        );
        expect(crud.lessons, isEmpty);
      }
    });

    test('conflicting correctIndex and correct_answer are rejected', () async {
      final json = _copy(builderOutput);
      final mcq = (json['content'] as List)[1] as Map;
      mcq['correct_answer'] = '5%';
      final error = await importError(json);
      expect(
        (error as LessonImportValidationException).issues.single.code,
        'conflicting_answer',
      );
    });

    test('agreeing correctIndex and correct_answer are accepted', () async {
      final json = _copy(builderOutput);
      ((json['content'] as List)[1] as Map)['correct_answer'] = '50%';
      await service.importLessonFromJson(jsonEncode(json), 'u');
      expect(content.questions.first.correctAnswer, 0);
    });
  });

  group('structural rejections', () {
    test('envelope without a title keeps the existing title error', () async {
      final json = _copy(builderOutput);
      (json['lesson'] as Map).remove('title');
      expect(await importError(json), isA<ArgumentError>());
      expect(LessonImportService.preview(json).issues.single.path, 'title');
    });

    test('unsupported content types are reported, not dropped', () async {
      final json = _copy(builderOutput);
      (json['content'] as List).add({'type': 'text', 'text': 'Note'});
      final issue =
          ((await importError(json)) as LessonImportValidationException)
              .issues
              .single;
      expect(issue.path, 'content[4].type');
      expect(issue.code, 'unsupported_type');
    });

    test(
      'term missing its definition is reported at its source path',
      () async {
        final json = _copy(quickGenerateResponse);
        ((json['content'] as List)[0] as Map).remove('content');
        final issue =
            ((await importError(json)) as LessonImportValidationException)
                .issues
                .single;
        expect(issue.path, 'content[0]');
      },
    );

    test(
      'curriculum manifests are never imported as personal lessons',
      () async {
        final error = await importError({
          'target': {'slug': 'clep'},
          'source_releases': [],
          'domains': [],
        });
        expect(
          (error as LessonImportValidationException).issues.single.code,
          'privileged_manifest',
        );
        expect(crud.lessons, isEmpty);
      },
    );

    test('"lesson" without a content list is an unknown format', () async {
      final error = await importError({
        'lesson': {'title': 'x'},
      });
      expect(
        (error as LessonImportValidationException).issues.single.code,
        'unknown_format',
      );
    });
  });

  test('flat personal lessons still import unchanged', () async {
    await service.importLessonFromJson(jsonEncode(flatPersonal), 'u');
    expect(content.questions.single.correctAnswer, 0);
    expect(content.terms.single.term, 'Fraction');
  });
}
