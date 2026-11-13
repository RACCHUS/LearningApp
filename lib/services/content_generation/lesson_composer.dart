import 'package:learning_pwa/models/content_generation/slot_plan.dart';

/// What kind of learning the lesson is for (master plan v2.6 §5.9). Picks
/// the Composer template.
enum LessonObjectiveType {
  /// Teach → key term → quick retrieval check, per idea; then a mixed
  /// review that interleaves the remaining questions across ideas.
  understand('understand', 'Understand ideas'),

  /// Goal and demonstration → guided practice right away, per idea; key
  /// terms gathered at the end as a reference.
  procedure('procedure', 'Learn how to do something'),

  /// All key terms first → mixed retrieval questions → explanations last
  /// as background.
  memorize('memorize', 'Remember terms and facts');

  const LessonObjectiveType(this.wire, this.label);
  final String wire;
  final String label;
}

/// Deterministic Lesson Composer (master plan v2.6 §5.9). It never calls AI
/// and never changes content: it only decides the order of slots that were
/// already validated, by template. Given the same plan, accepted slots and
/// type, the result is always the same.
class LessonComposer {
  const LessonComposer._();

  /// Accepted slot codes in teaching order for [type]. Slots that were not
  /// accepted are skipped; every accepted slot appears exactly once.
  static List<String> compose(
    SlotPlan plan,
    Set<String> accepted,
    LessonObjectiveType type,
  ) {
    // Group accepted slots per concept, keeping plan order inside groups.
    final concepts = <String>[];
    final byConcept = <String, Map<SlotKind, List<String>>>{};
    for (final s in plan.slots) {
      if (!accepted.contains(s.code)) continue;
      if (!byConcept.containsKey(s.conceptCode)) concepts.add(s.conceptCode);
      byConcept
          .putIfAbsent(s.conceptCode, () => {})
          .putIfAbsent(s.kind, () => [])
          .add(s.code);
    }
    List<String> of(String c, SlotKind k) => byConcept[c]?[k] ?? const [];

    /// Round-robin across concepts: spacing and interleaving for review.
    List<String> interleave(List<List<String>> lists) {
      final out = <String>[];
      final longest = lists.fold<int>(0, (m, l) => l.length > m ? l.length : m);
      for (var i = 0; i < longest; i++) {
        for (final l in lists) {
          if (i < l.length) out.add(l[i]);
        }
      }
      return out;
    }

    final order = <String>[];
    switch (type) {
      case LessonObjectiveType.understand:
        final rest = <List<String>>[];
        for (final c in concepts) {
          final qs = of(c, SlotKind.mcq);
          order
            ..addAll(of(c, SlotKind.explanation))
            ..addAll(of(c, SlotKind.term))
            ..addAll(qs.take(1));
          rest.add(qs.skip(1).toList());
        }
        order.addAll(interleave(rest));
      case LessonObjectiveType.procedure:
        for (final c in concepts) {
          order
            ..addAll(of(c, SlotKind.explanation))
            ..addAll(of(c, SlotKind.mcq));
        }
        for (final c in concepts) {
          order.addAll(of(c, SlotKind.term));
        }
      case LessonObjectiveType.memorize:
        for (final c in concepts) {
          order.addAll(of(c, SlotKind.term));
        }
        order.addAll(
          interleave([for (final c in concepts) of(c, SlotKind.mcq)]),
        );
        for (final c in concepts) {
          order.addAll(of(c, SlotKind.explanation));
        }
    }
    return order;
  }

  /// Display positions (10, 20, 30, …) for [composed], leaving gaps so a
  /// learner can later insert items without renumbering everything.
  static Map<String, int> positions(List<String> composed) => {
    for (final (i, code) in composed.indexed) code: (i + 1) * 10,
  };
}
