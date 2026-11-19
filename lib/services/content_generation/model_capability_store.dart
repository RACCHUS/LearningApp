import 'dart:convert';

import 'package:learning_pwa/services/content_generation/model_capability_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the store holds for one owner.
class CapabilityProfiles {
  const CapabilityProfiles({this.selected, this.profiles = const {}});

  /// The AI chat the learner last said they use.
  final AiChatLabel? selected;
  final Map<AiChatLabel, ModelCapabilityProfile> profiles;

  ModelCapabilityProfile profileFor(AiChatLabel label) =>
      profiles[label] ?? ModelCapabilityProfile(label: label);
}

/// Device-local capability profiles (master plan v2.6 §5.3): per device,
/// per owner, exportable and deletable, and never sent to a server.
/// Storage is best effort; failures only mean the app starts small again.
class ModelCapabilityStore {
  ModelCapabilityStore({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const keyPrefix = 'manual_generation_v2_capability_v1:';
  static String keyFor(String owner) => '$keyPrefix$owner';

  Future<CapabilityProfiles> load(String owner) async {
    try {
      final raw = (await _prefs()).getString(keyFor(owner));
      if (raw == null) return const CapabilityProfiles();
      return decode(jsonDecode(raw), owner);
    } catch (_) {
      return const CapabilityProfiles();
    }
  }

  /// Decodes a saved or exported value. Profiles that fail validation are
  /// dropped one by one; a save for another owner is ignored.
  static CapabilityProfiles decode(Object? json, String owner) {
    if (json is! Map || json['owner'] != owner) {
      return const CapabilityProfiles();
    }
    final profiles = <AiChatLabel, ModelCapabilityProfile>{};
    final list = json['profiles'];
    if (list is List) {
      for (final p in list) {
        final profile = ModelCapabilityProfile.fromJson(p);
        if (profile != null) profiles[profile.label] = profile;
      }
    }
    return CapabilityProfiles(
      selected: AiChatLabel.fromWire(json['selected']),
      profiles: profiles,
    );
  }

  static String encode(String owner, CapabilityProfiles value) => jsonEncode({
    'owner': owner,
    'selected': value.selected?.wire,
    'profiles': [for (final p in value.profiles.values) p.toJson()],
  });

  Future<bool> save(String owner, CapabilityProfiles value) async {
    try {
      return await (await _prefs()).setString(
        keyFor(owner),
        encode(owner, value),
      );
    } catch (_) {
      return false;
    }
  }

  /// Removes everything this device learned for [owner].
  Future<void> clear(String owner) async {
    try {
      await (await _prefs()).remove(keyFor(owner));
    } catch (_) {}
  }
}
