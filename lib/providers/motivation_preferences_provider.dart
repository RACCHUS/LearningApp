import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chosen once by a single onboarding question, adjustable per-mechanic later.
enum MotivationPreset { minimal, standard }

/// Which motivation mechanics are active.
///
/// Streaks and daily goals are opt-in under **both** presets: they are the two
/// mechanics that manufacture debt — something you can lose by not showing up —
/// and debt framing must be opted into, never assigned.
/// See `UI_ARCHITECTURE_LOCKED.md` §9.1.
class MotivationPreferences {
  /// Not removable: this is feedback, not a reward.
  static const bool completionConfirmation = true;

  final bool xp;
  final bool levels;
  final bool streaks;
  final bool celebrations;
  final bool dailyGoal;

  const MotivationPreferences({
    required this.xp,
    required this.levels,
    required this.streaks,
    required this.celebrations,
    required this.dailyGoal,
  });

  static const MotivationPreferences minimal = MotivationPreferences(
    xp: false,
    levels: false,
    streaks: false,
    celebrations: true,
    dailyGoal: false,
  );

  static const MotivationPreferences standard = MotivationPreferences(
    xp: true,
    levels: true,
    streaks: false,
    celebrations: true,
    dailyGoal: false,
  );

  factory MotivationPreferences.fromPreset(MotivationPreset preset) =>
      preset == MotivationPreset.minimal ? minimal : standard;

  /// True when nothing gamified should render anywhere at all.
  bool get isFullyQuiet => !xp && !levels && !streaks && !dailyGoal;

  MotivationPreferences copyWith({
    bool? xp,
    bool? levels,
    bool? streaks,
    bool? celebrations,
    bool? dailyGoal,
  }) {
    return MotivationPreferences(
      xp: xp ?? this.xp,
      levels: levels ?? this.levels,
      streaks: streaks ?? this.streaks,
      celebrations: celebrations ?? this.celebrations,
      dailyGoal: dailyGoal ?? this.dailyGoal,
    );
  }
}

class MotivationPreferencesNotifier extends StateNotifier<MotivationPreferences> {
  MotivationPreferencesNotifier() : super(MotivationPreferences.standard) {
    _load();
  }

  static const _kXp = 'motivation.xp';
  static const _kLevels = 'motivation.levels';
  static const _kStreaks = 'motivation.streaks';
  static const _kCelebrations = 'motivation.celebrations';
  static const _kDailyGoal = 'motivation.dailyGoal';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const fallback = MotivationPreferences.standard;
      state = MotivationPreferences(
        xp: prefs.getBool(_kXp) ?? fallback.xp,
        levels: prefs.getBool(_kLevels) ?? fallback.levels,
        streaks: prefs.getBool(_kStreaks) ?? fallback.streaks,
        celebrations: prefs.getBool(_kCelebrations) ?? fallback.celebrations,
        dailyGoal: prefs.getBool(_kDailyGoal) ?? fallback.dailyGoal,
      );
    } catch (_) {
      // Preferences are non-critical; a bad read must not break the app.
      state = MotivationPreferences.standard;
    }
  }

  Future<void> applyPreset(MotivationPreset preset) =>
      _persist(MotivationPreferences.fromPreset(preset));

  Future<void> update(MotivationPreferences next) => _persist(next);

  Future<void> _persist(MotivationPreferences next) async {
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kXp, next.xp);
      await prefs.setBool(_kLevels, next.levels);
      await prefs.setBool(_kStreaks, next.streaks);
      await prefs.setBool(_kCelebrations, next.celebrations);
      await prefs.setBool(_kDailyGoal, next.dailyGoal);
    } catch (_) {
      // State already updated in memory; persistence failure is recoverable.
    }
  }
}

final motivationPreferencesProvider =
    StateNotifierProvider<MotivationPreferencesNotifier, MotivationPreferences>(
  (ref) => MotivationPreferencesNotifier(),
);
