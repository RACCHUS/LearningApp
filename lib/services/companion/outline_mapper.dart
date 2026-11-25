import 'dart:convert';

import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/services/content_generation/reuse_gate.dart';

/// The parts found in a pasted outline.
class ParsedOutline {
  const ParsedOutline(
    this.titles, {
    this.truncated = false,
    this.minutes = const [],
    this.starts = const [],
  });
  final List<String> titles;

  /// For each title, where it begins in a video when its line opened with a
  /// timestamp ("2:15 Exponents"), in seconds; null otherwise.
  final List<int?> starts;

  /// For each title, the length stated on its line ("12:30", "25 min",
  /// "1 h 20 min"), in whole minutes; null where the line gave none.
  final List<int?> minutes;

  /// True when the paste was longer than the caps and the rest was dropped.
  final bool truncated;
}

/// What the learner's own AI chat said, after checking.
class AiMapResult {
  const AiMapResult({this.bySection = const {}, this.dropped = 0, this.error});

  /// Section index (0-based) to the objective keys the answer gave for it.
  final Map<int, Set<String>> bySection;

  /// Entries left out because they named a part or objective that is not in
  /// the learner's lists.
  final int dropped;
  final String? error;
}

/// Maps the outline of an outside resource to a goal's objectives (companion
/// plan v1.0 §3.4, rungs 2 and 3). Everything runs on the device from text
/// the learner pasted. Nothing is fetched and no model is called. Every
/// result is a proposal the learner confirms; none of it is a review.
class OutlineMapper {
  const OutlineMapper._();

  static const maxPasteLength = 20000;
  static const maxResponseLength = 60000;
  static const maxProposalsPerSection = 6;
  static const format = 'la-resource-map/1';

  /// Words that name a part of a resource, not what it teaches.
  static const _partWords = {
    'chapter',
    'unit',
    'section',
    'module',
    'week',
    'lecture',
    'part',
    'topic',
    'video',
    'episode', //
    'day',
    'session',
    'class',
    'quiz',
    'test',
    'exam',
    'review',
    'summary',
    'overview',
    'practice',
  };

  static final _leadBullet = RegExp(r'^[\s\-\*•‣◦▪·–—>#]+');
  static final _leadTime = RegExp(
    r'^\(?\[?\d{1,2}(:\d{2}){1,2}\]?\)?\s*[\-–—:|]?\s*',
  );
  static final _tailTime = RegExp(
    r'\s*[\-–—|(\[]?\s*\d{1,2}(:\d{2}){1,2}\s*[)\]]?$',
  );
  static final _tailPage = RegExp(
    r'(\s*\.{2,}\s*|\t+|\s{3,})(p\.?\s*)?\d{1,4}$',
  );
  static final _tailWords = RegExp(
    r'\s*[\-–—|(\[]?\s*(?:(\d{1,2})\s*(?:hours?|hrs?|h))?\s*(?:(\d{1,3})\s*(?:minutes?|mins?|m))?\s*[)\]]?$',
    caseSensitive: false,
  );
  static final _letter = RegExp(r'[A-Za-z]');

  /// Removes a length from the end of [line] and returns it in minutes.
  /// A two-part time is read as minutes:seconds, the usual form for video.
  static (String, int?) _takeLength(String line) {
    final time = _tailTime.firstMatch(line);
    if (time != null) {
      final parts = RegExp(
        r'\d+',
      ).allMatches(time.group(0)!).map((m) => int.parse(m.group(0)!)).toList();
      final seconds = parts.length == 3
          ? parts[0] * 3600 + parts[1] * 60 + parts[2]
          : parts[0] * 60 + parts[1];
      return (
        line.substring(0, time.start),
        _clampMinutes((seconds / 60).ceil()),
      );
    }
    final words = _tailWords.firstMatch(line);
    if (words != null && (words.group(1) != null || words.group(2) != null)) {
      final total =
          int.parse(words.group(1) ?? '0') * 60 +
          int.parse(words.group(2) ?? '0');
      return (line.substring(0, words.start), _clampMinutes(total));
    }
    return (line, null);
  }

