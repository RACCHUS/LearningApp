import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/words/word_sense_service.dart';

void main() {
  group('WordSenseService Tests', () {
    test('contains curated vocabulary across vocational categories', () {
      final service = WordSenseService();
      final items = service.getAllSenses();
      expect(items, isNotEmpty);
      expect(items.any((i) => i.category == 'Workplace Safety'), isTrue);
      expect(items.any((i) => i.category == 'Florida Real Estate'), isTrue);
      expect(items.any((i) => i.category == 'Food & Health Safety'), isTrue);
    });

    test('getSensesByCategory filters items accurately', () {
      final service = WordSenseService();
      final safetyItems = service.getSensesByCategory('Workplace Safety');
      expect(safetyItems, isNotEmpty);
      for (final item in safetyItems) {
        expect(item.category, equals('Workplace Safety'));
      }
    });

    test('getSenseForWord finds matching word sense case-insensitively', () {
      final service = WordSenseService();
      final sense = service.getSenseForWord('hazard');
      expect(sense, isNotNull);
      expect(sense!.word, equals('Hazard'));
      expect(sense.distractorDefinitions, isNotEmpty);
    });
  });
}
