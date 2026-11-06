import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/analytics/elo_rating_engine.dart';

void main() {
  group('EloRatingEngine Pelánek (2016) Tests', () {
    test('predictProbability follows standard logistic curve', () {
      // When ability == difficulty, P = 0.5
      expect(EloRatingEngine.predictProbability(ability: 0.0, difficulty: 0.0), closeTo(0.5, 0.001));

      // When ability > difficulty, P > 0.5
      expect(EloRatingEngine.predictProbability(ability: 1.0, difficulty: 0.0), greaterThan(0.70));

      // When ability < difficulty, P < 0.5
      expect(EloRatingEngine.predictProbability(ability: -1.0, difficulty: 0.0), lessThan(0.30));
    });

    test('updateRatings increases ability on correct and decreases on incorrect', () {
      const initialAbility = 0.0;
      const initialDifficulty = 0.0;

      // Correct answer on equal difficulty item
      final resCorrect = EloRatingEngine.updateRatings(
        learnerAbility: initialAbility,
        itemDifficulty: initialDifficulty,
        score: 1.0,
      );

      expect(resCorrect.updatedAbility, greaterThan(initialAbility));
      expect(resCorrect.updatedDifficulty, lessThan(initialDifficulty));

      // Incorrect answer on equal difficulty item
      final resIncorrect = EloRatingEngine.updateRatings(
        learnerAbility: initialAbility,
        itemDifficulty: initialDifficulty,
        score: 0.0,
      );

      expect(resIncorrect.updatedAbility, lessThan(initialAbility));
      expect(resIncorrect.updatedDifficulty, greaterThan(initialDifficulty));
    });

    test('computeCalibrationCurve produces expected probability bins', () {
      final observations = [
        (predictedP: 0.1, actualScore: 0.0),
        (predictedP: 0.15, actualScore: 0.0),
        (predictedP: 0.5, actualScore: 1.0),
        (predictedP: 0.55, actualScore: 0.0),
        (predictedP: 0.9, actualScore: 1.0),
        (predictedP: 0.95, actualScore: 1.0),
      ];

      final curve = EloRatingEngine.computeCalibrationCurve(
        observations: observations,
        binCount: 5,
      );

      expect(curve.length, 5);
      expect(curve.first.actualMean, 0.0);
      expect(curve.last.actualMean, 1.0);
    });
  });
}

