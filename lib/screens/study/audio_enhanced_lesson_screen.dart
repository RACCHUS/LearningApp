import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/session_result.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/providers/audio_lesson_provider.dart';
import 'package:learning_pwa/providers/audio_playback_provider.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/session_results_screen.dart';
import 'package:learning_pwa/widgets/audio_aware_lesson_renderer.dart';
import 'package:learning_pwa/widgets/audio/hands_free_indicator.dart';
import 'package:learning_pwa/services/audio_lesson_orchestrator.dart';

class AudioEnhancedLessonScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final bool enableHandsFreeMode;
  
  const AudioEnhancedLessonScreen({
    super.key, 
    required this.lessonId,
    this.enableHandsFreeMode = false,
  });

  @override
  ConsumerState<AudioEnhancedLessonScreen> createState() => _AudioEnhancedLessonScreenState();
}

class _AudioEnhancedLessonScreenState extends ConsumerState<AudioEnhancedLessonScreen> {
  int pageIndex = 0;
  bool _isOrchestratorMode = false;
  StreamSubscription<int>? _failedSegmentsSub;

  @override
  void initState() {
    super.initState();
    _isOrchestratorMode = widget.enableHandsFreeMode;
    
    // Initialize orchestrator if hands-free mode is enabled
    if (_isOrchestratorMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeOrchestrator();
      });
    }
  }

  @override
  void dispose() {
    _failedSegmentsSub?.cancel();
    // Stop orchestrator when leaving screen
    if (_isOrchestratorMode) {
      final orchestrator = ref.read(audioLessonOrchestratorProvider);
      orchestrator.stopLesson();
    }
    super.dispose();
  }

  Future<void> _initializeOrchestrator() async {
    final lessonAsync = ref.read(lessonProvider(widget.lessonId));
    
    lessonAsync.whenData((lessonData) async {
      final orchestrator = ref.read(audioLessonOrchestratorProvider);
      final settingsNotifier = ref.read(audioLessonSettingsProvider.notifier);
      
      // Request microphone permissions before enabling hands-free mode
      final audioNotifier = ref.read(audioPlaybackProvider.notifier);
      if (kDebugMode) {
        print('🎙️ Requesting microphone permissions for hands-free mode...');
      }
      
      final permissionsGranted = await audioNotifier.requestMicrophonePermissions();
      if (!permissionsGranted) {
        if (kDebugMode) {
          print('❌ Microphone permissions denied - hands-free mode not enabled');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required for hands-free mode'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      
      if (kDebugMode) {
        print('✅ Microphone permissions granted for hands-free mode');
      }
      
      // Enable hands-free mode
      settingsNotifier.toggleHandsFreeMode();
      
      // Initialize orchestrator
      await orchestrator.initialize();
      
      // Listen for TTS segment failures to notify the user
      _failedSegmentsSub?.cancel();
      _failedSegmentsSub = orchestrator.failedSegmentsStream.listen((count) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count segment${count > 1 ? 's' : ''} could not be read aloud'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
      
      // Start lesson with orchestrator
      await orchestrator.startLesson(lessonData.lessonContent, startIndex: pageIndex);
    });
  }

  void nextPage(int total) {
    if (_isOrchestratorMode) {
      // In orchestrator mode, navigation is handled by the orchestrator
      final orchestrator = ref.read(audioLessonOrchestratorProvider);
      orchestrator.nextContent();
    } else {
      // Manual navigation
      setState(() {
        pageIndex = (pageIndex + 1).clamp(0, total - 1);
      });
    }
  }

  void previousPage() {
    if (_isOrchestratorMode) {
      final orchestrator = ref.read(audioLessonOrchestratorProvider);
      orchestrator.previousContent();
    } else {
      setState(() {
        pageIndex = (pageIndex - 1).clamp(0, 999);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));
    
    // Listen to orchestrator progress updates
    if (_isOrchestratorMode) {
      ref.listen<int>(audioLessonProgressProvider, (previous, next) {
        setState(() {
          pageIndex = next;
        });
      });
      
      // Listen to lesson completion
      ref.listen<LessonFlowAction?>(audioLessonActionsProvider, (previous, next) {
        if (next == LessonFlowAction.complete) {
          _handleLessonComplete();
        }
      });
    }

    return lessonAsync.when(
      data: (lessonData) {
        final contentList = lessonData.lessonContent;
        if (contentList.isEmpty) {
          return _buildEmptyState();
        }
        
        final content = contentList[pageIndex];
        final isLastPage = pageIndex >= contentList.length - 1;

        return Scaffold(
          appBar: AppBar(
            title: Text(lessonData.lesson.title),
            actions: [
              // Hands-free mode toggle
              IconButton(
                icon: Icon(_isOrchestratorMode ? Icons.record_voice_over : Icons.touch_app),
                tooltip: _isOrchestratorMode ? 'Disable Hands-Free' : 'Enable Hands-Free',
                onPressed: _toggleOrchestratorMode,
              ),
              
              // Voice commands help
              if (_isOrchestratorMode)
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'Voice Commands Help',
                  onPressed: () => _showVoiceCommandsHelp(context),
                ),
              
              // Manual next button (when not in orchestrator mode)
              if (!_isOrchestratorMode && !isLastPage)
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => nextPage(contentList.length),
                ),
            ],
          ),
          body: Column(
            children: [
              // Progress indicator for orchestrator mode
              if (_isOrchestratorMode) const AudioLessonProgressIndicator(),
              
              // Main content
              Expanded(
                child: AudioAwareLessonRenderer(
                  content: content,
                  onNext: () => nextPage(contentList.length),
                  isOrchestratorMode: _isOrchestratorMode,
                ),
              ),
              
              // Manual navigation controls (when not in orchestrator mode)
              if (!_isOrchestratorMode) _buildManualControls(contentList.length),
            ],
          ),
          
          // Floating hands-free indicator
          floatingActionButton: _isOrchestratorMode ? const HandsFreeIndicator() : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
        );
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error),
    );
  }

  Widget _buildManualControls(int totalContent) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          ElevatedButton.icon(
            onPressed: pageIndex > 0 ? previousPage : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
          ),
          
          // Page indicator
          Text(
            '${pageIndex + 1} of $totalContent',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          
          // Next button
          ElevatedButton.icon(
            onPressed: pageIndex < totalContent - 1 ? () => nextPage(totalContent) : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }

  void _toggleOrchestratorMode() async {
    setState(() {
      _isOrchestratorMode = !_isOrchestratorMode;
    });

    if (_isOrchestratorMode) {
      await _initializeOrchestrator();
    } else {
      final orchestrator = ref.read(audioLessonOrchestratorProvider);
      await orchestrator.stopLesson();
      
      final settingsNotifier = ref.read(audioLessonSettingsProvider.notifier);
      settingsNotifier.toggleHandsFreeMode();
    }
  }

  void _showVoiceCommandsHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const VoiceCommandHelpDialog(),
    );
  }

  void _handleLessonComplete() {
    final studyState = ref.read(studyProvider);
    final lessonAsync = ref.read(lessonProvider(widget.lessonId));

    lessonAsync.whenData((lessonData) {
      // Build missed terms from studyProvider.termStatus
      final missedTerms = lessonData.lesson.terms
          .where((t) => studyState.termStatus[t.id] == false)
          .map((t) => MissedTerm(term: t))
          .toList();

      // Build missed questions from studyProvider.questionAnswers
      final missedQuestions = <MissedQuestion>[];
      for (final q in lessonData.lesson.questions) {
        final selected = studyState.questionAnswers[q.id];
        if (selected != null && selected != q.correctAnswer) {
          missedQuestions.add(MissedQuestion(question: q, selectedAnswer: selected));
        }
      }

      final totalItems = lessonData.lesson.terms.length +
          lessonData.lesson.questions.length;
      final correctItems = totalItems - missedTerms.length - missedQuestions.length;

      final result = SessionResult(
        mode: SessionMode.lesson,
        correct: correctItems,
        total: totalItems,
        missedTerms: missedTerms,
        missedQuestions: missedQuestions,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SessionResultsScreen(result: result),
          ),
        );
      }
    });
  }

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Lesson')),
      body: const Center(
        child: Text('No content available for this lesson.'),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Loading...')),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading lesson: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
