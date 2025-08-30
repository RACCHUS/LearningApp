import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:learning_pwa/widgets/audio/hands_free_indicator.dart';
import 'package:learning_pwa/widgets/audio_aware_lesson_renderer.dart';

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Stop orchestrator if active (check if mounted to avoid ref access after disposal)
    if (_isOrchestratorMode && mounted) {
      try {
        final orchestrator = ref.read(audioLessonOrchestratorProvider);
        orchestrator.stopLesson();
      } catch (e) {
        // Ignore errors during disposal
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
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
    setState(() {
      _isOrchestratorMode = !_isOrchestratorMode;
    });

    if (_isOrchestratorMode) {
      await _initializeOrchestrator();
    } else {
      final orchestrator = ref.read(audioLessonOrchestratorProvider);
      await orchestrator.stopLesson();
    }
  }

  Future<void> _initializeOrchestrator() async {
    final orchestrator = ref.read(audioLessonOrchestratorProvider);
    final settingsNotifier = ref.read(audioLessonSettingsProvider.notifier);
    
    // Enable hands-free mode
    settingsNotifier.toggleHandsFreeMode();
    
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
        if (next != _currentPageIndex) {
          _navigateToPage(next);
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
