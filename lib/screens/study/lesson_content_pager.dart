import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';
import 'package:learning_pwa/widgets/page_navigator_widget.dart';
import 'package:learning_pwa/providers/audio_lesson_provider.dart';
import 'package:learning_pwa/providers/audio_playback_provider.dart';
import 'package:learning_pwa/widgets/audio/hands_free_indicator.dart';
import 'package:learning_pwa/widgets/audio_aware_lesson_renderer.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';

class LessonContentPager extends ConsumerStatefulWidget {
  final List<LessonContent> contentList;
  final VoidCallback? onLessonComplete;
  const LessonContentPager({super.key, required this.contentList, this.onLessonComplete});

  @override
  ConsumerState<LessonContentPager> createState() => _LessonContentPagerState();
}

class _LessonContentPagerState extends ConsumerState<LessonContentPager> {
  late PageController _pageController;
  int _currentPageIndex = 0;
  bool _isLastPage = false;
  bool _isFirstPage = true;
  bool _isOrchestratorMode = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    if (kDebugMode) {
      print('🎓 LessonContentPager initialized');
    }
    
    // Check if auto lesson hands-free is enabled after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoEnableLessonHandsFree();
    });
  }
  
  /// Check and auto-enable hands-free mode for lessons if setting is enabled
  Future<void> _checkAutoEnableLessonHandsFree() async {
    try {
      final handsFreeSettings = ref.read(handsFreeSettingsProvider);
      
      if (handsFreeSettings.autoLessonHandsFree && !_isOrchestratorMode) {
        if (kDebugMode) {
          print('🎓 Auto-enabling hands-free mode for lesson content pager');
        }
        
        // Trigger hands-free mode automatically
        _toggleOrchestratorMode();
        
        if (kDebugMode) {
          print('✅ Lesson hands-free mode auto-enabled in content pager');
        }
      } else if (kDebugMode) {
        print('ℹ️ Auto lesson hands-free disabled or already in orchestrator mode');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error auto-enabling lesson hands-free: $e');
      }
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('🎓 LessonContentPager disposing...');
      final globalVoiceState = ref.read(globalVoiceProvider);
      print('🎙️ Global voice state at dispose: enabled=${globalVoiceState.isEnabled}, listening=${globalVoiceState.isListening}');
    }
    
    _pageController.dispose();
    // Stop orchestrator if active (check if mounted to avoid ref access after disposal)
    if (_isOrchestratorMode && mounted) {
      try {
        final orchestrator = ref.read(audioLessonOrchestratorProvider);
        orchestrator.stopLesson();
        if (kDebugMode) {
          print('🎓 Stopped audio lesson orchestrator');
        }
      } catch (e) {
        // Ignore errors during disposal
        if (kDebugMode) {
          print('🎓 Error stopping orchestrator during disposal: $e');
        }
      }
    }
    super.dispose();
  }

  void _onPageChanged(int index, int itemCount) {
    setState(() {
      _currentPageIndex = index;
      _isFirstPage = index == 0;
      _isLastPage = index == itemCount - 1;
    });
  }

  void _navigateToPage(int pageIndex) {
    if (kDebugMode) {
      print('🎓 Navigating to page: $pageIndex (from ${_currentPageIndex})');
      // Log global voice state before navigation
      final globalVoiceState = ref.read(globalVoiceProvider);
      print('🎙️ Global voice state before navigation: enabled=${globalVoiceState.isEnabled}, listening=${globalVoiceState.isListening}');
    }
    
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    // Log voice state after navigation (with slight delay to let animation complete)
    if (kDebugMode) {
      Future.delayed(const Duration(milliseconds: 400), () {
        final globalVoiceState = ref.read(globalVoiceProvider);
        print('🎙️ Global voice state after navigation: enabled=${globalVoiceState.isEnabled}, listening=${globalVoiceState.isListening}');
      });
    }
  }

  void _showPageNavigator(BuildContext context, List<LessonContent> contentList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PageNavigatorWidget(
        contentList: contentList,
        currentPageIndex: _currentPageIndex,
        onPageSelected: (index) {
          Navigator.pop(context);
          _navigateToPage(index);
        },
      ),
    );
  }

  void _toggleOrchestratorMode() async {
    print('🔘 HANDS-FREE BUTTON PRESSED! Current mode: $_isOrchestratorMode'); // Always print
    
    setState(() {
      _isOrchestratorMode = !_isOrchestratorMode;
    });

    if (_isOrchestratorMode) {
      print('🔘 Enabling hands-free mode - calling _initializeOrchestrator()'); // Always print
      await _initializeOrchestrator();
    } else {
      print('🔘 Disabling hands-free mode'); // Always print
      final orchestrator = ref.read(audioLessonOrchestratorProvider);
      await orchestrator.stopLesson();
    }
  }

  Future<void> _initializeOrchestrator() async {
    print('🔘 _initializeOrchestrator() called'); // Always print
    
    final orchestrator = ref.read(audioLessonOrchestratorProvider);
    final settingsNotifier = ref.read(audioLessonSettingsProvider.notifier);
    
    // Request microphone permissions FIRST, before enabling hands-free mode
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);
    print('🎙️ About to request microphone permissions for hands-free mode...'); // Always print
    print('🎙️ Audio notifier: $audioNotifier'); // Always print
    
    final permissionsGranted = await audioNotifier.requestMicrophonePermissions();
    print('🎙️ Permission request completed. Result: $permissionsGranted'); // Always print
    if (!permissionsGranted) {
      if (kDebugMode) {
        print('❌ Microphone permissions denied - hands-free mode not enabled');
      }
      // Show user feedback about permission requirement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Microphone permission is required for hands-free mode.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      // Reset orchestrator mode since permissions were denied
      setState(() {
        _isOrchestratorMode = false;
      });
      return;
    }
    
    if (kDebugMode) {
      print('✅ Microphone permissions granted for hands-free mode');
    }
    
    // Enable hands-free mode AFTER permissions are granted
    settingsNotifier.toggleHandsFreeMode();
    
    // Give a moment for settings to update
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Initialize orchestrator with lesson content
    await orchestrator.initialize();
    await orchestrator.startLesson(widget.contentList, startIndex: _currentPageIndex);
  }

  @override
  Widget build(BuildContext context) {
    final contentList = widget.contentList;
    
    // Listen to orchestrator progress changes
    if (_isOrchestratorMode) {
      ref.listen<int>(audioLessonProgressProvider, (previous, next) {
        if (kDebugMode) {
          print('🎓 Lesson pager received progress change: $previous -> $next');
          print('🎓 Current page index: $_currentPageIndex');
        }
        
        if (next != _currentPageIndex) {
          if (kDebugMode) {
            print('🎓 Navigating to page: $next');
          }
          _navigateToPage(next);
        } else {
          if (kDebugMode) {
            print('🎓 Progress matches current page, no navigation needed');
          }
        }
      });
    }
    
    // Listen to global voice state changes to debug connectivity issues
    if (kDebugMode) {
      ref.listen(globalVoiceProvider, (previous, current) {
        if (previous?.isEnabled != current.isEnabled) {
          print('🎙️ Global voice enabled changed: ${previous?.isEnabled} -> ${current.isEnabled}');
        }
        if (previous?.isListening != current.isListening) {
          print('🎙️ Global voice listening changed: ${previous?.isListening} -> ${current.isListening}');
        }
        if (previous?.statusMessage != current.statusMessage) {
          print('🎙️ Global voice status changed: "${previous?.statusMessage}" -> "${current.statusMessage}"');
        }
      });
    }
    
    if (contentList.isEmpty) {
      return const Center(child: Text('No content available'));
    }
    return Column(
      children: [
        // Progress bar and page indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentPageIndex + 1) / contentList.length,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page ${_currentPageIndex + 1} of ${contentList.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hands-free mode toggle
                      IconButton(
                        icon: Icon(_isOrchestratorMode ? Icons.record_voice_over : Icons.touch_app),
                        tooltip: _isOrchestratorMode ? 'Disable Hands-Free' : 'Enable Hands-Free',
                        onPressed: _toggleOrchestratorMode,
                        iconSize: 20,
                      ),
                      IconButton(
                        onPressed: () => _showPageNavigator(context, contentList),
                        icon: const Icon(Icons.list),
                        tooltip: 'Jump to page',
                        iconSize: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Hands-free indicator when orchestrator is active
        if (_isOrchestratorMode) const HandsFreeIndicator(),
        
        // Debug: Voice command test button (only in orchestrator mode and debug mode)
        if (_isOrchestratorMode && kDebugMode) 
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: FloatingActionButton.small(
              heroTag: "voice_test",
              onPressed: () async {
                final orchestrator = ref.read(audioLessonOrchestratorProvider);
                await orchestrator.simulateVoiceCommand("next");
              },
              child: const Icon(Icons.voice_chat),
              tooltip: "Test Voice 'Next' Command",
            ),
          ),
        
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: contentList.length,
            onPageChanged: (index) => _onPageChanged(index, contentList.length),
            itemBuilder: (context, index) {
              final content = contentList[index];
              final isLastItem = index == contentList.length - 1;
              
              Widget contentWidget;
              
              // Use AudioAwareLessonRenderer when in orchestrator mode
              if (_isOrchestratorMode) {
                contentWidget = AudioAwareLessonRenderer(
                  content: content,
                  isOrchestratorMode: true,
                  onNext: () {
                    if (isLastItem) {
                      widget.onLessonComplete?.call();
                    } else {
                      _navigateToPage(index + 1);
                    }
                  },
                );
              } else {
                // Use traditional individual screens when not in orchestrator mode
                if (content is TermContent) {
                  final term = Term.fromTermContent(content);
                  final finish = () {
                    if (isLastItem) {
                      widget.onLessonComplete?.call();
                    } else {
                      _navigateToPage(index + 1);
                    }
                  };
                  contentWidget = FlashcardScreen(
                    terms: [term],
                    onComplete: finish,
                    isEmbeddedInLesson: true, // Embedded in lesson mode
                  );
                } else if (content is QuestionContent) {
                  final question = Question(
                    id: content.id,
                    questionText: content.questionText,
                    options: content.options,
                    correctAnswer: content.correctAnswer,
                    type: 'multiple_choice',
                    explanation: content.explanation,
                    createdBy: 'system',
                  );
                  final finish = () {
                    if (isLastItem) {
                      widget.onLessonComplete?.call();
                    } else {
                      _navigateToPage(index + 1);
                    }
                  };
                  contentWidget = McqScreen(
                    questions: [question],
                    onComplete: finish,
                    isEmbeddedInLesson: true, // Embedded in lesson mode
                  );
                } else if (content is ConceptContent) {
                  final finish = () {
                    if (isLastItem) {
                      widget.onLessonComplete?.call();
                    } else {
                      _navigateToPage(index + 1);
                    }
                  };
                  contentWidget = ConceptScreen(
                    concepts: [content],
                    isLastInLesson: isLastItem,
                    onComplete: finish,
                    isEmbeddedInLesson: true, // New parameter to indicate lesson mode
                  );
                } else {
                  contentWidget = const Center(child: Text('Unsupported content type'));
                }
              }
              
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: contentWidget,
              );
            },
          ),
        ),
        // Navigation buttons
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isFirstPage)
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    onPressed: () {
                      _navigateToPage(_currentPageIndex - 1);
                    },
                  )
                else
                  const SizedBox(width: 100),
                ElevatedButton(
                  onPressed: () {
                    if (_isLastPage) {
                      widget.onLessonComplete?.call();
                    } else {
                      _navigateToPage(_currentPageIndex + 1);
                    }
                  },
                  child: Text(_isLastPage ? 'Complete Lesson' : 'Next'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
