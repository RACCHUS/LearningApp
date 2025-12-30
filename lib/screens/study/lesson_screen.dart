import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/utils/web_utils.dart';
import 'package:learning_pwa/utils/haptic_utils.dart';
import 'package:learning_pwa/models/lesson_content.dart';
// ...existing code...
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/providers/offline_provider.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/lesson_content_pager.dart';
import 'package:learning_pwa/screens/study/lesson_mode_dialog.dart';
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
  
  // ...existing code...

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


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));

    // Show mode selection dialog on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_modeDialogShown && ModalRoute.of(context)?.isCurrent == true) {
        _modeDialogShown = true;
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Failed to load lesson',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () {
                    ref.invalidate(lessonProvider(widget.lessonId));
                  },
                ),
              ],
            ),
          ),
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
