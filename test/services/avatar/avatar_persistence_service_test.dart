import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/avatar/device_local_avatar.dart';
import 'package:learning_pwa/services/avatar/avatar_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvatarPersistenceService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('avatar defaults to baseline profile', () {
      final service = AvatarPersistenceService();
      expect(service.avatar.style, equals(AvatarStyle.minimal));
      expect(service.avatar.expression, equals(AvatarExpression.happy));
    });

    test('saveAvatar saves and updates avatar in service', () async {
      final service = AvatarPersistenceService();
      final custom = DeviceLocalAvatar(
        style: AvatarStyle.bot,
        expression: AvatarExpression.cool,
        accessory: AvatarAccessory.hardHat,
        theme: AvatarColorTheme.amber,
        customNickname: 'Safety Bot',
        updatedAt: DateTime.now(),
      );

      await service.saveAvatar(custom);

      expect(service.avatar.customNickname, equals('Safety Bot'));
      expect(service.avatar.style, equals(AvatarStyle.bot));
      expect(service.avatar.accessory, equals(AvatarAccessory.hardHat));
    });

    test('resetToDefault restores default avatar', () async {
      final service = AvatarPersistenceService();
      final custom = DeviceLocalAvatar(
        customNickname: 'Test',
        accessory: AvatarAccessory.headphones,
        updatedAt: DateTime.now(),
      );

      await service.saveAvatar(custom);
      expect(service.avatar.customNickname, equals('Test'));

      await service.resetToDefault();
      expect(service.avatar.customNickname, isNull);
      expect(service.avatar.accessory, equals(AvatarAccessory.none));
    });
    test('per-account avatars survive reload without leaking to another user',
        () async {
      final alice = AvatarPersistenceService(userId: 'alice');
      await alice.saveAvatar(DeviceLocalAvatar(
        expression: AvatarExpression.cool,
        customNickname: 'Alice local',
        updatedAt: DateTime.now(),
      ));

      final aliceAgain = AvatarPersistenceService(userId: 'alice');
      await aliceAgain.load();
      expect(aliceAgain.avatar.expression, AvatarExpression.cool);
      expect(aliceAgain.avatar.customNickname, 'Alice local');

      final bob = AvatarPersistenceService(userId: 'bob');
      await bob.load();
      expect(bob.avatar.expression, AvatarExpression.happy);
      expect(bob.avatar.customNickname, isNull);

      alice.dispose();
      aliceAgain.dispose();
      bob.dispose();
    });

  });
}
