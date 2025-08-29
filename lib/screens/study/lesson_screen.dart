import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/utils/web_utils.dart';
import 'package:learning_pwa/models/lesson_content.dart';
// ...existing code...
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/providers/offline_provider.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/lesson_content_pager.dart';
import 'package:learning_pwa/screens/study/lesson_mode_dialog.dart';
import 'package:learning_pwa/widgets/timer_widget.dart';
import 'package:learning_pwa/providers/timer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              setState(() {
                _isLessonMode = true;
              });
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
    
    // Show completion dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Lesson Complete!'),
        content: const Text('Great job! You have completed this lesson.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Just close dialog to review
            child: const Text('Review'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _restartCounter++; // Increment to force rebuild
                _isLessonMode = true; // Ensure lesson mode is active
              });
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
