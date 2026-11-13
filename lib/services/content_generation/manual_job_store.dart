import 'dart:convert';
import 'dart:math';

import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ManualSaveOutcome {
  saved,

  /// Another tab or window saved this owner's job since we last read it.
  /// This tab stops saving (no last-writer-wins) and offers export.
  conflict,

  /// Storage failed or the read-back did not match.
  failed,
}

class SavedManualJob {
  const SavedManualJob(this.session, this.revision);

  final ManualJobSession session;
  final int revision;
}

/// Device-local saved progress for the slot-based generator, one job per
/// owner (master plan v2.6 §8, Appendix D.5).
///
/// Local storage is best effort and browsers do not give cross-tab
/// compare-and-swap, so this is a guarded check, not a lock: before each
/// write it re-reads the stored revision and editor; if another editor
/// wrote in between, it refuses and reports [ManualSaveOutcome.conflict].
/// Every write is read back before it counts as saved.
class ManualJobStore {
  ManualJobStore({
    Future<SharedPreferences> Function()? prefs,
    String? editorId,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       editorId = editorId ?? _newEditorId();

  final Future<SharedPreferences> Function() _prefs;

  /// Identifies this tab/instance.
  final String editorId;

  static const keyPrefix = 'manual_generation_v2_job_v1:';
  static String keyFor(String owner) => '$keyPrefix$owner';

  static String _newEditorId() {
    final r = Random.secure();
    return List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  int? _knownRevision;

  Map<String, Object?>? _readRaw(SharedPreferences prefs, String owner) {
    final raw = prefs.getString(keyFor(owner));
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      return j is Map<String, Object?> && j['owner'] == owner ? j : null;
    } catch (_) {
      return null;
    }
  }

  /// The saved job for [owner], re-validated. A save made under another
  /// owner key, or one that no longer parses, is ignored.
  Future<SavedManualJob?> load(String owner) async {
    try {
      final j = _readRaw(await _prefs(), owner);
      if (j == null) return null;
      final session = ManualJobSession.fromJson(j['session']);
      final rev = j['revision'];
      if (session == null || rev is! int) return null;
      _knownRevision = rev;
      return SavedManualJob(session, rev);
    } catch (_) {
      return null;
    }
  }

  Future<ManualSaveOutcome> save(String owner, ManualJobSession session) async {
    try {
      final prefs = await _prefs();
      final current = _readRaw(prefs, owner);
      final currentRev = current?['revision'] as int? ?? 0;
      final currentEditor = current?['editor'];
      if (current != null &&
          currentEditor != editorId &&
          currentRev != (_knownRevision ?? -1)) {
        return ManualSaveOutcome.conflict;
      }
      final next = currentRev + 1;
      final encoded = jsonEncode({
        'owner': owner,
        'editor': editorId,
        'revision': next,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'session': session.toJson(),
      });
      if (!await prefs.setString(keyFor(owner), encoded)) {
        return ManualSaveOutcome.failed;
      }
      if (prefs.getString(keyFor(owner)) != encoded) {
        return ManualSaveOutcome.failed;
      }
      _knownRevision = next;
      return ManualSaveOutcome.saved;
    } catch (_) {
      return ManualSaveOutcome.failed;
    }
  }

  Future<void> clear(String owner) async {
    try {
      await (await _prefs()).remove(keyFor(owner));
      _knownRevision = null;
    } catch (_) {}
  }
}