  static int? _clampMinutes(int m) => m < 1
      ? null
      : (m > ResourceSection.maxMinutes ? ResourceSection.maxMinutes : m);

  /// One part per line. Bullets, video timestamps and page numbers are
  /// removed; chapter numbers stay because the learner knows parts by them.
  static ParsedOutline parse(String pasted) {
    var truncated = pasted.length > maxPasteLength;
    final text = truncated ? pasted.substring(0, maxPasteLength) : pasted;
    final titles = <String>[];
    final minutes = <int?>[];
    final starts = <int?>[];
    final seen = <String>{};
    for (final raw in const LineSplitter().convert(text)) {
      var line = raw
          .trimRight()
          .replaceFirst(_tailPage, '')
          .replaceFirst(_leadBullet, '');
      final lead = _leadTime.firstMatch(line);
      final start = lead == null ? null : _seconds(lead.group(0)!);
      final (rest, length) = _takeLength(
        lead == null ? line : line.substring(lead.end),
      );
      line = rest;
      line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (!_letter.hasMatch(line)) continue;
      if (line.length > ResourceSection.maxTitleLength) {
        line = line.substring(0, ResourceSection.maxTitleLength).trimRight();
      }
      if (!seen.add(line.toLowerCase())) continue;
      if (titles.length == ResourceSection.maxSections) {
        truncated = true;
        break;
      }
      titles.add(line);
      minutes.add(length);
      starts.add(
        start != null && start <= ResourceSection.maxStartSeconds
            ? start
            : null,
      );
    }
    // A video chapter list gives start times, not lengths: a part runs until
    // the next one starts. The last part's length stays unknown.
    for (var i = 0; i + 1 < titles.length; i++) {
      final a = starts[i], b = starts[i + 1];
      if (minutes[i] == null && a != null && b != null && b > a) {
        minutes[i] = _clampMinutes(((b - a) / 60).ceil());
      }
    }
    return ParsedOutline(
      titles,
      truncated: truncated,
      minutes: minutes,
      starts: starts,
    );
  }

  /// "2:15" is 135 and "1:02:33" is 3753. A two-part time is minutes:seconds.
  static int _seconds(String text) {
    final parts = RegExp(
      r'\d+',
    ).allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
    return parts.length == 3
        ? parts[0] * 3600 + parts[1] * 60 + parts[2]
        : parts[0] * 60 + parts[1];
  }

  static Set<String> _words(String text) => {
    for (final w in ReuseGate.words(text))
      if (!_partWords.contains(w) && _letter.hasMatch(w)) w,
  };

  static String _itemText(ResourceOutlineItem item) {
    final code = item.code;
    return code != null && item.label.startsWith(code)
        ? item.label.substring(code.length)
        : item.label;
  }

  static double _score(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final hit = a.intersection(b).length;
    if (hit == 0) return 0;
    final share = hit / a.length, other = hit / b.length;
    return share > other ? share : other;
  }

  /// For each section title, the objective keys whose wording overlaps it:
  /// every objective of an area the title names, plus the closest single
  /// objectives. Word overlap only, so it misses synonyms and can be wrong.
  static List<Set<String>> propose(
    List<String> sectionTitles,
    ResourceOutline outline,
  ) {
    final groupWords = [for (final g in outline.groups) _words(g.title)];
    final itemWords = [
      for (final g in outline.groups)
        [for (final i in g.items) _words(_itemText(i))],
    ];
    return [
      for (final title in sectionTitles)
        _proposeOne(_words(title), outline, groupWords, itemWords),
    ];
  }

  static Set<String> _proposeOne(
    Set<String> words,
    ResourceOutline outline,
    List<Set<String>> groupWords,
    List<List<Set<String>>> itemWords,
  ) {
    final keys = <String>{};
    final singles = <(double, int, String)>[];
    var order = 0;
    for (final (gi, g) in outline.groups.indexed) {
      final wholeArea = _score(words, groupWords[gi]) >= ReuseGate.coverage;
      for (final (ii, item) in g.items.indexed) {
        order++;
        if (wholeArea) {
          keys.add(item.key);
          continue;
        }
        final s = _score(words, itemWords[gi][ii]);
        if (s >= ReuseGate.coverage) singles.add((s, order, item.key));
      }
    }
    singles.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    keys.addAll(singles.take(maxProposalsPerSection).map((s) => s.$3));
    return keys.length > ResourceSection.maxKeysPerSection
        ? keys.take(ResourceSection.maxKeysPerSection).toSet()
        : keys;
  }

