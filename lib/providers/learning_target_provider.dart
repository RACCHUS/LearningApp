import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/curriculum_node.dart';
import '../models/knowledge_concept.dart';
import '../models/learning_target.dart';
import '../services/learning_target_service.dart';

final learningTargetServiceProvider =
    Provider<LearningTargetService>((ref) => LearningTargetService());

final targetsListProvider = FutureProvider.family<List<LearningTarget>,
    ({TargetType? type, List<TargetType>? types, String? search})>(
  (ref, args) async {
    final service = ref.watch(learningTargetServiceProvider);
    return service.getTargets(
      type: args.type,
      types: args.types,
      search: args.search,
    );
  },
);

/// Eligible official and reviewed community records for goal-form suggestions.
final targetSuggestionsProvider =
    FutureProvider.family<List<LearningTarget>, TargetType>((ref, type) async {
  return ref.watch(learningTargetServiceProvider)
      .getSuggestionTargets(type: type);
});

final targetDetailProvider =
    FutureProvider.family<LearningTarget?, String>((ref, id) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.getTarget(id);
});

final targetVersionProvider =
    FutureProvider.family<TargetVersion?, String>((ref, targetId) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.getLatestVersion(targetId);
});

final targetCurriculumNodesProvider =
    FutureProvider.family<List<CurriculumNode>, String>((ref, versionId) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.getCurriculumNodes(versionId);
});

final conceptDetailProvider =
    FutureProvider.family<KnowledgeConcept?, String>((ref, conceptId) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.getConcept(conceptId);
});

final searchConceptsProvider =
    FutureProvider.family<List<KnowledgeConcept>, String>((ref, query) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.searchConcepts(query: query);
});

final nodeLessonsProvider =
    FutureProvider.family<List<CurriculumNodeLesson>, String>((ref, nodeId) async {
  final service = ref.watch(learningTargetServiceProvider);
  return service.getNodeLessons(nodeId);
});


