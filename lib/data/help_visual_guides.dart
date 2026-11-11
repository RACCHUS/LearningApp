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
      'start-with-pictures' => Icons.image_outlined,
      'choose-adult-kids' => Icons.people_outline_rounded,
      'hear-pause-replay' => Icons.volume_up_rounded,
      'letters-and-pictures' => Icons.abc_rounded,
      'life-skills-pictures' => Icons.health_and_safety_outlined,
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
    case 'start-with-pictures':
      return const HelpVisualGuide(
        icon: Icons.image_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.image_outlined,
            label: 'Tap Start with Pictures',
            spokenInstruction: 'First, on Learn home, tap the large Start with Pictures button.',
          ),
          HelpVisualStep(
            icon: Icons.people_outline_rounded,
            label: 'Choose Adult or Kids',
            spokenInstruction: 'Next, choose Adult or Kids using the picture options.',
          ),
          HelpVisualStep(
            icon: Icons.play_circle_outline,
            label: 'Tap Start',
            spokenInstruction: 'Then tap Start to begin learning with pictures and sound.',
          ),
        ],
      );
    case 'choose-adult-kids':
      return const HelpVisualGuide(
        icon: Icons.people_outline_rounded,
        steps: [
          HelpVisualStep(
            icon: Icons.image_outlined,
            label: 'Open picture learning',
            spokenInstruction: 'First tap Start with Pictures on the Learn home screen.',
          ),
          HelpVisualStep(
            icon: Icons.people_outline_rounded,
            label: 'Choose your track',
            spokenInstruction: 'Select the Adult picture or the Kids picture. Nothing starts until you choose.',
          ),
          HelpVisualStep(
            icon: Icons.play_circle_outline,
            label: 'Start learning',
            spokenInstruction: 'Tap Start to begin. You can switch between Adult and Kids later.',
          ),
        ],
      );
    case 'hear-pause-replay':
      return const HelpVisualGuide(
        icon: Icons.volume_up_rounded,
        steps: [
          HelpVisualStep(
            icon: Icons.volume_up_rounded,
            label: 'Listen',
            spokenInstruction: 'Tap a speaker picture to hear an instruction.',
          ),
          HelpVisualStep(
            icon: Icons.pause_circle_outline,
            label: 'Pause or resume',
            spokenInstruction: 'Use Pause to stop briefly. Use Resume to hear more.',
          ),
          HelpVisualStep(
            icon: Icons.replay_rounded,
            label: 'Restart or stop',
            spokenInstruction: 'Restart repeats the whole instruction. Stop ends it. On some devices Resume also restarts.',
          ),
        ],
      );
    case 'letters-and-pictures':
      return const HelpVisualGuide(
        icon: Icons.abc_rounded,
        steps: [
          HelpVisualStep(
            icon: Icons.image_outlined,
            label: 'Open Letters',
            spokenInstruction: 'Enter picture learning and choose Letters.',
          ),
          HelpVisualStep(
            icon: Icons.hearing_outlined,
            label: 'Hear a sound',
            spokenInstruction: 'Tap the speaker to listen to the letter sound.',
          ),
          HelpVisualStep(
            icon: Icons.touch_app_outlined,
            label: 'Choose or trace',
            spokenInstruction: 'Tap the matching picture, or choose the separate finger-tracing activity.',
          ),
        ],
      );
    case 'life-skills-pictures':
      return const HelpVisualGuide(
        icon: Icons.health_and_safety_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.image_outlined,
            label: 'Open Life Topics',
            spokenInstruction: 'Inside picture learning, choose Life Topics.',
          ),
          HelpVisualStep(
            icon: Icons.touch_app_outlined,
            label: 'Choose a picture',
            spokenInstruction: 'Tap a picture for safety, money, or another everyday topic.',
          ),
          HelpVisualStep(
            icon: Icons.volume_up_rounded,
            label: 'Listen and practice',
            spokenInstruction: 'Tap the speaker to hear guidance. Use Home to return when you are done.',
          ),
        ],
      );
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

    case 'focus-mode':
      return const HelpVisualGuide(
        icon: Icons.center_focus_strong_rounded,
        steps: [
          HelpVisualStep(
            icon: Icons.menu_book_outlined,
            label: 'Open a lesson',
            spokenInstruction: 'First, open something you are studying.',
          ),
          HelpVisualStep(
            icon: Icons.center_focus_strong_rounded,
            label: 'Choose Focus',
            spokenInstruction: 'If Focus mode is available, turn it on to hide distractions.',
          ),
          HelpVisualStep(
            icon: Icons.fullscreen_exit_rounded,
            label: 'Return to normal',
            spokenInstruction: 'Turn Focus mode off to see the usual controls again.',
          ),
        ],
      );
    case 'study-batch-size':
      return const HelpVisualGuide(
        icon: Icons.view_carousel_rounded,
        steps: [
          HelpVisualStep(
            icon: Icons.settings_outlined,
            label: 'Open Settings',
            spokenInstruction: 'Open Settings to change the number of cards in a session.',
          ),
          HelpVisualStep(
            icon: Icons.style_outlined,
            label: 'Choose a number',
            spokenInstruction: 'Choose fewer cards for a short session, or more cards for a longer one.',
          ),
        ],
      );
    case 'recall-before-reveal':
      return const HelpVisualGuide(
        icon: Icons.psychology_alt_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.psychology_alt_outlined,
            label: 'Try to remember',
            spokenInstruction: 'Before you see an answer, try to remember it yourself.',
          ),
          HelpVisualStep(
            icon: Icons.visibility_outlined,
            label: 'Then reveal',
            spokenInstruction: 'Reveal the answer and check if you remembered it.',
          ),
          HelpVisualStep(
            icon: Icons.settings_outlined,
            label: 'Change this option',
            spokenInstruction: 'You can turn Recall before reveal on or off in Settings.',
          ),
        ],
      );
    case 'words':
      return const HelpVisualGuide(
        icon: Icons.abc_rounded,
        steps: [
          HelpVisualStep(
            icon: Icons.menu_book_outlined,
            label: 'Find Words',
            spokenInstruction: 'Open Library and find Words.',
          ),
          HelpVisualStep(
            icon: Icons.edit_note_outlined,
            label: 'Make a word list',
            spokenInstruction: 'Create a list of words you want to practice.',
          ),
          HelpVisualStep(
            icon: Icons.record_voice_over_outlined,
            label: 'Practice spelling',
            spokenInstruction: 'Practice spelling those words and check your answers.',
          ),
        ],
      );
    case 'flashcards':
      return const HelpVisualGuide(
        icon: Icons.style_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.style_outlined,
            label: 'Open cards',
            spokenInstruction: 'Open a set of flashcards to practice.',
          ),
          HelpVisualStep(
            icon: Icons.psychology_alt_outlined,
            label: 'Remember first',
            spokenInstruction: 'Look at the question and try to remember the answer.',
          ),
          HelpVisualStep(
            icon: Icons.visibility_outlined,
            label: 'Reveal and review',
            spokenInstruction: 'Reveal the answer, then keep practicing the ones you need.',
          ),
        ],
      );
    case 'mock-exams':
      return const HelpVisualGuide(
        icon: Icons.assignment_turned_in_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.menu_book_outlined,
            label: 'Choose an exam',
            spokenInstruction: 'Open Library and choose the exam you are preparing for.',
          ),
          HelpVisualStep(
            icon: Icons.assignment_outlined,
            label: 'Find practice',
            spokenInstruction: 'If a mock exam is available, select it when you are ready.',
          ),
          HelpVisualStep(
            icon: Icons.fact_check_outlined,
            label: 'Review results',
            spokenInstruction: 'After practicing, look at the feedback to decide what to study.',
          ),
        ],
      );
    case 'completion-retention':
      return const HelpVisualGuide(
        icon: Icons.insights_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.check_circle_outline,
            label: 'Completed work',
            spokenInstruction: 'Completion shows how much learning activity you finished.',
          ),
          HelpVisualStep(
            icon: Icons.psychology_alt_outlined,
            label: 'What you remember',
            spokenInstruction: 'Retention shows information about what you have remembered during practice. These are different measures.',
          ),
        ],
      );
    case 'daily-study-goal':
      return const HelpVisualGuide(
        icon: Icons.flag_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.settings_outlined,
            label: 'Open Settings',
            spokenInstruction: 'Open Settings if you want to set a daily study goal.',
          ),
          HelpVisualStep(
            icon: Icons.timer_outlined,
            label: 'Choose your time',
            spokenInstruction: 'Choose how long you would like to study each day. A goal is optional.',
          ),
        ],
      );
    case 'motivation':
      return const HelpVisualGuide(
        icon: Icons.emoji_events_outlined,
        steps: [
          HelpVisualStep(
            icon: Icons.emoji_events_outlined,
            label: 'Celebrate practice',
            spokenInstruction: 'Some learning activities can show points or celebrations.',
          ),
          HelpVisualStep(
            icon: Icons.settings_outlined,
            label: 'Choose what you like',
            spokenInstruction: 'Check Settings to change optional motivation features.',
          ),
        ],
      );
    case 'create-learning-goal':
      return const HelpVisualGuide(
        icon: Icons.add_circle_outline_rounded,
        steps: [
          HelpVisualStep(
            icon: Icons.menu_book_outlined,
            label: 'Open Library',
            spokenInstruction: 'Open Library to make something of your own.',
          ),
          HelpVisualStep(
            icon: Icons.add_circle_outline_rounded,
            label: 'Choose Create',
            spokenInstruction: 'Choose Create, then choose what you want to make.',
          ),
          HelpVisualStep(
            icon: Icons.check_circle_outline,
            label: 'Save your choice',
            spokenInstruction: 'Follow the steps shown to finish creating your learning item.',
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
