import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/retrieval_state.dart';

/// Guards the A2/B5 language ban as well as the classification itself:
/// this model describes retrieval history, never mastery.
void main() {
  final now = DateTime(2026, 6, 1);
  final recent = now.subtract(const Duration(days: 2));
  final stale = now.subtract(const Duration(days: 90));

  RetrievalState classify({
    required int level,
    int totalReviews = 10,
    int correctReviews = 10,
    DateTime? lastReviewedAt,
  }) {
    return RetrievalState.classify(
      repetitionLevel: level,
      totalReviews: totalReviews,
      correctReviews: correctReviews,
      lastReviewedAt: lastReviewedAt ?? recent,
      now: now,
    );
  }

  group('bands', () {
    test('levels 0-1 need reinforcement', () {
      expect(classify(level: 0).band, RetrievalBand.needsReinforcement);
      expect(classify(level: 1).band, RetrievalBand.needsReinforcement);
    });

    test('levels 2-3 are developing', () {
      expect(classify(level: 2).band, RetrievalBand.developing);
      expect(classify(level: 3).band, RetrievalBand.developing);
    });

    test('levels 4-5 are well retained', () {
      expect(classify(level: 4).band, RetrievalBand.wellRetained);
      expect(classify(level: 5).band, RetrievalBand.wellRetained);
    });

    test('level 6 and beyond is well established', () {
      expect(classify(level: 6).band, RetrievalBand.wellEstablished);
      expect(classify(level: 12).band, RetrievalBand.wellEstablished);
    });

    test('a negative level is clamped rather than crashing', () {
      expect(classify(level: -3).band, RetrievalBand.needsReinforcement);
    });
  });

  group('confidence', () {
    test('thin evidence is low confidence', () {
      expect(classify(level: 6, totalReviews: 2, correctReviews: 2).confidence,
          Confidence.low);
    });

    test('stale evidence is low confidence regardless of level', () {
      expect(classify(level: 6, lastReviewedAt: stale).confidence,
          Confidence.low);
    });

    test('never reviewed is low confidence', () {
      final state = RetrievalState.classify(
        repetitionLevel: 0,
        totalReviews: 0,
        correctReviews: 0,
        lastReviewedAt: null,
        now: now,
      );
      expect(state.confidence, Confidence.low);
    });

    test('moderate evidence is medium confidence', () {
      expect(classify(level: 3, totalReviews: 4, correctReviews: 4).confidence,
          Confidence.medium);
    });

    test('high confidence needs volume, accuracy and a long interval', () {
      expect(
        classify(level: 5, totalReviews: 8, correctReviews: 8).confidence,
        Confidence.high,
      );
    });

    test('poor accuracy blocks high confidence', () {
      expect(
        classify(level: 5, totalReviews: 10, correctReviews: 5).confidence,
        Confidence.medium,
      );
    });

    test('a short interval blocks high confidence', () {
      expect(
        classify(level: 2, totalReviews: 10, correctReviews: 10).confidence,
        Confidence.medium,
      );
    });
  });

  group('SHIP GATE: language ban (A2)', () {
    const banned = ['master', 'secure', 'know', 'learned'];

    test('no band label overclaims', () {
      for (final band in RetrievalBand.values) {
        final label = band.label.toLowerCase();
        for (final word in banned) {
          expect(label.contains(word), isFalse,
              reason: '"${band.label}" must not contain "$word"');
        }
      }
    });

    test('rendered label is never a percentage', () {
      final label = classify(level: 5).label;
      expect(label.contains('%'), isFalse);
      expect(RegExp(r'\d+\.\d+').hasMatch(label), isFalse);
    });

    test('label is band plus confidence', () {
      expect(classify(level: 5, totalReviews: 8, correctReviews: 8).label,
          'Well retained · high confidence');
    });
  });

  group('summary', () {
    test('counts by band', () {
      final summary = RetrievalSummary.from([
        classify(level: 0),
        classify(level: 1),
        classify(level: 4),
        classify(level: 6),
      ]);
      expect(summary[RetrievalBand.needsReinforcement], 2);
      expect(summary[RetrievalBand.wellRetained], 1);
      expect(summary[RetrievalBand.wellEstablished], 1);
      expect(summary.total, 4);
      expect(summary.needingReinforcement, 2);
    });

    test('an empty summary is empty, not zeroed nonsense', () {
      final summary = RetrievalSummary.from(const []);
      expect(summary.isEmpty, isTrue);
      expect(summary.total, 0);
    });
  });
}
