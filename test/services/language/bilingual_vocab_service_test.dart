import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/language/bilingual_vocab_service.dart';

void main() {
  group('BilingualVocabService Tests', () {
    test('contains curated bilingual vocational terminology', () {
      final service = BilingualVocabService();
      final items = service.getAllItems();
      expect(items, isNotEmpty);
      expect(items.any((i) => i.category == 'OSHA Workplace Safety'), isTrue);
      expect(items.any((i) => i.category == 'Florida Driver Rules'), isTrue);
    });

    test('terms have both English and Spanish translations and phonetics', () {
      final service = BilingualVocabService();
      for (final item in service.getAllItems()) {
        expect(item.englishTerm, isNotEmpty);
        expect(item.spanishTerm, isNotEmpty);
        expect(item.englishDefinition, isNotEmpty);
        expect(item.spanishDefinition, isNotEmpty);
        expect(item.spanishPhonetic, isNotEmpty);
      }
    });

    test('getItemsByCategory filters correctly', () {
      final service = BilingualVocabService();
      final items = service.getItemsByCategory('OSHA Workplace Safety');
      expect(items, isNotEmpty);
      for (final item in items) {
        expect(item.category, equals('OSHA Workplace Safety'));
      }
    });
  });
}