  static List<ResourceOutlineItem> _items(ResourceOutline outline) => [
    for (final g in outline.groups) ...g.items,
  ];

  /// A prompt for the learner's own AI chat. It carries only the goal's
  /// objectives and the titles the learner pasted. Objectives are numbered
  /// (O1, O2, ...) so the answer cannot introduce one that is not listed.
  static String buildPrompt({
    required String resourceTitle,
    required List<String> sectionTitles,
    required ResourceOutline outline,
  }) {
    final b = StringBuffer()
      ..writeln(
        'I am studying "$resourceTitle" to prepare for a goal. Match each part of it to the',
      )
      ..writeln('objectives of my goal.')
      ..writeln()
      ..writeln('Rules:')
      ..writeln(
        '- Go only by what a part title plainly says. If you are not sure a part covers an',
      )
      ..writeln(
        '  objective, leave it out. A missing match is better than a wrong one.',
      )
      ..writeln('- Use only the objective ids and part numbers listed here.')
      ..writeln('- Do not quote or reproduce any content from the resource.')
      ..writeln()
      ..writeln('OBJECTIVES');
    for (final (i, item) in _items(outline).indexed) {
      b.writeln('O${i + 1}: ${item.label}');
    }
    b
      ..writeln()
      ..writeln('PARTS');
    for (final (i, t) in sectionTitles.indexed) {
      b.writeln('${i + 1}: $t');
    }
    b
      ..writeln()
      ..writeln('Answer with JSON only, in exactly this shape:')
      ..writeln(
        '{"format":"$format","sections":[{"n":1,"objectives":["O1","O2"]}]}',
      )
      ..write(
        'List every part number once. Use an empty list where no objective fits.',
      );
    return b.toString();
  }

  /// Checks a pasted answer to [buildPrompt]. Anything that is not a listed
  /// part number or objective id is dropped and counted; the text is never
  /// shown or stored.
  static AiMapResult parseResponse(
    String pasted, {
    required int sectionCount,
    required ResourceOutline outline,
  }) {
    const unreadable = AiMapResult(
      error:
          "That doesn't look like the answer to this prompt. Copy the whole answer and try again.",
    );
    if (pasted.trim().isEmpty) {
      return const AiMapResult(error: 'Paste the answer first.');
    }
    if (pasted.length > maxResponseLength) {
      return const AiMapResult(error: 'That answer is too long.');
    }
    final start = pasted.indexOf('{'), end = pasted.lastIndexOf('}');
    if (start < 0 || end <= start) return unreadable;
    Object? decoded;
    try {
      decoded = jsonDecode(pasted.substring(start, end + 1));
    } catch (_) {
      return unreadable;
    }
    if (decoded is! Map ||
        decoded['format'] != format ||
        decoded['sections'] is! List) {
      return unreadable;
    }

    final items = _items(outline);
    final id = RegExp(r'^O(\d{1,4})$');
    final bySection = <int, Set<String>>{};
    var dropped = 0;
    for (final s in decoded['sections'] as List) {
      final n = s is Map ? s['n'] : null;
      final objectives = s is Map ? s['objectives'] : null;
      if (n is! int || n < 1 || n > sectionCount || objectives is! List) {
        dropped++;
        continue;
      }
      final keys = bySection[n - 1] ??= <String>{};
      for (final o in objectives) {
        final m = o is String ? id.firstMatch(o.trim()) : null;
        final index = m == null ? 0 : int.parse(m.group(1)!);
        if (index < 1 ||
            index > items.length ||
            keys.length >= ResourceSection.maxKeysPerSection) {
          dropped++;
          continue;
        }
        keys.add(items[index - 1].key);
      }
    }
    if (bySection.isEmpty) return unreadable;
    return AiMapResult(bySection: bySection, dropped: dropped);
  }
}
