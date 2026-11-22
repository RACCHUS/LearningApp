import 'package:learning_pwa/services/learning_support/exact_number.dart';

/// The small allowlist of typed, deterministic templates whose formulas the
/// app owns (master plan v2.6 §6 "P2 numeric recomputation ... explicit
/// small allowlist"). Nothing here evaluates free text, spreadsheet
/// expressions or code.
enum BridgeCheckTemplate {
  /// `(new − original) ÷ original × 100`.
  percentChange('percent_change', ['original', 'new']),

  /// `percent ÷ 100 × whole`.
  percentOf('percent_of', ['percent', 'whole']),

  /// `numerator ÷ denominator`.
  fractionToDecimal('fraction_to_decimal', ['numerator', 'denominator']),

  /// `value × 100` (also what a Percentage cell format displays).
  decimalToPercent('decimal_to_percent', ['value']),

  /// `percent ÷ 100`.
  percentToDecimal('percent_to_decimal', ['percent']),

  /// `base ^ exponent` for a whole-number exponent from −12 to 12
  /// (a negative exponent means one over the positive power).
  power('power', ['base', 'exponent']),

  /// `coefficient × 10 ^ exponent` for a whole-number exponent from −12
  /// to 12 (scientific notation to an ordinary number).
  scientificToDecimal('scientific_to_decimal', ['coefficient', 'exponent']),

  /// The non-negative square root, only when it is exact (a perfect square
  /// such as 144 or 0.25); anything else is refused, never approximated.
  squareRoot('square_root', ['radicand']),

  /// `a + b × c` (multiplication before addition).
  addProduct('add_product', ['a', 'b', 'c']),

  /// `(a + b) × c` (brackets first).
  productOfSum('product_of_sum', ['a', 'b', 'c']),

  /// `a − b ÷ c` (division before subtraction).
  subtractQuotient('subtract_quotient', ['a', 'b', 'c']),

  /// `a/b + c/d` with whole-number numerators and denominators.
  fractionAdd('fraction_add', ['a', 'b', 'c', 'd']),

  /// `a/b × c/d`.
  fractionMultiply('fraction_multiply', ['a', 'b', 'c', 'd']),

  /// `a/b ÷ c/d`.
  fractionDivide('fraction_divide', ['a', 'b', 'c', 'd']),

  /// Whole-number division, the whole part only (Python `//`), for a
  /// dividend from 0 to 1,000,000 and a divisor from 1 to 1,000,000.
  /// Negative numbers are refused: languages disagree on them.
  integerQuotient('integer_quotient', ['dividend', 'divisor']),

  /// The remainder of that division (Python `%`), same limits.
  remainder('remainder', ['dividend', 'divisor']),

  /// How many values `range(start, stop, step)` produces (how many times
  /// a counting loop runs): whole numbers from −10,000 to 10,000, step not
  /// zero.
  rangeCount('range_count', ['start', 'stop', 'step']);

  const BridgeCheckTemplate(this.wire, this.inputNames);

  final String wire;
  final List<String> inputNames;

