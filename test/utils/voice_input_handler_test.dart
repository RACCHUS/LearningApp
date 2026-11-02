import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/utils/voice_input_handler.dart';

void main() {
  group('VoiceInputHandler', () {
    final mcq = QuestionContent(
      id: 'q1',
      lessonId: 'l1',
      order: 0,
      questionText: 'Sample question?',
      options: ['Alpha', 'Beta', 'Gamma', 'Delta'],
      correctAnswer: 1,
      explanation: 'Explanation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('translates spoken A without presentationOrder to slot 0', () {
      final result = VoiceInputHandler.handleMcqVoiceInput('option a', mcq);
      expect(result, equals(0));
    });

    test('translates spoken B without presentationOrder to slot 1', () {
      final result = VoiceInputHandler.handleMcqVoiceInput('option b', mcq);
      expect(result, equals(1));
    });

    test('translates spoken A with presentationOrder [2, 0, 1, 3] to original index 2', () {
      // Presented slots:
      // A (slot 0) -> original option 2 ('Gamma')
      // B (slot 1) -> original option 0 ('Alpha')
      // C (slot 2) -> original option 1 ('Beta')
      // D (slot 3) -> original option 3 ('Delta')
      final presentationOrder = [2, 0, 1, 3];

      final resultA = VoiceInputHandler.handleMcqVoiceInput(
        'option a',
        mcq,
        presentationOrder: presentationOrder,
      );
      expect(resultA, equals(2));

      final resultB = VoiceInputHandler.handleMcqVoiceInput(
        'option b',
        mcq,
        presentationOrder: presentationOrder,
      );
      expect(resultB, equals(0));

      final resultC = VoiceInputHandler.handleMcqVoiceInput(
        'option c',
        mcq,
        presentationOrder: presentationOrder,
      );
      expect(resultC, equals(1));

      final resultD = VoiceInputHandler.handleMcqVoiceInput(
        'option d',
        mcq,
        presentationOrder: presentationOrder,
      );
      expect(resultD, equals(3));
    });

    test('handles fallback natural phrases with presentationOrder', () {
      final presentationOrder = [3, 2, 1, 0];
      final result = VoiceInputHandler.handleMcqVoiceInput(
        'the first one',
        mcq,
        presentationOrder: presentationOrder,
      );
      expect(result, equals(3));
    });
  });
}

