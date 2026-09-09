import 'package:learning_pwa/models/learning_context.dart';

/// What the learner would actually do next.
///
/// The engine selects an activity; the UI renders whatever kind came back.
/// Nothing here is lesson-shaped, which is what lets a bare study set produce
/// a valid primary action (spec B2).
sealed class LearningActivity {
  const LearningActivity();

  String get title;
  Duration get estimate;
}

class LessonActivity extends LearningActivity {
  final String lessonId;
  @override
  final String title;
  @override
  final Duration estimate;

  /// Breadcrumb only — absent for a bare `lesson`-rooted context.
  final String? courseId;
  final String? courseTitle;
  final String? moduleTitle;
  final int? position;
  final int? total;

  const LessonActivity({
    required this.lessonId,
    required this.title,
    this.estimate = const Duration(minutes: 10),
    this.courseId,
    this.courseTitle,
    this.moduleTitle,
    this.position,
    this.total,
  });
}

class StudySetActivity extends LearningActivity {
  final String studySetId;
  @override
  final String title;
  @override
  final Duration estimate;
  final int itemCount;

  /// True when the batch was narrowed to items already due.
  final bool isDueSubset;

  const StudySetActivity({
    required this.studySetId,
    required this.title,
    required this.itemCount,
    this.estimate = const Duration(minutes: 6),
    this.isDueSubset = false,
  });
}

class ReviewActivity extends LearningActivity {
  final List<String> conceptIds;
  @override
  final Duration estimate;

  const ReviewActivity({
    required this.conceptIds,
    this.estimate = const Duration(minutes: 4),
  });

  int get count => conceptIds.length;

  @override
  String get title => count == 1 ? '1 concept' : '$count concepts';
}

/// The way onward when a context runs out of material.
///
/// Surfaced whenever the context is exhausted, never gated on `dueCount`
/// (spec C1) — reviews regenerate forever, so gating would hide the exit
/// from every finished course permanently.
class ForwardOffer {
  final String label;

  /// Null when the only way onward is to switch context or browse.
  final String? nextContextRootId;
  final ContextRootType? nextContextRootType;

  const ForwardOffer({
    required this.label,
    this.nextContextRootId,
    this.nextContextRootType,
  });

  static const ForwardOffer browse = ForwardOffer(label: 'Choose something new');
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

sealed class NextAction {
  const NextAction();

  /// One-line justification, shown only when non-trivial (spec §1.2h).
  String? get rationale => null;
}

/// Zero state. [catalogEmpty] swaps which option leads (spec C2).
class ChooseSomething extends NextAction {
  final bool catalogEmpty;
  const ChooseSomething({this.catalogEmpty = false});
}

class ResumeActivity extends NextAction {
  final LearningActivity activity;
  final int itemIndex;
  const ResumeActivity({required this.activity, required this.itemIndex});

  @override
  String get rationale => 'Picking up where you left off.';
}

class ReinforceConcepts extends NextAction {
  final ReviewActivity activity;
  const ReinforceConcepts({required this.activity});

  @override
  String get rationale => 'You missed these last time.';
}

class StartActivity extends NextAction {
  final LearningActivity activity;
  const StartActivity({required this.activity});

  // Deliberately silent: "it's next in the course" is not worth a sentence.
  @override
  String? get rationale => null;
}

class ReviewOnly extends NextAction {
  final ReviewActivity activity;
  final ForwardOffer offer;
  const ReviewOnly({required this.activity, required this.offer});

  @override
  String get rationale => "You've finished the material here.";
}

class ContextComplete extends NextAction {
  final ForwardOffer offer;
  const ContextComplete({required this.offer});

  @override
  String get rationale => "You've finished this course.";
}

// ---------------------------------------------------------------------------
// Engine input
// ---------------------------------------------------------------------------

/// Everything the engine needs about the active context, resolved by callers.
///
/// Keeping this a plain value object is what makes the engine pure and
/// exhaustively testable without Hive, Supabase, or a widget tree.
class ContextSnapshot {
  final LearningContext context;

