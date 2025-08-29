import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/widgets/audio/audio_question_header.dart';
import 'package:learning_pwa/widgets/audio_control_widget.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/models/voice_command.dart';

/// A reusable widget for MCQ options with audio
class AudioMCQWidget extends ConsumerStatefulWidget {
  final String questionText;
  final List<String> options;
  final int? correctAnswer;
  final int? selectedAnswer; // Previously selected answer index
  final String? explanation;
  final Function(int)? onAnswerSelected;
  final bool showResults;
  final Widget Function(String)? customTextBuilder;

  const AudioMCQWidget({
    super.key,
    required this.questionText,
    required this.options,
    this.correctAnswer,
    this.selectedAnswer,
    this.explanation,
    this.onAnswerSelected,
    this.showResults = false,
    this.customTextBuilder,
  });

  @override
  ConsumerState<AudioMCQWidget> createState() => _AudioMCQWidgetState();
}

class _AudioMCQWidgetState extends ConsumerState<AudioMCQWidget> {
  int? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _selectedAnswer = widget.selectedAnswer;
  }

  @override
  Widget build(BuildContext context) {
    final canSpeak = ref.watch(canSpeakProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question header with audio and voice input
        AudioQuestionHeader(
          questionText: widget.questionText,
          textStyle: Theme.of(context).textTheme.titleLarge,
          customTextBuilder: widget.customTextBuilder,
          onVoiceInput: _handleVoiceAnswer,
          voiceInputHint: 'Say A, B, C, or D',
        ),
        
        const SizedBox(height: 24),
        
        // Options with audio
        ...widget.options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final optionLetter = String.fromCharCode(65 + index); // A, B, C, D
          final isSelected = _selectedAnswer == index;
          final isCorrect = widget.correctAnswer == index;
          
          Color? backgroundColor;
          if (widget.showResults && _selectedAnswer != null) {
            if (isSelected) {
              backgroundColor = isCorrect ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2);
            } else if (isCorrect) {
              backgroundColor = Colors.green.withValues(alpha: 0.1);
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: RadioListTile<int>(
                title: Row(
                  children: [
                    Expanded(
                      child: widget.customTextBuilder?.call('$optionLetter. $option') ??
                             Text('$optionLetter. $option'),
                    ),
                    if (canSpeak) ...[
                      const SizedBox(width: 8),
                      AudioControlWidget(
                        text: '$optionLetter. $option',
                        contentType: 'answer',
                        tooltip: 'Listen to option $optionLetter',
                      ),
                    ],
                  ],
                ),
                value: index,
                groupValue: _selectedAnswer,
                onChanged: widget.showResults ? null : (value) {
                  setState(() {
                    _selectedAnswer = value;
                  });
                  widget.onAnswerSelected?.call(value!);
                },
              ),
            ),
          );
        }),
        
        // Explanation with audio (if showing results and explanation exists)
        if (widget.showResults && widget.explanation != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explanation:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      widget.customTextBuilder?.call(widget.explanation!) ??
                      Text(widget.explanation!),
                    ],
                  ),
                ),
                if (canSpeak) ...[
                  const SizedBox(width: 8),
                  AudioControlWidget(
                    text: widget.explanation!,
                    contentType: 'content',
                    tooltip: 'Listen to explanation',
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _handleVoiceAnswer(String voiceInput) {
    // Use the sophisticated VoiceCommand parsing system
    final command = VoiceCommand.parseCommand(voiceInput);
    int? answerIndex;
    
    if (command != null && command.type == VoiceCommandType.answer) {
      // Handle MCQ answers (A, B, C, D)
      if (command.value is String) {
        final answer = command.value as String;
        switch (answer) {
          case 'A':
            answerIndex = 0;
            break;
          case 'B':
            answerIndex = 1;
            break;
          case 'C':
            answerIndex = 2;
            break;
          case 'D':
            answerIndex = 3;
            break;
        }
      }
    } else {
      // Fallback to simple parsing for backwards compatibility
      final input = voiceInput.toLowerCase().trim();
      if (input.contains('a') || input.contains('first')) {
        answerIndex = 0;
      } else if (input.contains('b') || input.contains('second')) {
        answerIndex = 1;
      } else if (input.contains('c') || input.contains('third')) {
        answerIndex = 2;
      } else if (input.contains('d') || input.contains('fourth')) {
        answerIndex = 3;
      }
    }
    
    if (answerIndex != null && answerIndex < widget.options.length) {
      setState(() {
        _selectedAnswer = answerIndex;
      });
      widget.onAnswerSelected?.call(answerIndex);
    }
  }
}
