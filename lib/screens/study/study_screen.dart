import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/theme/app_theme.dart';

class StudyScreen extends ConsumerStatefulWidget {
  final Lesson lesson;

  const StudyScreen({
    super.key,
    required this.lesson,
  });

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  late StudyMode selectedMode;
  bool showModeSelection = true;

  @override
  void initState() {
    super.initState();
    selectedMode = StudyMode.lesson;
  }

  Widget _buildModeSelection() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
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
          const SizedBox(height: AppTheme.spacing24),
          _buildModeCard(
            title: 'Flashcards',
            description: 'Study with interactive flashcards',
            icon: Icons.style,
            mode: StudyMode.flashcard,
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildModeCard(
            title: 'Multiple Choice',
            description: 'Test your knowledge with questions',
            icon: Icons.question_answer,
            mode: StudyMode.mcq,
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildModeCard(
            title: 'Concepts',
            description: 'Review key concepts and examples',
            icon: Icons.book,
            mode: StudyMode.concept,
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildModeCard(
            title: 'Mixed Mode',
            description: 'Combine all types for comprehensive learning',
            icon: Icons.shuffle,
            mode: StudyMode.lesson,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              ref.read(studyProvider.notifier).startStudySession(
                widget.lesson.id, 
                selectedMode,
              );
              setState(() {
                showModeSelection = false;
              });
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Studying'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required StudyMode mode,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selectedMode == mode;

    return Card(
      color: isSelected 
        ? colorScheme.primaryContainer
        : colorScheme.surface,
      child: InkWell(
        onTap: () {
          setState(() {
            selectedMode = mode;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              ),
              const SizedBox(width: AppTheme.spacing16),
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
                const SizedBox(width: AppTheme.spacing16),
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

  @override
  Widget build(BuildContext context) {
    final studyState = ref.watch(studyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              setState(() {
                showModeSelection = true;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: showModeSelection 
          ? _buildModeSelection()
          : Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: studyState.currentIndex / 
                       (studyState.currentContent?.length ?? 1),
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
              
              // Main content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacing24),
                      child: studyState.isLoading || studyState.currentContent == null
                        ? const Center(child: CircularProgressIndicator())
                        : _StudyContent(
                            content: studyState.currentContent![studyState.currentIndex],
                            mode: studyState.currentMode!,
                          ),
                  ),
                ),
              ),
            ),
            
            // Bottom controls
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FilledButton.tonal(
                    onPressed: studyState.currentIndex > 0
                        ? () {
                            ref.read(studyProvider.notifier).previous();
                          }
                        : null,
                    child: const Text('Previous'),
                  ),
                  FilledButton(
                    onPressed: studyState.currentIndex < 
                              (studyState.currentContent?.length ?? 0) - 1
                        ? () {
                            ref.read(studyProvider.notifier).next();
                          }
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyContent extends StatelessWidget {
  final dynamic content;
  final StudyMode mode;

  const _StudyContent({
    required this.content,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    switch (mode) {
      case StudyMode.flashcard:
        return _FlashcardContent(
          term: content,
          textTheme: textTheme,
        );
      case StudyMode.mcq:
        return _MCQContent(
          question: content,
          textTheme: textTheme,
        );
      case StudyMode.concept:
        return _ConceptContent(
          concept: content,
          textTheme: textTheme,
        );
      default:
        return const Center(
          child: Text('Unsupported study mode'),
        );
    }
  }
}

class _FlashcardContent extends StatefulWidget {
  final dynamic term;
  final TextTheme textTheme;

  const _FlashcardContent({
    required this.term,
    required this.textTheme,
  });

  @override
  State<_FlashcardContent> createState() => _FlashcardContentState();
}

class _FlashcardContentState extends State<_FlashcardContent> {
  bool showDefinition = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          showDefinition = !showDefinition;
        });
      },
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            showDefinition ? widget.term.definition : widget.term.term,
            key: ValueKey(showDefinition),
            style: widget.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _MCQContent extends StatelessWidget {
  final dynamic question;
  final TextTheme textTheme;

  const _MCQContent({
    required this.question,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.questionText,
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: AppTheme.spacing24),
        ...question.options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
            child: RadioListTile(
              title: Text(option),
              value: index,
              groupValue: null, // TODO: Connect to provider
              onChanged: (value) {
                // TODO: Handle answer selection
              },
            ),
          );
        }),
      ],
    );
  }
}

class _ConceptContent extends StatelessWidget {
  final dynamic concept;
  final TextTheme textTheme;

  const _ConceptContent({
    required this.concept,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            concept.conceptText,
            style: textTheme.bodyLarge,
          ),
          if (concept.exampleText != null) ...[
            const SizedBox(height: AppTheme.spacing24),
            const Divider(),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Example:',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              concept.exampleText!,
              style: textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
