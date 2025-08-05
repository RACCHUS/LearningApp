import 'dart:convert';

class SettingsModel {
  List<String> notificationTimes; // e.g. ["10:00", "18:00"]
  bool notificationsEnabled;
  bool darkMode;

  SettingsModel({
    required this.notificationTimes,
    required this.notificationsEnabled,
    required this.darkMode,
  });

  factory SettingsModel.defaultSettings() => SettingsModel(
        notificationTimes: ["10:00", "18:00"],
        notificationsEnabled: true,
        darkMode: true,
      );

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
        notificationTimes: List<String>.from(json['notificationTimes'] ?? []),
        notificationsEnabled: json['notificationsEnabled'] ?? true,
        darkMode: json['darkMode'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'notificationTimes': notificationTimes,
        'notificationsEnabled': notificationsEnabled,
        'darkMode': darkMode,
      };

  String toRawJson() => json.encode(toJson());
  factory SettingsModel.fromRawJson(String str) =>
      SettingsModel.fromJson(json.decode(str));
}
