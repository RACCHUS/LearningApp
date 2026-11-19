import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/catalog_cluster.dart';
import '../models/canonical_field.dart';
import '../models/learning_target.dart';
import 'learning_target_provider.dart';

final catalogClustersProvider = FutureProvider<List<CatalogCluster>>((ref) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.getCatalogClusters();
});

final clusterFieldsProvider =
    FutureProvider.family<List<CanonicalField>, String>((ref, clusterId) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.getClusterFields(clusterId);
});

final clusterTargetsProvider =
    FutureProvider.family<List<LearningTarget>, String>((ref, clusterId) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.getTargetsForCluster(clusterId);
});

final allFieldsProvider = FutureProvider<List<CanonicalField>>((ref) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.getFields();
});
