import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('IrtParameters2Pl', () {
    test('computes response probability accurately across theta scale', () {
      const item = IrtParameters2Pl(discrimination: 1.5, difficulty: 0.5);

      // At theta == b, probability must equal 0.5
      expect(item.probability(0.5), closeTo(0.5, 1e-4));

      // Higher ability yields higher probability
      expect(item.probability(2.0), greaterThan(0.90));

      // Lower ability yields lower probability
      expect(item.probability(-1.5), lessThan(0.05));
    });

    test('computes Fisher information peaked at theta == difficulty', () {
      const item = IrtParameters2Pl(discrimination: 2.0, difficulty: 1.0);

      // Peak information is a^2 / 4 = 4.0 / 4 = 1.0
      expect(item.information(1.0), closeTo(1.0, 1e-4));

      // Away from difficulty, information decreases
      expect(item.information(2.5), lessThan(item.information(1.0)));
      expect(item.information(-0.5), lessThan(item.information(1.0)));
    });

    test('serializes to and from json', () {
      const original = IrtParameters2Pl(
        discrimination: 1.25,
        difficulty: -0.42,
        standardError: 0.18,
        converged: true,
      );

      final json = original.toJson();
      final recovered = IrtParameters2Pl.fromJson(json);

      expect(recovered.discrimination, equals(1.25));
      expect(recovered.difficulty, equals(-0.42));
      expect(recovered.standardError, equals(0.18));
      expect(recovered.converged, isTrue);
    });
  });

  group('IrtCalibratorCore Lifecycle (ER-09a, ER-09b)', () {
    const calibrator = IrtCalibratorCore(
      eloMinObservations: 30,
      calibrationMaxSe: 0.30,
      isEloOrderingActive: true,
      isCalibrationActive: true,
    );

    test('N=0 yields unobserved', () {
      final status = calibrator.evaluateLifecycleStatus(observationCount: 0);
      expect(status.status, equals('unobserved'));
      expect(status.observationCount, equals(0));
    });

    test('1 <= N < eloMinObservations yields observed_uncalibrated (not difficulty)', () {
      final status = calibrator.evaluateLifecycleStatus(
        observationCount: 12,
        difficultyEstimate: 0.2,
      );
      expect(status.status, equals('observed_uncalibrated'));
      expect(status.observationCount, equals(12));
    });

    test('N >= eloMinObservations with Elo active yields preliminary_elo_ordering', () {
      final status = calibrator.evaluateLifecycleStatus(
        observationCount: 35,
        difficultyEstimate: 0.45,
      );
      expect(status.status, equals('preliminary_elo_ordering'));
      expect(status.difficultyEstimate, equals(0.45));
    });

    test('preliminary_elo_ordering retained if standard error exceeds threshold', () {
      final status = calibrator.evaluateLifecycleStatus(
        observationCount: 40,
        difficultyEstimate: 0.35,
        standardError: 0.38, // Exceeds 0.30 bound
      );
      expect(status.status, equals('preliminary_elo_ordering'));
    });

    test('promotes to calibrated when SE <= calibrationMaxSe and converged', () {
      final status = calibrator.evaluateLifecycleStatus(
        observationCount: 50,
        difficultyEstimate: 0.35,
        standardError: 0.22, // Meets <= 0.30 bound
        discriminationEstimate: 1.4,
        modelConverged: true,
      );
      expect(status.status, equals('calibrated'));
      expect(status.standardError, equals(0.22));
      expect(status.discriminationEstimate, equals(1.4));
    });

    test('inactive Elo ordering keeps items in observed_uncalibrated', () {
      const inactiveEloCalibrator = IrtCalibratorCore(
        isEloOrderingActive: false,
        isCalibrationActive: false,
      );

      final status = inactiveEloCalibrator.evaluateLifecycleStatus(
        observationCount: 45,
        difficultyEstimate: 0.5,
      );
      expect(status.status, equals('observed_uncalibrated'));
    });
  });

  group('IrtCalibratorCore Elo & MLE Parameter Estimation', () {
    const calibrator = IrtCalibratorCore();

    test('updateEloDifficulty adjusts item difficulty in correct direction', () {
      // Learner of ability 0.0 answers item of difficulty 0.0 correctly (score 1.0)
      // Item difficulty must decrease (easier)
      final easier = calibrator.updateEloDifficulty(
        currentDifficulty: 0.0,
        learnerAbility: 0.0,
        learnerScore: 1.0,
      );
      expect(easier, lessThan(0.0));

      // Learner fails (score 0.0) -> item difficulty must increase (harder)
      final harder = calibrator.updateEloDifficulty(
        currentDifficulty: 0.0,
        learnerAbility: 0.0,
        learnerScore: 0.0,
      );
      expect(harder, greaterThan(0.0));
    });

    test('estimate2PlParameters calculates bounded estimates and SE', () {
      final thetas = [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0];
      final responses = [false, false, false, true, true, true, true, true];

      final params = calibrator.estimate2PlParameters(
        thetas: thetas,
        responses: responses,
      );

      expect(params.discrimination, inInclusiveRange(0.2, 3.0));
      expect(params.difficulty, inInclusiveRange(-4.0, 4.0));
      expect(params.standardError, isNotNull);
      expect(params.standardError!, greaterThan(0.0));
    });
  });
}

