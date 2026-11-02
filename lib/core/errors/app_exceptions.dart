/// Custom exception hierarchy for type-safe error handling
/// Replaces generic Exception usage across the application
library;

abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AppException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
    this.metadata,
  }) : timestamp = DateTime.now();

  @override
  String toString() => 'AppException: $message (code: $code)';

  /// Get user-friendly message (sanitized, no technical details)
  String getUserMessage() => message;
}

// ============================================================================
// SECURITY-CRITICAL ERRORS (sanitize before showing to users)
// ============================================================================

class AuthenticationException extends AppException {
  AuthenticationException(
    super.message, {
    String? code,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: code ?? 'AUTH_ERROR',
        );

  @override
  String getUserMessage() => 'Authentication failed. Please try again.';
}

class AuthorizationException extends AppException {
  AuthorizationException(
    super.message, {
    String? code,
  }) : super(code: code ?? 'AUTHZ_ERROR');

  @override
  String getUserMessage() => 'Access denied. Please check your permissions.';
}

// ============================================================================
// DATA INTEGRITY ERRORS
// ============================================================================

class DatabaseException extends AppException {
  DatabaseException(
    super.message, {
    String? code,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: code ?? 'DB_ERROR',
        );

  @override
  String getUserMessage() => 'Database operation failed. Please try again.';
}

class DataValidationException extends AppException {
  final Map<String, String> fieldErrors;

  DataValidationException(
    super.message,
    this.fieldErrors, {
    String? code,
  }) : super(code: code ?? 'VALIDATION_ERROR');

  @override
  String getUserMessage() {
    if (fieldErrors.isEmpty) return message;
    return fieldErrors.values.first; // Return first validation error
  }
}

class DataCorruptionException extends AppException {
  DataCorruptionException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'DATA_CORRUPT',
        );

  @override
  String getUserMessage() =>
      'Data integrity error detected. Please contact support.';
}

class SyncException extends AppException {
  final String entityType;

  SyncException(
    super.message,
    this.entityType, {
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'SYNC_ERROR',
        );

  @override
  String getUserMessage() => 'Failed to sync data. Changes saved locally.';
}

// ============================================================================
// NETWORK & SERVICE ERRORS
// ============================================================================

class NetworkException extends AppException {
  final int? statusCode;

  NetworkException(
    super.message, {
    this.statusCode,
    String? code,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: code ?? 'NETWORK_ERROR',
        );

  @override
  String getUserMessage() =>
      'Network error. Please check your internet connection.';
}

class ServiceUnavailableException extends AppException {
  final String serviceName;

  ServiceUnavailableException(
    this.serviceName, {
    String? message,
  }) : super(
          message ?? '$serviceName is currently unavailable',
          code: 'SERVICE_DOWN',
        );

  @override
  String getUserMessage() =>
      'Service temporarily unavailable. Please try again later.';
}

class TimeoutException extends AppException {
  TimeoutException(
    super.message, {
    String? code,
  }) : super(code: code ?? 'TIMEOUT');

  @override
  String getUserMessage() => 'Request timed out. Please try again.';
}

// ============================================================================
// USER INPUT ERRORS
// ============================================================================

class InvalidInputException extends AppException {
  InvalidInputException(
    super.message, {
    String? code,
  }) : super(code: code ?? 'INVALID_INPUT');

  @override
  String getUserMessage() =>
      message; // User input errors are already user-friendly
}

class PermissionDeniedException extends AppException {
  final String permission;

  PermissionDeniedException(
    this.permission, {
    String? message,
  }) : super(
          message ?? 'Permission denied: $permission',
          code: 'PERMISSION_DENIED',
        );

  @override
  String getUserMessage() =>
      'Permission denied. Please grant $permission access in settings.';
}

// ============================================================================
// FEATURE-SPECIFIC ERRORS
// ============================================================================

class StudySessionException extends AppException {
  StudySessionException(
    super.message, {
    String? code,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: code ?? 'STUDY_ERROR',
        );

  @override
  String getUserMessage() => 'Study session error. Please try again.';
}

class LessonLoadException extends AppException {
  final String lessonId;

  LessonLoadException(
    this.lessonId,
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(
          code: 'LESSON_LOAD_ERROR',
        );

  @override
  String getUserMessage() => 'Failed to load lesson. Please try again.';
}

class AudioServiceException extends AppException {
  AudioServiceException(
    super.message, {
    String? code,
    super.originalError,
  }) : super(
          code: code ?? 'AUDIO_ERROR',
        );

  @override
  String getUserMessage() => 'Audio service error. Check your audio settings.';
}

class VoiceInputException extends AppException {
  VoiceInputException(
    super.message, {
    String? code,
    super.originalError,
  }) : super(
          code: code ?? 'VOICE_ERROR',
        );

  @override
  String getUserMessage() =>
      'Voice input error. Please check microphone permissions.';
}

// ============================================================================
// CACHE & STORAGE ERRORS
// ============================================================================

class CacheException extends AppException {
  CacheException(
    super.message, {
    String? code,
    super.originalError,
    super.stackTrace,
  }) : super(
          code: code ?? 'CACHE_ERROR',
        );

  @override
  String getUserMessage() => 'Storage error. Please try again.';
}

class StorageFullException extends AppException {
  StorageFullException(
    super.message,
  ) : super(code: 'STORAGE_FULL');

  @override
  String getUserMessage() =>
      'Device storage full. Please free up space and try again.';
}
