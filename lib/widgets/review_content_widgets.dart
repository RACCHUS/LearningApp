import 'package:flutter/material.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:learning_pwa/theme/semantic_colors.dart';

/// Factory for creating content-type-specific review widgets
/// 
/// This enables mix-and-match of any content type in review sessions:
/// - Flashcards (terms)
/// - Multiple choice questions
/// - True/False questions
/// - Fill in the blank
/// - Concept cards
/// - Matching exercises
/// 
/// Each type has its own UI and interaction model, but all feed into
/// the same spaced repetition algorithm via [RecallQuality].
class ReviewContentFactory {
  /// Create the appropriate widget for reviewing an item
  static Widget buildReviewWidget({
    required ReviewableItem item,
    required bool showAnswer,
    required VoidCallback onReveal,
    required void Function(RecallQuality quality) onQualitySelected,
    required void Function(bool correct) onAnswerSubmitted,
  }) {
    switch (item.contentType) {
      case ReviewableContentType.term:
        return FlashcardReviewWidget(
          item: item,
          showAnswer: showAnswer,
          onReveal: onReveal,
          onQualitySelected: onQualitySelected,
        );
      case ReviewableContentType.multipleChoice:
        return MultipleChoiceReviewWidget(
          item: item,
          onAnswerSubmitted: onAnswerSubmitted,
        );
      case ReviewableContentType.trueFalse:
        return TrueFalseReviewWidget(
          item: item,
          onAnswerSubmitted: onAnswerSubmitted,
        );
      case ReviewableContentType.fillInBlank:
        return FillInBlankReviewWidget(
          item: item,
          onAnswerSubmitted: onAnswerSubmitted,
        );
      case ReviewableContentType.concept:
        return ConceptReviewWidget(
          item: item,
          showAnswer: showAnswer,
          onReveal: onReveal,
          onQualitySelected: onQualitySelected,
        );
      case ReviewableContentType.matching:
        return MatchingReviewWidget(
          item: item,
          onAnswerSubmitted: onAnswerSubmitted,
        );
      case ReviewableContentType.question:
        // Legacy question type - treat as multiple choice if has options
        if (item.metadata?['options'] != null) {
          return MultipleChoiceReviewWidget(
            item: item,
            onAnswerSubmitted: onAnswerSubmitted,
          );
        }
        return FlashcardReviewWidget(
          item: item,
          showAnswer: showAnswer,
          onReveal: onReveal,
          onQualitySelected: onQualitySelected,
        );
    }
  }
}

/// Flashcard-style review (flip to reveal answer)
class FlashcardReviewWidget extends StatelessWidget {
  final ReviewableItem item;
  final bool showAnswer;
  final VoidCallback onReveal;
  final void Function(RecallQuality quality) onQualitySelected;

  const FlashcardReviewWidget({
    super.key,
    required this.item,
    required this.showAnswer,
    required this.onReveal,
    required this.onQualitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: showAnswer ? null : onReveal,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DifficultyBadge(category: item.difficultyCategory),
                    const SizedBox(height: 16),
                    Icon(
                      showAnswer ? Icons.check_circle_outline : Icons.lightbulb_outline,
                      size: 48,
                      color: showAnswer 
                          ? theme.colorScheme.secondary 
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      showAnswer ? (item.subtitle ?? 'No definition') : item.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      showAnswer 
                          ? 'How well did you remember?' 
                          : 'Tap to reveal answer',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showAnswer) ...[
          const SizedBox(height: 16),
          _QualityButtons(onQualitySelected: onQualitySelected),
        ],
      ],
    );
  }
}

/// Multiple choice question review
class MultipleChoiceReviewWidget extends StatefulWidget {
  final ReviewableItem item;
  final void Function(bool correct) onAnswerSubmitted;

  const MultipleChoiceReviewWidget({
    super.key,
    required this.item,
    required this.onAnswerSubmitted,
  });

  @override
  State<MultipleChoiceReviewWidget> createState() => _MultipleChoiceReviewWidgetState();
}

class _MultipleChoiceReviewWidgetState extends State<MultipleChoiceReviewWidget> {
  int? _selectedIndex;
  bool _submitted = false;

