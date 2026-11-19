import 'dart:convert';

/// Result of the optional format probe.
enum ProbeOutcome {
  passed,

  /// Not readable JSON at all.
  unreadable,

  /// JSON, but not exactly the requested shape.
  wrongShape,

  /// The end marker was missing or different (likely cut off).
  missingEnd,
}

/// The optional free-model probe (master plan v2.6 Appendix A.1). It asks
/// for a fixed, trivially checkable reply and contains no learner details.
/// It checks formatting only: never factual accuracy, long prompts or any
/// provider limit. It costs the learner one chat message, so it is skipped
/// unless they choose it.
class ModelProbe {
  const ModelProbe._();

  static const schemaId = 'la-probe/1';
  static const endMarker = 'END-PROBE';

  static const prompt =
      'Return exactly this JSON with no extra commentary:\n'
      '{"schema":"$schemaId","items":[{"n":1,"v":"ok"},{"n":2,"v":"ok"}],'
      '"end":"$endMarker"}';

  /// Replies above this size are not a faithful copy of the request.
  static const maxChars = 2000;

  static ProbeOutcome check(String reply) {
    var text = reply.trim();
    if (text.isEmpty || text.length > maxChars) return ProbeOutcome.unreadable;
    // Allow one Markdown code fence, which chats often add.
    final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return text.contains(endMarker)
          ? ProbeOutcome.unreadable
          : ProbeOutcome.missingEnd;
    }
    if (decoded is! Map) return ProbeOutcome.wrongShape;
    if (decoded['end'] != endMarker) return ProbeOutcome.missingEnd;
    final items = decoded['items'];
    final shapeOk =
        decoded['schema'] == schemaId &&
        decoded.length == 3 &&
        items is List &&
        items.length == 2 &&
        [
          for (final (i, item) in items.indexed)
            item is Map &&
                item.length == 2 &&
                item['n'] == i + 1 &&
                item['v'] == 'ok',
        ].every((ok) => ok);
    return shapeOk ? ProbeOutcome.passed : ProbeOutcome.wrongShape;
  }

  static String describe(ProbeOutcome o) => switch (o) {
    ProbeOutcome.passed =>
      'It worked. The app will start with a medium batch for this AI.',
    ProbeOutcome.unreadable =>
      "That wasn't readable JSON. The app will start small and suggest "
          'one item per line.',
    ProbeOutcome.wrongShape =>
      "The reply didn't match exactly. The app will start small and "
          'suggest one item per line.',
    ProbeOutcome.missingEnd =>
      'The end marker was missing, so replies may get cut off. The app '
          'will start small and suggest one item per line.',
  };
}
