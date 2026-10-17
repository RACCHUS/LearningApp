import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/license_pathway_readiness.dart';
import '../services/pathway_readiness_service.dart';

final pathwayReadinessServiceProvider = Provider<PathwayReadinessService>((ref) {
  return PathwayReadinessService();
});

typedef PathwayReadinessKey = ({String pathwayKey, String? targetId});

class PathwayReadinessNotifier
    extends StateNotifier<AsyncValue<PathwayReadinessState>> {
  final PathwayReadinessService _service;
  final PathwayReadinessKey _key;

  PathwayReadinessNotifier(this._service, this._key)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final stateData = await _service.loadReadiness(
        _key.pathwayKey,
        targetId: _key.targetId,
      );
      state = AsyncValue.data(stateData);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> selectRoute(int routeIndex, String routeLabel) async {
    try {
      final updated = await _service.selectRoute(
        _key.pathwayKey,
        routeIndex,
        routeLabel,
        targetId: _key.targetId,
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleStep(String stepLabel) async {
    try {
      final updated = await _service.toggleStep(
        _key.pathwayKey,
        stepLabel,
        targetId: _key.targetId,
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reset() async {
    try {
      final updated = await _service.reset(
        _key.pathwayKey,
        targetId: _key.targetId,
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> linkToGoal(String targetId) async {
    try {
      final updated = await _service.linkToGoal(
        targetId: targetId,
        pathwayKey: _key.pathwayKey,
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final pathwayReadinessProvider = StateNotifierProvider.family<
    PathwayReadinessNotifier,
    AsyncValue<PathwayReadinessState>,
    PathwayReadinessKey>((ref, key) {
  final service = ref.watch(pathwayReadinessServiceProvider);
  return PathwayReadinessNotifier(service, key);
});
