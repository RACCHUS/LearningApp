import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/word_learning.dart';
import 'package:learning_pwa/services/word_learning_transfer.dart';

void main() {
  final originUser = '11111111-1111-4111-8111-111111111111';
  final sourceList = '22222222-2222-4222-8222-222222222222';
  final key = WordFormIdentity.formKey(word: 'liability');
  final reviewId = WordFormIdentity.spellingReviewContentId(key);

  Map<String, dynamic> fixture() => {
    'format': WordLearningTransfer.format,
    'version': 1,
    'source_user_id': originUser,
    'exported_at': DateTime.utc(2026, 10, 16).toIso8601String(),
    'lists': [
      {
        'source_id': sourceList,
        'title': 'Insurance spelling',
        'description': null,
        'entries': [
          {
            'word': 'liability',
            'form_key': key,
            'locale': 'en-US',
            'entry_kind': 'ordinary',
            'case_policy': 'ignore_case',
            'accepted_forms': <String>[],
            'pronunciation_hint': null,
            'sort_order': 0,
          }
        ],
      }
    ],
    'reviews': [
      {
        'content_id': reviewId,
        'title': 'liability',
        'repetition_level': 1,
        'ease_factor': 2.5,
        'next_review_date': DateTime.utc(2026, 10, 20).toIso8601String(),
        'last_reviewed_at': DateTime.utc(2026, 10, 16).toIso8601String(),
        'total_reviews': 1,
        'correct_reviews': 1,
      }
    ],
  };

  test('accepts a valid private spelling export', () {
    final result = WordLearningTransfer.validate(jsonEncode(fixture()));
    expect(result['source_user_id'], originUser);
    expect((result['lists'] as List).length, 1);
  });

  test('rejects unknown versions and arbitrary JSON', () {
    final data = fixture()..['version'] = 99;
    expect(() => WordLearningTransfer.validate(jsonEncode(data)),
        throwsFormatException);
    expect(() => WordLearningTransfer.validate('{}'), throwsFormatException);
  });

  test('rejects forged word identity', () {
    final data = fixture();
    final list = (data['lists'] as List).first as Map<String, dynamic>;
    final entry = (list['entries'] as List).first as Map<String, dynamic>;
    entry['word'] = 'unrelated';
    expect(() => WordLearningTransfer.validate(jsonEncode(data)),
        throwsFormatException);
  });

  test('rejects duplicated backup list origin', () {
    final data = fixture();
    final list = (data['lists'] as List).first;
    (data['lists'] as List).add(list);
    expect(() => WordLearningTransfer.validate(jsonEncode(data)),
        throwsFormatException);
  });

  test('rejects duplicate word key within one list', () {
    final data = fixture();
    final list = (data['lists'] as List).first as Map<String, dynamic>;
    final entry = (list['entries'] as List).first;
    (list['entries'] as List).add(entry);
    expect(() => WordLearningTransfer.validate(jsonEncode(data)),
        throwsFormatException);
  });

  test('rejects non-word review identifiers', () {
    final data = fixture();
    final review = (data['reviews'] as List).first as Map<String, dynamic>;
    review['content_id'] = 'term:somebody-elses-data';
    expect(() => WordLearningTransfer.validate(jsonEncode(data)),
        throwsFormatException);
  });

  test('rejects corrupted progress counters', () {
    final data = fixture();
    final review = (data['reviews'] as List).first as Map<String, dynamic>;
    review['correct_reviews'] = 3;
    expect(() => WordLearningTransfer.validate(jsonEncode(data)),
        throwsFormatException);
  });

  test('rejects non-JSON and excessively large input', () {
    expect(() => WordLearningTransfer.validate('not json'),
        throwsFormatException);
    expect(() => WordLearningTransfer.validate(
        'x' * (WordLearningTransfer.maxChars + 1)), throwsFormatException);
  });
}
