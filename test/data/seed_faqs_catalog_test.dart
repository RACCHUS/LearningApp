import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/data/seed_faqs_catalog.dart';

void main() {
  group('SeedFaqsCatalog & Manifest Verification (ECO-01, Priority 5)', () {
    test('catalog contains exactly 36 curated seed FAQs', () {
      final questions = SeedFaqsCatalog.allQuestions;
      expect(questions.length, equals(36));

      final uniqueIds = questions.map((q) => q.id).toSet();
      expect(uniqueIds.length, equals(36), reason: 'All FAQ IDs must be strictly unique');
    });

    test('catalog contains exactly 12 items per domain', () {
      final literacy = SeedFaqsCatalog.getByDomain('adult_literacy');
      final safety = SeedFaqsCatalog.getByDomain('workplace_safety');
      final licensure = SeedFaqsCatalog.getByDomain('florida_licensure');

      expect(literacy.length, equals(12));
      expect(safety.length, equals(12));
      expect(licensure.length, equals(12));
    });

    test('every question has a corresponding authoritative answer with citation', () {
      for (final q in SeedFaqsCatalog.allQuestions) {
        final answers = SeedFaqsCatalog.getAnswersForQuestion(q.id);
        expect(answers, isNotEmpty, reason: 'Question ${q.id} must have an answer');
        expect(answers.first.bodyMarkdown, contains('Source:'),
            reason: 'Answer for ${q.id} must cite an official or research authority');
      }
    });

    test('seed_faqs_manifest.json exists and parses cleanly', () {
      final file = File('data/seed_faqs/seed_faqs_manifest.json');
      expect(file.existsSync(), isTrue, reason: 'Manifest JSON must exist in data/seed_faqs/');

      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      expect(json['totalCount'], equals(36));
      expect(json['domains'], containsAll(['adult_literacy', 'workplace_safety', 'florida_licensure']));
      final faqs = json['faqs'] as List<dynamic>;
      expect(faqs.length, equals(36));
    });
  });
}
