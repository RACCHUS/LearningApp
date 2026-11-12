/// Canonical answer-key validation shared by every personal-lesson writer,
/// reader, renderer and scorer (master plan v2.6 §14.8, Appendix G.2/H.3).
///
/// The one rule this file exists to enforce: **never invent a correct
/// answer.** A missing, blank, partial, ambiguous or out-of-range key is
/// unscorable. An explicit, in-range integer `0` is a perfectly valid key.
library;

/// Why a question's answer key can or cannot be trusted for scoring.
enum AnswerKeyStatus {
  /// A real, in-range index pointing at a non-blank, unambiguous option.
  validIndex,

  /// A key is present but malformed, out of range, or matches no option.
  invalidKey,

  /// No key was supplied at all (null, missing or blank text).
  missingKey,

  /// The keyed option cannot be told apart from another option, or a
  /// textual answer matched more than one option.
  ambiguousOptions,

  /// The item type has no index-based answer (or its labels are unknown).
  unsupportedType,

  /// A legacy stored value that might be right but cannot be proven.
  unverifiedLegacyKey;

  /// Stable code for logs, item paths and localized messages.
  String get code => switch (this) {
    AnswerKeyStatus.validIndex => 'valid_index',
    AnswerKeyStatus.invalidKey => 'invalid_key',
    AnswerKeyStatus.missingKey => 'missing_key',
    AnswerKeyStatus.ambiguousOptions => 'ambiguous_options',
    AnswerKeyStatus.unsupportedType => 'unsupported_type',
    AnswerKeyStatus.unverifiedLegacyKey => 'unverified_legacy_key',
  };
}

/// Result of resolving an answer key against an option list.
class AnswerKeyResult {
  const AnswerKeyResult._(this.status, this.index, this.detail);

  const AnswerKeyResult.valid(int index)
    : this._(AnswerKeyStatus.validIndex, index, null);

  const AnswerKeyResult.rejected(AnswerKeyStatus status, String detail)
    : this._(status, null, detail);

  final AnswerKeyStatus status;

  /// Zero-based index; non-null only when [isScorable].
  final int? index;

  /// Human-readable reason for a rejection (English, for developers and
  /// repair UIs; [AnswerKeyStatus.code] is the stable identifier).
  final String? detail;

  bool get isScorable => status == AnswerKeyStatus.validIndex;

  /// The index to store in non-nullable legacy fields: the real index, or
  /// [AnswerKey.unscorableIndex] — never a fabricated `0`.
  int get storedIndex => index ?? AnswerKey.unscorableIndex;

  @override
  String toString() => isScorable
      ? 'AnswerKeyResult(valid_index: $index)'
      : 'AnswerKeyResult(${status.code}: $detail)';
}

/// Pure functions for deriving and checking answer keys.
class AnswerKey {
  const AnswerKey._();

  /// Sentinel stored in non-nullable `correctAnswer` fields when the key is
  /// unscorable. No learner selection index can ever equal it, so legacy
  /// `selected == correctAnswer` comparisons fail closed.
  static const int unscorableIndex = -1;

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _decimalDigits = RegExp(r'^\d+$');

  /// Normalization used for exact-text matching: trim, collapse internal
  /// whitespace and case-fold. No containment, edit distance or stemming.
  static String normalize(String value) =>
      value.trim().replaceAll(_whitespace, ' ').toLowerCase();

