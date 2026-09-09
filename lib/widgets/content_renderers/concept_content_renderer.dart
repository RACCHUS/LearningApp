import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/widgets/audio/audio_concept_widget.dart';

class ConceptContentRenderer extends StatelessWidget {
  final ConceptContent content;
  final bool? autoPlayOverride;

  const ConceptContentRenderer({
    super.key,
    required this.content,
    this.autoPlayOverride,
  });

  @override
  Widget build(BuildContext context) {
    // Since AudioConceptWidget doesn't have autoPlay param, 
    // we'll use a custom implementation when orchestrator is active
    if (autoPlayOverride == false) {
      return _buildManualConceptWidget(context);
    }
    
    return AudioConceptWidget(
      conceptText: content.conceptText,
      exampleText: content.exampleText,
      customTextBuilder: _renderText,
    );
  }

  Widget _buildManualConceptWidget(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                content.conceptText,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (content.exampleText != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Example: ${content.exampleText!}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderText(String text) {
    if (text.contains(r'\(') || text.contains(r'\[') || text.contains(r'\frac') || text.contains(r'\sqrt')) {
      return Math.tex(text);
    }
    return Text(text);
  }
}
