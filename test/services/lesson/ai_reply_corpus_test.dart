import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';
import 'package:learning_pwa/services/lesson/pasted_json.dart';

/// Realistic replies from AI chats to the Quick Generate prompt, run
/// through the same steps as JSON Import: read the paste, then the
/// importer's own normalize + preflight. Nothing may be guessed: a reply
/// either imports with the right answer keys or is refused with a reason.
void main() {
  String fixture(String name) =>
      File('test/fixtures/ai_replies/$name').readAsStringSync();

  ({PastedJson pasted, LessonImportPreview? preview}) run(String name) {
    final pasted = PastedJson.read(fixture(name));
    return (
      pasted: pasted,
      preview: pasted.json == null
          ? null
          : LessonImportService.preview(pasted.json!),
    );
  }

  List<int> keys(LessonImportPreview p) => [
    for (final q in p.draft.personal['questions'] as List)
      (q as Map)['correct_answer'] as int,
  ];

  test('plain JSON imports', () {
    final r = run('_lesson_body.json');
    expect(r.pasted.extracted, isFalse);
    expect(r.preview!.canImport, isTrue);
    expect(r.preview!.termCount, 2);
    expect(r.preview!.conceptCount, 2);
    expect(r.preview!.questionCount, 3);
    expect(keys(r.preview!), [2, 1, 0]);
  });

  for (final name in [
    'quick_chatgpt_fenced.txt',
    'quick_scope_warning.txt',
    'quick_prose_braces.txt',
  ]) {
    test('$name: the JSON is taken out of the surrounding text', () {
      final r = run(name);
      expect(r.pasted.extracted, isTrue);
      expect(r.preview!.canImport, isTrue, reason: '${r.preview!.issues}');
      expect(keys(r.preview!), [2, 1, 0]);
    });
  }

  test('letters, "B) text", trailing full stops and curly quotes resolve '
      'to the same keys', () {
    for (final name in [
      'quick_letters_and_typography.txt',
      'quick_curly_quotes.txt',
    ]) {
      final r = run(name);
      expect(
        r.preview!.canImport,
        isTrue,
        reason: '$name ${r.preview!.issues}',
      );
      expect(keys(r.preview!), [2, 1, 0], reason: name);
    }
  });

  test('an answer that is not an option is refused, never guessed', () {
    final r = run('quick_answer_not_an_option.txt');
    expect(r.preview!.canImport, isFalse);
    expect(
      r.preview!.issues.map((i) => i.toString()).join(),
      contains('Column H'),
    );
  });

  test('a letter that disagrees with its text, or options that are '
      'letters themselves, is refused', () {
    final r = run('quick_letter_conflict.txt');
    expect(r.preview!.canImport, isFalse);
  });

  test('a cut-off reply says so', () {
    final r = run('quick_truncated.txt');
    expect(r.pasted.json, isNull);
    expect(r.pasted.error, contains('cut off'));
  });

  test('two JSON blocks are refused rather than chosen between', () {
    final r = run('quick_two_blocks.txt');
    expect(r.pasted.json, isNull);
    expect(r.pasted.error, contains('more than one JSON block'));
  });

  test('empty and oversized pastes are explained', () {
    expect(PastedJson.read('  ').error, contains('Paste'));
    expect(
      PastedJson.read('x' * (PastedJson.maxChars + 1)).error,
      contains('too long'),
    );
  });

  group('PastedJson.readAny (AI-Guided batches)', () {
    test('arrays: plain, fenced, and with commentary', () {
      expect(PastedJson.readAny('[1, 2]').value, [1, 2]);
      expect(PastedJson.readAny('```json\n[{"a": 1}]\n```').value, [
        {'a': 1},
      ]);
      expect(PastedJson.readAny('Here you go: [{"a": 1}] Enjoy!').value, [
        {'a': 1},
      ]);
    });

    test('objects still come out exactly; nothing is repaired', () {
      expect(PastedJson.readAny('Plan:\n{"x": 1}').value, {'x': 1});
      final broken = PastedJson.readAny('[{"a": 1},]');
      expect(broken.value, isNull, reason: 'trailing comma is not repaired');
      expect(PastedJson.readAny('no json here').value, isNull);
      expect(PastedJson.readAny('Here is the plan [v1]: {"x": 1}').value, {
        'x': 1,
      }, reason: 'brackets in commentary do not make it an array');
    });
  });
}
