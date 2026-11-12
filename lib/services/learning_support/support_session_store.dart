import 'dart:convert';

import 'package:learning_pwa/models/learning_support/return_anchor_stack.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable, owner-scoped storage for the learning-help return stack
/// (master plan v2.6 §10.5, §13.5 "a persisted service, not Riverpod widget
/// state, owns the durable stack").
///
/// Local storage is best effort: browsers may evict it. Each owner has its
/// own key, and a stack saved by one account is never restored for another.
class SupportSessionStore {
  SupportSessionStore({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const keyPrefix = 'learning_support_anchor_stack_v1:';

  static String keyFor(String ownerScope) => '$keyPrefix$ownerScope';

  /// The saved stack for [ownerScope], or `null` when none is usable.
  /// Unreadable or foreign data is ignored, not deleted, so it can still be
  /// inspected; it is overwritten by the next successful save.
  Future<ReturnAnchorStack?> load(String ownerScope) async {
    try {
      final raw = (await _prefs()).getString(keyFor(ownerScope));
      if (raw == null) return null;
      final result = ReturnAnchorStack.decode(
        jsonDecode(raw),
        expectedOwnerScope: ownerScope,
      );
      return result.stack;
    } catch (_) {
      return null;
    }
  }

  /// Saves [stack] and reads it back. Returns `false` when storage failed
  /// or the read-back differs; the caller must not claim it was saved.
  Future<bool> save(ReturnAnchorStack stack) async {
    try {
      final prefs = await _prefs();
      final key = keyFor(stack.ownerScope);
      if (stack.isEmpty) return await prefs.remove(key);
      final encoded = jsonEncode(stack.toJson());
      if (!await prefs.setString(key, encoded)) return false;
      return prefs.getString(key) == encoded;
    } catch (_) {
      return false;
    }
  }

  Future<void> clear(String ownerScope) async {
    try {
      await (await _prefs()).remove(keyFor(ownerScope));
    } catch (_) {}
  }
}
