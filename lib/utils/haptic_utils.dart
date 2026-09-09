import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Utility class for haptic feedback throughout the app.
/// 
/// Provides consistent haptic feedback patterns for different events:
/// - [success] - Medium impact for positive events (correct answer, completion)
/// - [light] - Light impact for neutral events (navigation, wrong answer)
/// - [error] - Heavy impact for error states
/// - [selection] - Selection click for UI interactions
class HapticUtils {
  /// Haptic feedback for successful actions (correct answer, lesson complete)
  static void success() {
    if (!kIsWeb) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Light haptic feedback for neutral events (wrong answer, navigation)
  static void light() {
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
  }

  /// Heavy haptic feedback for errors or important alerts
  static void error() {
    if (!kIsWeb) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Selection click for UI button presses
  static void selection() {
    if (!kIsWeb) {
      HapticFeedback.selectionClick();
    }
  }

  /// Vibration pattern for milestone achievements (streak, level up)
  static void milestone() {
    if (!kIsWeb) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.mediumImpact();
      });
    }
  }
}
