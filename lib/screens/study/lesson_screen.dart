import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/providers/offline_provider.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';

class LessonScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const LessonScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late PageController _pageController;
  int _currentPageIndex = 0;
  bool _isLastPage = false;
  bool _isFirstPage = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));

    return lessonAsync.when(
      data: (lessonData) {
        final contentList = lessonData.lessonContent;
        
        // Reset page state when lesson data changes
        if (_currentPageIndex >= contentList.length) {
          _currentPageIndex = 0;
          _isLastPage = contentList.isEmpty;
          _isFirstPage = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lessonData.lesson.title,
                  style: theme.textTheme.titleMedium,
                ),
                if (contentList.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_currentPageIndex + 1} of ${contentList.length} • ${_getContentType(contentList[_currentPageIndex])}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              // Download button for offline access
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Download for offline',
                onPressed: () {
                  ref
                      .read(offlineProvider.notifier)
                      .cacheLesson(lessonData.lesson);
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4.0),
              child: LinearProgressIndicator(
                value: contentList.isEmpty ? 0 : (_currentPageIndex + 1) / contentList.length,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: theme.colorScheme.primary,
                minHeight: 2,
              ),
            ),
          ),
          body: contentList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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
              : PageView.builder(
                  controller: _pageController,
                  itemCount: contentList.length,
                  onPageChanged: (index) => _onPageChanged(index, contentList.length),
                  itemBuilder: (context, index) {
                    final content = contentList[index];
                    final isLastItem = index == contentList.length - 1;
                    
                    // Wrap each content type in a consistent container
                    Widget contentWidget;
                    
                    if (content is TermContent) {
                      // Convert TermContent to Term
                      final term = Term.fromTermContent(content);
                      contentWidget = FlashcardScreen(
                        terms: [term],
                        onComplete: isLastItem ? _onLessonComplete : null,
                      );
                    } else if (content is QuestionContent) {
                      // Convert QuestionContent to Question
                      final question = Question(
                        id: content.id,
                        questionText: content.questionText,
                        options: content.options,
                        correctAnswer: content.correctAnswer,
                        type: 'multiple_choice', // Default type
                        explanation: content.explanation,
                        createdBy: 'system', // Default value since content classes don't have createdBy
                      );
                      contentWidget = McqScreen(
                        questions: [question],
                        onComplete: isLastItem ? _onLessonComplete : null,
                      );
                    } else if (content is ConceptContent) {
                      contentWidget = ConceptScreen(
                        concepts: [content],
                        isLastInLesson: isLastItem,
                        onComplete: isLastItem ? _onLessonComplete : null,
                      );
                    } else {
                      contentWidget = const Center(child: Text('Unsupported content type'));
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: contentWidget,
                    );
                  },
                ),
          // Navigation buttons
          bottomNavigationBar: contentList.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous button
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

                        // Next/Complete button
                        ElevatedButton(
                          onPressed: () {
                            if (_isLastPage) {
                              _onLessonComplete();
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Review Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Back to Lessons'),
          ),
        ],
      ),
    );
  }

  String _getContentType(LessonContent content) {
    if (content is TermContent) return 'Flashcard';
    if (content is QuestionContent) return 'Question';
    if (content is ConceptContent) return 'Concept';
    return 'Content';
  }
}
