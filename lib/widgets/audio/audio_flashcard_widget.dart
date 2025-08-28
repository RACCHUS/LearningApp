import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/widgets/audio_control_widget.dart';

/// A reusable widget for flashcard content with audio
class AudioFlashcardWidget extends ConsumerStatefulWidget {
  final String frontText;
  final String backText;
  final String? example;
  final TextStyle? frontStyle;
  final TextStyle? backStyle;
  final Widget Function(String)? customTextBuilder;

  const AudioFlashcardWidget({
    super.key,
    required this.frontText,
    required this.backText,
    this.example,
    this.frontStyle,
    this.backStyle,
    this.customTextBuilder,
  });

  @override
  ConsumerState<AudioFlashcardWidget> createState() => _AudioFlashcardWidgetState();
}

class _AudioFlashcardWidgetState extends ConsumerState<AudioFlashcardWidget> {
  bool _showBack = false;

  @override
  Widget build(BuildContext context) {
    final canSpeak = ref.watch(canSpeakProvider);
    final currentText = _showBack ? widget.backText : widget.frontText;
    final currentStyle = _showBack ? widget.backStyle : widget.frontStyle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main content with audio
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: widget.customTextBuilder?.call(currentText) ?? 
                         Text(currentText, style: currentStyle, textAlign: TextAlign.center),
                ),
                if (canSpeak) ...[
                  const SizedBox(width: 8),
                  AudioControlWidget(
                    text: currentText,
                    contentType: 'content',
                    autoPlay: !_showBack, // Auto-play front side
                    tooltip: _showBack ? 'Listen to definition' : 'Listen to term',
                  ),
                ],
              ],
            ),
            
            // Example text with audio (if exists and showing back)
            if (_showBack && widget.example != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: widget.customTextBuilder?.call('Example: ${widget.example}') ?? 
                           Text(
                             'Example: ${widget.example}',
                             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                               fontStyle: FontStyle.italic,
                             ),
                           ),
                  ),
                  if (canSpeak) ...[
                    const SizedBox(width: 8),
                    AudioControlWidget(
                      text: 'Example: ${widget.example}',
                      contentType: 'content',
                      tooltip: 'Listen to example',
                    ),
                  ],
                ],
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Flip button
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showBack = !_showBack;
                });
              },
              icon: Icon(_showBack ? Icons.visibility_off : Icons.visibility),
              label: Text(_showBack ? 'Show Term' : 'Show Definition'),
            ),
          ],
        ),
      ),
    );
  }
}
