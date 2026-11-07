import 'package:flutter/material.dart';
import '../../models/avatar/device_local_avatar.dart';

/// Visual rendering widget for a device-local avatar with expression and accessory overlays (P8-1).
class DeviceLocalAvatarWidget extends StatelessWidget {
  final DeviceLocalAvatar avatar;
  final double radius;
  final VoidCallback? onTap;

  const DeviceLocalAvatarWidget({
    super.key,
    required this.avatar,
    this.radius = 24.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeColor = avatar.theme.primaryColor;
    final bgColor = avatar.theme.backgroundColor;

    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        // Base Avatar Circle
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(
              color: themeColor.withOpacity(0.6),
              width: radius >= 36 ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              avatar.expression.emoji,
              style: TextStyle(fontSize: radius * 0.95),
            ),
          ),
        ),

        // Accessory Overlay Badge
        if (avatar.accessory != AvatarAccessory.none && avatar.accessory.icon != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: EdgeInsets.all(radius * 0.12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface,
                border: Border.all(
                  color: themeColor,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                avatar.accessory.icon,
                size: radius * 0.45,
                color: themeColor,
              ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }

    return content;
  }
}

