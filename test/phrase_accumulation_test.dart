import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/global_voice_command.dart';

void main() {
  group('Phrase Accumulation Tests', () {
    test('should parse multi-word lesson commands correctly', () {
      // Test cases for commands that were failing
      final testCases = [
        'find lesson laptops',
        'start lesson python basics',
        'find laptops', // Should be interpreted as "find lesson laptops"
        'search programming', // Should be interpreted as "search lesson programming"
        'open database tutorial',
        'show javascript course',
      ];

      for (final testCase in testCases) {
        final command = GlobalVoiceCommand.parseCommand(testCase);
        
        print('Testing: "$testCase" -> ${command?.phrase ?? "null"}');
        
        if (testCase.contains('find') || testCase.contains('search') || 
            testCase.contains('show') || testCase.contains('open')) {
          expect(command, isNotNull, reason: 'Should recognize find/search command: $testCase');
          expect(command!.type, GlobalVoiceCommandType.lessonManagement);
          expect(command.value, LessonManagementCommand.findLesson);
          expect(command.parameters['lessonName'], isNotNull, reason: 'Should extract lesson name from: $testCase');
        } else if (testCase.contains('start') || testCase.contains('begin') || 
                   testCase.contains('launch')) {
          expect(command, isNotNull, reason: 'Should recognize start command: $testCase');
          expect(command!.type, GlobalVoiceCommandType.lessonManagement);
          expect(command.value, LessonManagementCommand.startLesson);
          expect(command.parameters['lessonName'], isNotNull, reason: 'Should extract lesson name from: $testCase');
        }
      }
    });

    test('should handle navigation commands', () {
      final navigationTests = [
        'go home',
        'settings',
        'profile',
        'help',
      ];

      for (final testCase in navigationTests) {
        final command = GlobalVoiceCommand.parseCommand(testCase);
        
        print('Testing navigation: "$testCase" -> ${command?.phrase ?? "null"}');
        
        expect(command, isNotNull, reason: 'Should recognize navigation command: $testCase');
        expect(command!.type, GlobalVoiceCommandType.navigation);
      }
    });

    test('should reject generic terms as lesson names', () {
      final genericTests = [
        'find home', // Should be navigation, not lesson
        'start the', // Too generic
        'show a', // Too generic
        'find settings', // Should be navigation
      ];

      for (final testCase in genericTests) {
        final command = GlobalVoiceCommand.parseCommand(testCase);
        
        print('Testing generic rejection: "$testCase" -> ${command?.phrase ?? "null"}');
        
        // These should either be null or navigation commands, not lesson commands
        if (command != null && command.type == GlobalVoiceCommandType.lessonManagement) {
          // If it's a lesson command, the lesson name should not be generic
          final lessonName = command.parameters['lessonName'] as String?;
          if (lessonName != null) {
            expect(GlobalVoiceCommand.isGenericTerm(lessonName), false, 
                   reason: 'Should not accept generic term "$lessonName" as lesson name');
          }
        }
      }
    });

    test('should handle synonym variations', () {
      // These should all be equivalent
      final synonymGroups = [
        ['find lesson laptops', 'search lesson laptops', 'show lesson laptops', 'look for lesson laptops'],
        ['start lesson python', 'begin lesson python', 'launch lesson python', 'play lesson python'],
      ];

      for (final group in synonymGroups) {
        final commands = group.map((phrase) => GlobalVoiceCommand.parseCommand(phrase)).toList();
        
        // All commands in the group should have the same type and value
        final firstCommand = commands.first;
        expect(firstCommand, isNotNull);
        
        for (int i = 1; i < commands.length; i++) {
          expect(commands[i], isNotNull, reason: 'Command $i should not be null: ${group[i]}');
          expect(commands[i]!.type, firstCommand!.type, 
                 reason: 'Command types should match for synonyms');
          expect(commands[i]!.value, firstCommand.value, 
                 reason: 'Command values should match for synonyms');
          
          print('Synonym test: "${group[0]}" == "${group[i]}" -> ${commands[i]!.phrase}');
        }
      }
    });
  });
}
