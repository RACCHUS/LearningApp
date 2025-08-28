/// Application-wide constants
/// 
/// This file contains all constants used throughout the Learning PWA application.
/// Constants are organized by category for better maintainability.

/// API and Network Constants
class ApiConstants {
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 10);
  static const int maxRetryAttempts = 3;
  static const String userAgent = 'LearningPWA/1.0';
}

/// UI and Design Constants  
class UIConstants {
  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  
  // Border Radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  
  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  
  // Component Sizes
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 80.0;
}

/// Study and Learning Constants
class StudyConstants {
  static const int defaultStudyGoalMinutes = 30;
  static const int maxStudySessionMinutes = 120;
  static const int minStudySessionMinutes = 5;
  static const int streakResetHours = 36;
  static const int maxDailyStudySessions = 10;
  
  // Progress tracking
  static const double passingScorePercentage = 70.0;
  static const int maxRecentLessons = 10;
  static const int maxFavoriteLessons = 50;
}

/// Audio and Voice Constants
class AudioConstants {
  static const double defaultPlaybackSpeed = 1.0;
  static const double minPlaybackSpeed = 0.5;
  static const double maxPlaybackSpeed = 2.0;
  static const double speedIncrement = 0.25;
  
  static const Duration maxVoiceInputDuration = Duration(seconds: 30);
  static const Duration voiceInputTimeout = Duration(seconds: 5);
  static const double defaultVolume = 0.8;
}

/// Storage and Caching Constants
class StorageConstants {
  // Hive box names
  static const String lessonsBox = 'lessons';
  static const String progressBox = 'progress';
  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';
  
  // Cache durations
  static const Duration shortCache = Duration(hours: 1);
  static const Duration mediumCache = Duration(hours: 24);
  static const Duration longCache = Duration(days: 7);
  
  // Storage limits
  static const int maxCachedLessons = 100;
  static const int maxOfflineLessons = 50;
}

/// Validation Constants
class ValidationConstants {
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;
  
  static const int minLessonTitleLength = 3;
  static const int maxLessonTitleLength = 100;
  static const int maxLessonDescriptionLength = 500;
  static const int maxTagsPerLesson = 10;
  static const int maxTagLength = 20;
  
  static const int minQuestionLength = 5;
  static const int maxQuestionLength = 500;
  static const int minAnswerLength = 1;
  static const int maxAnswerLength = 200;
}

/// Feature Flags and App Configuration
class AppConfig {
  static const bool enableVoiceInput = true;
  static const bool enableOfflineMode = true;
  static const bool enableAnalytics = true;
  static const bool enablePushNotifications = true;
  static const bool enableDebugLogging = false;
  
  // Version info
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String minimumSupportedVersion = '1.0.0';
}
