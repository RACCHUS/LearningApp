import 'package:learning_pwa/models/content_generation/content_resolution_decision.dart';

/// Something the learner can already open.
enum ReuseSourceKind { lesson, bridge }

/// A searchable item, built only from content the learner may already read
/// (the catalog is filtered by RLS; Bridges ship with the app).
class ReuseSource {
  const ReuseSource({
    required this.kind,
    required this.id,
    required this.title,
    this.text = '',
    this.tags = const [],
  });

  final ReuseSourceKind kind;
  final String id;
  final String title;

  /// Description or objective; matched together with the title.
  final String text;
  final List<String> tags;
}

/// A source that covers one or more of the requested ideas.
class ReuseCandidate {
  const ReuseCandidate(this.source, this.coveredIdeas);

  final ReuseSource source;

  /// Indexes into the request's ideas.
  final Set<int> coveredIdeas;
}

class ReuseGateResult {
  const ReuseGateResult({
    required this.decision,
    required this.candidates,
    required this.coveredIdeas,
  });

  final ContentResolutionDecision decision;

  /// Best matches first.
  final List<ReuseCandidate> candidates;

  /// Ideas some candidate already covers.
  final Set<int> coveredIdeas;

  bool get suggestsReuse =>
      decision.kind == ContentResolutionKind.exactReuse ||
      decision.kind == ContentResolutionKind.adapt;
}

/// The Reuse Gate (master plan v2.6 §6.3, §6.4, D20): before planning new
/// content, look for content the learner can already use. Deterministic
/// word overlap only (no model calls). It never blocks: the learner can
/// always override and make their own version.
class ReuseGate {
  const ReuseGate._();

  /// Share of an idea's words that must appear in one source.
  static const coverage = 0.6;
  static const maxCandidates = 5;

  static const _stop = {
    'a',
    'an',
    'the',
    'and',
    'or',
    'of',
    'to',
    'in',
    'on',
    'for',
    'with',
    'how',
    'what',
    'why',
    'when',
    'is',
    'are',
    'be',
    'by',
    'from',
    'into',
    'your',
    'you',
    'my',
    'about',
    'using',
    'use',
    'basic',
    'basics',
    'intro',
    'introduction',
    'lesson',
    'learn',
    'learning',
    'understanding',
    'understand',
  };

  /// Lower-case word stems without stop words. A plural `s` is dropped so
  /// "percentages" matches "percentage".
  static Set<String> words(String text) => {
    for (final raw in text.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
      if (raw.length > 1 && !_stop.contains(raw))
        raw.length > 3 && raw.endsWith('s') && !raw.endsWith('ss')
            ? raw.substring(0, raw.length - 1)
            : raw,
  };

  static ReuseGateResult evaluate({
    required String subject,
    required List<String> ideas,
    required Iterable<ReuseSource> sources,
  }) {
    final ideaWords = [for (final i in ideas) words(i)];
    final subjectWords = words(subject);
    final candidates = <ReuseCandidate>[];
    for (final s in sources) {
      final w = {
        ...words(s.title),
        ...words(s.text),
        for (final t in s.tags) ...words(t),
      };
      // A source that is not about the subject must contain every word of
      // an idea; one about the subject needs [coverage] of them.
      final onSubject =
          subjectWords.isEmpty || subjectWords.intersection(w).isNotEmpty;
      final need = onSubject ? coverage : 1.0;
      final covered = <int>{};
      for (final (i, iw) in ideaWords.indexed) {
        if (iw.isEmpty) continue;
        final hit = iw.intersection(w).length;
        if (hit >= (iw.length * need).ceil()) covered.add(i);
      }
      if (covered.isNotEmpty) candidates.add(ReuseCandidate(s, covered));
    }
    candidates.sort((a, b) {
      final c = b.coveredIdeas.length.compareTo(a.coveredIdeas.length);
      if (c != 0) return c;
      // Prefer lessons (complete) over Bridges (short help).
      return a.source.kind.index.compareTo(b.source.kind.index);
    });
    final top = candidates.take(maxCandidates).toList();
    final covered = {for (final c in candidates) ...c.coveredIdeas};
    final all = ideas.length;

    final ContentResolutionDecision decision;
    if (candidates.isNotEmpty && candidates.first.coveredIdeas.length == all) {
      final best = candidates.first.source;
      decision = ContentResolutionDecision(
        kind: ContentResolutionKind.exactReuse,
        reason:
            'Existing ${best.kind.name} "${best.title}" covers every planned '
            'idea.',
        eligibleAssetRef: '${best.kind.name}:${best.id}',
      );
    } else if (covered.isNotEmpty) {
      decision = ContentResolutionDecision(
        kind: ContentResolutionKind.adapt,
        reason:
            'Existing content covers ${covered.length} of $all ideas; only '
            'the rest needs new content.',
        eligibleAssetRef: candidates.isEmpty
            ? null
            : '${candidates.first.source.kind.name}:'
                  '${candidates.first.source.id}',
      );
    } else {
      decision = const ContentResolutionDecision(
        kind: ContentResolutionKind.generate,
        reason: 'No readable existing content covers these ideas.',
      );
    }
    return ReuseGateResult(
      decision: decision,
      candidates: top,
      coveredIdeas: covered,
    );
  }
}
