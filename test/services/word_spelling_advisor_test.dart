import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/word_spelling_advisor.dart';

void main() {
  late WordSpellingAdvisor advisor;

  setUp(() {
    advisor = WordSpellingAdvisor.fromWords([
      'reluctant',
      'relevant',
      'relative',
      'liability',
      'color',
      'draft',
      'dog',
      'cat',
      'letter',
      'later',
    ]);
  });

  test('recognizes a known spelling case-insensitively', () async {
    final response = await advisor.check('RELUCTANT');
    expect(response.recognized, isTrue);
    expect(response.suggestions, isEmpty);
  });

  test('offers a non-binding correction for a likely typo', () async {
    final response = await advisor.check('reluctent');
    expect(response.recognized, isFalse);
    expect(response.suggestions, contains('reluctant'));
  });

  test('recognizes that UK spelling is not automatically a US entry', () async {
    final response = await advisor.check('colour');
    expect(response.recognized, isFalse);
    expect(response.suggestions, contains('color'));
  });

  test('treats a name or unusual trade term as unrecognized, not invalid', () async {
    for (final word in ['Reaz', 'superheat']) {
      final response = await advisor.check(word);
      expect(response.recognized, isFalse);
    }
  });

  test('returns up to three suggestions, in a deterministic order', () async {
    final response = await advisor.check('latr');
    expect(response.suggestions.length, lessThanOrEqualTo(3));
    expect(response.suggestions.toSet().length, response.suggestions.length);
  });

  test('loads the word list once and retains it for repeated checks', () async {
    var loads = 0;
    final service = WordSpellingAdvisor(loadSource: () async {
      loads++;
      return '# header\ncolor\nliability\n';
    });
    expect((await service.check('color')).recognized, isTrue);
    expect((await service.check('liability')).recognized, isTrue);
    expect(loads, 1);
  });

  test('empty input has no suggestions', () async {
    final result = await advisor.check('   ');
    expect(result.recognized, isFalse);
    expect(result.suggestions, isEmpty);
  });
}
