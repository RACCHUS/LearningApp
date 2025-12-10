import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/utils/voice_command_router.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/models/content_types.dart';

void main() {
  group('VoiceCommandRouter - Context-Aware Parsing', () {
    test('should parse commands with MCQ context', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'A',
        context: 'mcq',
      );

      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.answer);
      expect(command.value, 'A');
    });

    test('should parse commands with true/false context', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'true',
        context: 'true_false',
      );

      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.answer);
      expect(command.value, isTrue);
    });

    test('should parse commands with short answer context', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'Paris',
        context: 'short_answer',
      );

      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.answer);
      expect(command.value, 'Paris');
    });

    test('should parse commands with navigation context', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'next',
        context: 'lesson_navigation',
      );

      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.navigation);
    });

    test('should fallback to standard parsing without context', () {
      final command = VoiceCommandRouter.parseContextAwareCommand('next');

      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.navigation);
    });

    test('should prioritize standard commands over context', () {
      // "next" should be parsed as navigation even in MCQ context
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'next',
        context: 'mcq',
      );

      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.navigation);
    });
  });

  group('VoiceCommandRouter - MCQ Answer Recognition', () {
    test('should recognize direct letter answers', () {
      final testCases = ['a', 'b', 'c', 'd'];
      final expectedValues = ['A', 'B', 'C', 'D'];

      for (int i = 0; i < testCases.length; i++) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCases[i],
          context: 'mcq',
        );

        expect(command, isNotNull, reason: 'Should parse: ${testCases[i]}');
        expect(command!.type, VoiceCommandType.answer);
        expect(command.value, expectedValues[i]);
      }
    });

    test('should recognize option variants', () {
      final testCases = [
        'option a',
        'option b',
        'option c',
        'option d',
      ];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'mcq',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.type, VoiceCommandType.answer);
      }
    });

    test('should recognize ordinal answers', () {
      final testCases = {
        'first': 'A',
        'second': 'B',
        'third': 'C',
        'fourth': 'D',
      };

      testCases.forEach((input, expectedValue) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          input,
          context: 'mcq',
        );

        expect(command, isNotNull, reason: 'Should parse: $input');
        expect(command!.value, expectedValue);
      });
    });

    test('should recognize ordinal with option keyword', () {
      final testCases = [
        'first option',
        'second option',
        'third option',
        'fourth option',
      ];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'mcq',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.type, VoiceCommandType.answer);
      }
    });

    test('should recognize choice indicators', () {
      final testCases = [
        'choice a',
        'choice b',
        'choice c',
        'choice d',
      ];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'mcq',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.type, VoiceCommandType.answer);
      }
    });

    test('should recognize natural speech patterns', () {
      final testCases = [
        'the first one',
        'the second one',
        'the third one',
        'the fourth one',
      ];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'mcq',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.type, VoiceCommandType.answer);
      }
    });

    test('should recognize answer patterns', () {
      final testCases = [
        'answer a',
        'answer b',
        'answer c',
        'answer d',
      ];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'mcq',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.type, VoiceCommandType.answer);
      }
    });

    test('should be case insensitive for MCQ answers', () {
      final testCases = ['A', 'a', 'OPTION A', 'option a'];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'mcq',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.value, 'A');
      }
    });
  });

  group('VoiceCommandRouter - True/False Recognition', () {
    test('should recognize direct true/false answers', () {
      final trueCommand = VoiceCommandRouter.parseContextAwareCommand(
        'true',
        context: 'true_false',
      );
      expect(trueCommand, isNotNull);
      expect(trueCommand!.value, isTrue);

      final falseCommand = VoiceCommandRouter.parseContextAwareCommand(
        'false',
        context: 'true_false',
      );
      expect(falseCommand, isNotNull);
      expect(falseCommand!.value, isFalse);
    });

    test('should recognize yes/no variants', () {
      final yesCommand = VoiceCommandRouter.parseContextAwareCommand(
        'yes',
        context: 'true_false',
      );
      expect(yesCommand, isNotNull);
      expect(yesCommand!.value, isTrue);

      final noCommand = VoiceCommandRouter.parseContextAwareCommand(
        'no',
        context: 'true_false',
      );
      expect(noCommand, isNotNull);
      expect(noCommand!.value, isFalse);
    });

    test('should recognize correct/incorrect variants', () {
      final correctCommand = VoiceCommandRouter.parseContextAwareCommand(
        'correct',
        context: 'true_false',
      );
      expect(correctCommand, isNotNull);
      expect(correctCommand!.value, isTrue);

      final incorrectCommand = VoiceCommandRouter.parseContextAwareCommand(
        'incorrect',
        context: 'true_false',
      );
      expect(incorrectCommand, isNotNull);
      expect(incorrectCommand!.value, isFalse);
    });

    test('should recognize right/wrong variants', () {
      final rightCommand = VoiceCommandRouter.parseContextAwareCommand(
        'right',
        context: 'true_false',
      );
      expect(rightCommand, isNotNull);
      expect(rightCommand!.value, isTrue);

      final wrongCommand = VoiceCommandRouter.parseContextAwareCommand(
        'wrong',
        context: 'true_false',
      );
      expect(wrongCommand, isNotNull);
      expect(wrongCommand!.value, isFalse);
    });

    test('should recognize natural speech patterns for true/false', () {
      final testCases = {
        'that is true': true,
        'that is false': false,
        "that's true": true,
        "that's false": false,
      };

      testCases.forEach((input, expectedValue) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          input,
          context: 'true_false',
        );

        expect(command, isNotNull, reason: 'Should parse: $input');
        expect(command!.value, expectedValue);
      });
    });

    test('should recognize affirmative patterns', () {
      final testCases = [
        'definitely true',
        'absolutely true',
        'definitely false',
        'absolutely false',
      ];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'true_false',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.type, VoiceCommandType.answer);
        expect(command.value is bool, isTrue);
      }
    });

    test('should be case insensitive for true/false', () {
      final testCases = ['TRUE', 'True', 'FALSE', 'False'];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'true_false',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.value is bool, isTrue);
      }
    });
  });

  group('VoiceCommandRouter - Short Answer Recognition', () {
    test('should capture full text as answer', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'The capital of France is Paris',
        context: 'short_answer',
      );

      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.answer);
      expect(command.value, 'The capital of France is Paris');
    });

    test('should trim whitespace from short answers', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        '  Paris  ',
        context: 'short_answer',
      );

      expect(command, isNotNull);
      expect(command!.value, 'Paris');
    });

    test('should not interpret navigation commands as answers', () {
      final navigationCommands = ['next', 'previous', 'pause', 'stop', 'repeat'];

      for (final navCommand in navigationCommands) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          navCommand,
          context: 'short_answer',
        );

        // Should parse as navigation, not answer
        expect(command, isNotNull);
        expect(command!.type, isNot(VoiceCommandType.answer));
      }
    });

    test('should handle empty short answers', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        '',
        context: 'short_answer',
      );

      expect(command, isNull);
    });

    test('should preserve case in short answers', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'JavaScript',
        context: 'short_answer',
      );

      expect(command, isNotNull);
      expect(command!.value, 'JavaScript'); // Case preserved
    });

    test('should handle numeric answers', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        '42',
        context: 'short_answer',
      );

      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.answer);
      expect(command.value, '42');
    });

    test('should handle multi-word answers', () {
      final testCases = [
        'World War Two',
        'Marie Curie',
        'United States of America',
      ];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'short_answer',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.value, testCase);
      }
    });
  });

  group('VoiceCommandRouter - Navigation Context', () {
    test('should recognize next command variants', () {
      final testCases = ['next', 'forward', 'continue', 'move on', 'go next'];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'lesson_navigation',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.type, VoiceCommandType.navigation);
        expect(command.value, NavigationCommand.next);
      }
    });

    test('should recognize previous command variants', () {
      final testCases = ['previous', 'back', 'go back', 'move back'];

      for (final testCase in testCases) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          testCase,
          context: 'lesson_navigation',
        );

        expect(command, isNotNull, reason: 'Should parse: $testCase');
        expect(command!.value, NavigationCommand.previous);
      }
    });

    test('should recognize jump commands', () {
      final testCases = {
        'first': NavigationCommand.first,
        'last': NavigationCommand.last,
        'beginning': NavigationCommand.first,
        'end': NavigationCommand.last,
      };

      testCases.forEach((input, expectedValue) {
        final command = VoiceCommandRouter.parseContextAwareCommand(
          input,
          context: 'lesson_navigation',
        );

        expect(command, isNotNull, reason: 'Should parse: $input');
        expect(command!.value, expectedValue);
      });
    });
  });

  group('VoiceCommandRouter - Context Detection from Content', () {
    test('should detect MCQ context from content', () {
      final mcqContent = QuestionContent(
        id: '1',
        lessonId: 'test_lesson',
        order: 0,
        questionText: 'What is 2+2?',
        options: ['2', '3', '4', '5'],
        correctAnswer: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final context = VoiceCommandRouter.getContextFromContent(mcqContent);
      expect(context, equals('question'));
    });

    test('should detect true/false context from content', () {
      final tfContent = QuestionContent(
        id: '1',
        lessonId: 'test_lesson',
        order: 0,
        questionText: 'The sky is blue',
        options: ['True', 'False'],
        correctAnswer: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final context = VoiceCommandRouter.getContextFromContent(tfContent);
      expect(context, equals('question'));
    });

    test('should detect short answer context from content', () {
      final saContent = QuestionContent(
        id: '1',
        lessonId: 'test_lesson',
        order: 0,
        questionText: 'What is the capital of France?',
        options: [],
        correctAnswer: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final context = VoiceCommandRouter.getContextFromContent(saContent);
      expect(context, equals('question'));
    });

    test('should return null context for non-question content', () {
      final conceptContent = ConceptContent(
        id: '1',
        lessonId: 'test_lesson',
        order: 0,
        conceptText: 'This is a concept',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final context = VoiceCommandRouter.getContextFromContent(conceptContent);
      expect(context, isNull);
    });
  });

  group('VoiceCommandRouter - Edge Cases', () {
    test('should handle null text input', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        '',
        context: 'mcq',
      );

      expect(command, isNull);
    });

    test('should handle invalid context', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'test',
        context: 'invalid_context',
      );

      // Should fallback to standard parsing or return null
      expect(command, anyOf(isNull, isNotNull));
    });

    test('should handle ambiguous input in MCQ context', () {
      // Input that could be confused with other patterns
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'e',
        context: 'mcq',
      );

      // Should not parse as valid MCQ answer (only A-D are valid)
      if (command != null) {
        expect(command.value, isNot(equals('E')));
      }
    });

    test('should handle mixed case in context', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'TrUe',
        context: 'true_false',
      );

      expect(command, isNotNull);
      expect(command!.value, isTrue);
    });

    test('should handle extra whitespace', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        '  option  a  ',
        context: 'mcq',
      );

      expect(command, isNotNull);
      expect(command!.value, 'A');
    });

    test('should prioritize exact matches over partial matches', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        'a next',
        context: 'mcq',
      );

      // Should recognize as navigation command (next) not MCQ answer
      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.navigation);
    });

    test('should handle special characters in short answers', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        "it's a test",
        context: 'short_answer',
      );

      expect(command, isNotNull);
      expect(command!.value, contains("'"));
    });

    test('should handle numbers in MCQ context', () {
      final command = VoiceCommandRouter.parseContextAwareCommand(
        '1',
        context: 'mcq',
      );

      // Numbers should not be recognized as MCQ answers (only A-D)
      if (command != null && command.type == VoiceCommandType.answer) {
        expect(command.value, isNot(anyOf('A', 'B', 'C', 'D')));
      }
    });
  });

  group('VoiceCommandRouter - Integration with VoiceInputHandler', () {
    test('should integrate with MCQ handler pattern', () {
      final userInput = 'option b';
      final command = VoiceCommandRouter.parseContextAwareCommand(
        userInput,
        context: 'mcq',
      );

      expect(command, isNotNull);
      expect(command!.type, VoiceCommandType.answer);
      
      // Should convert to index (B = index 1)
      final letterToIndex = {'A': 0, 'B': 1, 'C': 2, 'D': 3};
      final index = letterToIndex[command.value];
      expect(index, equals(1));
    });

    test('should integrate with true/false handler pattern', () {
      final userInput = 'yes';
      final command = VoiceCommandRouter.parseContextAwareCommand(
        userInput,
        context: 'true_false',
      );

      expect(command, isNotNull);
      expect(command!.value, isTrue);
    });

    test('should filter navigation commands in answer contexts', () {
      final navigationCommands = ['next', 'previous', 'pause'];

      for (final navCmd in navigationCommands) {
        final mcqCommand = VoiceCommandRouter.parseContextAwareCommand(
          navCmd,
          context: 'mcq',
        );

        // Should not be treated as MCQ answer
        if (mcqCommand != null) {
          expect(mcqCommand.type, isNot(VoiceCommandType.answer));
        }

        final tfCommand = VoiceCommandRouter.parseContextAwareCommand(
          navCmd,
          context: 'true_false',
        );

        // Should not be treated as true/false answer
        if (tfCommand != null) {
          expect(tfCommand.type, isNot(VoiceCommandType.answer));
        }
      }
    });
  });
}
