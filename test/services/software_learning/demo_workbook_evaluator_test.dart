import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/software_learning/demo_workbook_reader.dart';
import 'package:learning_pwa/widgets/software_learning/excel_upload_card.dart';

Uint8List rewrite(
  Uint8List bytes, {
  Map<String, String Function(String)> edits = const {},
  Map<String, String> additions = const {},
}) {
  final original = ZipDecoder().decodeBytes(bytes);
  final archive = Archive();
  for (final file in original.files) {
    final text = utf8.decode(file.content as List<int>);
    final data = utf8.encode(edits[file.name]?.call(text) ?? text);
    archive.addFile(ArchiveFile(file.name, data.length, data));
  }
  for (final entry in additions.entries) {
    final data = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  late Uint8List sample;

  setUp(() {
    sample = SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes();
  });

  bool passes(Uint8List bytes, [String? criterion]) {
    final result = SoftwareLearningWorkbookEvaluator.evaluateWorkbook(
      attemptId: 'demo',
      exerciseId: 'excel-budget-total-v1',
      fileName: 'budget.xlsx',
      bytes: bytes,
    );
    expect(result.canAwardSkill, isFalse);
    expect(result.evidenceTrust, 'unverified_checker_only');
    return criterion == null
        ? result.overallPassed
        : result.criteria.singleWhere((c) => c.id == criterion).passed;
  }

  Uint8List editSheet(String Function(String) edit) =>
      rewrite(sample, edits: {'xl/worksheets/sheet1.xml': edit});

  test('valid sample and equivalent absolute-reference addition pass', () {
    expect(passes(sample), isTrue);
    expect(
      passes(
        SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes(
          formula: r'$C$9+$C$8+$C$7+$C$6+$C$5+$C$4+$C$3+$C$2',
        ),
      ),
      isTrue,
    );
  });

  test('fixed demo inputs match the original bundled starter transactions', () {
    final lines = File(
      [
        'assets',
        'lessons',
        'excel_budget_transactions.csv',
      ].join(Platform.pathSeparator),
    ).readAsLinesSync().skip(1);
    final expected = [
      for (final line in lines) double.parse(line.split(',').last),
    ];
    expect(
      SoftwareLearningWorkbookEvaluator.defaultTransactions.values,
      orderedEquals(expected),
    );
  });

  test('missing, incorrect and non-finite cached totals cannot pass', () {
    for (final replacement in [
      '',
      '<v>1</v>',
      '<v>NaN</v>',
      '<v>Infinity</v>',
    ]) {
      expect(
        passes(
          editSheet(
            (xml) => xml.replaceFirst(
              RegExp(r'(<f>.*?</f>)<v>[^<]+</v>'),
              '<f>SUM(C2:C9)</f>$replacement',
            ),
          ),
          'total_calculation',
        ),
        isFalse,
      );
    }
  });

  test('changed numeric inputs fail even when their sum is unchanged', () {
    final changed = Map<int, double>.of(
      SoftwareLearningWorkbookEvaluator.defaultTransactions,
    );
    changed[2] = changed[2]! + 1;
    changed[3] = changed[3]! - 1;
    final bytes = SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes(
      transactions: changed,
    );
    expect(passes(bytes, 'inputs_intact'), isFalse);
    expect(passes(bytes, 'total_calculation'), isFalse);
  });

  test(
    'text, shared-string, boolean and formula inputs are not original data',
    () {
      for (final type in ['s', 'str', 'b', 'e', 'inlineStr']) {
        expect(
          passes(
            editSheet(
              (xml) => xml.replaceFirst('<c r="C2">', '<c r="C2" t="$type">'),
            ),
            'inputs_intact',
          ),
          isFalse,
        );
      }
      expect(
        passes(
          editSheet(
            (xml) => xml.replaceFirst('<c r="C2">', '<c r="C2"><f>1250</f>'),
          ),
          'inputs_intact',
        ),
        isFalse,
      );
    },
  );

  test('text cached total is not numeric and wrong formulas fail', () {
    expect(
      passes(
        editSheet(
          (xml) => xml.replaceFirst('<c r="C10">', '<c r="C10" t="s">'),
        ),
        'total_calculation',
      ),
      isFalse,
    );
    expect(
      passes(
        SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes(
          formula: 'SUM(C2:C8)',
        ),
      ),
      isFalse,
    );
  });

  test('Budget relationship is resolved instead of assuming sheet1', () {
    final sheet = utf8.decode(
      ZipDecoder()
              .decodeBytes(sample)
              .findFile('xl/worksheets/sheet1.xml')!
              .content
          as List<int>,
    );
    final bytes = rewrite(
      sample,
      edits: {
        'xl/_rels/workbook.xml.rels': (xml) =>
            xml.replaceFirst('worksheets/sheet1.xml', 'worksheets/sheet2.xml'),
        'xl/worksheets/sheet1.xml': (_) => '<unrelated/>',
      },
      additions: {'xl/worksheets/sheet2.xml': sheet},
    );
    expect(passes(bytes), isTrue);
    expect(
      passes(
        rewrite(
          sample,
          edits: {
            'xl/_rels/workbook.xml.rels': (xml) => xml.replaceFirst(
              'worksheets/sheet1.xml',
              'worksheets/sheet2.xml',
            ),
          },
        ),
      ),
      isFalse,
    );
  });

  test('wrong relationship id, external target and traversal are rejected', () {
    for (final target in [
      'worksheets/absent.xml',
      '../worksheets/sheet1.xml',
      'https://example.invalid/sheet.xml',
    ]) {
      expect(
        passes(
          rewrite(
            sample,
            edits: {
              'xl/_rels/workbook.xml.rels': (xml) =>
                  xml.replaceFirst('worksheets/sheet1.xml', target),
            },
          ),
        ),
        isFalse,
      );
    }
    expect(
      passes(
        rewrite(
          sample,
          edits: {
            'xl/workbook.xml': (xml) =>
                xml.replaceFirst('r:id="rId1"', 'r:id="rId2"'),
          },
        ),
      ),
      isFalse,
    );
  });

  test(
    'malformed XML, comment spoofing, entities and duplicate cells fail',
    () {
      for (final edit in <String Function(String)>[
        (xml) => xml.replaceFirst('</sheetData>', ''),
        (xml) => xml
            .replaceFirst('<sheetData>', '<!-- <sheetData>')
            .replaceFirst('</sheetData>', '</sheetData> -->'),
        (xml) => '<!DOCTYPE worksheet [<!ENTITY x "1250">]>$xml',
        (xml) => xml.replaceFirst(
          '</sheetData>',
          '<row r="2"><c r="C2"><v>1250</v></c></row></sheetData>',
        ),
      ]) {
        expect(passes(editSheet(edit)), isFalse);
      }
    },
  );

  test('part size and entry count limits reject at their boundaries', () {
    expect(
      passes(
        rewrite(
          sample,
          additions: {
            'docProps/core.xml': 'x' * (DemoWorkbookReader.maxPartBytes + 1),
          },
        ),
      ),
      isFalse,
    );
    expect(
      passes(
        rewrite(
          sample,
          additions: {
            for (var i = 2; i <= DemoWorkbookReader.maxEntries; i++)
              'xl/worksheets/sheet$i.xml': '<worksheet/>',
          },
        ),
      ),
      isFalse,
    );
  });

  test('forged small expanded size is bounded during actual inflation', () {
    final bytes = rewrite(
      sample,
      additions: {'docProps/core.xml': '<x>${'x' * 10000}</x>'},
    );
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 46; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        final length = data.getUint16(i + 28, Endian.little);
        final name = utf8.decode(bytes.sublist(i + 46, i + 46 + length));
        if (name == 'docProps/core.xml') {
          data.setUint32(i + 24, 50, Endian.little);
        }
      }
    }
    expect(passes(bytes), isFalse);
  });

  String sizedXml(int size) {
    final random = Random(188);
    return '<x>${String.fromCharCodes(List.generate(size - 7, (_) => 65 + random.nextInt(26)))}</x>';
  }

  test('exact part-size boundary passes, one byte beyond fails', () {
    for (final extra in [0, 1]) {
      expect(
        passes(
          rewrite(
            sample,
            additions: {
              'docProps/core.xml': sizedXml(
                DemoWorkbookReader.maxPartBytes + extra,
              ),
            },
          ),
        ),
        extra == 0,
      );
    }
  });

  test('exact entry-count boundary passes, one entry beyond fails', () {
    for (final extra in [0, 1]) {
      expect(
        passes(
          rewrite(
            sample,
            additions: {
              for (
                var i = 2;
                i <= DemoWorkbookReader.maxEntries - 4 + extra;
                i++
              )
                'xl/worksheets/sheet$i.xml': '<worksheet/>',
            },
          ),
        ),
        extra == 0,
      );
    }
  });

  test('exact total expanded boundary passes, one byte beyond fails', () {
    final baseSize = ZipDecoder()
        .decodeBytes(sample)
        .files
        .fold<int>(0, (total, file) => total + file.size);
    for (final extra in [0, 1]) {
      final remaining =
          DemoWorkbookReader.maxExpandedBytes -
          baseSize -
          DemoWorkbookReader.maxPartBytes * 3 +
          extra;
      expect(
        passes(
          rewrite(
            sample,
            additions: {
              for (var i = 2; i <= 4; i++)
                'xl/worksheets/sheet$i.xml': sizedXml(
                  DemoWorkbookReader.maxPartBytes,
                ),
              'xl/worksheets/sheet5.xml': sizedXml(remaining),
            },
          ),
        ),
        extra == 0,
      );
    }
  });

  test('high expansion ratio and forged entry count are rejected', () {
    expect(
      passes(
        rewrite(
          sample,
          additions: {'docProps/core.xml': '<x>${'x' * 20000}</x>'},
        ),
      ),
      isFalse,
    );
    final bytes = Uint8List.fromList(sample);
    final end = ByteData.sublistView(bytes, bytes.length - 22);
    end.setUint16(8, 1, Endian.little);
    end.setUint16(10, 1, Endian.little);
    expect(passes(bytes), isFalse);
  });
}
