import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';

/// One chat's worth of the cart: up to [ManualJobRequest.maxConcepts]
/// topics, sent in [messages] messages at the chosen size.
class PromptCartBatch {
  const PromptCartBatch({required this.needs, required this.slots, required this.messages});

  final List<CoverageNeed> needs;
  final int slots;
  final int messages;

  /// One idea per topic, as the generator takes them.
  List<String> get ideas => [for (final n in needs) n.row.title];
}

class PromptCartPlan {
  const PromptCartPlan(this.batches);

  final List<PromptCartBatch> batches;

  int get messages => batches.fold(0, (sum, b) => sum + b.messages);
  int get chats => batches.length;
  bool get isEmpty => batches.isEmpty;
}

/// The prompt cart (master plan v2.6 §5.5 M-06): several missing pieces
/// bundled into the fewest chats, highest reuse value first (§6.5), with an
/// honest "about N messages" estimate that respects the size the learner
/// picked for their AI (§5.3). It plans only; nothing is sent anywhere.
class PromptCart {
  const PromptCart._();

  /// Slots one topic needs: an explanation, an optional key term and the
  /// questions (the same plan [ManualJob.plan] makes).
  static int slotsPerTopic({required int questionsPerConcept, required bool includeTerms}) =>
      1 + (includeTerms ? 1 : 0) + questionsPerConcept;

  /// Highest priority first; ties keep outline order.
  static List<CoverageNeed> ordered(List<CoverageNeed> needs) {
    final indexed = [for (final (i, n) in needs.indexed) (i, n)];
    indexed.sort((a, b) {
      final byPriority = b.$2.row.priority.compareTo(a.$2.row.priority);
      return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
    });
    return [for (final (_, n) in indexed) n];
  }

  static PromptCartPlan plan(
    List<CoverageNeed> needs, {
    required ModelSizeTier tier,
    int questionsPerConcept = 2,
    bool includeTerms = true,
  }) {
    final perTopic = slotsPerTopic(
      questionsPerConcept: questionsPerConcept,
      includeTerms: includeTerms,
    );
    final sorted = ordered(needs);
    final batches = <PromptCartBatch>[];
    for (var i = 0; i < sorted.length; i += ManualJobRequest.maxConcepts) {
      final chunk = sorted.sublist(
        i,
        (i + ManualJobRequest.maxConcepts).clamp(0, sorted.length),
      );
      final slots = chunk.length * perTopic;
      batches.add(PromptCartBatch(
        needs: List.unmodifiable(chunk),
        slots: slots,
        messages: (slots / tier.slotsPerMessage).ceil(),
      ));
    }
    return PromptCartPlan(List.unmodifiable(batches));
  }
}
