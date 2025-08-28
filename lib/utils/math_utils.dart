import 'dart:math' as math;

/// Mathematical utility functions for the Learning PWA
/// 
/// Provides common calculations, validations, and formatting
/// used throughout the application.
class MathUtils {
  /// Check if user answer matches correct answer (case-insensitive, trimmed)
  static bool isAnswerCorrect(String userAnswer, String correctAnswer) {
    return userAnswer.trim().toLowerCase() == correctAnswer.trim().toLowerCase();
  }

  /// Calculate percentage with specified decimal places
  static double calculatePercentage(num value, num total, {int decimals = 1}) {
    if (total == 0) return 0.0;
    final percentage = (value / total) * 100;
    return double.parse(percentage.toStringAsFixed(decimals));
  }

  /// Calculate progress percentage (0-100)
  static double calculateProgress(int completed, int total) {
    if (total == 0) return 0.0;
    return math.min(100.0, calculatePercentage(completed, total));
  }

  /// Calculate study streak bonus multiplier
  static double calculateStreakMultiplier(int streakDays) {
    if (streakDays <= 0) return 1.0;
    // Bonus increases by 0.1 for each day, capped at 2.0x
    return math.min(2.0, 1.0 + (streakDays * 0.1));
  }

  /// Calculate score based on correct answers and time taken
  static int calculateScore({
    required int correctAnswers,
    required int totalQuestions,
    required Duration timeTaken,
    Duration? timeLimit,
  }) {
    if (totalQuestions == 0) return 0;
    
    // Base score from correct answers (0-800 points)
    final accuracyScore = (correctAnswers / totalQuestions * 800).round();
    
    // Time bonus (0-200 points) if time limit is provided
    int timeBonus = 0;
    if (timeLimit != null && timeTaken.inSeconds <= timeLimit.inSeconds) {
      final timeEfficiency = 1.0 - (timeTaken.inSeconds / timeLimit.inSeconds);
      timeBonus = (timeEfficiency * 200).round();
    }
    
    return accuracyScore + timeBonus;
  }

  /// Round to specified decimal places
  static double roundToDecimals(double value, int decimals) {
    final factor = math.pow(10, decimals);
    return (value * factor).round() / factor;
  }

  /// Clamp value between min and max
  static T clamp<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Calculate average from a list of numbers
  static double calculateAverage(List<num> values) {
    if (values.isEmpty) return 0.0;
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  /// Calculate median from a list of numbers
  static double calculateMedian(List<num> values) {
    if (values.isEmpty) return 0.0;
    
    final sorted = List<num>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    
    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2.0;
    } else {
      return sorted[middle].toDouble();
    }
  }

  /// Generate random integer between min and max (inclusive)
  static int randomInt(int min, int max) {
    final random = math.Random();
    return min + random.nextInt(max - min + 1);
  }

  /// Format number with appropriate suffix (K, M, B)
  static String formatNumber(num number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else if (number < 1000000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    }
  }

  /// Format duration in minutes to human readable format
  static String formatStudyTime(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  /// Calculate learning velocity (lessons per day)
  static double calculateLearningVelocity(int lessonsCompleted, int days) {
    if (days == 0) return 0.0;
    return lessonsCompleted / days;
  }

  /// Determine difficulty level based on accuracy
  static String getDifficultyLevel(double accuracyPercentage) {
    if (accuracyPercentage >= 90) return 'Easy';
    if (accuracyPercentage >= 70) return 'Medium';
    if (accuracyPercentage >= 50) return 'Hard';
    return 'Very Hard';
  }

  /// Calculate confidence interval for success rate
  static Map<String, double> calculateConfidenceInterval(
    int successes, 
    int total, 
    {double confidence = 0.95}
  ) {
    if (total == 0) return {'lower': 0.0, 'upper': 0.0};
    
    final p = successes / total;
    final z = confidence == 0.95 ? 1.96 : 2.58; // 95% or 99%
    final margin = z * math.sqrt((p * (1 - p)) / total);
    
    return {
      'lower': math.max(0.0, p - margin),
      'upper': math.min(1.0, p + margin),
    };
  }

  /// Check if two floating point numbers are approximately equal
  static bool approximatelyEqual(double a, double b, {double epsilon = 0.001}) {
    return (a - b).abs() < epsilon;
  }
}
