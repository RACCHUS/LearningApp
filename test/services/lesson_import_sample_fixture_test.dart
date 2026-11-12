// The published lesson sample must import through the production path
// (plan PR-3; replaces the test/integration/test_import.dart diagnostic, which
// re-implemented order handling instead of calling the importer and printed
// success for a sample the importer rejected).
//
// data/samples/sample_lesson_valid.json is also served to AI agents as the
// example lesson by tool/mcp_server, so it must stay importable.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';

Map<String, dynamic> _sample() =>
    jsonDecode(File('data/samples/sample_lesson_valid.json').readAsStringSync()) as Map<String, dynamic>;

List<String> _field(LessonImportPreview p, String list, String key) =>
    [for (final item in p.draft.personal[list] as List) (item as Map)[key].toString()];

void main() {
  test('sample lesson passes the production preflight with exact counts', () {
    final raw = _sample();
    final content = raw['content'] as List;
    int count(Set<String> types) => content.where((i) => types.contains((i as Map)['type'])).length;

    final preview = LessonImportService.preview(raw);

    expect(preview.issues, isEmpty);
    expect(preview.canImport, isTrue);
    expect(preview.termCount, count({'term'}));
    expect(preview.conceptCount, count({'concept'}));
    expect(preview.questionCount, count({'mcq', 'multiple_choice', 'question', 'true_false', 'short_answer'}));
    expect(preview.termCount + preview.conceptCount + preview.questionCount, content.length,
        reason: 'every sample item must be importable; none may be dropped');
  });

  test('items keep their array order within each type; "order" values are not used', () {
    final raw = _sample();
    final content = raw['content'] as List;
    final sourceTerms = [
      for (final i in content)
        if ((i as Map)['type'] == 'term') i['term'].toString(),
    ];

    final asAuthored = LessonImportService.preview(raw);
    expect(_field(asAuthored, 'terms', 'term'), sourceTerms);

    // Reverse every "order" value: the importer must produce the same draft,
    // documenting that order is taken from array position, not this field.
    final reordered = _sample();
    final items = reordered['content'] as List;
    for (var i = 0; i < items.length; i++) {
      (items[i] as Map)['order'] = items.length - i;
    }
    final withReversedOrder = LessonImportService.preview(reordered);
    expect(_field(withReversedOrder, 'terms', 'term'), sourceTerms);
    expect(_field(withReversedOrder, 'questions', 'question_text'),
        _field(asAuthored, 'questions', 'question_text'));
  });

  test('a free "text" item is rejected with its path (regression for the old sample)', () {
    final raw = _sample();
    (raw['content'] as List).add({'type': 'text', 'text': 'Free prose'});
    final preview = LessonImportService.preview(raw);
    expect(preview.canImport, isFalse);
    expect(preview.issues.map((i) => i.path), contains('content[${(raw['content'] as List).length - 1}].type'));
  });
}
