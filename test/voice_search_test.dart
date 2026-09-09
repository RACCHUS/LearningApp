import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/global_voice_command.dart';

void main() {
  group('Voice Search Implementation Tests', () {
    test('should extract lesson names correctly from voice commands', () {
      final testCases = [
        {
          'command': 'find lesson laptops',
          'expectedLessonName': 'laptops',
          'expectedType': GlobalVoiceCommandType.lessonManagement,
        },
        {
          'command': 'search lesson python basics',
          'expectedLessonName': 'python basics',
          'expectedType': GlobalVoiceCommandType.lessonManagement,
        },
        {
          'command': 'start lesson javascript fundamentals',
          'expectedLessonName': 'javascript fundamentals',
          'expectedType': GlobalVoiceCommandType.lessonManagement,
        },
        {
          'command': 'show lesson database design',
          'expectedLessonName': 'database design',
          'expectedType': GlobalVoiceCommandType.lessonManagement,
        },
      ];

      for (final testCase in testCases) {
        final command = GlobalVoiceCommand.parseCommand(testCase['command'] as String);
        
        expect(command, isNotNull, reason: 'Should parse command: ${testCase['command']}');
        expect(command!.type, testCase['expectedType']);
        expect(command.parameters['lessonName'], testCase['expectedLessonName'],
               reason: 'Should extract correct lesson name from: ${testCase['command']}');
        
        print('✅ ${testCase['command']} → lessonName: "${command.parameters['lessonName']}"');
      }
    });

    test('should handle implicit lesson commands without "lesson" keyword', () {
      final testCases = [
        {
          'command': 'find laptops',
          'expectedLessonName': 'laptops',
        },
        {
          'command': 'search python',
          'expectedLessonName': 'python',
        },
        {
          'command': 'show javascript',
          'expectedLessonName': 'javascript',
        },
        {
          'command': 'open database',
          'expectedLessonName': 'database',
        },
      ];

      for (final testCase in testCases) {
        final command = GlobalVoiceCommand.parseCommand(testCase['command'] as String);
        
        expect(command, isNotNull, reason: 'Should parse implicit command: ${testCase['command']}');
        expect(command!.type, GlobalVoiceCommandType.lessonManagement);
        expect(command.parameters['lessonName'], testCase['expectedLessonName'],
               reason: 'Should extract lesson name from implicit command: ${testCase['command']}');
        
        print('✅ ${testCase['command']} → lessonName: "${command.parameters['lessonName']}"');
      }
    });

    test('should reject navigation commands as lesson searches', () {
      final navigationCommands = [
        'find home',
        'show settings',
        'open profile',
        'search help',
      ];

      for (final command in navigationCommands) {
        final parsedCommand = GlobalVoiceCommand.parseCommand(command);
        
        // These should either be null or navigation commands, not lesson commands
        if (parsedCommand != null) {
          expect(parsedCommand.type, isNot(GlobalVoiceCommandType.lessonManagement),
                 reason: 'Should not treat navigation term as lesson: $command');
        }
        
        print('✅ $command → ${parsedCommand?.type.toString() ?? "null"} (not lesson)');
      }
    });

    test('should handle URL encoding scenarios', () {
      // Test lesson names that might need URL encoding
      final testCases = [
        'programming basics',
        'C++ fundamentals',
        'data & analytics',
        'web development 101',
      ];

      for (final lessonName in testCases) {
        final encoded = Uri.encodeComponent(lessonName);
        final decoded = Uri.decodeComponent(encoded);
        
        expect(decoded, lessonName, reason: 'URL encoding should be reversible');
        
        print('✅ "$lessonName" → encoded: "$encoded" → decoded: "$decoded"');
      }
    });

    test('should recognize lesson management commands correctly', () {
      final managementCommands = [
        'my lessons',
        'recent lessons',
        'lesson library',
        'all lessons',
      ];

      for (final command in managementCommands) {
        final parsedCommand = GlobalVoiceCommand.parseCommand(command);
        
        expect(parsedCommand, isNotNull, reason: 'Should recognize: $command');
        expect(parsedCommand!.type, GlobalVoiceCommandType.lessonManagement);
        
        print('✅ $command → ${parsedCommand.phrase}');
      }
    });
  });
}
