/// Exact rational number for deterministic Bridge checks. Avoids floating
/// point so `0.1 * 3` and `1/3` behave identically on VM and web.
class ExactNumber implements Comparable<ExactNumber> {
  factory ExactNumber(BigInt numerator, [BigInt? denominator]) {
    var d = denominator ?? BigInt.one;
    if (d == BigInt.zero) throw ArgumentError('denominator must not be zero');
    var n = numerator;
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = n.gcd(d);
    return ExactNumber._(n ~/ g, d ~/ g);
  }

  const ExactNumber._(this.numerator, this.denominator);

  factory ExactNumber.fromInt(int v) => ExactNumber(BigInt.from(v));

  final BigInt numerator;
  final BigInt denominator;

  static final RegExp _decimal = RegExp(r'^(-?)(\d{1,15})(?:\.(\d{1,15}))?$');

  /// Parses an integer or a plain decimal string such as `-3.5`. JSON
  /// doubles are rejected by [tryParseJson] so no binary rounding sneaks in.
  static ExactNumber? tryParse(String text) {
    final m = _decimal.firstMatch(text.trim());
    if (m == null) return null;
    final frac = m[3] ?? '';
    final digits = BigInt.parse('${m[2]}$frac');
    final value = ExactNumber(digits, BigInt.from(10).pow(frac.length));
    return m[1] == '-' ? -value : value;
  }

  /// Accepts a JSON int or a decimal string; never a JSON double.
  static ExactNumber? tryParseJson(Object? v) {
    if (v is int) return ExactNumber.fromInt(v);
    if (v is String) return tryParse(v);
    return null;
  }

  bool get isZero => numerator == BigInt.zero;

  ExactNumber operator +(ExactNumber o) => ExactNumber(
    numerator * o.denominator + o.numerator * denominator,
    denominator * o.denominator,
  );
  ExactNumber operator -(ExactNumber o) => this + (-o);
  ExactNumber operator -() => ExactNumber._(-numerator, denominator);
  ExactNumber operator *(ExactNumber o) =>
      ExactNumber(numerator * o.numerator, denominator * o.denominator);
  ExactNumber operator /(ExactNumber o) {
    if (o.isZero) throw ArgumentError('division by zero');
    return ExactNumber(numerator * o.denominator, denominator * o.numerator);
  }

  /// Rounds half away from zero to [places] decimal places.
  ExactNumber roundTo(int places) {
    final scale = BigInt.from(10).pow(places);
    final scaled = numerator.abs() * scale;
    var q = scaled ~/ denominator;
    if ((scaled % denominator) * BigInt.two >= denominator) q += BigInt.one;
    return ExactNumber(numerator.isNegative ? -q : q, scale);
  }

  @override
  int compareTo(ExactNumber o) =>
      (numerator * o.denominator).compareTo(o.numerator * denominator);

  @override
  bool operator ==(Object o) =>
      o is ExactNumber &&
      o.numerator == numerator &&
      o.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  /// Terminating decimal text, or `n/d` when it does not terminate.
  @override
  String toString() {
    var d = denominator;
    var places = 0;
    for (final p in [BigInt.two, BigInt.from(5)]) {
      while (d % p == BigInt.zero) {
        d ~/= p;
      }
    }
    if (d != BigInt.one) return '$numerator/$denominator';
    while (BigInt.from(10).pow(places) % denominator != BigInt.zero) {
      places++;
    }
    final scaled = numerator.abs() * BigInt.from(10).pow(places) ~/ denominator;
    var s = scaled.toString().padLeft(places + 1, '0');
    if (places > 0) {
      s = '${s.substring(0, s.length - places)}.${s.substring(s.length - places)}';
    }
    return numerator.isNegative ? '-$s' : s;
  }
}
