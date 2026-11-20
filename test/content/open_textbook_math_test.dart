import 'dart:io';

import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Every formula in imported open textbook lessons (content/open_*.yaml)
/// must parse with the same LaTeX engine the app renders with, so no
/// learner sees a broken formula. Uses the inline syntax of
/// lib/widgets/lesson/blocks/markdown_math.dart.
final _math = RegExp(
  r'\$\$(?!\s)([^$]+?)(?<!\s)\$\$|\$(?!\s)([^$\n]+?)(?<!\s)\$(?!\d)',
);

Iterable<String> _strings(Object? node) sync* {
  if (node is String) {
    yield node;
  } else if (node is Map) {
    for (final v in node.values) {
      yield* _strings(v);
    }
  } else if (node is List) {
    for (final v in node) {
      yield* _strings(v);
    }
  }
}

void main() {
  final files = Directory('content')
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'open_.*\.yaml$').hasMatch(f.path))
      .toList();

  test('there are imported open textbook manifests', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    test('every formula in ${file.path} parses', () {
      final manifest = loadYaml(file.readAsStringSync());
      final failures = <String>[];
      var count = 0;
      for (final text in _strings(manifest)) {
        for (final m in _math.allMatches(text)) {
          final tex = (m[1] ?? m[2])!.trim();
          count++;
          try {
            TexParser(tex, const TexParserSettings()).parse();
          } catch (e) {
            if (failures.length < 20) failures.add('$tex  →  $e');
          }
        }
      }
      expect(count, greaterThan(0));
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}
