import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/widgets/audio_control_widget.dart';
import 'package:learning_pwa/widgets/study/study_mode_selector.dart';
import 'package:learning_pwa/widgets/study/study_content_router.dart';
import 'package:learning_pwa/widgets/study/study_navigation_controls.dart';

/// Refactored study screen with extracted components
/// 
/// This screen now uses focused components for mode selection,
/// content display, and navigation instead of being monolithic.
class StudyScreen extends ConsumerStatefulWidget {
  final Lesson lesson;

  const StudyScreen({
    super.key,
    required this.lesson,
  });

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  late StudyMode selectedMode;
  bool showModeSelection = true;

  @override
  void initState() {
    super.initState();
    selectedMode = StudyMode.lesson;
  }

  @override
  Widget build(BuildContext context) {
    final studyState = ref.watch(studyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          const AudioPlaybackIndicator(),
          const SizedBox(width: 8),
          const AudioSpeedControl(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              setState(() {
                showModeSelection = true;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: showModeSelection 
          ? _buildModeSelection()
          : _buildStudyInterface(studyState, colorScheme),
      ),
    );
  }

  Widget _buildModeSelection() {
    return StudyModeSelector(
      selectedMode: selectedMode,
      onModeChanged: (mode) {
        setState(() {
          selectedMode = mode;
        });
      },
      onStartStudy: () {
        ref.read(studyProvider.notifier).startStudySession(
          widget.lesson.id, 
          selectedMode,
        );
        setState(() {
          showModeSelection = false;
        });
      },
    );
  }

  Widget _buildStudyInterface(dynamic studyState, ColorScheme colorScheme) {
    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: studyState.currentIndex / 
                 (studyState.currentContent?.length ?? 1),
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        
        // Main content area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: studyState.isLoading || studyState.currentContent == null
                  ? const Center(child: CircularProgressIndicator())
                  : StudyContentRouter(
                      content: studyState.currentContent![studyState.currentIndex],
                      mode: studyState.currentMode!,
                    ),
              ),
            ),
          ),
        ),
        
        // Bottom navigation controls
        StudyNavigationControls(
          currentIndex: studyState.currentIndex,
          totalItems: studyState.currentContent?.length ?? 0,
          onPrevious: studyState.currentIndex > 0
              ? () => ref.read(studyProvider.notifier).previous()
              : null,
          onNext: studyState.currentIndex < 
                  (studyState.currentContent?.length ?? 0) - 1
              ? () => ref.read(studyProvider.notifier).next()
              : null,
          onFinish: () {
            _finishStudySession();
          },
        ),
      ],
    );
  }

  void _finishStudySession() {
    // Show completion dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Study Session Complete!'),
        content: const Text('Great job! You\'ve completed this study session.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                showModeSelection = true;
              });
            },
            child: const Text('Study Again'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}
