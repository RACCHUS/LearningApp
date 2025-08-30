import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/widgets/audio/hands_free_indicator.dart';
import 'package:learning_pwa/widgets/content_renderers/term_content_renderer.dart';
import 'package:learning_pwa/widgets/content_renderers/question_content_renderer.dart';
import 'package:learning_pwa/widgets/content_renderers/concept_content_renderer.dart';

class AudioAwareLessonRenderer extends ConsumerWidget {
  final LessonContent content;
  final VoidCallback onNext;
  final bool isOrchestratorMode;

  const AudioAwareLessonRenderer({
    super.key,
    required this.content,
    required this.onNext,
    this.isOrchestratorMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Show hands-free indicator when orchestrator is active
        if (isOrchestratorMode) const HandsFreeIndicator(),
        
        // Show progress indicator when orchestrator is active
        if (isOrchestratorMode) const AudioLessonProgressIndicator(),
        
        // Render the actual content
        Expanded(
          child: _buildContentWidget(context, ref),
        ),
      ],
    );
  }

  Widget _buildContentWidget(BuildContext context, WidgetRef ref) {
    // In orchestrator mode, the orchestrator handles all audio
    // so we disable autoplay in individual widgets
    final autoPlayOverride = isOrchestratorMode ? false : null;

    if (content is TermContent) {
      return TermContentRenderer(
        content: content as TermContent,
        autoPlayOverride: autoPlayOverride,
      );
    } else if (content is QuestionContent) {
      return QuestionContentRenderer(
        content: content as QuestionContent,
        onNext: onNext,
        autoPlayOverride: autoPlayOverride,
        isOrchestratorMode: isOrchestratorMode,
      );
    } else if (content is ConceptContent) {
      return ConceptContentRenderer(
        content: content as ConceptContent,
        autoPlayOverride: autoPlayOverride,
      );
    } else {
      return _buildGenericContent(context);
    }
  }

  Widget _buildGenericContent(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Unsupported content type: ${content.runtimeType}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