  List<String> get _options {
    final opts = widget.item.metadata?['options'];
    if (opts is List) return opts.cast<String>();
    return ['Option A', 'Option B', 'Option C', 'Option D'];
  }

  int get _correctIndex {
    return widget.item.metadata?['correctIndex'] as int? ?? 0;
  }

  void _submit() {
    if (_selectedIndex == null) return;
    setState(() => _submitted = true);
    
    // Delay to show result, then callback
    Future.delayed(const Duration(milliseconds: 800), () {
      widget.onAnswerSubmitted(_selectedIndex == _correctIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Question
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.item.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Options
        Expanded(
          child: ListView.separated(
            itemCount: _options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              final isCorrect = index == _correctIndex;
              
              Color? backgroundColor;
              if (_submitted) {
                if (isCorrect) {
                  backgroundColor = Colors.green.withValues(alpha: 0.2);
                } else if (isSelected && !isCorrect) {
                  backgroundColor = Colors.red.withValues(alpha: 0.2);
                }
              }

              return Card(
                color: backgroundColor ?? (isSelected 
                    ? theme.colorScheme.primaryContainer 
                    : null),
                child: InkWell(
                  onTap: _submitted ? null : () {
                    setState(() => _selectedIndex = index);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected 
                                  ? theme.colorScheme.primary 
                                  : theme.colorScheme.outline,
                              width: 2,
                            ),
                            color: isSelected 
                                ? theme.colorScheme.primary 
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index), // A, B, C, D
                              style: TextStyle(
                                color: isSelected 
                                    ? theme.colorScheme.onPrimary 
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _options[index],
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        if (_submitted && isCorrect)
                          const Icon(Icons.check_circle, color: Colors.green),
                        if (_submitted && isSelected && !isCorrect)
                          const Icon(Icons.cancel, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (!_submitted)
          FilledButton(
            onPressed: _selectedIndex != null ? _submit : null,
            child: const Text('Submit Answer'),
          ),
      ],
    );
  }
}

/// True/False question review
class TrueFalseReviewWidget extends StatefulWidget {
  final ReviewableItem item;
  final void Function(bool correct) onAnswerSubmitted;

  const TrueFalseReviewWidget({
    super.key,
    required this.item,
    required this.onAnswerSubmitted,
  });

  @override
  State<TrueFalseReviewWidget> createState() => _TrueFalseReviewWidgetState();
}

class _TrueFalseReviewWidgetState extends State<TrueFalseReviewWidget> {
  bool? _selectedAnswer;
  bool _submitted = false;

  bool get _correctAnswer {
    return widget.item.metadata?['correctAnswer'] as bool? ?? true;
  }

  void _submit(bool answer) {
    setState(() {
      _selectedAnswer = answer;
      _submitted = true;
    });
    
    Future.delayed(const Duration(milliseconds: 800), () {
      widget.onAnswerSubmitted(answer == _correctAnswer);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.item.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_submitted) ...[
                    const SizedBox(height: 24),
                    Icon(
                      _selectedAnswer == _correctAnswer 
                          ? Icons.check_circle 
                          : Icons.cancel,
                      size: 48,
                      color: _selectedAnswer == _correctAnswer 
                        ? semantic.success
                        : semantic.danger,
                    ),
                    Text(
                      _selectedAnswer == _correctAnswer 
                          ? 'Correct!' 
                          : 'The answer is ${_correctAnswer ? "True" : "False"}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_submitted)
          Row(
            children: [
              Expanded(
                child: _TrueFalseButton(
                  label: 'True',
                  icon: Icons.check,
                  color: semantic.success,
                  foregroundColor: semantic.onSuccess,
                  onPressed: () => _submit(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TrueFalseButton(
                  label: 'False',
                  icon: Icons.close,
                  color: semantic.danger,
                  foregroundColor: semantic.onDanger,
                  onPressed: () => _submit(false),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TrueFalseButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color foregroundColor;
  final VoidCallback onPressed;

  const _TrueFalseButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.foregroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
        ),
      ),
    );
  }
}

/// Fill in the blank review
class FillInBlankReviewWidget extends StatefulWidget {
  final ReviewableItem item;
  final void Function(bool correct) onAnswerSubmitted;

  const FillInBlankReviewWidget({
    super.key,
    required this.item,
    required this.onAnswerSubmitted,
  });

  @override
  State<FillInBlankReviewWidget> createState() => _FillInBlankReviewWidgetState();
}

class _FillInBlankReviewWidgetState extends State<FillInBlankReviewWidget> {
  final _controller = TextEditingController();
  bool _submitted = false;
  bool? _isCorrect;

  String get _correctAnswer {
    return widget.item.metadata?['correctAnswer'] as String? ?? '';
  }

  List<String> get _acceptableAnswers {
    final answers = widget.item.metadata?['acceptableAnswers'];
    if (answers is List) {
      return [_correctAnswer, ...answers.cast<String>()];
    }
    return [_correctAnswer, _correctAnswer.toLowerCase()];
  }

  void _submit() {
    final answer = _controller.text.trim();
    final correct = _acceptableAnswers.any(
      (a) => a.toLowerCase() == answer.toLowerCase(),
    );
    
    setState(() {
      _submitted = true;
      _isCorrect = correct;
    });
    
    Future.delayed(const Duration(milliseconds: 800), () {
      widget.onAnswerSubmitted(correct);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    return Column(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.item.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!_submitted)
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type your answer...',
                        border: OutlineInputBorder(),
                      ),
                      textAlign: TextAlign.center,
                      onSubmitted: (_) => _submit(),
                    ),
                  if (_submitted) ...[
                    Icon(
                      _isCorrect! ? Icons.check_circle : Icons.cancel,
                      size: 48,
                      color: _isCorrect! ? semantic.success : semantic.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isCorrect! ? 'Correct!' : 'Answer: $_correctAnswer',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_submitted)
          FilledButton(
            onPressed: _controller.text.isNotEmpty ? _submit : null,
            child: const Text('Submit Answer'),
          ),
      ],
    );
  }
}

/// Concept card review (similar to flashcard but focused on understanding)
class ConceptReviewWidget extends StatelessWidget {
  final ReviewableItem item;
  final bool showAnswer;
  final VoidCallback onReveal;
  final void Function(RecallQuality quality) onQualitySelected;

  const ConceptReviewWidget({
    super.key,
    required this.item,
    required this.showAnswer,
    required this.onReveal,
    required this.onQualitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: showAnswer ? null : onReveal,
            child: Card(
              color: theme.colorScheme.primaryContainer,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DifficultyBadge(category: item.difficultyCategory),
                    const SizedBox(height: 16),
                    Icon(
                      Icons.psychology_outlined,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      showAnswer ? 'Explanation' : 'Concept',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      showAnswer ? (item.subtitle ?? 'No explanation') : item.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (!showAnswer)
                      Text(
                        'Tap to reveal explanation',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    if (showAnswer)
                      Text(
                        'Did you understand this concept?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showAnswer) ...[
          const SizedBox(height: 16),
          _QualityButtons(onQualitySelected: onQualitySelected),
        ],
      ],
    );
  }
}

/// Matching pairs review
class MatchingReviewWidget extends StatefulWidget {
  final ReviewableItem item;
  final void Function(bool correct) onAnswerSubmitted;

  const MatchingReviewWidget({
    super.key,
    required this.item,
    required this.onAnswerSubmitted,
  });

  @override
  State<MatchingReviewWidget> createState() => _MatchingReviewWidgetState();
}

class _MatchingReviewWidgetState extends State<MatchingReviewWidget> {
  final Map<String, String?> _matches = {};
  String? _selectedLeft;
  bool _submitted = false;
  int _correctCount = 0;

  List<Map<String, String>> get _pairs {
    final pairs = widget.item.metadata?['pairs'];
    if (pairs is List) {
      return pairs.map((p) => Map<String, String>.from(p as Map)).toList();
    }
    return [];
  }

  List<String> get _leftItems => _pairs.map((p) => p['left']!).toList();
  
  List<String> get _rightItems {
    // Shuffle right items for the challenge
    final items = _pairs.map((p) => p['right']!).toList();
    items.shuffle();
    return items;
  }

  void _submit() {
    int correct = 0;
    for (final pair in _pairs) {
      if (_matches[pair['left']] == pair['right']) {
        correct++;
      }
    }
    
    setState(() {
      _submitted = true;
      _correctCount = correct;
    });
    
    Future.delayed(const Duration(milliseconds: 1200), () {
      widget.onAnswerSubmitted(correct == _pairs.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_pairs.isEmpty) {
      return Center(
        child: Text(
          'No matching pairs configured',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    return Column(
      children: [
        Text(
          widget.item.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              // Left column
              Expanded(
                child: ListView.separated(
                  itemCount: _leftItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _leftItems[index];
                    final isSelected = _selectedLeft == item;
                    final isMatched = _matches[item] != null;
                    
                    return Card(
                      color: isSelected 
                          ? theme.colorScheme.primaryContainer 
                          : isMatched 
                              ? theme.colorScheme.secondaryContainer 
                              : null,
                      child: InkWell(
                        onTap: _submitted ? null : () {
                          setState(() => _selectedLeft = item);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            item,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Right column
              Expanded(
                child: ListView.separated(
                  itemCount: _rightItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _rightItems[index];
                    final isMatched = _matches.containsValue(item);
                    
                    return Card(
                      color: isMatched 
                          ? theme.colorScheme.secondaryContainer 
                          : null,
                      child: InkWell(
                        onTap: (_submitted || _selectedLeft == null) ? null : () {
                          setState(() {
                            _matches[_selectedLeft!] = item;
                            _selectedLeft = null;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            item,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_submitted)
          Text(
            '$_correctCount/${_pairs.length} correct',
            style: theme.textTheme.titleMedium?.copyWith(
              color: _correctCount == _pairs.length 
                  ? semantic.success
                  : semantic.warning,
            ),
          ),
        if (!_submitted)
          FilledButton(
            onPressed: _matches.length == _pairs.length ? _submit : null,
            child: const Text('Check Matches'),
          ),
      ],
    );
  }
}

/// Reusable quality rating buttons
class _QualityButtons extends StatelessWidget {
  final void Function(RecallQuality quality) onQualitySelected;

  const _QualityButtons({required this.onQualitySelected});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _QualityButton(
                quality: RecallQuality.blackout,
                label: 'Forgot',
                color: semantic.danger,
                foregroundColor: semantic.onDanger,
                onTap: () => onQualitySelected(RecallQuality.blackout),
              ),
              _QualityButton(
                quality: RecallQuality.difficult,
                label: 'Hard',
                color: semantic.warning,
                foregroundColor: semantic.onWarning,
                onTap: () => onQualitySelected(RecallQuality.difficult),
              ),
              _QualityButton(
                quality: RecallQuality.good,
                label: 'Good',
                color: semantic.info,
                foregroundColor: semantic.onInfo,
                onTap: () => onQualitySelected(RecallQuality.good),
              ),
              _QualityButton(
                quality: RecallQuality.perfect,
                label: 'Easy',
                color: semantic.success,
                foregroundColor: semantic.onSuccess,
                onTap: () => onQualitySelected(RecallQuality.perfect),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QualityButton extends StatelessWidget {
  final RecallQuality quality;
  final String label;
  final Color color;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _QualityButton({
    required this.quality,
    required this.label,
    required this.color,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: foregroundColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}

/// Small colored pill showing how well-learned an item is (SM-2 derived).
class DifficultyBadge extends StatelessWidget {
  final DifficultyCategory category;

  const DifficultyBadge({super.key, required this.category});

  static Color colorFor(DifficultyCategory category) {
    switch (category) {
      case DifficultyCategory.learning:
        return const Color(0xFFE53935); // red — needs work
      case DifficultyCategory.familiar:
        return const Color(0xFFF9A825); // amber — getting there
      case DifficultyCategory.mastered:
        return const Color(0xFF43A047); // green — solid
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(category);
    return Semantics(
      label: 'Difficulty: ${category.displayName}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              category.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
