import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/services/learning_support/bridge_check_evaluator.dart';
import 'package:learning_pwa/services/learning_support/exact_number.dart';

ExactNumber n(String s) => ExactNumber.tryParse(s)!;

Map<String, Object?> load(String name) =>
    jsonDecode(File('content/bridges/$name').readAsStringSync())
        as Map<String, Object?>;

/// Deep copy so a test can mutate a fixture freely.
Map<String, Object?> copy(Map<String, Object?> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, Object?>;

List<String> issuesOf(Map<String, Object?> json) =>
    BridgeLesson.decode(json).issues.map((i) => i.toString()).toList();

void main() {
  group('ExactNumber', () {
    test('parses ints and decimal strings exactly', () {
      expect(n('0.1') + n('0.2'), n('0.3'));
      expect(n('-3.50').toString(), '-3.5');
      expect(ExactNumber.tryParse('1e3'), isNull);
      expect(ExactNumber.tryParse('.5'), isNull);
      expect(ExactNumber.tryParseJson(0.25), isNull, reason: 'no JSON doubles');
      expect(ExactNumber.tryParseJson(7), ExactNumber.fromInt(7));
    });

    test('rounds half away from zero', () {
      expect(n('2.345').roundTo(2), n('2.35'));
      expect(n('-2.345').roundTo(2), n('-2.35'));
      expect(n('2.344').roundTo(2), n('2.34'));
      expect((n('2') / n('3')).roundTo(2), n('0.67'));
      expect(n('0.5').roundTo(0), n('1'));
    });

    test('prints terminating decimals and fractions otherwise', () {
      expect((n('7') / n('8')).toString(), '0.875');
      expect((n('1') / n('3')).toString(), '1/3');
      expect(n('1200').toString(), '1200');
      expect(n('-0.05').toString(), '-0.05');
    });
  });

  group('BridgeCheckEvaluator', () {
    ExactNumber? calc(BridgeCheckTemplate t, Map<String, Object?> inputs) =>
        BridgeCheckEvaluator.compute(t, inputs).value;
    String? err(BridgeCheckTemplate t, Map<String, Object?> inputs) =>
        BridgeCheckEvaluator.compute(t, inputs).error;

    test('powers, including zero and negative exponents, are exact', () {
      const t = BridgeCheckTemplate.power;
      expect(calc(t, {'base': 2, 'exponent': 10}), ExactNumber.fromInt(1024));
      expect(calc(t, {'base': 7, 'exponent': 0}), ExactNumber.fromInt(1));
      expect(calc(t, {'base': 2, 'exponent': -2}), ExactNumber.tryParse('0.25'));
      expect(calc(t, {'base': '-3', 'exponent': 3}), ExactNumber.fromInt(-27));
      expect(err(t, {'base': 2, 'exponent': 13}), isNotNull);
      expect(err(t, {'base': 2, 'exponent': '1.5'}), isNotNull);
      expect(err(t, {'base': 0, 'exponent': -1}), isNotNull);
    });

    test('scientific notation becomes an exact ordinary number', () {
      const t = BridgeCheckTemplate.scientificToDecimal;
      expect(calc(t, {'coefficient': '3.2', 'exponent': 4}), ExactNumber.fromInt(32000));
      expect(calc(t, {'coefficient': '4.5', 'exponent': -3}), ExactNumber.tryParse('0.0045'));
      expect(err(t, {'coefficient': 1, 'exponent': -13}), isNotNull);
    });

    test('order of operations: fixed forms, exact', () {
      expect(calc(BridgeCheckTemplate.addProduct, {'a': 3, 'b': 4, 'c': 5}), ExactNumber.fromInt(23));
      expect(calc(BridgeCheckTemplate.productOfSum, {'a': 3, 'b': 4, 'c': 5}), ExactNumber.fromInt(35));
      expect(calc(BridgeCheckTemplate.subtractQuotient, {'a': 20, 'b': 12, 'c': 4}), ExactNumber.fromInt(17));
      expect(err(BridgeCheckTemplate.subtractQuotient, {'a': 1, 'b': 1, 'c': 0}), isNotNull);
    });

    test('fraction arithmetic is exact and refuses bad parts', () {
      expect(calc(BridgeCheckTemplate.fractionAdd, {'a': 1, 'b': 2, 'c': 1, 'd': 4}), ExactNumber.tryParse('0.75'));
      expect(calc(BridgeCheckTemplate.fractionMultiply, {'a': 2, 'b': 3, 'c': 3, 'd': 4}), ExactNumber.tryParse('0.5'));
      expect(calc(BridgeCheckTemplate.fractionDivide, {'a': 3, 'b': 4, 'c': 1, 'd': 2}), ExactNumber.tryParse('1.5'));
      expect(err(BridgeCheckTemplate.fractionAdd, {'a': 1, 'b': 0, 'c': 1, 'd': 2}), isNotNull);
      expect(err(BridgeCheckTemplate.fractionMultiply, {'a': '0.5', 'b': 2, 'c': 1, 'd': 2}), isNotNull);
      expect(err(BridgeCheckTemplate.fractionDivide, {'a': 1, 'b': 2, 'c': 0, 'd': 3}), isNotNull);
    });

    test('square roots are exact or refused, never approximated', () {
      const t = BridgeCheckTemplate.squareRoot;
      expect(calc(t, {'radicand': 144}), ExactNumber.fromInt(12));
      expect(calc(t, {'radicand': '0.36'}), ExactNumber.tryParse('0.6'));
      expect(calc(t, {'radicand': 0}), ExactNumber.fromInt(0));
      expect(err(t, {'radicand': 2}), isNotNull);
      expect(err(t, {'radicand': '0.5'}), isNotNull);
      expect(err(t, {'radicand': -4}), isNotNull);
    });

    ExactNumber run(BridgeCheckTemplate t, Map<String, Object?> i) =>
        BridgeCheckEvaluator.compute(t, i).value!;

    test('templates compute exactly', () {
      expect(
        run(BridgeCheckTemplate.percentChange, {'original': 40, 'new': 50}),
        n('25'),
      );
      expect(
        run(BridgeCheckTemplate.percentChange, {'original': 250, 'new': 200}),
        n('-20'),
      );
      expect(
        run(BridgeCheckTemplate.percentOf, {'percent': '12.5', 'whole': 80}),
        n('10'),
      );
      expect(
        run(BridgeCheckTemplate.decimalToPercent, {'value': '0.07'}),
        n('7'),
      );
      expect(
        run(BridgeCheckTemplate.percentToDecimal, {'percent': 45}),
        n('0.45'),
      );
    });

    test('rejects zero divisors, wrong inputs and doubles', () {
      for (final (t, i) in [
        (BridgeCheckTemplate.percentChange, {'original': 0, 'new': 5}),
        (
          BridgeCheckTemplate.fractionToDecimal,
          {'numerator': 1, 'denominator': 0},
        ),
        (BridgeCheckTemplate.decimalToPercent, {'value': 0.5}),
        (BridgeCheckTemplate.decimalToPercent, {'value': '1', 'extra': 1}),
        (BridgeCheckTemplate.percentOf, {'percent': 5}),
      ]) {
        expect(BridgeCheckEvaluator.compute(t, i).isOk, isFalse, reason: '$i');
      }
    });

    test('grades typed numbers without guessing', () {
      bool? g(String s, String e, {bool pct = false}) =>
          BridgeCheckEvaluator.gradeNumeric(s, n(e), allowPercentSign: pct);
      expect(g(' 15 ', '15'), isTrue);
      expect(g('15%', '15', pct: true), isTrue);
      expect(g('15%', '15'), isNull, reason: '% only when allowed');
      expect(g('15.0', '15'), isTrue);
      expect(g('+15', '15'), isTrue);
      expect(g('−20', '-20'), isTrue);
      expect(g('1,200', '1200'), isTrue);
      expect(g('0,6', '0.6'), isNull, reason: 'ambiguous decimal comma');
      expect(g('16', '15'), isFalse);
      expect(g('fifteen', '15'), isNull);
      expect(g('', '15'), isNull);
    });
  });

  group('starter set content', () {
    final files = Directory('content/bridges')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.bridge.json'))
        .toList();

    test('has a small, reviewed-size set of Bridges', () {
      expect(files.length, inInclusiveRange(2, 12));
    });

    for (final f in files) {
      test('${f.uri.pathSegments.last} is valid', () {
        final r = BridgeLesson.decode(jsonDecode(f.readAsStringSync()));
        expect(r.issues, isEmpty);
        final b = r.bridge!;
        expect(b.checks.length, greaterThanOrEqualTo(2));
        for (final c in b.checks) {
          if (c.kind == BridgeCheckKind.choice) {
            expect(c.correctOptionIndex, isNonNegative);
            expect(c.options[c.correctOptionIndex].value, c.expected);
          } else {
            expect(
              BridgeCheckEvaluator.gradeNumeric(
                c.expected.toString(),
                c.expected,
              ),
              isTrue,
            );
          }
        }
        // Honest evidence: no claimed review without a reviewer.
        expect(b.evidence.humanReviewed, isFalse);
        // OpenStax sources are linked only; text is written independently.
        // Second editions are CC BY-NC-SA (and forbid model training);
        // first editions are CC BY 4.0 (data/content_sources.json).
        for (final s in b.sources.where(
          (s) => s.url.contains('openstax.org'),
        )) {
          expect(s.rightsPosture, SourceRightsPosture.linkOnly);
          expect(
            s.license,
            s.url.contains('-2e/') ? contains('NC-SA') : 'CC BY 4.0',
          );
        }
      });
    }

    test('the set has valid, acyclic dependencies', () {
      final all = [
        for (final f in files)
          BridgeLesson.decode(jsonDecode(f.readAsStringSync())).bridge!,
      ];
      expect(BridgeLibraryValidator.validate(all), isEmpty);
    });
  });

  group('validator rejects', () {
    final base = load('percent_change.bridge.json');

    test('a wrong stated answer', () {
      final j = copy(base);
      ((j['checks']! as List)[0] as Map)['answer'] = 16;
      expect(issuesOf(j).join(), contains('template gives 15'));
    });

    test('a wrong correct_option_id', () {
      final j = copy(base);
      ((j['checks']! as List)[1] as Map)['correct_option_id'] = 'b';
      expect(issuesOf(j).join(), contains('correct_option_id'));
    });

    test('two options equal to the answer', () {
      final j = copy(base);
      final opts = ((j['checks']! as List)[1] as Map)['options'] as List;
      (opts[2] as Map)['value'] = -20;
      expect(issuesOf(j).join(), contains('exactly one option'));
    });

    test('a check that repeats a worked example', () {
      final j = copy(base);
      ((j['checks']! as List)[0] as Map)
        ..['inputs'] = {'original': 40, 'new': 50}
        ..['answer'] = 25;
      expect(issuesOf(j).join(), contains('unseen numbers'));
    });

    test('a wrong worked-example result', () {
      final j = copy(base);
      (((j['examples']! as List)[0] as Map)['worked'] as Map)['result'] = 20;
      expect(issuesOf(j).join(), contains('template gives 25'));
    });

    test('a non-terminating answer without round_to', () {
      final j = copy(base);
      ((j['checks']! as List)[2] as Map).remove('round_to');
      expect(issuesOf(j).join(), contains('set round_to'));
    });

    test('AI dependence, fake review and restricted sources', () {
      final j = copy(base)..['uses_ai'] = true;
      expect(issuesOf(j).join(), contains('without AI'));

      final r = copy(base);
      (r['evidence']! as Map)['human_reviewed'] = true;
      expect(issuesOf(r).join(), contains('name who reviewed'));

      final s = copy(base);
      ((s['sources']! as List)[0] as Map)['rights_posture'] = 'restricted';
      expect(issuesOf(s).join(), contains('restricted'));
    });

    test('uncited text, markup and non-https sources', () {
      final j = copy(base);
      ((j['teach']! as List)[0] as Map)['source_ids'] = ['nope'];
      expect(issuesOf(j).join(), contains('unknown source'));

      final m = copy(base);
      ((m['teach']! as List)[0] as Map)['text'] = '<b>hi</b>';
      expect(issuesOf(m).join(), contains('markup'));

      final u = copy(base);
      ((u['sources']! as List)[0] as Map)['url'] = 'http://example.test';
      expect(issuesOf(u).join(), contains('https'));
    });

    test('JSON doubles and unknown templates', () {
      final j = copy(base);
      ((j['checks']! as List)[0] as Map)['inputs'] = {
        'original': 20.0,
        'new': 23,
      };
      expect(issuesOf(j).join(), contains('not an int or decimal'));

      final t = copy(base);
      ((t['checks']! as List)[0] as Map)['template'] = 'eval';
      expect(issuesOf(t).join(), contains('allowlisted'));
    });

    test('missing builds_on targets and cycles in a set', () {
      BridgeLesson make(String id, String concept, List<String> deps) {
        final j = copy(base)
          ..['bridge_id'] = id
          ..['concept_id'] = concept
          ..['builds_on'] = deps;
        return BridgeLesson.decode(j).bridge!;
      }

      expect(
        BridgeLibraryValidator.validate([
          make('a', 'x', ['ghost']),
        ]).join(),
        contains('unknown "ghost"'),
      );
      expect(
        BridgeLibraryValidator.validate([
          make('a', 'x', ['b']),
          make('b', 'y', ['a']),
        ]).join(),
        contains('cycle'),
      );
      expect(
        BridgeLibraryValidator.validate([
          make('a', 'x', []),
          make('b', 'x', []),
        ]).join(),
        contains('reused'),
      );
    });
  });

  group('misconception tags', () {
    const pf = 'spreadsheet_percent_format.bridge.json';

    test('bundled tags decode and each spans two different questions', () {
      for (final name in [pf, 'percent_change.bridge.json']) {
        final b = BridgeLesson.decode(load(name)).bridge!;
        expect(b.misconceptions, isNotEmpty, reason: name);
        for (final m in b.misconceptions) {
          final items = {
            for (final c in b.checks)
              for (final o in c.options)
                if (o.misconceptionId == m.misconceptionId) c.itemId,
          };
          expect(items.length, greaterThanOrEqualTo(2), reason: name);
        }
      }
    });

    test('an unknown tag, a tagged correct option or an unused one fail', () {
      final unknown = copy(load(pf));
      ((((unknown['checks'] as List)[0] as Map)['options'] as List)[2]
              as Map)['misconception_id'] =
          'nope';
      expect(issuesOf(unknown).join(), contains('unknown misconception'));

      final correct = copy(load(pf));
      ((((correct['checks'] as List)[0] as Map)['options'] as List)[0]
              as Map)['misconception_id'] =
          'pf-adds-sign-only';
      expect(issuesOf(correct).join(), contains('correct option cannot'));

      final unused = copy(load(pf));
      for (final c in (unused['checks'] as List)) {
        for (final o in ((c as Map)['options'] as List? ?? const [])) {
          (o as Map).remove('misconception_id');
        }
      }
      expect(issuesOf(unused).join(), contains('tags no option'));

      final uncited = copy(load(pf));
      (((uncited['misconceptions'] as List)[0]) as Map)['source_ids'] = [];
      expect(issuesOf(uncited).join(), contains('cite at least one source'));
    });

    test('Bridges without misconceptions still decode', () {
      final b = BridgeLesson.decode(
        load('fraction_decimal.bridge.json'),
      ).bridge!;
      expect(b.misconceptions, isEmpty);
    });
  });
}
