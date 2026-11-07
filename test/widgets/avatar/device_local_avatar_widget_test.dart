import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/avatar/device_local_avatar.dart';
import 'package:learning_pwa/widgets/avatar/device_local_avatar_widget.dart';

void main() {
  group('DeviceLocalAvatarWidget Tests', () {
    testWidgets('renders avatar with expression emoji and accessory icon', (tester) async {
      final avatar = DeviceLocalAvatar(
        style: AvatarStyle.illustrated,
        expression: AvatarExpression.happy,
        accessory: AvatarAccessory.hardHat,
        theme: AvatarColorTheme.amber,
        customNickname: 'Supervisor Dan',
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceLocalAvatarWidget(
              avatar: avatar,
              radius: 32.0,
            ),
          ),
        ),
      );

      expect(find.text(avatar.expression.emoji), findsOneWidget);
      expect(find.byIcon(Icons.construction), findsOneWidget);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      bool tapped = false;
      final avatar = DeviceLocalAvatar.defaultAvatar();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceLocalAvatarWidget(
              avatar: avatar,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DeviceLocalAvatarWidget));
      expect(tapped, isTrue);
    });
  });
}
