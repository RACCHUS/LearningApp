// PR-A2: bounded la-gen/1.1 parsing (master plan v2.6 §5.6, Appendix D.3).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_generation/generation_error.dart';
import 'package:learning_pwa/models/content_generation/slot_plan.dart';
import 'package:learning_pwa/services/content_generation/json_structure_scanner.dart';
import 'package:learning_pwa/services/content_generation/la_gen_parser.dart';
import 'package:learning_pwa/services/content_generation/la_gen_personal_adapter.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';

final plan = SlotPlan(
  jobCode: 'J7F3A',
  slots: const [
    SlotSpec(
      code: 'S1',
      kind: SlotKind.explanation,
      conceptCode: 'C1',
      allowedSupport: {'F2'},
    ),
    SlotSpec(
      code: 'S2',
      kind: SlotKind.mcq,
      conceptCode: 'C1',
      allowedSupport: {'F2'},
    ),
    SlotSpec(code: 'S3', kind: SlotKind.term, conceptCode: 'C1'),
  ],
);

Map<String, dynamic> s1() => {
  'slot': 'S1',
  'kind': 'explanation',
  'concept': 'C1',
  'title': 'Percentage change',
  'text': 'Percentage change compares the difference with the start.',
  'example': '100 to 120 is 20%.',
  'support': ['F2'],
};

Map<String, dynamic> s2({Object answer = 'B'}) => {
  'slot': 'S2',
  'kind': 'mcq',
  'concept': 'C1',
  'stem': 'A value rises from 100 to 120. What is the increase?',
  'options': ['10%', '20%', '25%', '120%'],
  'answer': answer,
  'why': 'The increase is 20 relative to 100.',
  'support': ['F2'],
};

Map<String, dynamic> s3() => {
  'slot': 'S3',
  'kind': 'term',
  'concept': 'C1',
  'term': 'Base value',
  'definition': 'The starting value a change is compared with.',
};

String package(
  List<Map<String, dynamic>> items, {
  String job = 'J7F3A',
  bool withEnd = true,
  bool? complete,
}) => const JsonEncoder.withIndent('  ').convert({
  'schema': 'la-gen/1.1',
  'job': job,
  'pack': 'micro_lesson_v1',
  'part': 1,
  'of': 1,
  if (complete != null) 'complete': complete,
  'items': items,
  'uncertain': [],
  if (withEnd) 'end': 'END-$job',
});

String records(List<Object> lines) =>
    lines.map((l) => l is String ? l : jsonEncode(l)).join('\n');

