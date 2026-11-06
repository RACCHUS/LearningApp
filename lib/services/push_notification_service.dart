import 'package:flutter/material.dart';
import 'package:learning_pwa/services/notifications/web_notification_stub.dart'
    if (dart.library.js_interop) 'package:learning_pwa/services/notifications/web_notification_web.dart';

/// Standard Web Notification service that replaces deprecated Firebase FCM dependencies (ARCH-8).
///
/// Uses the browser's native Notification API on web and provides in-app
/// SnackBar alerts as fallbacks across all platforms.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _initialized = false;

  /// Global key for accessing ScaffoldMessenger without a direct BuildContext
  static GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Requests notification permission from the browser.
  Future<bool> requestPermission() async {
    return await requestWebNotificationPermission();
  }

  /// Whether notification permission has been granted.
  bool get hasPermission => hasWebNotificationPermission();

  /// Displays a notification using browser notifications if granted,
  /// with an in-app SnackBar fallback.
  void showNotification(String title, {String? body}) {
    showWebNotification(title, body);

    final messenger = scaffoldMessengerKey?.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (body != null) Text(body),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {
              messenger.hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  // Deprecated FCM compatibility stubs to maintain interface stability.
  Future<String?> getToken() async => null;
  Future<void> subscribeToTopic(String topic) async {}
  Future<void> unsubscribeFromTopic(String topic) async {}
}
