import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/words/word_sense_item.dart';
import '../../services/words/word_sense_service.dart';

enum PracticeStepMode { spelling, definitionSense }

/// Interactive dual-mode widget combining W1 spelling recall and W2 vocabulary sense matching (P8-3).
class CombinedWordPracticeWidget extends StatefulWidget {
  final WordSenseService senseService;
  final String? category;
  final void Function(int spellingCorrect, int vocabCorrect, int total)?
      onCompleted;

  const CombinedWordPracticeWidget({
    super.key,
    required this.senseService,
    this.category,
    this.onCompleted,
  });

  @override
  State<CombinedWordPracticeWidget> createState() =>
      _CombinedWordPracticeWidgetState();
}

class _CombinedWordPracticeWidgetState
    extends State<CombinedWordPracticeWidget> {
  late List<WordSenseItem> _items;
  int _currentIndex = 0;
  PracticeStepMode _mode = PracticeStepMode.spelling;

  final TextEditingController _spellingController = TextEditingController();
  int? _selectedDefinitionIndex;
  List<String> _shuffledDefinitions = [];

  int _spellingScore = 0;
  int _vocabScore = 0;
  bool _isAnswerChecked = false;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    _items = widget.category != null
        ? widget.senseService.getSensesByCategory(widget.category!)
        : widget.senseService.getAllSenses();
    _setupCurrentWord();
  }

  @override
  void dispose() {
    _spellingController.dispose();
    super.dispose();
  }

  void _setupCurrentWord() {
    if (_items.isEmpty) return;
    _spellingController.clear();
    _selectedDefinitionIndex = null;
    _isAnswerChecked = false;
    _isCorrect = false;

    final current = _items[_currentIndex];
    final allDefs = [
      current.definition,
      ...current.distractorDefinitions.take(3),
    ];
    allDefs.shuffle(Random());
    _shuffledDefinitions = allDefs;
  }

  void _checkSpelling() {
    final current = _items[_currentIndex];
    final typed = _spellingController.text.trim();
    final correct = typed.toLowerCase() == current.word.toLowerCase();

    setState(() {
      _isAnswerChecked = true;
      _isCorrect = correct;
      if (correct) _spellingScore++;
    });
  }

  void _checkDefinition() {
    if (_selectedDefinitionIndex == null) return;
    final current = _items[_currentIndex];
    final chosen = _shuffledDefinitions[_selectedDefinitionIndex!];
    final correct = chosen == current.definition;

    setState(() {
      _isAnswerChecked = true;
      _isCorrect = correct;
      if (correct) _vocabScore++;
    });
  }

  void _advanceNext() {
    setState(() {
      if (_mode == PracticeStepMode.spelling) {
        // Switch to definition sense mode for the same word
        _mode = PracticeStepMode.definitionSense;
        _setupCurrentWord();
      } else {
        // Advance to next word
        if (_currentIndex < _items.length - 1) {
          _currentIndex++;
          _mode = PracticeStepMode.spelling;
          _setupCurrentWord();
        } else {
          // Completed
          widget.onCompleted?.call(
            _spellingScore,
            _vocabScore,
            _items.length,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: Text('No vocabulary words found for this category.')),
        ),
      );
    }

    final current = _items[_currentIndex];
    final isDone = _currentIndex >= _items.length - 1 &&
        _mode == PracticeStepMode.definitionSense &&
        _isAnswerChecked;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode Header Badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _mode == PracticeStepMode.spelling
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _mode == PracticeStepMode.spelling
                        ? 'Phase 1: Spelling Recall (W1)'
                        : 'Phase 2: Vocabulary Sense Matching (W2)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _mode == PracticeStepMode.spelling
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Word ${_currentIndex + 1} of ${_items.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content according to mode
            if (_mode == PracticeStepMode.spelling) ...[
              // Prompt: Clue / Definition with masked target
              Text(
                'Type the word defined below:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${current.definition}"',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Part of speech: ${current.partOfSpeech} • Category: ${current.category}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Spelling Input Field
              TextField(
                key: const Key('spelling_input_field'),
                controller: _spellingController,
                enabled: !_isAnswerChecked,
                decoration: InputDecoration(
                  labelText: 'Your Spelling',
                  hintText: 'Type exact spelling...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.spellcheck),
                  suffixIcon: _isAnswerChecked
                      ? Icon(
                          _isCorrect ? Icons.check_circle : Icons.cancel,
                          color: _isCorrect ? Colors.green : Colors.red,
                        )
                      : null,
                ),
                onSubmitted: (_) {
                  if (!_isAnswerChecked) _checkSpelling();
                },
              ),
            ] else ...[
              // Mode 2: Vocabulary Sense Selection
              Text(
                'Select the correct definition for:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                current.word,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),

              // 4 Shuffled Choices
              ..._shuffledDefinitions.asMap().entries.map((entry) {
                final idx = entry.key;
                final def = entry.value;
                final isSelected = _selectedDefinitionIndex == idx;
                final isCorrectOption = def == current.definition;

                Color? borderColor;
                if (_isAnswerChecked) {
                  if (isCorrectOption) {
                    borderColor = Colors.green;
                  } else if (isSelected && !_isCorrect) {
                    borderColor = Colors.red;
                  }
                } else if (isSelected) {
                  borderColor = theme.colorScheme.primary;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    key: Key('vocab_option_$idx'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: _isAnswerChecked
                        ? null
                        : () => setState(() => _selectedDefinitionIndex = idx),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withOpacity(0.08)
                            : theme.colorScheme.surfaceVariant.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: borderColor ?? theme.colorScheme.outlineVariant,
                          width: isSelected || (_isAnswerChecked && isCorrectOption)
                              ? 1.8
                              : 1.0,
                        ),
                      ),
                      child: Text(
                        def,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 12),

            // Feedback Display
            if (_isAnswerChecked) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isCorrect
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCorrect ? Icons.check_circle : Icons.error,
                      color: _isCorrect ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCorrect
                            ? 'Excellent! Correct ${_mode == PracticeStepMode.spelling ? "spelling" : "definition"}.'
                            : 'Not quite. The correct answer is: ${current.word} — "${current.definition}".',
                        style: TextStyle(
                          color: _isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Button
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('practice_action_button'),
                onPressed: () {
                  if (!_isAnswerChecked) {
                    if (_mode == PracticeStepMode.spelling) {
                      _checkSpelling();
                    } else {
                      _checkDefinition();
                    }
                  } else {
                    _advanceNext();
                  }
                },
                child: Text(
                  !_isAnswerChecked
                      ? 'Check Answer'
                      : (isDone
                          ? 'Finish Practice'
                          : (_mode == PracticeStepMode.spelling
                              ? 'Practice Definition'
                              : 'Next Word')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

