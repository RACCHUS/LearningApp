import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/avatar/device_local_avatar.dart';

/// Offline-first avatar settings, isolated per signed-in user on this browser.
/// They are not synchronized to Supabase or uploaded as images.
class AvatarPersistenceService extends ChangeNotifier {
  static const String _legacyStorageKey = 'device_local_avatar_v1';

  final SharedPreferences? _prefs;
  final String _storageKey;
  DeviceLocalAvatar _avatar = DeviceLocalAvatar.defaultAvatar();
  bool _modified = false;
  bool _disposed = false;

  AvatarPersistenceService({SharedPreferences? prefs, String? userId})
      : _prefs = prefs,
        _storageKey = userId == null
            ? _legacyStorageKey
            : 'device_local_avatar_v2_$userId' {
    if (prefs != null) _loadFromStorage(prefs);
  }

  DeviceLocalAvatar get avatar => _avatar;

  /// Call after construction when SharedPreferences was not injected.
  /// A late load cannot overwrite changes made while it was pending.
  Future<void> load() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    if (_disposed || _modified) return;
    _loadFromStorage(prefs);
    if (!_disposed) notifyListeners();
  }

  void _loadFromStorage(SharedPreferences prefs) {
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) return;
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      _avatar = DeviceLocalAvatar.fromJson(decoded);
    } catch (e) {
      debugPrint('Error parsing device-local avatar: $e');
      _avatar = DeviceLocalAvatar.defaultAvatar();
    }
  }

  /// Only this signed-in user's local key is written.
  Future<void> saveAvatar(DeviceLocalAvatar newAvatar) async {
    final updated = newAvatar.copyWith(updatedAt: DateTime.now());
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(updated.toJson()));
    if (_disposed) return;
    _modified = true;
    _avatar = updated;
    notifyListeners();
  }

  Future<void> resetToDefault() =>
      saveAvatar(DeviceLocalAvatar.defaultAvatar());

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
