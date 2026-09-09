/// Custom exception hierarchy for type-safe error handling
/// Replaces generic Exception usage across the application

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
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'AUTH_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String getUserMessage() => 'Authentication failed. Please try again.';
}

class AuthorizationException extends AppException {
  AuthorizationException(
    String message, {
    String? code,
  }) : super(message, code: code ?? 'AUTHZ_ERROR');

  @override
  String getUserMessage() => 'Access denied. Please check your permissions.';
}

// ============================================================================
// DATA INTEGRITY ERRORS
// ============================================================================

class DatabaseException extends AppException {
  DatabaseException(
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'DB_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String getUserMessage() => 'Database operation failed. Please try again.';
}

class DataValidationException extends AppException {
  final Map<String, String> fieldErrors;

  DataValidationException(
    String message,
    this.fieldErrors, {
    String? code,
  }) : super(message, code: code ?? 'VALIDATION_ERROR');

  @override
  String getUserMessage() {
    if (fieldErrors.isEmpty) return message;
    return fieldErrors.values.first; // Return first validation error
  }
}

class DataCorruptionException extends AppException {
  DataCorruptionException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'DATA_CORRUPT',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String getUserMessage() =>
      'Data integrity error detected. Please contact support.';
}

class SyncException extends AppException {
  final String entityType;

  SyncException(
    String message,
    this.entityType, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'SYNC_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
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
    String message, {
    this.statusCode,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'NETWORK_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
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
    String message, {
    String? code,
  }) : super(message, code: code ?? 'TIMEOUT');

  @override
  String getUserMessage() => 'Request timed out. Please try again.';
}

// ============================================================================
// USER INPUT ERRORS
// ============================================================================

class InvalidInputException extends AppException {
  InvalidInputException(
    String message, {
    String? code,
  }) : super(message, code: code ?? 'INVALID_INPUT');

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
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'STUDY_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String getUserMessage() => 'Study session error. Please try again.';
}

class LessonLoadException extends AppException {
  final String lessonId;

  LessonLoadException(
    this.lessonId,
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: 'LESSON_LOAD_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String getUserMessage() => 'Failed to load lesson. Please try again.';
}

class AudioServiceException extends AppException {
  AudioServiceException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code ?? 'AUDIO_ERROR',
          originalError: originalError,
        );

  @override
  String getUserMessage() => 'Audio service error. Check your audio settings.';
}

class VoiceInputException extends AppException {
  VoiceInputException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(
          message,
          code: code ?? 'VOICE_ERROR',
          originalError: originalError,
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
    String message, {
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          code: code ?? 'CACHE_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String getUserMessage() => 'Storage error. Please try again.';
}

class StorageFullException extends AppException {
  StorageFullException(
    String message,
  ) : super(message, code: 'STORAGE_FULL');

  @override
  String getUserMessage() =>
      'Device storage full. Please free up space and try again.';
}
