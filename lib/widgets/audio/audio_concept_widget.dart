import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/widgets/audio/audio_text_widget.dart';

/// A reusable widget for concept content with audio
class AudioConceptWidget extends ConsumerWidget {
  final String conceptText;
  final String? exampleText;
  final List<String>? keyPoints;
  final Widget Function(String)? customTextBuilder;

  const AudioConceptWidget({
    super.key,
    required this.conceptText,
    this.exampleText,
    this.keyPoints,
    this.customTextBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main concept text with audio
        AudioTextWidget(
          text: conceptText,
          style: Theme.of(context).textTheme.titleLarge,
          contentType: 'content',
          autoPlay: true,
          customTextBuilder: customTextBuilder,
        ),
        
        // Example text with audio (if exists)
        if (exampleText != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          AudioTextWidget(
            text: 'Example: $exampleText',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
            ),
            contentType: 'content',
            customTextBuilder: customTextBuilder,
          ),
        ],
        
        // Key points with audio (if exist)
        if (keyPoints != null && keyPoints!.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Key Points:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...keyPoints!.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AudioTextWidget(
              text: '• $point',
              style: Theme.of(context).textTheme.bodyMedium,
              contentType: 'content',
              customTextBuilder: customTextBuilder,
            ),
          )),
        ],
      ],
    );
  }
}
