import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/avatar/device_local_avatar.dart';

void main() {
  group('DeviceLocalAvatar Model Tests', () {
    test('default avatar has sensible default values', () {
      final avatar = DeviceLocalAvatar.defaultAvatar();
      expect(avatar.style, equals(AvatarStyle.minimal));
      expect(avatar.expression, equals(AvatarExpression.happy));
      expect(avatar.accessory, equals(AvatarAccessory.none));
      expect(avatar.theme, equals(AvatarColorTheme.blue));
    });

    test('toJson and fromJson preserves all properties', () {
      final avatar = DeviceLocalAvatar(
        style: AvatarStyle.illustrated,
        expression: AvatarExpression.focused,
        accessory: AvatarAccessory.hardHat,
        theme: AvatarColorTheme.amber,
        customNickname: 'Sam Builder',
        updatedAt: DateTime(2026, 11, 7),
      );

      final json = avatar.toJson();
      final restored = DeviceLocalAvatar.fromJson(json);

      expect(restored.customNickname, equals('Sam Builder'));
      expect(restored.style, equals(AvatarStyle.illustrated));
      expect(restored.expression, equals(AvatarExpression.focused));
      expect(restored.accessory, equals(AvatarAccessory.hardHat));
      expect(restored.theme, equals(AvatarColorTheme.amber));
    });

    test('copyWith updates specified fields', () {
      final avatar = DeviceLocalAvatar.defaultAvatar();
      final updated = avatar.copyWith(
        customNickname: 'Maria Nurse',
        accessory: AvatarAccessory.safetyGoggles,
      );

      expect(updated.customNickname, equals('Maria Nurse'));
      expect(updated.accessory, equals(AvatarAccessory.safetyGoggles));
      expect(updated.style, equals(avatar.style));
      expect(updated.theme, equals(avatar.theme));
    });
  });
}
