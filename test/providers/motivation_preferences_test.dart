import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/motivation_preferences_provider.dart';

void main() {
  group('presets', () {
    test('Minimal keeps only completion confirmation', () {
      const p = MotivationPreferences.minimal;
      expect(p.xp, isFalse);
      expect(p.levels, isFalse);
      expect(p.streaks, isFalse);
      expect(p.dailyGoal, isFalse);
      expect(p.celebrations, isTrue);
      expect(MotivationPreferences.completionConfirmation, isTrue);
    });

    test('Standard enables XP, levels and celebrations', () {
      const p = MotivationPreferences.standard;
      expect(p.xp, isTrue);
      expect(p.levels, isTrue);
      expect(p.celebrations, isTrue);
    });

    test('SHIP GATE: debt mechanics are opt-in under BOTH presets', () {
      for (final preset in MotivationPreset.values) {
        final p = MotivationPreferences.fromPreset(preset);
        expect(p.streaks, isFalse,
            reason: 'streaks must be opted into, never assigned ($preset)');
        expect(p.dailyGoal, isFalse,
            reason: 'daily goals must be opted into, never assigned ($preset)');
      }
    });

    test('fromPreset maps correctly', () {
      expect(MotivationPreferences.fromPreset(MotivationPreset.minimal).xp,
          isFalse);
      expect(MotivationPreferences.fromPreset(MotivationPreset.standard).xp,
          isTrue);
    });
  });

  group('isFullyQuiet', () {
    test('Minimal is fully quiet', () {
      expect(MotivationPreferences.minimal.isFullyQuiet, isTrue);
    });

    test('Standard is not', () {
      expect(MotivationPreferences.standard.isFullyQuiet, isFalse);
    });

    test('celebrations alone do not break quiet', () {
      const p = MotivationPreferences(
        xp: false,
        levels: false,
        streaks: false,
        celebrations: true,
        dailyGoal: false,
      );
      expect(p.isFullyQuiet, isTrue);
    });

    test('any single debt mechanic breaks quiet', () {
      expect(
        MotivationPreferences.minimal.copyWith(streaks: true).isFullyQuiet,
        isFalse,
      );
      expect(
        MotivationPreferences.minimal.copyWith(dailyGoal: true).isFullyQuiet,
        isFalse,
      );
    });
  });

  group('copyWith', () {
    test('changes only the named field', () {
      final p = MotivationPreferences.standard.copyWith(xp: false);
      expect(p.xp, isFalse);
      expect(p.levels, isTrue);
      expect(p.celebrations, isTrue);
    });
  });
}
