import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/widgets/audio/audio_text_widget.dart';

class TermContentRenderer extends StatelessWidget {
  final TermContent content;
  final bool? autoPlayOverride;

  const TermContentRenderer({
    super.key,
    required this.content,
    this.autoPlayOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AudioTextWidget(
                text: content.term,
                style: Theme.of(context).textTheme.titleLarge,
                contentType: 'content',
                autoPlay: autoPlayOverride ?? true,
                customTextBuilder: _renderText,
              ),
              const SizedBox(height: 16),
              if (content.example != null) ...[
                AudioTextWidget(
                  text: 'Example: ${content.example!}',
                  style: Theme.of(context).textTheme.bodyLarge,
                  contentType: 'content',
                  autoPlay: false, // Don't auto-play examples in individual mode
                ),
                const SizedBox(height: 8),
              ],
              AudioTextWidget(
                text: content.definition,
                style: Theme.of(context).textTheme.titleLarge,
                contentType: 'answer',
                autoPlay: false, // Let user control definition playback
                customTextBuilder: _renderText,
              ),
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
