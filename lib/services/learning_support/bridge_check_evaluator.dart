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
  percentToDecimal('percent_to_decimal', ['percent']);

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
    }
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