  /// Where the learner stopped, if anywhere.
  final ResumePointer? resume;

  /// The activity [resume] refers to. Null if it can no longer be resolved
  /// (deleted lesson, emptied study set) — the engine then falls through
  /// rather than offering a broken Continue.
  final LearningActivity? resumeActivity;

  /// Total items in [resumeActivity]; used to detect a finished activity.
  final int resumeItemCount;

  /// Next available activity in this context, already resolved per rootType.
  final LearningActivity? nextActivity;

  /// Concepts due for review inside this context.
  final List<String> dueConceptIds;

  /// Concepts the learner recently got wrong.
  final List<String> strugglingConceptIds;

  /// Where to go when the context is exhausted.
  final ForwardOffer? forwardOffer;

  const ContextSnapshot({
    required this.context,
    this.resume,
    this.resumeActivity,
    this.resumeItemCount = 0,
    this.nextActivity,
    this.dueConceptIds = const [],
    this.strugglingConceptIds = const [],
    this.forwardOffer,
  });

  int get dueCount => dueConceptIds.length;
}

/// Minimum number of missed concepts before remediation outranks new material.
const int kReinforcementThreshold = 3;

/// Resolves the single primary action for the Learn screen.
///
/// Precedence is fixed and documented in `UI_ARCHITECTURE_LOCKED.md` §5.2.
/// Two invariants are load-bearing:
///
/// 1. Review never outranks forward progress while material remains (A1).
/// 2. No state is reachable-but-terminal — every result offers a way onward
///    that is not a repeat of itself (§1.6).
class NextActionEngine {
  const NextActionEngine();

  NextAction resolve({
    required List<LearningContext> contexts,
    ContextSnapshot? active,
    bool catalogEmpty = false,
  }) {
    final live = contexts.where((c) => !c.isArchived).toList();

    // 1 — nothing to learn yet.
    if (live.isEmpty || active == null) {
      return ChooseSomething(catalogEmpty: catalogEmpty);
    }

    // 2 — a partially completed activity outranks everything else.
    final resume = active.resume;
    final resumeActivity = active.resumeActivity;
    if (resume != null && resumeActivity != null) {
      final index = resume.itemIndex ?? 0;
      final isPartial = index > 0 && index < active.resumeItemCount;
      if (isPartial) {
        return ResumeActivity(activity: resumeActivity, itemIndex: index);
      }
    }

    // 3 — targeted remediation before new material.
    if (active.strugglingConceptIds.length >= kReinforcementThreshold) {
      return ReinforceConcepts(
        activity: ReviewActivity(conceptIds: active.strugglingConceptIds),
      );
    }

    // 4 — forward progress. Study sets always land here: practice is
    // repeatable, so a studySet context never runs out of material.
    final next = active.nextActivity;
    if (next != null) {
      return StartActivity(activity: next);
    }

    // 5/6 — context exhausted. The forward offer appears either way; only its
    // slot changes. Gating it on dueCount would hide it forever (C1).
    final offer = active.forwardOffer ?? ForwardOffer.browse;
    if (active.dueCount > 0) {
      return ReviewOnly(
        activity: ReviewActivity(conceptIds: active.dueConceptIds),
        offer: offer,
      );
    }
    return ContextComplete(offer: offer);
  }

  /// Switcher ordering: pinned first by [LearningContext.sortOrder] ascending,
  /// then the rest by recency (spec B4).
  List<LearningContext> orderForSwitcher(List<LearningContext> contexts) {
    final live = contexts.where((c) => !c.isArchived).toList();
    final pinned = live.where((c) => c.isPinned).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final rest = live.where((c) => !c.isPinned).toList()
      ..sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
    return [...pinned, ...rest];
  }

  /// Whether the secondary review prompt renders beneath the primary action.
  ///
  /// Suppressed when review is already the primary action.
  bool showSecondaryReviewPrompt(NextAction action, int dueCount) {
    if (dueCount <= 0) return false;
    return action is! ReviewOnly;
  }
}
