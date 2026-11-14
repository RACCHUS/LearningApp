import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/answer_key.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/services/lesson/content_loading_service.dart';

import '../../test_helpers/fake_supabase_client.dart';

/// Lesson reading must never expose protected exam items, must keep invalid
/// answer keys unscorable, and must fall back to legacy content in order.
void main() {
  const lessonId = 'lesson-1';
  late FakeSupabaseClient client;

  Map<String, dynamic> item(String id, Map<String, dynamic> metadata) => {
        'id': id,
        'lesson_id': lessonId,
        'interaction_type': 'single_choice',
        'prompt': 'Prompt $id',
        'response_spec': {
          'options': ['a', 'b'],
        },
        'metadata': metadata,
      };

  setUp(() {
    client = FakeSupabaseClient();
    client.setTableData('lessons', [
      {
        'id': lessonId,
        'title': 'Fractions',
        'created_at': '2026-11-01T00:00:00Z',
        'updated_at': '2026-11-01T00:00:00Z',
        'user_id': 'owner-1',
      },
    ]);
  });

  test('protected, simulation-bank and timed-only items never reach lesson reading', () async {
    client.setTableData('assessment_items', [
      item('formative', {}),
      item('protected-bool', {'is_protected': true}),
      item('protected-string', {'is_protected': 'true'}),
      item('simulation-bank', {'bank': 'simulation_exam'}),
      item('timed-only', {'exposure': 'timed_exam_only'}),
      item('not-protected', {'is_protected': false, 'bank': 'formative'}),
    ]);

    final lesson = await ContentLoadingService(supabase: client).loadUnifiedLesson(lessonId);

    expect(lesson.assessmentItems.map((i) => i.id), ['formative', 'not-protected']);
  });

  test('without lesson blocks, legacy terms, concepts and questions load in order', () async {
    client.setTableData('terms', [
      {'id': 't1', 'lesson_id': lessonId, 'term': 'Numerator', 'definition': 'Top number', 'order_index': 2},
    ]);
    client.setTableData('concepts', [
      {'id': 'c1', 'lesson_id': lessonId, 'concept_text': 'Equivalent fractions', 'order_index': 1},
    ]);
    client.setTableData('questions', [
      {
        'id': 'q1',
        'lesson_id': lessonId,
        'question_text': '1/2 = ?',
        'options': ['2/4', '1/3'],
        'correct_answer': 0,
        'order_index': 3,
      },
    ]);

    final lesson = await ContentLoadingService(supabase: client).loadUnifiedLesson(lessonId);

    expect(lesson.blocks, isEmpty);
    expect(lesson.legacyContent.map((c) => c.id), ['c1', 't1', 'q1']);
    expect(lesson.legacyContent[0], isA<ConceptContent>());
    expect((lesson.legacyContent[1] as TermContent).definition, 'Top number');
    final question = lesson.legacyContent[2] as QuestionContent;
    expect(question.correctAnswer, 0, reason: 'an explicit in-range 0 is a valid key');
  });

  test('missing or out-of-range stored answer keys become unscorable, never option A', () async {
    client.setTableData('questions', [
      {'id': 'missing', 'lesson_id': lessonId, 'question_text': 'a', 'options': ['x', 'y'], 'order_index': 1},
      {
        'id': 'out-of-range',
        'lesson_id': lessonId,
        'question_text': 'b',
        'options': ['x', 'y'],
        'correct_answer': 5,
        'order_index': 2,
      },
      {
        'id': 'garbage',
        'lesson_id': lessonId,
        'question_text': 'c',
        'options': ['x', 'y'],
        'correct_answer': 'B?',
        'order_index': 3,
      },
    ]);

    final lesson = await ContentLoadingService(supabase: client).loadUnifiedLesson(lessonId);
    final keys = {
      for (final q in lesson.legacyContent.whereType<QuestionContent>()) q.id: q.correctAnswer,
    };

    expect(keys, {
      'missing': AnswerKey.unscorableIndex,
      'out-of-range': AnswerKey.unscorableIndex,
      'garbage': AnswerKey.unscorableIndex,
    });
  });

  test('with lesson blocks, only legacy questions are appended as practice', () async {
    client.setTableData('lesson_blocks', [
      {'id': 'b1', 'lesson_id': lessonId, 'sort_order': 0, 'block_type': 'markdown', 'content': {'text': 'Hi'}},
    ]);
    client.setTableData('terms', [
      {'id': 't1', 'lesson_id': lessonId, 'term': 'x', 'definition': 'y'},
    ]);
    client.setTableData('questions', [
      {'id': 'q1', 'lesson_id': lessonId, 'question_text': 'q', 'options': ['a', 'b'], 'correct_answer': 1},
    ]);

    final lesson = await ContentLoadingService(supabase: client).loadUnifiedLesson(lessonId);

    expect(lesson.blocks.map((b) => b.id), ['b1']);
    expect(lesson.legacyContent.map((c) => c.id), ['q1']);
  });

  test('another lesson\'s rows are not mixed in', () async {
    client.setTableData('questions', [
      {'id': 'mine', 'lesson_id': lessonId, 'question_text': 'q', 'options': ['a'], 'correct_answer': 0},
      {'id': 'theirs', 'lesson_id': 'other-lesson', 'question_text': 'q', 'options': ['a'], 'correct_answer': 0},
    ]);

    final lesson = await ContentLoadingService(supabase: client).loadUnifiedLesson(lessonId);

    expect(lesson.legacyContent.map((c) => c.id), ['mine']);
    expect(lesson.lesson.title, 'Fractions');
  });
}
