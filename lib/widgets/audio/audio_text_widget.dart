import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/widgets/audio_control_widget.dart';

/// A reusable widget that displays text with an optional audio control
class AudioTextWidget extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final String contentType; // 'question', 'answer', 'content'
  final bool autoPlay;
  final bool showAudioControl;
  final TextAlign textAlign;
  final Widget Function(String)? customTextBuilder;

  const AudioTextWidget({
    super.key,
    required this.text,
    this.style,
    this.contentType = 'content',
    this.autoPlay = false,
    this.showAudioControl = true,
    this.textAlign = TextAlign.start,
    this.customTextBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSpeak = ref.watch(canSpeakProvider);
    
    if (!canSpeak || !showAudioControl) {
      // Just show text without audio controls
      return _buildText();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildText()),
        const SizedBox(width: 8),
        AudioControlWidget(
          text: text,
          contentType: contentType,
          autoPlay: autoPlay,
          tooltip: _getTooltip(),
        ),
      ],
    );
  }

  Widget _buildText() {
    if (customTextBuilder != null) {
      return customTextBuilder!(text);
    }
    
    return Text(
      text,
      style: style,
      textAlign: textAlign,
    );
  }

  String _getTooltip() {
    switch (contentType) {
      case 'question':
        return 'Listen to question';
      case 'answer':
        return 'Listen to answer';
      case 'content':
        return 'Listen to content';
      default:
        return 'Listen';
    }
  }
}
