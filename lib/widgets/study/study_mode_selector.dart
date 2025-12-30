import 'package:flutter/material.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Widget for selecting and displaying study mode options
/// 
/// Provides a clean interface for users to choose between
/// flashcards, MCQ, concepts, and mixed mode studying.
class StudyModeSelector extends StatefulWidget {
  final StudyMode selectedMode;
  final ValueChanged<StudyMode> onModeChanged;
  final VoidCallback onStartStudy;

  const StudyModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.onStartStudy,
  });

  @override
  State<StudyModeSelector> createState() => _StudyModeSelectorState();
}

class _StudyModeSelectorState extends State<StudyModeSelector> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Study Mode',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.space5),
          
          // Flashcards mode
          _StudyModeCard(
            title: 'Flashcards',
            description: 'Study with interactive flashcards',
            icon: Icons.style,
            mode: StudyMode.flashcard,
            selectedMode: widget.selectedMode,
            onModeChanged: widget.onModeChanged,
          ),
          const SizedBox(height: DesignTokens.space4),
          
          // MCQ mode
          _StudyModeCard(
            title: 'Multiple Choice',
            description: 'Test your knowledge with questions',
            icon: Icons.question_answer,
            mode: StudyMode.mcq,
            selectedMode: widget.selectedMode,
            onModeChanged: widget.onModeChanged,
          ),
          const SizedBox(height: DesignTokens.space4),
          
          // Concepts mode
          _StudyModeCard(
            title: 'Concepts',
            description: 'Review key concepts and examples',
            icon: Icons.book,
            mode: StudyMode.concept,
            selectedMode: widget.selectedMode,
            onModeChanged: widget.onModeChanged,
          ),
          const SizedBox(height: DesignTokens.space4),
          
          // Mixed mode
          _StudyModeCard(
            title: 'Mixed Mode',
            description: 'Combine all types for comprehensive learning',
            icon: Icons.shuffle,
            mode: StudyMode.lesson,
            selectedMode: widget.selectedMode,
            onModeChanged: widget.onModeChanged,
          ),
          
          const Spacer(),
          
          // Start studying button
          FilledButton.icon(
            onPressed: widget.onStartStudy,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Studying'),
          ),
        ],
      ),
    );
  }
}

/// Individual mode selection card widget
class _StudyModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final StudyMode mode;
  final StudyMode selectedMode;
  final ValueChanged<StudyMode> onModeChanged;

  const _StudyModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.mode,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selectedMode == mode;

    return Card(
      color: isSelected 
        ? colorScheme.primaryContainer
        : colorScheme.surface,
      child: InkWell(
        onTap: () => onModeChanged(mode),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              ),
              const SizedBox(width: DesignTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: DesignTokens.space4),
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
