import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/mcq.dart';

void main() {
  group('Concept Model Tests', () {
    test('fromJson creates a Concept with correct values', () {
      final json = {
        'id': '1',
        'lesson_id': '101',
        'concept_text': 'Test Concept',
        'example_text': 'Test Example',
        'created_by': 'test_user',
        'created_at': '2023-01-01T00:00:00.000Z',
      };

      final concept = Concept.fromJson(json);

      expect(concept.id, '1');
      expect(concept.lessonId, '101');
      expect(concept.conceptText, 'Test Concept');
      expect(concept.exampleText, 'Test Example');
      expect(concept.createdBy, 'test_user');
      expect(concept.createdAt, DateTime.utc(2023, 1, 1));
    });

    test('toJson returns correct map', () {
      final concept = Concept(
        id: '1',
        lessonId: '101',
        conceptText: 'Test Concept',
        exampleText: 'Test Example',
        createdBy: 'test_user',
        createdAt: DateTime.utc(2023, 1, 1),
      );

      final json = concept.toJson();

      expect(json['id'], '1');
      expect(json['lesson_id'], '101');
      expect(json['concept_text'], 'Test Concept');
      expect(json['example_text'], 'Test Example');
      expect(json['created_by'], 'test_user');
      expect(json['created_at'], '2023-01-01T00:00:00.000Z');
    });
  });

  group('MCQ Model Tests', () {
    test('fromJson creates an MCQ with correct values', () {
      final json = {
        'id': '1',
        'lesson_id': '101',
        'order': 0,
        'question': 'Test Question',
        'options': ['Option 1', 'Option 2', 'Option 3'],
        'correct_option_index': 0,
        'explanation': 'Test Explanation',
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-01T00:00:00.000Z',
      };

      final mcq = Mcq.fromJson(json);

      expect(mcq.id, '1');
      expect(mcq.lessonId, '101');
      expect(mcq.order, 0);
      expect(mcq.question, 'Test Question');
      expect(mcq.options, ['Option 1', 'Option 2', 'Option 3']);
      expect(mcq.correctOption, 0);
      expect(mcq.explanation, 'Test Explanation');
      expect(mcq.createdAt, DateTime.utc(2023, 1, 1));
      expect(mcq.updatedAt, DateTime.utc(2023, 1, 1));
    });

    test('toJson returns correct map', () {
      final mcq = Mcq(
        id: '1',
        lessonId: '101',
        order: 0,
        question: 'Test Question',
        options: ['Option 1', 'Option 2', 'Option 3'],
        correctOption: 0,
        explanation: 'Test Explanation',
        createdAt: DateTime.utc(2023, 1, 1),
        updatedAt: DateTime.utc(2023, 1, 1),
      );

      final json = mcq.toJson();

      expect(json['id'], '1');
      expect(json['lesson_id'], '101');
      expect(json['order'], 0);
      expect(json['question'], 'Test Question');
      expect(json['options'], ['Option 1', 'Option 2', 'Option 3']);
      expect(json['correct_option_index'], 0);
      expect(json['explanation'], 'Test Explanation');
      expect(json['created_at'], '2023-01-01T00:00:00.000Z');
      expect(json['updated_at'], '2023-01-01T00:00:00.000Z');
    });
  });
}