import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  
  // Global key for accessing ScaffoldMessenger without context
  static GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  Future<void> init() async {
    if (_initialized) return;
    await _messaging.requestPermission();
    await _messaging.setAutoInitEnabled(true);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundNotification(message);
    });

    _initialized = true;
  }
  
  /// Handle push notifications received while app is in foreground
  void _handleForegroundNotification(RemoteMessage message) {
    debugPrint('Push notification received: ${message.notification?.title}');
    
    final notification = message.notification;
    if (notification == null) return;
    
    // Show in-app snackbar notification
    final messenger = scaffoldMessengerKey?.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title ?? 'Notification',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (notification.body != null)
                Text(notification.body!),
            ],
          ),
          duration: const Duration(seconds: 5),
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

  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
