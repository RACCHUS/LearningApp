import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/notification_service.dart';

void main() {
  test('init is callable (skipped: depends on platform notification plugin)', () async {
    final service = NotificationService();
    await service.init();
  }, skip: 'Notification plugin requires platform channels; skip in unit tests');
}