  static BridgeCheckTemplate? fromWire(Object? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

class BridgeComputation {
  const BridgeComputation._(this.value, this.error);

  final ExactNumber? value;
  final String? error;

  bool get isOk => value != null;
}

class BridgeCheckEvaluator {
  const BridgeCheckEvaluator._();

  /// Computes [template] exactly. Inputs must be JSON ints or decimal
  /// strings with exactly the template's input names.
  static BridgeComputation compute(
    BridgeCheckTemplate template,
    Map<String, Object?> inputs,
  ) {
    BridgeComputation fail(String e) => BridgeComputation._(null, e);

    final names = inputs.keys.toSet();
    if (names.length != template.inputNames.length ||
        !names.containsAll(template.inputNames)) {
      return fail('inputs must be exactly ${template.inputNames.join(', ')}');
    }
    final v = <String, ExactNumber>{};
    for (final n in template.inputNames) {
      final parsed = ExactNumber.tryParseJson(inputs[n]);
      if (parsed == null) return fail('input "$n" is not an int or decimal');
      v[n] = parsed;
    }
    final hundred = ExactNumber.fromInt(100);
    switch (template) {
      case BridgeCheckTemplate.percentChange:
        if (v['original']!.isZero) return fail('original must not be zero');
        return BridgeComputation._(
          (v['new']! - v['original']!) / v['original']! * hundred,
          null,
        );
      case BridgeCheckTemplate.percentOf:
        return BridgeComputation._(v['percent']! / hundred * v['whole']!, null);
      case BridgeCheckTemplate.fractionToDecimal:
        if (v['denominator']!.isZero) {
          return fail('denominator must not be zero');
        }
        return BridgeComputation._(v['numerator']! / v['denominator']!, null);
      case BridgeCheckTemplate.decimalToPercent:
        return BridgeComputation._(v['value']! * hundred, null);
      case BridgeCheckTemplate.percentToDecimal:
        return BridgeComputation._(v['percent']! / hundred, null);
      case BridgeCheckTemplate.power:
        final n = _smallWhole(v['exponent']!);
        if (n == null) return fail('exponent must be a whole number from -12 to 12');
        if (n < 0 && v['base']!.isZero) return fail('zero has no negative power');
        return BridgeComputation._(_pow(v['base']!, n), null);
      case BridgeCheckTemplate.scientificToDecimal:
        final n = _smallWhole(v['exponent']!);
        if (n == null) return fail('exponent must be a whole number from -12 to 12');
        return BridgeComputation._(
          v['coefficient']! * _pow(ExactNumber.fromInt(10), n),
          null,
        );
      case BridgeCheckTemplate.squareRoot:
        final r = v['radicand']!;
        if (r.numerator.isNegative) return fail('radicand must not be negative');
        final top = _exactSqrt(r.numerator);
        final bottom = _exactSqrt(r.denominator);
        if (top == null || bottom == null) {
          return fail('radicand must be a perfect square');
        }
        return BridgeComputation._(ExactNumber(top, bottom), null);
      case BridgeCheckTemplate.addProduct:
        return BridgeComputation._(v['a']! + v['b']! * v['c']!, null);
      case BridgeCheckTemplate.productOfSum:
        return BridgeComputation._((v['a']! + v['b']!) * v['c']!, null);
      case BridgeCheckTemplate.subtractQuotient:
        if (v['c']!.isZero) return fail('c must not be zero');
        return BridgeComputation._(v['a']! - v['b']! / v['c']!, null);
      case BridgeCheckTemplate.fractionAdd:
      case BridgeCheckTemplate.fractionMultiply:
      case BridgeCheckTemplate.fractionDivide:
        for (final n in ['a', 'b', 'c', 'd']) {
          if (v[n]!.denominator != BigInt.one) {
            return fail('fraction parts must be whole numbers');
          }
        }
        if (v['b']!.isZero || v['d']!.isZero) {
          return fail('denominators must not be zero');
        }
        final left = v['a']! / v['b']!;
        final right = v['c']! / v['d']!;
        if (template == BridgeCheckTemplate.fractionAdd) {
          return BridgeComputation._(left + right, null);
        }
        if (template == BridgeCheckTemplate.fractionMultiply) {
          return BridgeComputation._(left * right, null);
        }
        if (right.isZero) return fail('cannot divide by zero');
        return BridgeComputation._(left / right, null);
      case BridgeCheckTemplate.integerQuotient:
      case BridgeCheckTemplate.remainder:
        final dividend = _whole(v['dividend']!, 0, 1000000);
        final divisor = _whole(v['divisor']!, 1, 1000000);
        if (dividend == null || divisor == null) {
          return fail('dividend must be a whole number from 0 and divisor from 1, up to 1,000,000');
        }
        return BridgeComputation._(
          ExactNumber.fromInt(template == BridgeCheckTemplate.integerQuotient
              ? dividend ~/ divisor
              : dividend % divisor),
          null,
        );
      case BridgeCheckTemplate.rangeCount:
        final start = _whole(v['start']!, -10000, 10000);
        final stop = _whole(v['stop']!, -10000, 10000);
        final step = _whole(v['step']!, -10000, 10000);
        if (start == null || stop == null || step == null || step == 0) {
          return fail('start, stop and step must be whole numbers from -10000 to 10000, step not zero');
        }
        final span = step > 0 ? stop - start : start - stop;
        final by = step.abs();
        final count = span <= 0 ? 0 : (span + by - 1) ~/ by;
        return BridgeComputation._(ExactNumber.fromInt(count), null);
    }
  }

  static int? _whole(ExactNumber e, int min, int max) {
    if (e.denominator != BigInt.one) return null;
    final n = e.numerator;
    if (n < BigInt.from(min) || n > BigInt.from(max)) return null;
    return n.toInt();
  }

  static int? _smallWhole(ExactNumber e) {
    if (e.denominator != BigInt.one) return null;
    final n = e.numerator.toInt();
    return n >= -12 && n <= 12 ? n : null;
  }

  static ExactNumber _pow(ExactNumber base, int n) {
    var out = ExactNumber.fromInt(1);
    for (var i = 0; i < n.abs(); i++) {
      out = out * base;
    }
    return n < 0 ? ExactNumber.fromInt(1) / out : out;
  }

  /// Integer square root when [x] is a perfect square, else null.
  static BigInt? _exactSqrt(BigInt x) {
    if (x < BigInt.zero) return null;
    if (x < BigInt.two) return x;
    var lo = BigInt.one;
    var hi = x;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final sq = mid * mid;
      if (sq == x) return mid;
      if (sq < x) {
        lo = mid + BigInt.one;
      } else {
        hi = mid - BigInt.one;
      }
    }
    return null;
  }

  /// The value a learner must give: the exact result, or the result
  /// rounded half away from zero when [roundTo] is set.
  static ExactNumber expected(ExactNumber exact, int? roundTo) =>
      roundTo == null ? exact : exact.roundTo(roundTo);

  static final RegExp _grouped = RegExp(r'^-?\d{1,3}(,\d{3})+(\.\d+)?$');

  /// Grades typed numeric input. Accepts surrounding spaces, a leading
  /// `+`, a Unicode minus, correctly grouped thousands (`1,200`) and (when
  /// [allowPercentSign]) one trailing `%`. Returns `null` for anything
  /// that is not clearly a number (e.g. `0,6`), so it is never guessed.
  static bool? gradeNumeric(
    String input,
    ExactNumber expectedValue, {
    bool allowPercentSign = false,
  }) {
    var s = input.trim().replaceAll('−', '-');
    if (allowPercentSign && s.endsWith('%')) {
      s = s.substring(0, s.length - 1).trim();
    }
    if (s.startsWith('+')) s = s.substring(1);
    if (s.contains(',')) {
      if (!_grouped.hasMatch(s)) return null;
      s = s.replaceAll(',', '');
    }
    final n = ExactNumber.tryParse(s);
    if (n == null) return null;
    return n == expectedValue;
  }
}
