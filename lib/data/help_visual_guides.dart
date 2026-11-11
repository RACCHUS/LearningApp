import 'package:flutter/material.dart';
import 'package:learning_pwa/models/help_topic.dart';

/// Local, reviewed, picture-supported guidance. No network or AI required.
class HelpVisualStep {
  final IconData icon;
  final String label;
  final String spokenInstruction;

  const HelpVisualStep({
    required this.icon,
    required this.label,
    required this.spokenInstruction,
  });
}

class HelpVisualGuide {
  final IconData icon;
  final List<HelpVisualStep> steps;

  const HelpVisualGuide({required this.icon, required this.steps});

  String get narration =>
      steps.map((step) => step.spokenInstruction).join(' ');
}

IconData helpIconForTopic(HelpTopic topic) => switch (topic.id) {
      'find-learning' => Icons.search_rounded,
      'learning-paths' => Icons.route_rounded,
      'study-timer-breaks' => Icons.timer_outlined,
      'focus-mode' => Icons.center_focus_strong_rounded,
      'study-batch-size' => Icons.view_carousel_rounded,
      'recall-before-reveal' => Icons.psychology_alt_outlined,
      'words' => Icons.abc_rounded,
      'flashcards' => Icons.style_outlined,
      'practice-questions' => Icons.quiz_outlined,
      'mock-exams' => Icons.assignment_turned_in_outlined,
      'completion-retention' => Icons.insights_outlined,
      'daily-study-goal' => Icons.flag_outlined,
      'motivation' => Icons.emoji_events_outlined,
      'create-learning-goal' => Icons.add_circle_outline_rounded,
      'account-settings' => Icons.settings_outlined,
      _ => Icons.help_outline_rounded,
    };

/// Prefer short, concrete steps over reading an entire technical article.
/// Unmapped topics remain available with their existing help text spoken.
HelpVisualGuide helpVisualGuideFor(HelpTopic topic) {
  final icon = helpIconForTopic(topic);
  switch (topic.id) {
    case 'find-learning':
      return const HelpVisualGuide(
        icon: Icons.search_rounded,
        steps: [
          HelpVisualStep(
            icon: Icons.menu_book_outlined,
            label: 'Open Library',
            spokenInstruction: 'First, open Library to find something to learn.',
          ),
          HelpVisualStep(
            icon: Icons.touch_app_outlined,
            label: 'Choose something',
            spokenInstruction: 'Next, choose the course, subject, or picture you want.',
          ),
          HelpVisualStep(
            icon: Icons.play_circle_outline,
            label: 'Start learning',
            spokenInstruction: 'Then select the available start or continue action.',
          ),
        ],
      );
    case 'learning-paths':
      return const HelpVisualGuide(
        icon: Icons.route_rounded,
        steps: [
          HelpVisualStep(
            icon: Icons.flag_outlined,
            label: 'Choose your focus',
            spokenInstruction: 'Choose what you want to learn.',
          ),
          HelpVisualStep(
            icon: Icons.route_outlined,
            label: 'Follow your path',
            spokenInstruction: 'Follow your learning path one activity at a time.',
          ),
          HelpVisualStep(
            icon: Icons.history_outlined,
            label: 'Come back later',
            spokenInstruction: 'You can return and keep your progress.',
          ),
        ],
      );
    case 'study-timer-breaks':
      return const HelpVisualGuide(
        icon: Icons.timer_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.play_circle_outline,
            label: 'Begin studying',
            spokenInstruction: 'Start learning first. You do not need the timer.',
          ),
          HelpVisualStep(
            icon: Icons.timer_outlined,
            label: 'Use the timer',
            spokenInstruction: 'When a timer is available, you can use it for a focus period.',
          ),
          HelpVisualStep(
            icon: Icons.free_breakfast_outlined,
            label: 'Take a break',
            spokenInstruction: 'Take a break when you need one, then continue learning.',
          ),
        ],
      );
    case 'practice-questions':
      return const HelpVisualGuide(
        icon: Icons.quiz_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.hearing_outlined,
            label: 'Read or listen',
            spokenInstruction: 'Read or listen to the practice question.',
          ),
          HelpVisualStep(
            icon: Icons.touch_app_outlined,
            label: 'Choose an answer',
            spokenInstruction: 'Choose the answer you think is right.',
          ),
          HelpVisualStep(
            icon: Icons.fact_check_outlined,
            label: 'Check feedback',
            spokenInstruction: 'Review the feedback to see what to practice next.',
          ),
        ],
      );
    case 'account-settings':
      return const HelpVisualGuide(
        icon: Icons.settings_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.settings_outlined,
            label: 'Open Settings',
            spokenInstruction: 'Open Settings to change app preferences.',
          ),
          HelpVisualStep(
            icon: Icons.volume_up_outlined,
            label: 'Choose audio',
            spokenInstruction: 'Look for audio preferences to change how listening works.',
          ),
          HelpVisualStep(
            icon: Icons.arrow_back_rounded,
            label: 'Go back',
            spokenInstruction: 'Go back when you are ready. You can keep learning.',
          ),
        ],
      );
    default:
      return HelpVisualGuide(
        icon: icon,
        steps: [
          HelpVisualStep(
            icon: icon,
            label: topic.title,
            spokenInstruction: topic.summary,
          ),
          HelpVisualStep(
            icon: Icons.info_outline_rounded,
            label: 'How it works',
            spokenInstruction: topic.body,
          ),
        ],
      );
  }
}
