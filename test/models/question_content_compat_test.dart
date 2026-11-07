import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/models/question_content.dart';

/// Writes the pre-grading layout (fields 0-9 only) under typeId 5.
class _LegacyQuestionAdapter extends TypeAdapter<QuestionContent> {
  @override
  final int typeId = 5;

  @override
  QuestionContent read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, QuestionContent obj) {
    writer
      ..writeByte(10)
      ..writeByte(6)
      ..write(obj.questionText)
      ..writeByte(7)
      ..write(obj.options)
      ..writeByte(8)
      ..write(obj.correctAnswer)
      ..writeByte(9)
      ..write(obj.explanation)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.lessonId)
      ..writeByte(2)
      ..write(obj.order)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }
}

QuestionContent q(List<String> options, {String? type}) => QuestionContent(
  id: 'q',
  lessonId: 'l',
  order: 0,
  questionText: 'Q?',
  options: options,
  correctAnswer: 0,
  questionType: type,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('effectiveQuestionType uses the declared type, else infers', () {
    expect(
      q(['a', 'b'], type: 'short_answer').effectiveQuestionType,
      'short_answer',
    );
    expect(q(['True', 'False']).effectiveQuestionType, 'true_false');
    expect(q(['Paris']).effectiveQuestionType, 'short_answer');
    expect(q(['a', 'b', 'c']).effectiveQuestionType, 'mcq');
    expect(q(['a', 'b', 'c'], type: 'question').effectiveQuestionType, 'mcq');
  });

  test('JSON without grading fields still parses', () {
    final legacy = QuestionContent.fromJson({
      'id': 'q',
      'lesson_id': 'l',
      'order': 0,
      'questionText': 'Q?',
      'options': ['4'],
      'correctAnswer': 0,
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    });
    expect(legacy.acceptedAnswers, isNull);
    expect(legacy.gradingMethod, isNull);
    expect(legacy.effectiveQuestionType, 'short_answer');
  });

  test('JSON round-trips grading fields', () {
    final original = QuestionContent(
      id: 'q',
      lessonId: 'l',
      order: 0,
      questionText: 'Q?',
      options: const [],
      correctAnswer: 0,
      questionType: 'short_answer',
      acceptedAnswers: const ['3.14'],
      gradingMethod: 'numeric',
      numericTolerance: 0.01,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final copy = QuestionContent.fromJson(original.toJson());
    expect(copy.acceptedAnswers, ['3.14']);
    expect(copy.gradingMethod, 'numeric');
    expect(copy.numericTolerance, 0.01);
    expect(copy.questionType, 'short_answer');
  });

  test('Hive records written before the new fields still load', () async {
    final dir = Directory.systemTemp.createTempSync('question_compat');
    addTearDown(() => dir.deleteSync(recursive: true));
    Hive.init(dir.path);

    Hive.registerAdapter(_LegacyQuestionAdapter(), override: true);
    final box = await Hive.openBox<QuestionContent>('legacy_questions');
    await box.put('q', q(['Paris']));
    await box.close();

    Hive.registerAdapter(QuestionContentAdapter(), override: true);
    final reopened = await Hive.openBox<QuestionContent>('legacy_questions');
    final loaded = reopened.get('q')!;
    expect(loaded.options, ['Paris']);
    expect(loaded.questionType, isNull);
    expect(loaded.acceptedAnswers, isNull);
    expect(loaded.effectiveQuestionType, 'short_answer');
    await reopened.close();
  });
}