void main() {
  group('JsonStructureScanner', () {
    test('ignores brackets inside strings and escaped quotes', () {
      final r = JsonStructureScanner.scan(
        r'{"a": "x } ] \" {", "b": [1, {"c": 2}]}',
        maxDepth: 5,
      );
      expect(r.ok, isTrue);
      expect(r.spans, hasLength(1));
    });

    test('reports mismatch, unterminated and too-deep structures', () {
      expect(
        JsonStructureScanner.scan('{"a": [1}', maxDepth: 5).problem,
        JsonScanProblem.mismatchedBracket,
      );
      expect(
        JsonStructureScanner.scan('{"a": "open', maxDepth: 5).problem,
        JsonScanProblem.unterminated,
      );
      expect(
        JsonStructureScanner.scan('{"a": [[[1]]]}', maxDepth: 3).problem,
        JsonScanProblem.tooDeep,
      );
    });

    test('commentary quotes outside objects are not strings', () {
      final r = JsonStructureScanner.scan(
        'Here\'s your "answer": {"a": 1} hope it helps',
        maxDepth: 5,
      );
      expect(r.ok, isTrue);
      expect(r.spans, hasLength(1));
    });
  });

  group('package mode', () {
    test('accepts a complete valid package', () {
      final r = LaGenParser.parse(package([s1(), s2(), s3()]), plan);
      expect(r.fatal, isNull);
      expect(r.mode, LaGenMode.package);
      expect(r.accepted.keys, {'S1', 'S2', 'S3'});
      expect(r.accepted['S2']!.correctIndex, 1);
      expect(r.isComplete, isTrue);
      expect(r.sentinelPresent, isTrue);
      expect(r.errors, isEmpty);
    });

    test('content is kept exactly as written', () {
      final r = LaGenParser.parse(package([s1()]), plan);
      expect(r.accepted['S1']!.fields['text'], s1()['text']);
      expect(r.accepted['S1']!.fields.containsKey('slot'), isFalse);
    });

    test('answer A maps to index 0', () {
      final r = LaGenParser.parse(package([s2(answer: 'A')]), plan);
      expect(r.accepted['S2']!.correctIndex, 0);
    });

    test('one enclosing code fence and a BOM are allowed', () {
      final fenced = '﻿```json\n${package([s1()])}\n```';
      expect(LaGenParser.parse(fenced, plan).accepted, contains('S1'));
    });

    test('a single payload inside commentary is extracted and flagged', () {
      final text = 'Sure! Here it is:\n${package([s1()])}\nLet me know.';
      final r = LaGenParser.parse(text, plan);
      expect(r.accepted, contains('S1'));
      expect(r.extractedFromCommentary, isTrue);
    });

    test('two code blocks are ambiguous', () {
      final p = package([s1()]);
      final r = LaGenParser.parse('```\n$p\n```\nor\n```\n$p\n```', plan);
      expect(r.fatal!.errorCode, GenerationErrorCode.payloadAmbiguous);
    });

    test('two payload objects are ambiguous', () {
      final p = package([s1()]);
      expect(
        LaGenParser.parse('$p\n$p', plan).fatal!.errorCode,
        GenerationErrorCode.payloadAmbiguous,
      );
    });

    test('truncated package is refused, never completed', () {
      final p = package([s1(), s2()]);
      final r = LaGenParser.parse(p.substring(0, p.length - 40), plan);
      expect(r.fatal!.errorCode, GenerationErrorCode.invalidJson);
      expect(r.accepted, isEmpty);
    });

    test('trailing commas and smart quotes are not repaired', () {
      final trailing = package([
        s1(),
      ]).replaceFirst('"END-J7F3A"', '"END-J7F3A",');
      expect(
        LaGenParser.parse(trailing, plan).fatal!.errorCode,
        GenerationErrorCode.invalidJson,
      );
      final curly = package([s1()]).replaceAll('"schema"', '“schema”');
      expect(LaGenParser.parse(curly, plan).fatal, isNotNull);
    });

    test('wrong schema or job is refused', () {
      expect(
        LaGenParser.parse(
          package([s1()]).replaceFirst('la-gen/1.1', 'la-gen/2.0'),
          plan,
        ).fatal!.errorCode,
        GenerationErrorCode.schemaUnsupported,
      );
      expect(
        LaGenParser.parse(package([s1()], job: 'OTHER'), plan).fatal!.errorCode,
        GenerationErrorCode.unknownJobOrSlot,
      );
    });

    test('complete:true is a hint; missing slots are computed', () {
      final r = LaGenParser.parse(package([s1()], complete: true), plan);
      expect(r.claimedComplete, isTrue);
      expect(r.missingSlots, ['S2', 'S3']);
      expect(r.isComplete, isFalse);
    });

    test('missing end sentinel is only a hint', () {
      final r = LaGenParser.parse(package([s1()], withEnd: false), plan);
      expect(r.sentinelPresent, isFalse);
      expect(r.accepted, contains('S1'));
    });
  });

  group('slot validation (both modes share it)', () {
    GenerationError only(Map<String, dynamic> item) {
      final r = LaGenParser.parse(package([item]), plan);
      expect(r.accepted, isEmpty, reason: '$item');
      return r.errors.single;
    }

    test('unknown slot, wrong kind, wrong concept', () {
      expect(
        only({...s1(), 'slot': 'S9'}).errorCode,
        GenerationErrorCode.unknownJobOrSlot,
      );
      expect(
        only({...s2(), 'slot': 'S1'}).errorCode,
        GenerationErrorCode.unknownJobOrSlot,
      );
      expect(
        only({...s1(), 'concept': 'C2'}).errorCode,
        GenerationErrorCode.unknownJobOrSlot,
      );
    });

    test('unknown kind and unexpected fields', () {
      expect(
        only({...s1(), 'kind': 'video'}).errorCode,
        GenerationErrorCode.schemaUnsupported,
      );
      expect(
        only({...s1(), 'html': '<b>x</b>'}).errorCode,
        GenerationErrorCode.schemaUnsupported,
      );
    });

    test('unknown support code needs review', () {
      expect(
        only({
          ...s1(),
          'support': ['F9'],
        }).errorCode,
        GenerationErrorCode.reviewRequired,
      );
    });

    test('missing or blank required field needs review', () {
      expect(
        only(s1()..remove('text')).errorCode,
        GenerationErrorCode.reviewRequired,
      );
      expect(
        only({...s1(), 'title': '  '}).errorCode,
        GenerationErrorCode.reviewRequired,
      );
    });

    test('answers: only one canonical capital letter in range', () {
      for (final bad in ['b', 'B)', 'Option B', '20%', 'AB']) {
        expect(
          only(s2(answer: bad)).errorCode,
          GenerationErrorCode.answerUnresolvable,
          reason: bad,
        );
      }
      expect(only(s2(answer: '')).errorCode,
          GenerationErrorCode.reviewRequired);
      expect(only(s2(answer: 1)).errorCode, GenerationErrorCode.reviewRequired);
      expect(
        only(s2(answer: 'E')).errorCode,
        GenerationErrorCode.correctIndexOutOfRange,
      );
    });

    test('duplicate options are ambiguous', () {
      expect(
        only({
          ...s2(),
          'options': ['20%', '20 %', ' 20%', '25%'],
        }).errorCode,
        GenerationErrorCode.optionsAmbiguous,
      );
    });

    test('duplicate slot codes are all held (no last-writer-wins)', () {
      final r = LaGenParser.parse(
        package([
          s1(),
          {...s1(), 'title': 'Other'},
        ]),
        plan,
      );
      expect(r.accepted, isEmpty);
      expect(r.errors.map((e) => e.errorCode).toSet(), {
        GenerationErrorCode.payloadAmbiguous,
      });
    });

    test('a bad slot does not discard valid ones', () {
      final r = LaGenParser.parse(package([s1(), s2(answer: 'Z')]), plan);
      expect(r.accepted.keys, ['S1']);
      expect(r.missingSlots, ['S2', 'S3']);
    });
  });

  group('Mode S (one record per line)', () {
    test('accepts records and the sentinel', () {
      final r = LaGenParser.parse(
        records([
          s1(),
          s2(),
          s3(),
          {'end': 'END-J7F3A'},
        ]),
        plan,
      );
      expect(r.mode, LaGenMode.records);
      expect(r.isComplete, isTrue);
      expect(r.sentinelPresent, isTrue);
    });

    test('a truncated last line is discarded, earlier lines kept', () {
      final full = jsonEncode(s3());
      final r = LaGenParser.parse(
        records([s1(), s2(), full.substring(0, full.length - 10)]),
        plan,
      );
      expect(r.accepted.keys, {'S1', 'S2'});
      expect(r.missingSlots, ['S3']);
      expect(r.errors.single.errorCode, GenerationErrorCode.invalidJsonlRecord);
      expect(r.errors.single.line, 3);
    });

    test('a record from another job is not salvaged', () {
      final r = LaGenParser.parse(
        records([
          s1(),
          {...s2(), 'job': 'X'},
        ]),
        plan,
      );
      expect(r.accepted.keys, ['S1']);
      expect(r.errors.single.errorCode, GenerationErrorCode.unknownJobOrSlot);
    });

    test('wrong end sentinel is reported', () {
      final r = LaGenParser.parse(
        records([
          s1(),
          {'end': 'END-OTHER'},
        ]),
        plan,
      );
      expect(r.sentinelPresent, isFalse);
      expect(r.errors.single.errorCode, GenerationErrorCode.unknownJobOrSlot);
    });

    test('over-long line is refused individually', () {
      final r = LaGenParser.parse(
        records([
          s1(),
          {...s3(), 'definition': 'x' * 300},
        ]),
        plan,
        limits: const LaGenLimits(maxLineBytes: 200),
      );
      expect(r.accepted.keys, ['S1']);
      expect(r.errors.single.errorCode, GenerationErrorCode.payloadTooLarge);
    });
  });

  group('limits', () {
    test('oversized payload is refused before decoding', () {
      final r = LaGenParser.parse(
        package([s1()]),
        plan,
        limits: const LaGenLimits(maxBytes: 100),
      );
      expect(r.fatal!.errorCode, GenerationErrorCode.payloadTooLarge);
    });

    test('multi-byte text is measured in UTF-8 bytes', () {
      final text = package([
        {...s1(), 'text': 'é' * 60},
      ]);
      final r = LaGenParser.parse(
        text,
        plan,
        limits: LaGenLimits(maxBytes: text.length + 10),
      );
      expect(r.fatal!.errorCode, GenerationErrorCode.payloadTooLarge);
    });

    test('nesting deeper than the limit is refused', () {
      final r = LaGenParser.parse(
        package([s1()]),
        plan,
        limits: const LaGenLimits(maxDepth: 2),
      );
      expect(r.fatal!.errorCode, GenerationErrorCode.structureTooDeep);
    });

    test('too many items is refused', () {
      final r = LaGenParser.parse(
        package([s1(), s2(), s3()]),
        plan,
        limits: const LaGenLimits(maxRecords: 2),
      );
      expect(r.fatal!.errorCode, GenerationErrorCode.payloadTooLarge);
    });

    test('over-long field is refused', () {
      final r = LaGenParser.parse(
        package([
          {...s1(), 'text': 'x' * 50},
        ]),
        plan,
        limits: const LaGenLimits(maxFieldChars: 20),
      );
      expect(r.errors.single.errorCode, GenerationErrorCode.payloadTooLarge);
    });
  });

  group('personal-lesson adapter', () {
    test('produces a lesson the real importer accepts unchanged', () {
      final r = LaGenParser.parse(package([s2(), s3(), s1()]), plan);
      final lesson = LaGenPersonalAdapter.toPersonalLesson(
        title: 'Percent change',
        result: r,
      );
      expect(lesson['questions'][0]['correct_answer'], 1);
      expect(
        lesson['concepts'][0]['example_text'],
        contains('Example: 100 to 120 is 20%.'),
      );
      final preview = LessonImportService.preview(lesson);
      expect(preview.issues, isEmpty);
      expect(preview.questionCount, 1);
      expect(preview.termCount, 1);
      expect(preview.conceptCount, 1);
    });

    test('rejected slots are not carried into the lesson', () {
      final r = LaGenParser.parse(package([s1(), s2(answer: 'Z')]), plan);
      final lesson = LaGenPersonalAdapter.toPersonalLesson(
        title: 'T',
        result: r,
      );
      expect(lesson.containsKey('questions'), isFalse);
    });
  });
}
