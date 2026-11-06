import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation using standard browser Notification API.
Future<bool> requestWebNotificationPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

bool hasWebNotificationPermission() {
  try {
    return web.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

void showWebNotification(String title, String? body) {
  try {
    if (hasWebNotificationPermission()) {
      web.Notification(
        title,
        web.NotificationOptions(body: body ?? ''),
      );
    }
  } catch (_) {
    // Non-fatal fallback handled by in-app UI
  }
}

