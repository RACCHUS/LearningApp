import 'package:flutter/services.dart';

/// Advisory US-English spelling reference derived from a SCOWL Hunspell list.
/// Base forms only: missing entries must NEVER be automatically rejected.
/// Loaded on first use rather than at app startup.
class WordSpellingAdvisor {
  static const assetPath = 'assets/lexicons/en_us_scowl_roots.txt';
  final Future<String> Function() _loadSource;
  Future<Set<String>>? _entries;

  WordSpellingAdvisor({Future<String> Function()? loadSource})
      : _loadSource = loadSource ?? (() => rootBundle.loadString(assetPath));

  factory WordSpellingAdvisor.fromWords(Iterable<String> words) {
    return WordSpellingAdvisor(
      loadSource: () async => words.join('\n'),
    );
  }

  Future<WordSpellingAdvice> check(String word) async {
    final input = word.trim();
    if (input.isEmpty) return const WordSpellingAdvice(recognized: false);
    final dictionary = await (_entries ??= _readEntries());
    final lower = input.toLowerCase();
    if (dictionary.contains(lower)) {
      return const WordSpellingAdvice(recognized: true);
    }
    // This is NOT a definitive misspelling verdict: proper nouns, technical
    // terms, plurals and valid variants can be missing from a roots list.
    final maxDistance = lower.length <= 4 ? 1 : 2;
    final matches = <({String word, int distance})>[];
    for (final candidate in dictionary) {
      if (candidate.isEmpty ||
          candidate[0] != lower[0] ||
          (candidate.length - lower.length).abs() > maxDistance) {
        continue;
      }
      final distance = _boundedDistance(lower, candidate, maxDistance);
      if (distance <= maxDistance) {
        matches.add((word: candidate, distance: distance));
      }
    }
    matches.sort((a, b) {
      final byDist = a.distance.compareTo(b.distance);
      if (byDist != 0) return byDist;
      final byLen = (a.word.length - lower.length)
          .abs()
          .compareTo((b.word.length - lower.length).abs());
      return byLen != 0 ? byLen : a.word.compareTo(b.word);
    });
    return WordSpellingAdvice(
      recognized: false,
      suggestions: matches.take(3).map((m) => m.word).toList(),
    );
  }

  Future<Set<String>> _readEntries() async {
    final raw = await _loadSource();
    return raw.split(RegExp(r'\r?\n'))
        .map((word) => word.trim().toLowerCase())
        .where((word) => word.isNotEmpty && !word.startsWith('#'))
        .toSet();
  }

  /// Unit-cost Levenshtein with early budget exit; no automatic substitutions.
  static int _boundedDistance(String a, String b, int maxDistance) {
    if ((a.length - b.length).abs() > maxDistance) return maxDistance + 1;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      var rowMin = current[0];
      for (var j = 1; j <= b.length; j++) {
        final penalty = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + penalty,
        ].reduce((x, y) => x < y ? x : y);
        if (current[j] < rowMin) rowMin = current[j];
      }
      if (rowMin > maxDistance) return maxDistance + 1;
      previous = current;
    }
    return previous.last;
  }
}

class WordSpellingAdvice {
  final bool recognized;
  final List<String> suggestions;
  const WordSpellingAdvice({
    required this.recognized,
    this.suggestions = const [],
  });
}
