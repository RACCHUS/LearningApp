import 'package:flutter/material.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/widgets/content_type_chip.dart';

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
                ContentTypeChip(
                  contentList: widget.contentList,
                  label: 'Terms',
                  icon: Icons.auto_stories,
                  color: Colors.blue,
                ),
                ContentTypeChip(
                  contentList: widget.contentList,
                  label: 'Concepts',
                  icon: Icons.lightbulb,
                  color: Colors.green,
                ),
                ContentTypeChip(
                  contentList: widget.contentList,
                  label: 'Questions',
                  icon: Icons.quiz,
                  color: Colors.orange,
                ),
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
}
