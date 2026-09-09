import 'package:flutter/foundation.dart';

/// Service for reporting errors to external monitoring services
/// Currently implements basic logging, can be extended with Sentry/Crashlytics
class ErrorReportingService {
  static final ErrorReportingService _instance =
      ErrorReportingService._internal();
  static ErrorReportingService get instance => _instance;

  ErrorReportingService._internal();

  bool _isInitialized = false;

  /// Initialize error reporting service
  /// In production, this would initialize Sentry/Crashlytics/Firebase
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kReleaseMode) {
        // Production: Initialize external error reporting
        // Example for Sentry:
        // await SentryFlutter.init(
        //   (options) {
        //     options.dsn = 'YOUR_SENTRY_DSN';
        //     options.tracesSampleRate = 1.0;
        //     options.environment = 'production';
        //   },
        // );

        // Example for Firebase Crashlytics:
        // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

        if (kDebugMode) {
          print('✅ Error reporting service initialized (production mode)');
        }
      } else {
        // Development: Just log locally
        if (kDebugMode) {
          print(
              'ℹ️ Error reporting service initialized (debug mode - local logging only)');
        }
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize error reporting service: $e');
      }
    }
  }

  /// Report an error to external service
  Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
    String? level,
  }) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('⚠️ Error reporting service not initialized');
      }
      return;
    }

    try {
      if (kReleaseMode) {
        // Production: Send to external service
        // Example for Sentry:
        // await Sentry.captureException(
        //   error,
        //   stackTrace: stackTrace,
        //   hint: Hint.withMap(context ?? {}),
        // );

        // Example for Firebase Crashlytics:
        // await FirebaseCrashlytics.instance.recordError(
        //   error,
        //   stackTrace,
        //   reason: context?['reason'],
        //   information: context?.entries.map((e) => '${e.key}: ${e.value}').toList() ?? [],
        //   fatal: level == 'fatal',
        // );

        // For now, just log in release mode (uncomment above when services are configured)
        debugPrint('📤 [ERROR REPORT] $error');
        if (context != null) {
          debugPrint('📤 [CONTEXT] $context');
        }
      } else {
        // Development: Log locally
        if (kDebugMode) {
          print('🐛 [DEV ERROR REPORT]');
          print('   Error: $error');
          if (stackTrace != null) {
            print(
                '   Stack: ${stackTrace.toString().split('\n').take(5).join('\n   ')}');
          }
          if (context != null) {
            print('   Context: $context');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to report error: $e');
      }
    }
  }

  /// Set user context for error reports
  Future<void> setUserContext({
    String? userId,
    String? email,
    Map<String, dynamic>? extras,
  }) async {
    if (!_isInitialized) return;

    try {
      if (kReleaseMode) {
        // Example for Sentry:
        // await Sentry.configureScope((scope) {
        //   scope.setUser(SentryUser(
        //     id: userId,
        //     email: email,
        //     extras: extras,
        //   ));
        // });

        // Example for Firebase Crashlytics:
        // if (userId != null) {
        //   await FirebaseCrashlytics.instance.setUserIdentifier(userId);
        // }
        // if (extras != null) {
        //   for (var entry in extras.entries) {
        //     await FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value);
        //   }
        // }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to set user context: $e');
      }
    }
  }

  /// Log a breadcrumb for error context
  Future<void> addBreadcrumb({
    required String message,
    String? category,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) return;

    try {
      if (kReleaseMode) {
        // Example for Sentry:
        // await Sentry.addBreadcrumb(Breadcrumb(
        //   message: message,
        //   category: category,
        //   data: data,
        //   timestamp: DateTime.now(),
        // ));
      } else if (kDebugMode) {
        print(
            '🍞 [BREADCRUMB] $category: $message ${data != null ? data : ""}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to add breadcrumb: $e');
      }
    }
  }
}
