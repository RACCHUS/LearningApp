/// Problems the structure scanner can report before any JSON decoding.
enum JsonScanProblem {
  /// A `}` or `]` that does not close the most recent opener.
  mismatchedBracket,

  /// Input ended inside an object/array or inside a string.
  unterminated,

  /// Nesting deeper than the configured limit.
  tooDeep,
}

/// A top-level `{…}` region found in the text: [start] inclusive,
/// [end] exclusive.
class JsonSpan {
  const JsonSpan(this.start, this.end);

  final int start;
  final int end;
}

class JsonScanResult {
  const JsonScanResult(this.spans, {this.problem, this.position});

  /// Complete top-level object regions, in order.
  final List<JsonSpan> spans;

  final JsonScanProblem? problem;

  /// Character offset where [problem] was detected.
  final int? position;

  bool get ok => problem == null;
}

/// Linear, read-only, quote-and-escape-aware bracket scanner (master plan
/// v2.6 Appendix D.3).
///
/// It only measures structure: it counts `{}`/`[]` outside strings, checks
/// that closers match, enforces a depth limit and reports where top-level
/// objects begin and end. It never rewrites or "repairs" text; `jsonDecode`
/// remains the authority for every other syntax rule.
///
/// Text outside any object (surrounding commentary) is skipped and its
/// quotes are not treated as JSON strings.
class JsonStructureScanner {
  const JsonStructureScanner._();

  static JsonScanResult scan(String text, {required int maxDepth}) {
    final spans = <JsonSpan>[];
    final stack = <int>[]; // expected closer code units
    var inString = false;
    var escaped = false;
    var start = -1;

    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (stack.isEmpty) {
        if (c == 0x7B /* { */ ) {
          start = i;
          stack.add(0x7D);
        }
        // Commentary between top-level objects is ignored, including `[`.
        continue;
      }
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == 0x5C /* \ */ ) {
          escaped = true;
        } else if (c == 0x22 /* " */ ) {
          inString = false;
        }
        continue;
      }
      switch (c) {
        case 0x22:
          inString = true;
        case 0x7B:
        case 0x5B:
          stack.add(c == 0x7B ? 0x7D : 0x5D);
          if (stack.length > maxDepth) {
            return JsonScanResult(
              spans,
              problem: JsonScanProblem.tooDeep,
              position: i,
            );
          }
        case 0x7D:
        case 0x5D:
          if (stack.removeLast() != c) {
            return JsonScanResult(
              spans,
              problem: JsonScanProblem.mismatchedBracket,
              position: i,
            );
          }
          if (stack.isEmpty) spans.add(JsonSpan(start, i + 1));
      }
    }
    if (stack.isNotEmpty) {
      return JsonScanResult(
        spans,
        problem: JsonScanProblem.unterminated,
        position: start,
      );
    }
    return JsonScanResult(spans);
  }
}
