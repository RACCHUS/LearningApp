import 'package:flutter/material.dart';
import 'package:learning_pwa/widgets/audio_control_widget.dart';

/// Flashcard study content widget
/// 
/// Displays terms and definitions with flip animation,
/// audio controls, and intuitive interaction.
class FlashcardContent extends StatefulWidget {
  final dynamic term;

  const FlashcardContent({
    super.key,
    required this.term,
  });

  @override
  State<FlashcardContent> createState() => _FlashcardContentState();
}

class _FlashcardContentState extends State<FlashcardContent> {
  bool showDefinition = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentText = showDefinition ? widget.term.definition : widget.term.term;
    
    return Column(
      children: [
        // Audio control and flip button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AudioControlWidget(
              text: currentText,
              tooltip: showDefinition ? 'Listen to definition' : 'Listen to term',
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _toggleCard,
              icon: Icon(showDefinition ? Icons.quiz : Icons.lightbulb),
              label: Text(showDefinition ? 'Show Term' : 'Show Definition'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Flashcard content with tap to flip
        Expanded(
          child: GestureDetector(
            onTap: _toggleCard,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      currentText,
                      key: ValueKey(showDefinition),
                      style: textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Instruction text
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Tap the card or button to flip',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  void _toggleCard() {
    setState(() {
      showDefinition = !showDefinition;
    });
  }
}
