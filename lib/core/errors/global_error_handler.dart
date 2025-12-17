import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';

/// Global error handler for uncaught exceptions and error sanitization
class GlobalErrorHandler {
  static bool _initialized = false;

  /// Initialize global error handling
  static void initialize() {
    if (_initialized) return;

    // Catch all uncaught Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('❌ Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');

      if (kReleaseMode) {
        // In production, report to error tracking service
        // ErrorReportingService.instance.reportError(details.exception, details.stack);
      }
    };

    // Catch all uncaught async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('❌ Uncaught Error: $error');
      debugPrint('Stack trace: $stack');

      if (kReleaseMode) {
        // In production, report to error tracking service
        // ErrorReportingService.instance.reportError(error, stack);
      }
      return true; // Handled
    };

    _initialized = true;
    debugPrint('✅ Global error handler initialized');
  }

  /// Convert any exception to user-friendly message
  static String getUserMessage(dynamic error) {
    if (error is AppException) {
      return error.getUserMessage();
    } else if (error is PostgrestException) {
      return 'Database operation failed. Please try again.';
    } else if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (error is FormatException) {
      return 'Invalid data format. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Sanitize error for logging (remove PII, sensitive data)
  static Map<String, dynamic> sanitizeForLogging(dynamic error) {
    if (error is AppException) {
      return {
        'type': error.runtimeType.toString(),
        'code': error.code,
        'message': error.message,
        'timestamp': error.timestamp.toIso8601String(),
        'metadata': _sanitizeMetadata(error.metadata),
      };
    } else if (error is PostgrestException) {
      // Sanitize PostgrestException - don't expose database internals
      return {
        'type': 'PostgrestException',
        'code': error.code,
        'message': 'Database error occurred', // Generic message
        // DO NOT include: error.details, error.hint (may expose schema)
      };
    } else {
      return {
        'type': error.runtimeType.toString(),
        'message': error.toString(),
      };
    }
  }

  static Map<String, dynamic>? _sanitizeMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;

    // Remove sensitive keys
    final sensitive = [
      'password',
      'token',
      'apiKey',
      'api_key',
      'secret',
      'email',
      'phone',
      'ssn',
      'credit_card',
      'authorization',
    ];

    return Map.fromEntries(
      metadata.entries.where(
        (e) => !sensitive.any(
          (s) => e.key.toLowerCase().contains(s),
        ),
      ),
    );
  }

  /// Check if error should be retried
  static bool isRetryable(dynamic error) {
    if (error is NetworkException) return true;
    if (error is TimeoutException) return true;
    if (error is ServiceUnavailableException) return true;
    if (error is SocketException) return true;
    if (error is PostgrestException) {
      // Retry on network/timeout errors, not on constraint violations
      return error.code == 'PGRST301' || // Timeout
          error.code == 'PGRST000'; // Connection error
    }
    return false;
  }

  /// Determine if error is critical (requires immediate attention)
  static bool isCritical(dynamic error) {
    if (error is DataCorruptionException) return true;
    if (error is StorageFullException) return true;
    if (error is AuthorizationException) return true;
    return false;
  }
}
