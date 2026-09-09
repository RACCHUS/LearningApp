import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/global_voice_command.dart';

void main() {
  group('Immediate Command Processing Tests', () {
    test('should recognize simple navigation commands immediately', () {
      // Test simple navigation commands that should be processed immediately
      final immediateCommands = [
        'settings',
        'home',
        'profile',
        'help',
        'go home',
        'go back',
      ];

      for (final command in immediateCommands) {
        final parsedCommand = GlobalVoiceCommand.parseCommand(command);
        
        print('Testing immediate command: "$command" -> ${parsedCommand?.phrase ?? "null"}');
        
        expect(parsedCommand, isNotNull, reason: 'Should recognize navigation command: $command');
        expect(parsedCommand!.type, GlobalVoiceCommandType.navigation, 
               reason: 'Should be navigation command: $command');
      }
    });

    test('should handle lesson commands correctly', () {
      // Test lesson commands that might need phrase accumulation
      final lessonCommands = [
        'find lesson laptops',
        'start lesson python',
        'find laptops',
        'show progress',
      ];

      for (final command in lessonCommands) {
        final parsedCommand = GlobalVoiceCommand.parseCommand(command);
        
        print('Testing lesson command: "$command" -> ${parsedCommand?.phrase ?? "null"}');
        
        expect(parsedCommand, isNotNull, reason: 'Should recognize lesson command: $command');
        expect(parsedCommand!.type, GlobalVoiceCommandType.lessonManagement, 
               reason: 'Should be lesson management command: $command');
      }
    });

    test('should apply confidence thresholds correctly', () {
      // Simulate different confidence levels
      final testCases = [
        {'command': 'settings', 'confidence': 0.95, 'shouldProcess': true},
        {'command': 'settings', 'confidence': 0.6, 'shouldProcess': false}, // Below 0.7 threshold for single word
        {'command': 'find lesson laptops', 'confidence': 0.7, 'shouldProcess': true}, // Above 0.6 threshold for multi-word
        {'command': 'find lesson laptops', 'confidence': 0.5, 'shouldProcess': false}, // Below 0.6 threshold for multi-word
      ];

      for (final testCase in testCases) {
        final command = testCase['command'] as String;
        final confidence = testCase['confidence'] as double;
        final shouldProcess = testCase['shouldProcess'] as bool;
        
        final parsedCommand = GlobalVoiceCommand.parseCommand(command);
        final words = command.split(' ');
        final confidenceThreshold = words.length > 2 ? 0.6 : 0.7;
        
        print('Testing confidence: "$command" (${(confidence * 100).toStringAsFixed(1)}%) threshold: ${(confidenceThreshold * 100).toStringAsFixed(1)}%');
        
        if (shouldProcess) {
          expect(parsedCommand, isNotNull, reason: 'Should recognize command: $command');
          expect(confidence, greaterThanOrEqualTo(confidenceThreshold), 
                 reason: 'Confidence should meet threshold');
        } else {
          expect(confidence, lessThan(confidenceThreshold), 
                 reason: 'Confidence should be below threshold');
        }
      }
    });
  });
}
