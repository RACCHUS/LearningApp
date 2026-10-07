import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/settings_model.dart';

void main() {
  group('SettingsModel Tests', () {
    test('default settings initializes with expected study focus defaults', () {
      final settings = SettingsModel.defaultSettings();
      expect(settings.studyBatchSize, 15);
      expect(settings.recallBeforeReveal, isTrue);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.darkMode, isTrue);
      expect(settings.notificationTimes, containsAll(['10:00', '18:00']));
    });

    test('serializes and deserializes correctly with custom study focus options', () {
      final original = SettingsModel(
        notificationTimes: ['08:30'],
        notificationsEnabled: false,
        darkMode: false,
        studyBatchSize: 25,
        recallBeforeReveal: false,
      );

      final json = original.toJson();
      expect(json['studyBatchSize'], 25);
      expect(json['recallBeforeReveal'], isFalse);

      final reconstructed = SettingsModel.fromJson(json);
      expect(reconstructed.studyBatchSize, 25);
      expect(reconstructed.recallBeforeReveal, isFalse);
      expect(reconstructed.notificationsEnabled, isFalse);
      expect(reconstructed.darkMode, isFalse);
      expect(reconstructed.notificationTimes, equals(['08:30']));
    });

    test('fromRawJson handles legacy JSON without recallBeforeReveal gracefully', () {
      const legacyJson = '{"notificationTimes":["09:00"],"notificationsEnabled":true,"darkMode":true,"studyBatchSize":10}';
      final settings = SettingsModel.fromRawJson(legacyJson);
      expect(settings.studyBatchSize, 10);
      expect(settings.recallBeforeReveal, isTrue); // Defaults to true
    });
  });
}
