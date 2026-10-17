import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/license_pathway_readiness.dart';

/// Client-side persistence service for self-reported pathway preparation readiness.
///
/// Preserves readiness progress across sessions without altering database schemas.
/// Clearly delineates self-reported planning from official regulator determinations.
class PathwayReadinessService {
  final SharedPreferences? _prefs;

  PathwayReadinessService({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  String _storageKey(String pathwayKey, {String? targetId}) {
    if (targetId != null && targetId.trim().isNotEmpty) {
      return 'pathway_readiness_target_${targetId.trim()}';
    }
    return 'pathway_readiness_pathway_${pathwayKey.trim()}';
  }

  /// Loads the saved readiness state for a pathway or linked goal.
  Future<PathwayReadinessState> loadReadiness(
    String pathwayKey, {
    String? targetId,
  }) async {
    final prefs = await _getPrefs();
    final key = _storageKey(pathwayKey, targetId: targetId);
    final raw = prefs.getString(key);

    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
        return PathwayReadinessState.fromJson(decoded);
      } catch (_) {}
    }

    // Fallback: If querying for a targetId that has no record yet, check base pathway state
    if (targetId != null && targetId.isNotEmpty) {
      final baseKey = _storageKey(pathwayKey);
      final baseRaw = prefs.getString(baseKey);
      if (baseRaw != null && baseRaw.isNotEmpty) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(baseRaw) as Map<String, dynamic>;
          final state = PathwayReadinessState.fromJson(decoded);
          final linked = state.copyWith(targetId: targetId);
          await saveReadiness(linked);
          return linked;
        } catch (_) {}
      }
    }

    return PathwayReadinessState.empty(pathwayKey, targetId: targetId);
  }

  /// Persists readiness state to SharedPreferences.
  Future<void> saveReadiness(PathwayReadinessState state) async {
    final prefs = await _getPrefs();
    final jsonStr = jsonEncode(state.toJson());

    // Save under primary target key if present
    if (state.targetId != null && state.targetId!.isNotEmpty) {
      await prefs.setString(_storageKey(state.pathwayKey, targetId: state.targetId), jsonStr);
    }
    // Always keep base pathway key synchronized
    await prefs.setString(_storageKey(state.pathwayKey), jsonStr);
  }

  /// Selects or changes the learner's chosen qualification route.
  Future<PathwayReadinessState> selectRoute(
    String pathwayKey,
    int routeIndex,
    String routeLabel, {
    String? targetId,
  }) async {
    final current = await loadReadiness(pathwayKey, targetId: targetId);
    final updated = current.copyWith(
      selectedRouteIndex: routeIndex,
      selectedRouteLabel: routeLabel,
      lastUpdated: DateTime.now(),
    );
    await saveReadiness(updated);
    return updated;
  }

  /// Toggles completion status for an individual milestone step.
  Future<PathwayReadinessState> toggleStep(
    String pathwayKey,
    String stepLabel, {
    String? targetId,
  }) async {
    final current = await loadReadiness(pathwayKey, targetId: targetId);
    final newCompleted = Set<String>.from(current.completedStepLabels);

    if (newCompleted.contains(stepLabel)) {
      newCompleted.remove(stepLabel);
    } else {
      newCompleted.add(stepLabel);
    }

    final updated = current.copyWith(
      completedStepLabels: newCompleted,
      lastUpdated: DateTime.now(),
    );
    await saveReadiness(updated);
    return updated;
  }

  /// Resets route and step completion for the pathway.
  Future<PathwayReadinessState> reset(
    String pathwayKey, {
    String? targetId,
  }) async {
    final empty = PathwayReadinessState.empty(pathwayKey, targetId: targetId);
    await saveReadiness(empty);
    return empty;
  }

  /// Connects an existing standalone pathway checklist to a newly created private target.
  Future<PathwayReadinessState> linkToGoal({
    required String targetId,
    required String pathwayKey,
  }) async {
    final current = await loadReadiness(pathwayKey);
    final linked = current.copyWith(targetId: targetId);
    await saveReadiness(linked);
    return linked;
  }
}
