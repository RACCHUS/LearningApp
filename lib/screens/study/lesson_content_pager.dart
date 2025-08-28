import 'package:flutter/material.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';

class LessonContentPager extends StatefulWidget {
  final List<LessonContent> contentList;
  final VoidCallback? onLessonComplete;
  const LessonContentPager({super.key, required this.contentList, this.onLessonComplete});

  @override
  State<LessonContentPager> createState() => _LessonContentPagerState();
}

class _LessonContentPagerState extends State<LessonContentPager> {
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
    final contentList = widget.contentList;
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
              Text(
                'Page ${_currentPageIndex + 1} of ${contentList.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
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
              if (content is TermContent) {
                final term = Term.fromTermContent(content);
                contentWidget = FlashcardScreen(
                  terms: [term],
                  onComplete: isLastItem ? widget.onLessonComplete : null,
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
                contentWidget = McqScreen(
                  questions: [question],
                  onComplete: isLastItem ? widget.onLessonComplete : null,
                );
              } else if (content is ConceptContent) {
                contentWidget = ConceptScreen(
                  concepts: [content],
                  isLastInLesson: isLastItem,
                  onComplete: isLastItem ? widget.onLessonComplete : null,
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
