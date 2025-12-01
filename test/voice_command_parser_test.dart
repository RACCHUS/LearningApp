import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/voice_command_parser.dart';

void main() {
  group('VoiceCommandParser Tests', () {
    late VoiceCommandParser parser;

    setUp(() {
      parser = VoiceCommandParser();
    });

    test('should parse navigation commands', () {
      final result1 = parser.parseCommand('next');
      expect(result1, isNotNull);
      expect(result1!.phrase, 'next');
      
      final result2 = parser.parseCommand('previous');
      expect(result2, isNotNull);
      expect(result2!.phrase, 'previous');
      
      final result3 = parser.parseCommand('first');
      expect(result3, isNotNull);
      expect(result3!.phrase, 'first');
    });

    test('should parse audio control commands', () {
      final result1 = parser.parseCommand('pause');
      expect(result1, isNotNull);
      expect(result1!.phrase, 'pause');
      
      final result2 = parser.parseCommand('resume');
      expect(result2, isNotNull);
      
      final result3 = parser.parseCommand('faster');
      expect(result3, isNotNull);
      expect(result3!.phrase, 'faster');
    });

    test('should parse volume commands', () {
      final result1 = parser.parseCommand('volume up');
      expect(result1, isNotNull);
      expect(result1!.phrase, 'volume up');
      
      final result2 = parser.parseCommand('volume down');
      expect(result2, isNotNull);
      expect(result2!.phrase, 'volume down');
    });

    test('should parse page navigation commands', () {
      final result = parser.parseCommand('go to page 5');
      expect(result, isNotNull);
      expect(result!.phrase, contains('page'));
    });

    test('should return null for empty text', () {
      final result1 = parser.parseCommand('');
      expect(result1, isNull);
      
      final result2 = parser.parseCommand(null);
      expect(result2, isNull);
    });

    test('should handle case insensitivity', () {
      final result1 = parser.parseCommand('NEXT');
      expect(result1, isNotNull);
      
      final result2 = parser.parseCommand('Pause');
      expect(result2, isNotNull);
    });

    test('should detect command patterns', () {
      expect(parser.containsCommandPattern('next please'), isTrue);
      expect(parser.containsCommandPattern('pause'), isTrue);
      expect(parser.containsCommandPattern('random words xyz'), isFalse);
      expect(parser.containsCommandPattern(''), isFalse);
      expect(parser.containsCommandPattern(null), isFalse);
    });

    test('should provide available commands help text', () {
      final help = parser.getAvailableCommands();
      expect(help, isNotEmpty);
      expect(help, contains('next'));
      expect(help, contains('pause'));
      expect(help, contains('volume'));
      expect(help, contains('faster'));
    });

    test('should parse with confidence scoring', () {
      final result = parser.parseCommandWithConfidence('next', 0.9);
      expect(result, isNotNull);
      expect(result!.phrase, 'next');
      
      final lowConfidence = parser.parseCommandWithConfidence('next', 0.3);
      expect(lowConfidence, isNotNull); // Should still return command
    });
  });
}
