import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/utils/web_utils.dart';
import 'package:learning_pwa/utils/haptic_utils.dart';
import 'package:learning_pwa/models/lesson_content.dart';
// ...existing code...
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/providers/lesson_progress_provider.dart';
import 'package:learning_pwa/providers/offline_provider.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/lesson_content_pager.dart';
import 'package:learning_pwa/screens/study/lesson_mode_dialog.dart';
import 'package:learning_pwa/widgets/error_retry_view.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';
import 'package:learning_pwa/widgets/timer_widget.dart';
import 'package:learning_pwa/widgets/celebration_overlay.dart';
import 'package:learning_pwa/providers/timer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/widgets/global_voice_indicator.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';

class LessonScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const LessonScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  bool _modeDialogShown = false;
  bool _isLessonMode = false; // Track lesson mode state
  int _restartCounter = 0; // Track restarts to force rebuild
  bool _nudgeChecked = false; // Anti-cramming nudge shown at most once
  
  /// Launch a previously saved study mode without showing the dialog
  void _launchSavedMode(StudyModePreference mode) {
    final lessonContent = ref.read(lessonProvider(widget.lessonId)).asData?.value.lessonContent ?? [];
    
    switch (mode) {
      case StudyModePreference.lesson:
        ref.read(studyProvider.notifier).resetStudySession();
        setState(() => _isLessonMode = true);
        _checkAutoEnableLessonHandsFree();
      case StudyModePreference.flashcards:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlashcardScreen(
              terms: lessonContent.whereType<TermContent>().map((c) => Term.fromTermContent(c)).toList(),
            ),
          ),
        );
      case StudyModePreference.mcq:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => McqScreen(
              questions: lessonContent.whereType<QuestionContent>().map((c) => Question(
                id: c.id,
                questionText: c.questionText,
                options: c.options,
                correctAnswer: c.correctAnswer,
                type: 'multiple_choice',
                explanation: c.explanation,
                createdBy: 'system',
              )).toList(),
            ),
          ),
        );
      case StudyModePreference.concepts:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConceptScreen(
              concepts: lessonContent.whereType<ConceptContent>().toList(),
            ),
          ),
        );
      case StudyModePreference.mixed:
        context.go('/study-set?ids=${widget.lessonId}');
    }
  }

  void _showModeDialog() {
    showDialog(
      context: context,
      builder: (context) => LessonModeDialog(
        lessonId: widget.lessonId,
        onLessonModeSelected: () {
          ref.read(studyProvider.notifier).resetStudySession();
          setState(() => _isLessonMode = true);
          _checkAutoEnableLessonHandsFree();
        },
      ),
    );
  }

  /// Check if auto hands-free for lessons is enabled and enable global voice
  Future<void> _checkAutoEnableLessonHandsFree() async {
    if (kDebugMode) {
      print('🎓 _checkAutoEnableLessonHandsFree() method called');
    }
    try {
      final handsFreeSettings = ref.read(handsFreeSettingsProvider);
      
      if (kDebugMode) {
        print('🎓 Settings check - autoLessonHandsFree: ${handsFreeSettings.autoLessonHandsFree}');
      }
      
      if (handsFreeSettings.autoLessonHandsFree) {
        if (kDebugMode) {
          print('🎓 Auto lesson hands-free enabled - LessonContentPager will handle orchestrator');
        }
      } else {
        if (kDebugMode) {
          print('ℹ️ Auto lesson hands-free disabled in settings');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking auto-enable lesson hands-free: $e');
      }
    }
  }


  /// Gently discourage cramming: if this lesson was studied within the last
  /// few hours, suggest spacing reviews out instead of re-studying now.
  Future<void> _maybeShowAntiCrammingNudge() async {
    try {
      final lastStudied =
          await ref.read(lessonLastStudiedProvider(widget.lessonId).future);
      if (lastStudied == null || !mounted) return;

      final since = DateTime.now().difference(lastStudied);
      if (since < const Duration(hours: 4)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You studied this recently. Spacing reviews out strengthens '
              'memory — a short review may help more than a full re-study.',
            ),
            duration: Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Non-critical nudge — ignore failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));

    // Show mode selection dialog on first build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_nudgeChecked) {        _nudgeChecked = true;
        _maybeShowAntiCrammingNudge();
      }
      if (!_modeDialogShown && ModalRoute.of(context)?.isCurrent == true) {
        _modeDialogShown = true;
        
        // Check for saved preference
        final savedMode = await getSavedStudyMode(widget.lessonId);
        if (savedMode != null && mounted) {
          _launchSavedMode(savedMode);
          return;
        }
        
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => LessonModeDialog(
            lessonId: widget.lessonId,
            onLessonModeSelected: () {
              // Reset study session scores for fresh lesson tracking
              ref.read(studyProvider.notifier).resetStudySession();
              setState(() {
                _isLessonMode = true;
              });
              
              // Check if auto hands-free for lessons is enabled
              _checkAutoEnableLessonHandsFree();
            },
          ),
        );
      }
    });

    return lessonAsync.when(
      data: (lessonData) {
        // Sort content ONLY by order field (respecting lesson design), ignoring content types
        final contentList = <LessonContent>[...lessonData.lessonContent];
        contentList.sort((a, b) {
          // Sort ONLY by order field - this should give us the correct sequence from JSON
          return a.order.compareTo(b.order);
        });
        return Scaffold(
          appBar: AppBar(
            title: Text(lessonData.lesson.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: 'Change study mode',
                onPressed: () async {
                  await clearStudyMode(widget.lessonId);
                  if (mounted) _showModeDialog();
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  final timerEnabled = ref.watch(timerProvider.select((s) => s.enabled));
                  final timerNotifier = ref.read(timerProvider.notifier);
                  return IconButton(
                    icon: Icon(
                      Icons.timer,
                      color: timerEnabled ? Theme.of(context).colorScheme.primary : null,
                    ),
                    tooltip: timerEnabled ? 'Disable Timer' : 'Enable Timer',
                    onPressed: () => timerNotifier.toggleEnabled(!timerEnabled),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share lesson link',
                onPressed: () async {
                  final url = Uri.base.removeFragment().replace(path: '/lesson/${widget.lessonId}').toString();
                  final didShare = await shareText(url, title: 'Lesson Link');
                  if (!didShare) {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lesson link copied!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Download for offline',
                onPressed: () {
                  ref.read(offlineProvider.notifier).cacheLesson(lessonData.lesson);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lesson downloaded for offline use'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: Consumer(
            builder: (context, ref, _) {
              final timerEnabled = ref.watch(timerProvider.select((s) => s.enabled));
              return Column(
                children: [
                  if (timerEnabled) const TimerWidget(),
                  Expanded(
                    child: contentList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_stories_outlined,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No content available',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This lesson does not contain any study materials yet.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _isLessonMode
                            ? LessonContentPager(
                                key: ValueKey(_restartCounter), // Force rebuild on restart
                                contentList: contentList,
                                onLessonComplete: _onLessonComplete,
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.school,
                                      size: 64,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Select a Study Mode',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Choose how you want to study this lesson from the dialog.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: const GlobalVoiceFAB(heroTag: "lessonVoiceFAB"),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: ErrorRetryView(
          message: 'Failed to load lesson',
          error: error,
          showDetails: kDebugMode,
          onRetry: () => ref.invalidate(lessonProvider(widget.lessonId)),
        ),
      ),
    );
  }

  void _onLessonComplete() {
    // Update study progress
    ref.read(studyProvider.notifier).markLessonAsCompleted(widget.lessonId);
    
    // Trigger celebration (confetti + haptic)
    HapticUtils.milestone();
    CelebrationOverlay.trigger(ref, CelebrationType.lessonComplete);
    
    // Get study state for score information
    final studyState = ref.read(studyProvider);
    final totalMCQs = studyState.correctAnswers + studyState.incorrectAnswers;
    final hasQuestions = totalMCQs > 0;
    
    // Show completion dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Lesson Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Great job! You have completed this lesson.'),
            if (hasQuestions) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Quiz Performance:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Score: ${studyState.correctAnswers}/$totalMCQs (${((studyState.correctAnswers / totalMCQs) * 100).round()}%)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Just close dialog to review
            child: const Text('Review'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Reset study session scores for fresh lesson tracking
              ref.read(studyProvider.notifier).resetStudySession();
              setState(() {
                _restartCounter++; // Increment to force rebuild
                _isLessonMode = true; // Ensure lesson mode is active
              });
              
              // Check if auto hands-free for lessons is enabled on restart
              _checkAutoEnableLessonHandsFree();
            },
            child: const Text('Restart'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home page
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

}
