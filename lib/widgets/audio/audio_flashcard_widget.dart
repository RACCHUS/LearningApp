import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/widgets/audio_control_widget.dart';

/// A reusable widget for flashcard content with audio
class AudioFlashcardWidget extends ConsumerStatefulWidget {
  final String frontText;
  final String backText;
  final String? example;
  final String? emoji;
  final TextStyle? frontStyle;
  final TextStyle? backStyle;
  final Widget Function(String)? customTextBuilder;
  final bool? autoPlayOverride; // Override autoplay setting
  final bool? isRevealed; // External control over front/back reveal state
  final ValueChanged<bool>? onFlipChanged; // Callback when flip state changes
  final bool showFlipButton; // Whether to show flip button inside card

  const AudioFlashcardWidget({
    super.key,
    required this.frontText,
    required this.backText,
    this.example,
    this.emoji,
    this.frontStyle,
    this.backStyle,
    this.customTextBuilder,
    this.autoPlayOverride,
    this.isRevealed,
    this.onFlipChanged,
    this.showFlipButton = true,
  });

  @override
  ConsumerState<AudioFlashcardWidget> createState() => _AudioFlashcardWidgetState();
}

class _AudioFlashcardWidgetState extends ConsumerState<AudioFlashcardWidget> {
  bool _internalShowBack = false;

  bool get _effectiveShowBack => widget.isRevealed ?? _internalShowBack;

  void _handleFlip() {
    final nextState = !_effectiveShowBack;
    setState(() {
      _internalShowBack = nextState;
    });
    widget.onFlipChanged?.call(nextState);
  }

  @override
  Widget build(BuildContext context) {
    final canSpeak = ref.watch(canSpeakProvider);
    final isBack = _effectiveShowBack;
    final currentText = isBack ? widget.backText : widget.frontText;
    final currentStyle = isBack ? widget.backStyle : widget.frontStyle;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _handleFlip,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji visual anchor (shown on front side only)
              if (!isBack && widget.emoji != null) ...[
                Text(
                  widget.emoji!,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 16),
              ],
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
                      autoPlay: widget.autoPlayOverride ?? (!isBack), // Respect override or auto-play front side
                      tooltip: isBack ? 'Listen to definition' : 'Listen to term',
                    ),
                  ],
                ],
              ),
              
              // Example text with audio (if exists and showing back)
              if (isBack && widget.example != null) ...[
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
              
              if (widget.showFlipButton) ...[
                const SizedBox(height: 24),
                // Flip button
                ElevatedButton.icon(
                  onPressed: _handleFlip,
                  icon: Icon(isBack ? Icons.visibility_off : Icons.visibility),
                  label: Text(isBack ? 'Show Term' : 'Show Definition'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
