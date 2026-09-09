/// Classification of **retrieval history**. NOT a mastery measurement.
///
/// An SM-2 repetition level records when we intend to ask again — a scheduling
/// artefact that correlates with retention rather than measuring it. Every band
/// name here is therefore a claim about retention, never about knowing.
/// See `UI_ARCHITECTURE_LOCKED.md` §6.1.
enum RetrievalBand { needsReinforcement, developing, wellRetained, wellEstablished }

/// Our confidence in the classification, not the learner's confidence.
enum Confidence { low, medium, high }

extension RetrievalBandLabel on RetrievalBand {
  String get label => switch (this) {
        RetrievalBand.needsReinforcement => 'Needs reinforcement',
        RetrievalBand.developing => 'Developing',
        RetrievalBand.wellRetained => 'Well retained',
        RetrievalBand.wellEstablished => 'Well established',
      };
}

extension ConfidenceLabel on Confidence {
  String get label => switch (this) {
        Confidence.low => 'low confidence',
        Confidence.medium => 'medium confidence',
        Confidence.high => 'high confidence',
      };
}

/// Highest SM-2 level treated as the top band.
const int kMaxRetrievalLevel = 6;

/// Recency beyond which any classification drops to low confidence.
const Duration kStaleAfter = Duration(days: 60);

class RetrievalState {
  final RetrievalBand band;
  final Confidence confidence;

  /// == ReviewableItem.totalReviews
  final int evidenceCount;

  const RetrievalState({
    required this.band,
    required this.confidence,
    required this.evidenceCount,
  });

  /// Copy shown to the learner. Never a percentage, and never the words
  /// "mastered", "secure", "knows" or "learned".
  String get label => '${band.label} · ${confidence.label}';

  /// Classify a single reviewable item.
  ///
  /// Every cutoff here is an engineering heuristic chosen for v1; no study
  /// produced these numbers. Deliberately limited to fields that actually
  /// exist on `ReviewableItem` — session counts are not computable, so
  /// `repetitionLevel >= 4` stands in as the long-interval proxy (spec B5).
  factory RetrievalState.classify({
    required int repetitionLevel,
    required int totalReviews,
    required int correctReviews,
    DateTime? lastReviewedAt,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final level = repetitionLevel < 0 ? 0 : repetitionLevel;

    final band = switch (level) {
      0 || 1 => RetrievalBand.needsReinforcement,
      2 || 3 => RetrievalBand.developing,
      4 || 5 => RetrievalBand.wellRetained,
      _ => RetrievalBand.wellEstablished,
    };

    final isStale = lastReviewedAt == null ||
        clock.difference(lastReviewedAt) > kStaleAfter;
    final accuracy = totalReviews > 0 ? correctReviews / totalReviews : 0.0;

    final Confidence confidence;
    if (totalReviews < 3 || isStale) {
      confidence = Confidence.low;
    } else if (totalReviews >= 6 && accuracy >= 0.8 && level >= 4) {
      confidence = Confidence.high;
    } else {
      confidence = Confidence.medium;
    }

    return RetrievalState(
      band: band,
      confidence: confidence,
      evidenceCount: totalReviews,
    );
  }
}

/// Aggregate band counts for a context, used by Progress §1.
class RetrievalSummary {
  final Map<RetrievalBand, int> counts;

  const RetrievalSummary(this.counts);

  factory RetrievalSummary.from(Iterable<RetrievalState> states) {
    final counts = <RetrievalBand, int>{
      for (final band in RetrievalBand.values) band: 0,
    };
    for (final state in states) {
      counts[state.band] = (counts[state.band] ?? 0) + 1;
    }
    return RetrievalSummary(counts);
  }

  int operator [](RetrievalBand band) => counts[band] ?? 0;

  int get total => counts.values.fold(0, (a, b) => a + b);

  int get needingReinforcement => this[RetrievalBand.needsReinforcement];

  bool get isEmpty => total == 0;
}
