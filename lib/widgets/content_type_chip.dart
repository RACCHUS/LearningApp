import 'package:flutter/material.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/term_content.dart';

class ContentTypeChip extends StatelessWidget {
  final List<LessonContent> contentList;
  final String label;
  final IconData icon;
  final Color color;

  const ContentTypeChip({
    super.key,
    required this.contentList,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final count = contentList.where((content) {
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
