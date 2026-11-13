import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/services/content_generation/lesson_composer.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';

import '../lesson_import_service_test.dart' show MockLessonCrudService;

/// Two ideas, each with explanation (E), term (T) and two questions (Q).
ManualJob job() => ManualJob.plan(
  ManualJobRequest(
    subject: 'S',
    concepts: ['A', 'B'],
    questionsPerConcept: 2,
    includeTerms: true,
  ),
  random: Random(1),
);
// A: S1=E S2=T S3=Q S4=Q   B: S5=E S6=T S7=Q S8=Q
const all = {'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8'};

class OrderCapturingContent implements LessonContentService {
  final terms = <int?>[];
  final questions = <int?>[];
  final concepts = <int?>[];

  @override
  Future<void> addTerms(
    String lessonId,
    List<Term> t, {
    List<int?> orders = const [],
  }) async => terms.addAll(orders);

  @override
  Future<void> addQuestions(
    String lessonId,
    List<Question> q, {
    List<int?> orders = const [],
  }) async => questions.addAll(orders);

  @override
  Future<void> addConcepts(
    String lessonId,
    List<Concept> c, {
    List<int?> orders = const [],
  }) async => concepts.addAll(orders);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('LessonComposer templates', () {
    test('understand: teach, term, one check per idea, then mixed review', () {
      expect(
        LessonComposer.compose(job().plan, all, LessonObjectiveType.understand),
        ['S1', 'S2', 'S3', 'S5', 'S6', 'S7', 'S4', 'S8'],
      );
    });

    test('procedure: explain then practise per idea, terms at the end', () {
      expect(
        LessonComposer.compose(job().plan, all, LessonObjectiveType.procedure),
        ['S1', 'S3', 'S4', 'S5', 'S7', 'S8', 'S2', 'S6'],
      );
    });

    test('memorize: terms, interleaved questions, explanations last', () {
      expect(
        LessonComposer.compose(job().plan, all, LessonObjectiveType.memorize),
        ['S2', 'S6', 'S3', 'S7', 'S4', 'S8', 'S1', 'S5'],
      );
    });

    test('every accepted slot appears exactly once; missing ones skipped', () {
      for (final t in LessonObjectiveType.values) {
        final out = LessonComposer.compose(job().plan, {'S1', 'S4', 'S6'}, t);
        expect(out.toSet(), {'S1', 'S4', 'S6'}, reason: t.name);
        expect(out.length, 3, reason: t.name);
      }
    });

    test('positions leave gaps', () {
      expect(LessonComposer.positions(['S2', 'S1']), {'S2': 10, 'S1': 20});
    });
  });

  group('composed import', () {
    Map<String, dynamic> lesson(LessonObjectiveType? type) {
      final j = job();
      final s = ManualJobSession(j)
        ..applyPaste(
          jsonEncode({
            'schema': 'la-gen/1.1',
            'job': j.plan.jobCode,
            'items': [
              for (final c in ['C1', 'C2']) ...[
                {
                  'slot': c == 'C1' ? 'S1' : 'S5',
                  'kind': 'explanation',
                  'concept': c,
                  'title': 'E$c',
                  'text': 'Text',
                },
                {
                  'slot': c == 'C1' ? 'S2' : 'S6',
                  'kind': 'term',
                  'concept': c,
                  'term': 'T$c',
                  'definition': 'D',
                },
                for (final q in c == 'C1' ? ['S3', 'S4'] : ['S7', 'S8'])
                  {
                    'slot': q,
                    'kind': 'mcq',
                    'concept': c,
                    'stem': 'Q$q',
                    'options': ['x', 'y'],
                    'answer': 'A',
                  },
              ],
            ],
          }),
        );
      return s.toPersonalLesson(title: 'T', objectiveType: type);
    }

    test('without a type, no order is set (old behaviour)', () {
      final l = lesson(null);
      expect((l['questions'] as List).first.containsKey('order'), isFalse);
    });

    test('memorize puts terms first through import to storage', () async {
      final content = OrderCapturingContent();
      final service = LessonImportService(
        crudService: MockLessonCrudService(),
        contentService: content,
      );
      final l = lesson(LessonObjectiveType.memorize);
      expect(LessonImportService.preview(l).issues, isEmpty);
      await service.importLessonFromJson(jsonEncode(l), 'user-1');
      expect(content.terms, [10, 20]);
      expect(content.questions, [30, 50, 40, 60]); // S3 S4 S7 S8 positions
      expect(content.concepts, [70, 80]);
    });

    test('invalid order values are refused before anything is saved', () {
      final l = lesson(LessonObjectiveType.understand);
      ((l['questions'] as List).first as Map)['order'] = -5;
      final issues = LessonImportService.preview(l).issues;
      expect(issues.map((i) => i.code), contains('invalid_order'));
      ((l['questions'] as List).first as Map)['order'] = '10';
      expect(
        LessonImportService.preview(l).issues.map((i) => i.code),
        contains('invalid_order'),
      );
    });
  });
}
