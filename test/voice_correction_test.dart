import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/voice_command_corrector.dart';

void main() {
  group('Voice Command Correction Tests', () {
    late VoiceCommandCorrector corrector;

    setUp(() {
      corrector = VoiceCommandCorrector();
      corrector.initialize();
    });

    test('should correct common speech recognition errors', () {
      // Test "fine lesson" -> "find lesson"
      final correction1 = corrector.analyzeCommand('fine lesson laptops', 0.8);
      expect(correction1, isNotNull);
      expect(correction1!.suggestedCommand, contains('find lesson'));
      expect(correction1.confidence, greaterThan(0.7));
      
      print('✅ "fine lesson laptops" → "${correction1.suggestedCommand}" (${(correction1.confidence * 100).toStringAsFixed(1)}%)');

      // Test "strat lesson" -> "start lesson"
      final correction2 = corrector.analyzeCommand('strat lesson python', 0.8);
      expect(correction2, isNotNull);
      expect(correction2!.suggestedCommand, contains('start lesson'));
      expect(correction2.confidence, greaterThan(0.7));
      
      print('✅ "strat lesson python" → "${correction2.suggestedCommand}" (${(correction2.confidence * 100).toStringAsFixed(1)}%)');

      // Test "setting" -> "settings"
      final correction3 = corrector.analyzeCommand('setting', 0.8);
      expect(correction3, isNotNull);
      expect(correction3!.suggestedCommand, equals('settings'));
      expect(correction3.confidence, greaterThan(0.8));
      
      print('✅ "setting" → "${correction3.suggestedCommand}" (${(correction3.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('should handle fuzzy matching for similar commands', () {
      // Test fuzzy matching
      final correction1 = corrector.analyzeCommand('gome', 0.7);
      expect(correction1, isNotNull);
      expect(correction1!.suggestedCommand, equals('go home'));
      
      print('✅ "gome" → "${correction1.suggestedCommand}" (${(correction1.confidence * 100).toStringAsFixed(1)}%)');

      final correction2 = corrector.analyzeCommand('prof', 0.7);
      expect(correction2, isNotNull);
      expect(correction2!.suggestedCommand, equals('profile'));
      
      print('✅ "prof" → "${correction2.suggestedCommand}" (${(correction2.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('should not suggest corrections for valid commands', () {
      // Test exact matches - should return null (no correction needed)
      final correction1 = corrector.analyzeCommand('find lesson laptops', 0.9);
      expect(correction1, isNull); // No correction needed
      
      final correction2 = corrector.analyzeCommand('settings', 0.9);
      expect(correction2, isNull); // No correction needed
      
      final correction3 = corrector.analyzeCommand('go home', 0.9);
      expect(correction3, isNull); // No correction needed
      
      print('✅ Valid commands correctly identified as not needing correction');
    });

    test('should handle complex multi-word corrections', () {
      // Test complex corrections
      final correction1 = corrector.analyzeCommand('fine less laptops', 0.7);
      expect(correction1, isNotNull);
      expect(correction1!.suggestedCommand, contains('find lesson'));
      
      print('✅ "fine less laptops" → "${correction1.suggestedCommand}" (${(correction1.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('should provide confidence scores appropriately', () {
      // High-confidence corrections (exact error matches)
      final highConfidence = corrector.analyzeCommand('fine lesson', 0.8);
      expect(highConfidence!.confidence, greaterThan(0.9));
      
      // Medium-confidence corrections (fuzzy matches)
      final mediumConfidence = corrector.analyzeCommand('hom', 0.7);
      expect(mediumConfidence!.confidence, greaterThanOrEqualTo(0.6));
      expect(mediumConfidence.confidence, lessThan(0.9));
      
      print('✅ Confidence scoring working correctly:');
      print('   High: "fine lesson" → ${(highConfidence.confidence * 100).toStringAsFixed(1)}%');
      print('   Medium: "hom" → ${(mediumConfidence.confidence * 100).toStringAsFixed(1)}%');
    });

    test('should handle phonetic similarity', () {
      // Test phonetic-like errors
      final correction1 = corrector.analyzeCommand('sine in', 0.7);
      expect(correction1, isNotNull);
      // Should suggest something similar phonetically
      
      print('✅ "sine in" → "${correction1!.suggestedCommand}" (${(correction1.confidence * 100).toStringAsFixed(1)}%)');
    });

    test('should reject very different inputs', () {
      // Test inputs that are too different
      final correction1 = corrector.analyzeCommand('xyz abc def', 0.5);
      expect(correction1?.confidence ?? 0, lessThan(0.6));
      
      final correction2 = corrector.analyzeCommand('', 0.5);
      expect(correction2, isNull);
      
      print('✅ Correctly rejected very different/empty inputs');
    });
  });
}
