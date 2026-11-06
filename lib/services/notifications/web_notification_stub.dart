/// Platform-agnostic stub for non-web environments (VM, desktop, native tests).
Future<bool> requestWebNotificationPermission() async => false;

bool hasWebNotificationPermission() => false;

void showWebNotification(String title, String? body) {}

