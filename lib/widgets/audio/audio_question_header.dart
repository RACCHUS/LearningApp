import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/widgets/audio_control_widget.dart';

/// A reusable widget for question headers with audio and voice input
class AudioQuestionHeader extends ConsumerWidget {
  final String questionText;
  final TextStyle? textStyle;
  final Widget Function(String)? customTextBuilder;
  final Function(String)? onVoiceInput;
  final String? voiceInputHint;
  final bool showVoiceInput;

  const AudioQuestionHeader({
    super.key,
    required this.questionText,
    this.textStyle,
    this.customTextBuilder,
    this.onVoiceInput,
    this.voiceInputHint,
    this.showVoiceInput = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSpeak = ref.watch(canSpeakProvider);
    final canListen = ref.watch(canListenProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question text with audio control
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: customTextBuilder?.call(questionText) ?? 
                     Text(questionText, style: textStyle),
            ),
            if (canSpeak) ...[
              const SizedBox(width: 8),
              AudioControlWidget(
                text: questionText,
                contentType: 'question',
                autoPlay: true,
                tooltip: 'Listen to question',
              ),
            ],
          ],
        ),
        
        // Voice input section
        if (showVoiceInput && onVoiceInput != null && canListen) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              VoiceInputButton(
                tooltip: voiceInputHint ?? 'Voice answer',
                onResult: onVoiceInput,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  voiceInputHint ?? 'Speak your answer',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
