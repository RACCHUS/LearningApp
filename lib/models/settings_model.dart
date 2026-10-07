import 'dart:convert';

class SettingsModel {
  List<String> notificationTimes; // e.g. ["10:00", "18:00"]
  bool notificationsEnabled;
  bool darkMode;
  int studyBatchSize; // Max cards per study session (0 = unlimited)
  bool recallBeforeReveal; // Require thinking/recall before revealing flashcard answers

  SettingsModel({
    required this.notificationTimes,
    required this.notificationsEnabled,
    required this.darkMode,
    this.studyBatchSize = 15,
    this.recallBeforeReveal = true,
  });

  factory SettingsModel.defaultSettings() => SettingsModel(
        notificationTimes: ["10:00", "18:00"],
        notificationsEnabled: true,
        darkMode: true,
        studyBatchSize: 15,
        recallBeforeReveal: true,
      );

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
        notificationTimes: List<String>.from(json['notificationTimes'] ?? []),
        notificationsEnabled: json['notificationsEnabled'] ?? true,
        darkMode: json['darkMode'] ?? true,
        studyBatchSize: json['studyBatchSize'] ?? 15,
        recallBeforeReveal: json['recallBeforeReveal'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'notificationTimes': notificationTimes,
        'notificationsEnabled': notificationsEnabled,
        'darkMode': darkMode,
        'studyBatchSize': studyBatchSize,
        'recallBeforeReveal': recallBeforeReveal,
      };

  String toRawJson() => json.encode(toJson());
  factory SettingsModel.fromRawJson(String str) =>
      SettingsModel.fromJson(json.decode(str));
}
