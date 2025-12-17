import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/core/errors/global_error_handler.dart';

enum LogLevel { trace, debug, info, warn, error, fatal }

/// Standardized logger for consistent logging across the application
class AppLogger {
  final String _component;

  AppLogger(this._component);

  void trace(String message, {Map<String, dynamic>? metadata}) {
    if (kDebugMode) _log(LogLevel.trace, message, metadata: metadata);
  }

  void debug(String message, {Map<String, dynamic>? metadata}) {
    if (kDebugMode) _log(LogLevel.debug, message, metadata: metadata);
  }

  void info(String message, {Map<String, dynamic>? metadata}) {
    _log(LogLevel.info, message, metadata: metadata);
  }

  void warn(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      LogLevel.warn,
      message,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  void fatal(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _log(
      LogLevel.fatal,
      message,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  void _log(
    LogLevel level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final logData = {
      'component': _component,
      'level': level.name,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      if (error != null) 'error': GlobalErrorHandler.sanitizeForLogging(error),
      if (stackTrace != null && kDebugMode)
        'stackTrace': stackTrace.toString(),
      if (metadata != null) 'metadata': metadata,
    };

    // Production: JSON structured logging
    if (kReleaseMode) {
      // Only log warnings and above in production
      if (level.index >= LogLevel.warn.index) {
        debugPrint(jsonEncode(logData));
      }
    } else {
      // Development: Pretty formatted
      final emoji = {
        LogLevel.trace: '🔍',
        LogLevel.debug: '🐛',
        LogLevel.info: 'ℹ️',
        LogLevel.warn: '⚠️',
        LogLevel.error: '❌',
        LogLevel.fatal: '💀',
      }[level];

      debugPrint('$emoji [$_component] $message');
      if (error != null) debugPrint('  Error: $error');
      if (metadata != null) debugPrint('  Metadata: $metadata');
      if (stackTrace != null && level.index >= LogLevel.error.index) {
        debugPrint('  Stack trace: $stackTrace');
      }
    }

    // Send errors and fatals to external service in production
    if (kReleaseMode && (level == LogLevel.error || level == LogLevel.fatal)) {
      // TODO: Integrate with Sentry/Crashlytics
      // ErrorReportingService.instance.reportError(error, stackTrace, context: logData);
    }
  }
}
