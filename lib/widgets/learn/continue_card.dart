import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// The single primary action. Exactly one filled button, exactly one secondary.
class ContinueCard extends StatelessWidget {
  final NextAction action;

  const ContinueCard({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = _ContinueView.from(action);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          view.sectionLabel,
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: DesignTokens.space3),
        Text(view.title, style: theme.textTheme.headlineSmall),
        if (view.orientation != null) ...[
          const SizedBox(height: DesignTokens.space1),
          Text(
            view.orientation!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        if (view.rationale != null) ...[
          const SizedBox(height: DesignTokens.space3),
          Text(
            view.rationale!,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: DesignTokens.space4),
        Row(
          children: [
            FilledButton(
              key: const Key('learn-primary-action'),
              onPressed: () => context.push(view.primaryRoute),
              child: Text(view.primaryLabel),
            ),
            const SizedBox(width: DesignTokens.space3),
            TextButton(
              key: const Key('learn-secondary-action'),
              onPressed: () => context.push(view.secondaryRoute),
              child: Text(view.secondaryLabel),
            ),
          ],
        ),
      ],
    );
  }
}

/// Flattens a [NextAction] into what the card actually renders.
class _ContinueView {
  final String sectionLabel;
  final String title;
  final String? orientation;
  final String? rationale;
  final String primaryLabel;
  final String primaryRoute;
  final String secondaryLabel;
  final String secondaryRoute;

  const _ContinueView({
    required this.sectionLabel,
    required this.title,
    required this.primaryLabel,
    required this.primaryRoute,
    required this.secondaryLabel,
    required this.secondaryRoute,
    this.orientation,
    this.rationale,
  });

  factory _ContinueView.from(NextAction action) {
    switch (action) {
      case ResumeActivity(:final activity):
        return _ContinueView(
          sectionLabel: 'Continue',
          title: activity.title,
          orientation: _orientation(activity),
          rationale: action.rationale,
          primaryLabel: 'Continue',
          primaryRoute: _route(activity),
          secondaryLabel: _secondaryLabel(activity),
          secondaryRoute: _secondaryRoute(activity),
        );

      case StartActivity(:final activity):
        return _ContinueView(
          sectionLabel: 'Continue',
          title: activity.title,
          orientation: _orientation(activity),
          rationale: action.rationale,
          primaryLabel: activity is StudySetActivity ? 'Practice' : 'Start',
          primaryRoute: _route(activity),
          secondaryLabel: _secondaryLabel(activity),
          secondaryRoute: _secondaryRoute(activity),
        );

      case ReinforceConcepts(:final activity):
        return _ContinueView(
          sectionLabel: 'Reinforce',
          title: activity.title,
          orientation: '~${activity.estimate.inMinutes} min',
          rationale: action.rationale,
          primaryLabel: 'Review',
          primaryRoute: '/review',
          secondaryLabel: 'Choose lesson',
          secondaryRoute: '/library',
        );

      // Reviews are primary only because the context is exhausted — the way
      // onward is still present, as the secondary action (spec C1).
      case ReviewOnly(:final activity, :final offer):
        return _ContinueView(
          sectionLabel: 'Ready to review',
          title: activity.title,
          orientation: '~${activity.estimate.inMinutes} min',
          rationale: action.rationale,
          primaryLabel: 'Review',
          primaryRoute: '/review',
          secondaryLabel: offer.label,
          secondaryRoute: '/library',
        );

      case ContextComplete(:final offer):
        return _ContinueView(
          sectionLabel: 'Finished',
          title: 'Nothing left here',
          rationale: action.rationale,
          primaryLabel: offer.label,
          primaryRoute: '/library',
          secondaryLabel: 'Browse all learning',
          secondaryRoute: '/library',
        );

      case ChooseSomething():
        return const _ContinueView(
          sectionLabel: 'Start',
          title: 'What do you want to learn?',
          primaryLabel: 'Browse courses',
          primaryRoute: '/library',
          secondaryLabel: 'Import or create',
          secondaryRoute: '/create-lesson',
        );
    }
  }

  static String? _orientation(LearningActivity activity) {
    final minutes = '~${activity.estimate.inMinutes} min';
    if (activity is LessonActivity) {
      final parts = <String>[
        if (activity.courseTitle != null) activity.courseTitle!,
        if (activity.moduleTitle != null) activity.moduleTitle!,
        if (activity.position != null && activity.total != null)
          'Lesson ${activity.position} of ${activity.total}',
        minutes,
      ];
      return parts.join(' · ');
    }
    if (activity is StudySetActivity) {
      final count = activity.itemCount;
      final noun = activity.isDueSubset ? 'due' : 'cards';
      return count > 0 ? 'Study set · $count $noun · $minutes' : 'Study set';
    }
    return minutes;
  }

  static String _route(LearningActivity activity) {
    if (activity is LessonActivity) return '/lesson/${activity.lessonId}';
    if (activity is StudySetActivity) {
      return '/study-set?setId=${activity.studySetId}';
    }
    return '/review';
  }

  static String _secondaryLabel(LearningActivity activity) {
    if (activity is StudySetActivity) return 'Browse set';
    if (activity is LessonActivity && activity.courseId == null) {
      return 'Choose lesson';
    }
    return 'Course outline';
  }

  static String _secondaryRoute(LearningActivity activity) {
    if (activity is LessonActivity) {
      final courseId = activity.courseId;
      return courseId == null ? '/library' : '/course/$courseId/outline';
    }
    if (activity is StudySetActivity) return '/study-sets';
    return '/library';
  }
}
