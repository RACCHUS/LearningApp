import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/word_learning.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';

void main() {
  group('stable word identity', () {
    test('same word on different lists maps to the same spelling review', () {
      final a = WordFormIdentity.formKey(word: 'Liability');
      final b = WordFormIdentity.formKey(word: ' liability ');
      expect(a, b);
      expect(
        WordFormIdentity.spellingReviewContentId(a),
        WordFormIdentity.spellingReviewContentId(b),
      );
    });

    test('en-US and en-GB, proper names and exact case are distinct', () {
      final base = WordFormIdentity.formKey(word: 'color');
      expect(base, isNot(WordFormIdentity.formKey(word: 'color', locale: 'en-GB')));
      expect(base, isNot(WordFormIdentity.formKey(
        word: 'color', kind: WordEntryKind.properName,
        casePolicy: WordCasePolicy.exact,
      )));
      expect(
        WordFormIdentity.formKey(word: 'Reaz',
          kind: WordEntryKind.properName, casePolicy: WordCasePolicy.exact),
        isNot(WordFormIdentity.formKey(word: 'reaz',
          kind: WordEntryKind.properName, casePolicy: WordCasePolicy.exact)),
      );
    });

    test('meaningful punctuation and accents are preserved', () {
      expect(WordFormIdentity.formKey(word: 'co-op'),
        isNot(WordFormIdentity.formKey(word: 'coop')));
      expect(WordFormIdentity.formKey(word: 'café'),
        isNot(WordFormIdentity.formKey(word: 'cafe')));
    });

    test('rejects empty entries', () {
      expect(() => WordFormIdentity.formKey(word: '   '), throwsArgumentError);
    });
  });

  test('review item persists the SQL content type word_skill', () {
    final item = ReviewableItem.fromJson({
      'id': 'item-1',
      'content_id': 'word:v1:en-US:ordinary:ignore_case:bGlhYmlsaXR5:spelling',
      'content_type': 'word_skill',
      'title': 'liability',
      'next_review_date': DateTime.utc(2026, 10, 20).toIso8601String(),
      'metadata': <String, dynamic>{},
    });
    expect(item.contentType, ReviewableContentType.wordSkill);
    expect(item.toJson()['content_type'], 'word_skill');
  });

  group('spelling scoring', () {
    test('ordinary words are case insensitive, proper names can be exact', () {
      expect(SpellingScorer.score(submitted: 'DOG', target: 'dog').correct, isTrue);
      expect(SpellingScorer.score(submitted: 'reaz', target: 'Reaz',
        casePolicy: WordCasePolicy.exact).correct, isFalse);
    });

    test('regional alternatives are not accepted implicitly', () {
      final result = SpellingScorer.score(submitted: 'colour', target: 'color');
      expect(result.correct, isFalse);
      expect(result.acceptedVariant, isFalse);
    });

    test('user explicitly approved variant earns credit', () {
      final result = SpellingScorer.score(
        submitted: 'colour', target: 'color', acceptedForms: ['colour'],
      );
      expect(result.correct, isTrue);
      expect(result.acceptedVariant, isTrue);
    });

    test('assisted accuracy does not count as independent retrieval', () {
      final result = SpellingScorer.score(
        submitted: 'liability', target: 'liability', assisted: true,
      );
      expect(result.correct, isTrue);
      expect(result.unassistedSuccess, isFalse);
    });

    test('wrong spelling is not repaired by scoring', () {
      expect(SpellingScorer.score(submitted: 'reluctent', target: 'reluctant')
          .correct, isFalse);
      expect(SpellingScorer.score(submitted: '  ', target: 'dog').correct, isFalse);
    });
  });
}
