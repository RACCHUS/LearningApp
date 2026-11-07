import 'package:flutter/material.dart';

enum AvatarStyle {
  minimal,
  illustrated,
  bot,
  academic;

  String get label {
    switch (this) {
      case AvatarStyle.minimal:
        return 'Minimal';
      case AvatarStyle.illustrated:
        return 'Expressive';
      case AvatarStyle.bot:
        return 'Tech Bot';
      case AvatarStyle.academic:
        return 'Scholar';
    }
  }
}

enum AvatarExpression {
  happy,
  focused,
  cool,
  curious,
  thoughtful,
  celebrating;

  String get emoji {
    switch (this) {
      case AvatarExpression.happy:
        return '😊';
      case AvatarExpression.focused:
        return '🧐';
      case AvatarExpression.cool:
        return '😎';
      case AvatarExpression.curious:
        return '🤔';
      case AvatarExpression.thoughtful:
        return '💡';
      case AvatarExpression.celebrating:
        return '🥳';
    }
  }

  String get label {
    switch (this) {
      case AvatarExpression.happy:
        return 'Happy';
      case AvatarExpression.focused:
        return 'Focused';
      case AvatarExpression.cool:
        return 'Confident';
      case AvatarExpression.curious:
        return 'Curious';
      case AvatarExpression.thoughtful:
        return 'Thoughtful';
      case AvatarExpression.celebrating:
        return 'Celebrating';
    }
  }
}

enum AvatarAccessory {
  none,
  glasses,
  sunglasses,
  headphones,
  safetyGoggles,
  hardHat;

  String get label {
    switch (this) {
      case AvatarAccessory.none:
        return 'None';
      case AvatarAccessory.glasses:
        return 'Reading Glasses';
      case AvatarAccessory.sunglasses:
        return 'Sunglasses';
      case AvatarAccessory.headphones:
        return 'Headphones';
      case AvatarAccessory.safetyGoggles:
        return 'Safety Goggles';
      case AvatarAccessory.hardHat:
        return 'Safety Hard Hat';
    }
  }

  IconData? get icon {
    switch (this) {
      case AvatarAccessory.none:
        return null;
      case AvatarAccessory.glasses:
        return Icons.visibility;
      case AvatarAccessory.sunglasses:
        return Icons.wb_sunny;
      case AvatarAccessory.headphones:
        return Icons.headphones;
      case AvatarAccessory.safetyGoggles:
        return Icons.security;
      case AvatarAccessory.hardHat:
        return Icons.construction;
    }
  }
}

enum AvatarColorTheme {
  blue,
  emerald,
  amber,
  purple,
  coral,
  teal;

  Color get primaryColor {
    switch (this) {
      case AvatarColorTheme.blue:
        return Colors.blue.shade600;
      case AvatarColorTheme.emerald:
        return Colors.green.shade600;
      case AvatarColorTheme.amber:
        return Colors.amber.shade700;
      case AvatarColorTheme.purple:
        return Colors.purple.shade600;
      case AvatarColorTheme.coral:
        return Colors.deepOrange.shade400;
      case AvatarColorTheme.teal:
        return Colors.teal.shade600;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case AvatarColorTheme.blue:
        return Colors.blue.shade50;
      case AvatarColorTheme.emerald:
        return Colors.green.shade50;
      case AvatarColorTheme.amber:
        return Colors.amber.shade50;
      case AvatarColorTheme.purple:
        return Colors.purple.shade50;
      case AvatarColorTheme.coral:
        return Colors.deepOrange.shade50;
      case AvatarColorTheme.teal:
        return Colors.teal.shade50;
    }
  }

  String get label {
    switch (this) {
      case AvatarColorTheme.blue:
        return 'Ocean Blue';
      case AvatarColorTheme.emerald:
        return 'Forest Green';
      case AvatarColorTheme.amber:
        return 'Warm Amber';
      case AvatarColorTheme.purple:
        return 'Royal Purple';
      case AvatarColorTheme.coral:
        return 'Vibrant Coral';
      case AvatarColorTheme.teal:
        return 'Teal Cyan';
    }
  }
}

/// Device-local customizable avatar configuration (Priority 8, P8-1).
///
/// Stores learner styling offline without external image uploads or privacy risk.
class DeviceLocalAvatar {
  final AvatarStyle style;
  final AvatarExpression expression;
  final AvatarAccessory accessory;
  final AvatarColorTheme theme;
  final String? customNickname;
  final DateTime updatedAt;

  const DeviceLocalAvatar({
    this.style = AvatarStyle.minimal,
    this.expression = AvatarExpression.happy,
    this.accessory = AvatarAccessory.none,
    this.theme = AvatarColorTheme.blue,
    this.customNickname,
    required this.updatedAt,
  });

  factory DeviceLocalAvatar.defaultAvatar() {
    return DeviceLocalAvatar(
      style: AvatarStyle.minimal,
      expression: AvatarExpression.happy,
      accessory: AvatarAccessory.none,
      theme: AvatarColorTheme.blue,
      updatedAt: DateTime.now(),
    );
  }

  factory DeviceLocalAvatar.fromJson(Map<String, dynamic> json) {
    return DeviceLocalAvatar(
      style: AvatarStyle.values.firstWhere(
        (e) => e.name == json['style'],
        orElse: () => AvatarStyle.minimal,
      ),
      expression: AvatarExpression.values.firstWhere(
        (e) => e.name == json['expression'],
        orElse: () => AvatarExpression.happy,
      ),
      accessory: AvatarAccessory.values.firstWhere(
        (e) => e.name == json['accessory'],
        orElse: () => AvatarAccessory.none,
      ),
      theme: AvatarColorTheme.values.firstWhere(
        (e) => e.name == json['theme'],
        orElse: () => AvatarColorTheme.blue,
      ),
      customNickname: json['custom_nickname'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'style': style.name,
        'expression': expression.name,
        'accessory': accessory.name,
        'theme': theme.name,
        if (customNickname != null) 'custom_nickname': customNickname,
        'updated_at': updatedAt.toIso8601String(),
      };

  DeviceLocalAvatar copyWith({
    AvatarStyle? style,
    AvatarExpression? expression,
    AvatarAccessory? accessory,
    AvatarColorTheme? theme,
    String? customNickname,
    DateTime? updatedAt,
  }) {
    return DeviceLocalAvatar(
      style: style ?? this.style,
      expression: expression ?? this.expression,
      accessory: accessory ?? this.accessory,
      theme: theme ?? this.theme,
      customNickname: customNickname ?? this.customNickname,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

