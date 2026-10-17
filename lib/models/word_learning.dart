import 'dart:convert';

/// Distinguishes dictionary words, proper nouns and user-confirmed custom forms.
enum WordEntryKind {
  ordinary('ordinary'),
  properName('proper_name'),
  custom('custom');

  const WordEntryKind(this.dbValue);
  final String dbValue;

  static WordEntryKind parse(String? value) {
    return WordEntryKind.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => WordEntryKind.ordinary,
    );
  }
}

enum WordCasePolicy {
  ignoreCase('ignore_case'),
  exact('exact');

  const WordCasePolicy(this.dbValue);
  final String dbValue;

  static WordCasePolicy parse(String? value) {
    return WordCasePolicy.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => WordCasePolicy.ignoreCase,
    );
  }
}

/// Form identity is independent of lists, lessons and their database IDs.
///
/// v1 deliberately does NOT strip accents, change punctuation, convert regional
/// spellings or merge unrelated word senses. Changing normalization requires a
/// versioned identity migration rather than silently rewriting review history.
class WordFormIdentity {
  static String formKey({
    required String word,
    String locale = 'en-US',
    WordEntryKind kind = WordEntryKind.ordinary,
    WordCasePolicy casePolicy = WordCasePolicy.ignoreCase,
  }) {
    final candidate = word.trim();
    if (candidate.isEmpty || candidate.runes.length > 160) {
      throw ArgumentError.value(word, 'word', 'Must contain 1–160 characters');
    }
    final form = casePolicy == WordCasePolicy.exact
        ? candidate
        : candidate.toLowerCase();
    final encoded = base64Url.encode(utf8.encode(form)).replaceAll('=', '');
    return 'v1:$locale:${kind.dbValue}:${casePolicy.dbValue}:$encoded';
  }

  static String spellingReviewContentId(String formKey) =>
      'word:$formKey:spelling';
}

class SpellingGrade {
  final bool correct;
  final bool assisted;
  final bool acceptedVariant;
  final String submitted;
  final String expected;

  const SpellingGrade({
    required this.correct,
    required this.assisted,
    required this.acceptedVariant,
    required this.submitted,
    required this.expected,
  });

  /// Do not use assisted/hinted answers as evidence of independent retention.
  bool get unassistedSuccess => correct && !assisted;
}

class SpellingScorer {
  static SpellingGrade score({
    required String submitted,
    required String target,
    WordCasePolicy casePolicy = WordCasePolicy.ignoreCase,
    List<String> acceptedForms = const [],
    bool assisted = false,
  }) {
    final answer = submitted.trim();
    final expected = target.trim();
    String normalized(String value) =>
        casePolicy == WordCasePolicy.exact ? value : value.toLowerCase();

    final match = normalized(answer) == normalized(expected);
    final variant = !match && acceptedForms.any(
      (form) => normalized(form.trim()) == normalized(answer),
    );

    return SpellingGrade(
      correct: answer.isNotEmpty && (match || variant),
      assisted: assisted,
      acceptedVariant: variant,
      submitted: answer,
      expected: expected,
    );
  }
}

class WordList {
  final String id;
  final String userId;
  final String title;
  final String? description;

  const WordList({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
  });

  factory WordList.fromJson(Map<String, dynamic> json) => WordList(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
      );
}

class WordListEntry {
  final String id;
  final String listId;
  final String word;
  final String formKey;
  final String locale;
  final WordEntryKind kind;
  final WordCasePolicy casePolicy;
  final List<String> acceptedForms;
  final String? pronunciationHint;
  /// Private user-supplied explanatory note; not a graded vocabulary sense.
  final String? meaning;
  final int sortOrder;

  const WordListEntry({
    required this.id,
    required this.listId,
    required this.word,
    required this.formKey,
    this.locale = 'en-US',
    this.kind = WordEntryKind.ordinary,
    this.casePolicy = WordCasePolicy.ignoreCase,
    this.acceptedForms = const [],
    this.pronunciationHint,
    this.meaning,
    this.sortOrder = 0,
  });

  factory WordListEntry.fromJson(Map<String, dynamic> json) => WordListEntry(
        id: json['id'] as String,
        listId: json['list_id'] as String,
        word: json['word'] as String,
        formKey: json['form_key'] as String,
        locale: json['locale'] as String? ?? 'en-US',
        kind: WordEntryKind.parse(json['entry_kind'] as String?),
        casePolicy: WordCasePolicy.parse(json['case_policy'] as String?),
        acceptedForms: (json['accepted_forms'] as List? ?? const [])
            .map((v) => v.toString())
            .toList(growable: false),
        pronunciationHint: json['pronunciation_hint'] as String?,
        meaning: json['meaning'] as String?,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'list_id': listId,
        'word': word,
        'form_key': formKey,
        'locale': locale,
        'entry_kind': kind.dbValue,
        'case_policy': casePolicy.dbValue,
        'accepted_forms': acceptedForms,
        'pronunciation_hint': pronunciationHint,
        'meaning': meaning,
        'sort_order': sortOrder,
      };
}
