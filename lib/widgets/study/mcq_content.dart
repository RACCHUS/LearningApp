import 'package:flutter/material.dart';
import 'package:learning_pwa/widgets/audio_control_widget.dart';
import 'package:learning_pwa/theme/app_theme.dart';

/// Multiple choice question study content widget
/// 
/// Displays questions with options, supports voice input,
/// and provides audio controls for accessibility.
class McqContent extends StatefulWidget {
  final dynamic question;

  const McqContent({
    super.key,
    required this.question,
  });

  @override
  State<McqContent> createState() => _McqContentState();
}

class _McqContentState extends State<McqContent> {
  int? selectedAnswer;

  @override
  void initState() {
    super.initState();
    // Reset selection when question changes
    selectedAnswer = null;
  }

  @override
  void didUpdateWidget(McqContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset selection when question changes
    if (oldWidget.question != widget.question) {
      selectedAnswer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question with audio control
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.question.questionText,
                style: textTheme.titleLarge,
              ),
            ),
            AudioControlWidget(
              text: widget.question.questionText,
              tooltip: 'Listen to question',
              contentType: 'question',
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Voice input instructions
        _VoiceInputInstruction(),
        
        const SizedBox(height: 24),
        
        // Answer options
        Expanded(
          child: ListView.builder(
            itemCount: widget.question.options.length,
            itemBuilder: (context, index) {
              final option = widget.question.options[index];
              final optionLetter = String.fromCharCode(65 + index); // A, B, C, D
              
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: Text('$optionLetter. $option'),
                        value: index,
                        groupValue: selectedAnswer,
                        onChanged: (value) {
                          setState(() {
                            selectedAnswer = value;
                          });
                        },
                      ),
                    ),
                    AudioControlWidget(
                      text: '$optionLetter. $option',
                      tooltip: 'Listen to option $optionLetter',
                      contentType: 'answer',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Answer feedback
        if (selectedAnswer != null) ...[
          const SizedBox(height: 16),
          _AnswerFeedback(
            selectedIndex: selectedAnswer!,
            correctIndex: widget.question.correctIndex,
            explanation: widget.question.explanation,
          ),
        ],
      ],
    );
  }
}

/// Voice input instruction widget
class _VoiceInputInstruction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.mic,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          'Say your answer (A, B, C, or D) or tap below',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Answer feedback widget showing correctness and explanation
class _AnswerFeedback extends StatelessWidget {
  final int selectedIndex;
  final int correctIndex;
  final String? explanation;

  const _AnswerFeedback({
    required this.selectedIndex,
    required this.correctIndex,
    this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = selectedIndex == correctIndex;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect 
          ? colorScheme.surfaceContainerHighest
          : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? colorScheme.primary : colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct!' : 'Incorrect',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isCorrect ? colorScheme.primary : colorScheme.error,
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 4),
            Text(
              'Correct answer: ${String.fromCharCode(65 + correctIndex)}',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ],
          if (explanation != null && explanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation!,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
