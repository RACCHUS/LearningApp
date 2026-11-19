import 'dart:convert';

import 'package:learning_pwa/services/content_generation/json_structure_scanner.dart';

/// Result of reading pasted text that should contain one lesson JSON object.
class PastedJson {
  const PastedJson._({this.json, this.extracted = false, this.error});

  /// The decoded object, or `null` with an [error].
  final Map<String, dynamic>? json;

  /// The object was taken out of surrounding text or a code fence.
  final bool extracted;

  /// Why nothing could be read (plain language), or `null`.
  final String? error;

  static final RegExp _fence = RegExp(
    r'```[A-Za-z]*[ \t]*\r?\n([\s\S]*?)\r?\n?```',
  );

  /// Like [read], but also accepts a JSON array (the AI-Guided batches).
  /// Candidates are tried in order and each is decoded strictly, never
  /// edited: the whole text, the inside of a single code fence, one
  /// top-level object, then one top-level array (from the first `[` to the
  /// last `]`). Returns the decoded value, or `null` with [error] set.
  static ({Object? value, String? error}) readAny(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty)
      return (value: null, error: 'Paste the AI reply first.');
    if (trimmed.length > maxChars) {
      return (value: null, error: 'The paste is too long.');
    }
    Object? tryDecode(String s) {
      try {
        final v = jsonDecode(s.trim());
        return v is Map || v is List ? v : null;
      } on FormatException {
        return null;
      }
    }

    final whole = tryDecode(trimmed);
    if (whole != null) return (value: whole, error: null);
    final fences = _fence.allMatches(trimmed).toList();
    if (fences.length == 1) {
      final inside = tryDecode(fences.single.group(1)!);
      if (inside != null) return (value: inside, error: null);
    }
    final open = trimmed.indexOf('[');
    final brace = trimmed.indexOf('{');
    // When the reply's first bracket is `[`, only a whole array counts: an
    // object cut out of a broken array would silently drop its other items.
    final opensArray =
        open >= 0 &&
        (brace < 0 ||
            (open < brace &&
                trimmed.substring(open + 1, brace).trim().isEmpty));
    if (opensArray) {
      final close = trimmed.lastIndexOf(']');
      final array = close > open
          ? tryDecode(trimmed.substring(open, close + 1))
          : null;
      if (array is List) return (value: array, error: null);
      return (
        value: null,
        error: close > open
            ? 'The JSON list is not valid. Ask the AI to send it again, '
                  'exactly in the requested format.'
            : 'The JSON list is not finished. The AI reply was probably '
                  'cut off: ask it to continue.',
      );
    }
    final object = read(trimmed);
    if (object.json != null) return (value: object.json, error: null);
    return (value: null, error: object.error);
  }

  /// Largest paste we try to read (characters).
  static const maxChars = 400000;
  static const _maxDepth = 32;

  /// Reads [text] the way AI chats usually send it: plain JSON, JSON inside
  /// a ```json code fence, or JSON with a sentence before or after it.
  ///
  /// Nothing inside the JSON is changed or repaired: the one complete
  /// top-level object is cut out unchanged and decoded by `jsonDecode`.
  /// Two or more objects are refused rather than guessed between.
  static PastedJson read(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const PastedJson._(error: 'Paste the AI reply first.');
    }
    if (trimmed.length > maxChars) {
      return const PastedJson._(
        error:
            'The paste is too long. Ask the AI for a shorter lesson, or '
            'paste one lesson at a time.',
      );
    }
    try {
      final direct = jsonDecode(trimmed);
      if (direct is Map<String, dynamic>) return PastedJson._(json: direct);
      return const PastedJson._(
        error: 'The JSON must be one object that starts with {.',
      );
    } on FormatException {
      // Fall through: look for one object inside surrounding text.
    }

    final scan = JsonStructureScanner.scan(trimmed, maxDepth: _maxDepth);
    // Braces in prose ("use {name}") are not JSON objects; keep only spans
    // that decode as objects.
    final objects = <Map<String, dynamic>>[];
    String? firstError;
    for (final span in scan.spans) {
      try {
        final decoded = jsonDecode(trimmed.substring(span.start, span.end));
        if (decoded is Map<String, dynamic>) objects.add(decoded);
      } on FormatException catch (e) {
        firstError ??= e.message;
      }
    }
    if (objects.length > 1) {
      return const PastedJson._(
        error:
            'The paste contains more than one JSON block. Paste only the '
            'lesson block.',
      );
    }
    if (objects.length == 1) {
      return PastedJson._(json: objects.single, extracted: true);
    }
    if (scan.problem == JsonScanProblem.unterminated) {
      return const PastedJson._(
        error:
            'The JSON is not finished. The AI reply was probably cut off: '
            'ask it to continue, or to send a shorter lesson.',
      );
    }
    if (firstError != null) {
      return PastedJson._(
        error:
            'The JSON block is not valid ($firstError). Ask the AI to send '
            'the JSON again, exactly in the requested format.',
      );
    }
    return const PastedJson._(error: 'No JSON lesson was found in the paste.');
  }
}
