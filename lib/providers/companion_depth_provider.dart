import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much of an outside resource's companion the learner wants (master
/// plan v2.6 §9.2, levels 0–2; the Bridge itself is the level-3 companion
/// micro-lesson, and a companion plan is level 4). Device-local,
/// learner-controlled, never sent anywhere.
enum CompanionDepth {
  /// Level 0: the link only.
  link('Just the link'),

  /// Level 1: the link plus "what to look for" in our own words.
  pointer('Link + what to look for'),

  /// Level 2: the above plus short independent checks afterwards.
  checkpoint('Link + checks');

  const CompanionDepth(this.label);
  final String label;

  bool get showsFocusNote => index >= CompanionDepth.pointer.index;
  bool get showsChecks => index >= CompanionDepth.checkpoint.index;
}

class CompanionDepthNotifier extends StateNotifier<CompanionDepth> {
  CompanionDepthNotifier() : super(CompanionDepth.checkpoint) {
    _load();
  }

  static const _key = 'companion_depth_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      for (final d in CompanionDepth.values) {
        if (d.name == saved && mounted) state = d;
      }
    } catch (_) {}
  }

  Future<void> set(CompanionDepth depth) async {
    state = depth;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, depth.name);
    } catch (_) {}
  }
}

final companionDepthProvider =
    StateNotifierProvider<CompanionDepthNotifier, CompanionDepth>(
      (ref) => CompanionDepthNotifier(),
    );
