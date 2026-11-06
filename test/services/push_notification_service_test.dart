import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/push_notification_service.dart';

void main() {
  group('PushNotificationService (Web Notification without Firebase)', () {
    test('is a singleton', () {
      final s1 = PushNotificationService();
      final s2 = PushNotificationService();
      expect(identical(s1, s2), isTrue);
    });

    test('init completes successfully without external network dependencies', () async {
      final service = PushNotificationService();
      await expectLater(service.init(), completes);
    });

    test('requestPermission returns false on non-web/test platform gracefully', () async {
      final service = PushNotificationService();
      final granted = await service.requestPermission();
      expect(granted, isFalse);
    });

    test('hasPermission returns false in stub environment', () {
      final service = PushNotificationService();
      expect(service.hasPermission, isFalse);
    });

    test('showNotification runs without throwing when no scaffold key is set', () {
      final service = PushNotificationService();
      expect(() => service.showNotification('Study Reminder', body: 'Time to review!'), returnsNormally);
    });

    test('compatibility stubs execute cleanly', () async {
      final service = PushNotificationService();
      expect(await service.getToken(), isNull);
      await expectLater(service.subscribeToTopic('daily_reviews'), completes);
      await expectLater(service.unsubscribeFromTopic('daily_reviews'), completes);
    });
  });
}