  /// Validates an explicit index key.
  ///
  /// Only a real `int` is accepted. A decimal-digit string such as `"2"` is
  /// accepted only when [allowLegacyDecimalString] is set (a tested legacy
  /// adapter for older stored or bundled data); `bool`, fractional numbers
  /// and every other shape are rejected.
  static AnswerKeyResult fromIndex(
    Object? raw,
    List<String> options, {
    bool allowLegacyDecimalString = false,
  }) {
    if (raw == null) {
      return const AnswerKeyResult.rejected(
        AnswerKeyStatus.missingKey,
        'No correct answer was given.',
      );
    }
    int? index;
    if (raw is int) {
      index = raw;
    } else if (raw is String && allowLegacyDecimalString) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return const AnswerKeyResult.rejected(
          AnswerKeyStatus.missingKey,
          'The correct answer is blank.',
        );
      }
      if (_decimalDigits.hasMatch(trimmed)) index = int.tryParse(trimmed);
    }
    if (index == null) {
      return AnswerKeyResult.rejected(
        AnswerKeyStatus.invalidKey,
        'The correct answer "$raw" is not a whole-number option index.',
      );
    }
    return _checkIndex(index, options);
  }

  /// Converts a textual answer to an index by **unique normalized exact**
  /// match only. Blank text, no match, or more than one match is rejected.
  static AnswerKeyResult fromText(Object? raw, List<String> options) {
    final text = raw?.toString();
    if (text == null || text.trim().isEmpty) {
      return const AnswerKeyResult.rejected(
        AnswerKeyStatus.missingKey,
        'No correct answer was given.',
      );
    }
    final wanted = normalize(text);
    final matches = <int>[
      for (var i = 0; i < options.length; i++)
        if (normalize(options[i]) == wanted) i,
    ];
    if (matches.isEmpty) {
      return AnswerKeyResult.rejected(
        AnswerKeyStatus.invalidKey,
        'The correct answer "$text" does not exactly match any option.',
      );
    }
    if (matches.length > 1) {
      return AnswerKeyResult.rejected(
        AnswerKeyStatus.ambiguousOptions,
        'The correct answer "$text" matches more than one option.',
      );
    }
    return _checkIndex(matches.single, options);
  }

  static AnswerKeyResult _checkIndex(int index, List<String> options) {
    if (options.isEmpty) {
      return const AnswerKeyResult.rejected(
        AnswerKeyStatus.invalidKey,
        'The question has no answer options.',
      );
    }
    if (index < 0 || index >= options.length) {
      return AnswerKeyResult.rejected(
        AnswerKeyStatus.invalidKey,
        'Correct answer index $index is outside 0..${options.length - 1}.',
      );
    }
    final keyed = normalize(options[index]);
    if (keyed.isEmpty) {
      return AnswerKeyResult.rejected(
        AnswerKeyStatus.invalidKey,
        'Correct answer index $index points at a blank option.',
      );
    }
    final sameText = options.where((o) => normalize(o) == keyed).length;
    if (sameText > 1) {
      return AnswerKeyResult.rejected(
        AnswerKeyStatus.ambiguousOptions,
        'The correct option "${options[index]}" appears more than once.',
      );
    }
    return AnswerKeyResult.valid(index);
  }

  /// Reader-side check of an already-stored index. Invalid values become
  /// [unscorableIndex] instead of `0`; valid values are returned unchanged.
  static int storedIndexOrUnscorable(Object? raw, List<String> options) =>
      fromIndex(raw, options, allowLegacyDecimalString: true).storedIndex;

  /// True when [index] is a usable lookup into [options].
  static bool inRange(int? index, List<Object?> options) =>
      index != null && index >= 0 && index < options.length;
}

/// Semantic true/false mapping derived from option labels, never from an
/// assumed index position (plan §14.8 "True/false repair", H.3 rule 2).
class TrueFalseKey {
  const TrueFalseKey._();

  static const _trueLabels = {'true', 't', 'yes'};
  static const _falseLabels = {'false', 'f', 'no'};

  /// Truth value a label means, or null if it is not a recognised label.
  static bool? labelValue(String label) {
    final normalized = AnswerKey.normalize(label);
    if (_trueLabels.contains(normalized)) return true;
    if (_falseLabels.contains(normalized)) return false;
    return null;
  }

  /// Whether [options] is exactly one True-like and one False-like label.
  static bool hasValidLabels(List<String> options) {
    if (options.length != 2) return false;
    final a = labelValue(options[0]);
    final b = labelValue(options[1]);
    return a != null && b != null && a != b;
  }

  /// The truth value the keyed option means. `['True','False']` with index 0
  /// is true; `['False','True']` with index 0 is false. Returns null (not
  /// scorable) for unknown/duplicate labels or an out-of-range index.
  static bool? correctValue(List<String> options, int correctIndex) {
    if (!hasValidLabels(options)) return null;
    if (!AnswerKey.inRange(correctIndex, options)) return null;
    return labelValue(options[correctIndex]);
  }

  /// Index of the option meaning [value], for writing a key from a choice.
  static int? indexFor(List<String> options, bool value) {
    if (!hasValidLabels(options)) return null;
    for (var i = 0; i < options.length; i++) {
      if (labelValue(options[i]) == value) return i;
    }
    return null;
  }
}
