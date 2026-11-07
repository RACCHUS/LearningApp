import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/avatar/device_local_avatar.dart';

/// Offline-first persistence service for the learner's device-local avatar (P8-1).
class AvatarPersistenceService extends ChangeNotifier {
  static const String _storageKey = 'device_local_avatar_v1';

  final SharedPreferences? _prefs;
  DeviceLocalAvatar _avatar = DeviceLocalAvatar.defaultAvatar();

  AvatarPersistenceService({SharedPreferences? prefs}) : _prefs = prefs {
    _loadFromStorage();
  }

  DeviceLocalAvatar get avatar => _avatar;

  void _loadFromStorage() {
    final jsonStr = _prefs?.getString(_storageKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        _avatar = DeviceLocalAvatar.fromJson(decoded);
      } catch (e) {
        debugPrint('Error parsing device-local avatar: $e');
        _avatar = DeviceLocalAvatar.defaultAvatar();
      }
    }
  }

  /// Saves updated avatar configuration to device storage.
  Future<void> saveAvatar(DeviceLocalAvatar newAvatar) async {
    _avatar = newAvatar.copyWith(updatedAt: DateTime.now());
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_avatar.toJson()));
    notifyListeners();
  }

  /// Resets the avatar to the platform baseline.
  Future<void> resetToDefault() async {
    await saveAvatar(DeviceLocalAvatar.defaultAvatar());
  }
}

