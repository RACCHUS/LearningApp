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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page ${_currentPageIndex + 1} of ${contentList.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
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

class PageNavigatorWidget extends StatefulWidget {
  final List<LessonContent> contentList;
  final int currentPageIndex;
  final Function(int) onPageSelected;

  const PageNavigatorWidget({
    super.key,
    required this.contentList,
    required this.currentPageIndex,
    required this.onPageSelected,
  });

  @override
  State<PageNavigatorWidget> createState() => _PageNavigatorWidgetState();
}

class _PageNavigatorWidgetState extends State<PageNavigatorWidget> {
  List<LessonContent> _filteredContent = [];

  @override
  void initState() {
    super.initState();
    _filteredContent = widget.contentList;
  }

  void _filterContent(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContent = widget.contentList;
      } else {
        _filteredContent = widget.contentList.where((content) {
          String title;
          if (content is TermContent) {
            title = content.term;
          } else if (content is QuestionContent) {
            title = 'Question';
          } else if (content is ConceptContent) {
            title = content.conceptText;
          } else {
            title = 'Content';
          }
          return title.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Text(
              'Jump to Page',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search content...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _filterContent,
            ),
            const SizedBox(height: 16),
            // Content summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildContentTypeChip(context, 'Terms', Icons.auto_stories, Colors.blue),
                _buildContentTypeChip(context, 'Concepts', Icons.lightbulb, Colors.green),
                _buildContentTypeChip(context, 'Questions', Icons.quiz, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            // Content list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredContent.length,
                itemBuilder: (context, filteredIndex) {
                  final content = _filteredContent[filteredIndex];
                  // Find the original index in the full content list
                  final originalIndex = widget.contentList.indexOf(content);
                  final isCurrentPage = originalIndex == widget.currentPageIndex;
                  
                  // Determine content type and title
                  String title;
                  IconData icon;
                  Color iconColor;
                  
                  if (content is TermContent) {
                    title = content.term;
                    icon = Icons.auto_stories;
                    iconColor = Colors.blue;
                  } else if (content is QuestionContent) {
                    title = 'Question ${originalIndex + 1}';
                    icon = Icons.quiz;
                    iconColor = Colors.orange;
                  } else if (content is ConceptContent) {
                    title = content.conceptText;
                    icon = Icons.lightbulb;
                    iconColor = Colors.green;
                  } else {
                    title = 'Content ${originalIndex + 1}';
                    icon = Icons.article;
                    iconColor = Colors.grey;
                  }
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isCurrentPage 
                        ? Theme.of(context).colorScheme.primaryContainer 
                        : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: iconColor.withValues(alpha: 0.2),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: isCurrentPage ? FontWeight.bold : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Page ${originalIndex + 1}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: isCurrentPage 
                          ? Icon(
                              Icons.check_circle, 
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => widget.onPageSelected(originalIndex),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTypeChip(BuildContext context, String label, IconData icon, Color color) {
    final count = widget.contentList.where((content) {
      if (label == 'Terms') return content is TermContent;
      if (label == 'Concepts') return content is ConceptContent;
      if (label == 'Questions') return content is QuestionContent;
      return false;
    }).length;

    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text('$label ($count)'),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}
